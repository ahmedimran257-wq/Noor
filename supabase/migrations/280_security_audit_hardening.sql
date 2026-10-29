-- Silarah — security audit fixes (October 2026).
--
-- 1. Server-only functions. Earlier migrations ran REVOKE ... FROM PUBLIC and
--    GRANT ... TO service_role, but Supabase also grants EXECUTE directly to
--    anon and authenticated when a function is created, and a PUBLIC revoke
--    does not remove those grants. Signed-in members could therefore call
--    worker functions. Most of them re-check auth.role() inside, but
--    claim_transactional_email did not: any member could claim a queued
--    billing email and read its purchase details. Remove the member grants
--    from every function the migrations meant for the server alone, and from
--    compute_reporter_trust_score, which disclosed how many reports any
--    member had against them.
--
-- 2. can_view_photo trusted the viewer id passed by the caller, so any member
--    could ask whether any other two members were matched or had shared
--    photos. Bind the viewer to the signed-in caller; workers keep any
--    viewer. can_access_chat_realtime_topic gets the same binding.
--
-- 3. Blocking someone must cut off their view of your photos. The photo
--    signer still served a blocker's photos to the blocked member through an
--    old interest, closed match, bookmark or granted request, and a blocked
--    member could keep sending photo access requests (and notifications).

-- 1. Server-only functions --------------------------------------------------

DO $$
DECLARE
  v_function regprocedure;
BEGIN
  FOR v_function IN
    SELECT p.oid::regprocedure
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname IN (
        'begin_admin_login_attempt',
        'begin_worker_run',
        'checkout_account_purge_jobs',
        'checkout_notifications',
        'checkout_storage_deletions',
        'claim_transactional_email',
        'compute_reporter_trust_score',
        'consume_upload_reservation',
        'expire_upload_reservations',
        'finish_account_purge_phase',
        'finish_admin_login_attempt',
        'finish_notification_delivery',
        'finish_storage_deletion',
        'finish_worker_run',
        'is_disposable_email_domain',
        'record_notification_token_delivery',
        'request_profile_photo_deletion'
      )
  LOOP
    EXECUTE format(
      'REVOKE EXECUTE ON FUNCTION %s FROM PUBLIC, anon, authenticated',
      v_function
    );
    EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO service_role', v_function);
  END LOOP;
END;
$$;

-- 2. Caller-bound relationship checks -------------------------------------

CREATE OR REPLACE FUNCTION public.can_view_photo(p_viewer uuid, p_owner_profile uuid)
RETURNS boolean
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_owner_user_id uuid;
  v_privacy       text;
BEGIN
  -- Anonymous: never
  IF p_viewer IS NULL THEN RETURN false; END IF;

  -- Members may only ask about themselves; workers may ask about anyone.
  IF p_viewer IS DISTINCT FROM auth.uid()
     AND coalesce(auth.role(), '') <> 'service_role' THEN
    RETURN false;
  END IF;

  -- Own photos: always visible
  IF EXISTS (
    SELECT 1 FROM profiles WHERE id = p_owner_profile AND user_id = p_viewer
  ) THEN RETURN true; END IF;

  -- Get the owner's privacy setting and user_id
  SELECT pr.photo_privacy, pr.user_id INTO v_privacy, v_owner_user_id
  FROM profiles pr
  WHERE pr.id = p_owner_profile
    AND pr.visibility = 'visible';

  IF v_privacy IS NULL THEN RETURN false; END IF;

  -- Public: visible to all
  IF v_privacy = 'public' THEN RETURN true; END IF;

  -- Mutual_only: viewer must have an accepted match with the owner
  IF v_privacy = 'mutual_only' THEN
    IF EXISTS (
      SELECT 1
      FROM matches m
      WHERE m.status = 'active'
        AND (
          (m.user_a = p_viewer AND m.user_b = v_owner_user_id)
          OR (m.user_b = p_viewer AND m.user_a = v_owner_user_id)
        )
    ) THEN RETURN true; END IF;
    RETURN false;
  END IF;

  -- Request_only: viewer must have been granted access
  IF v_privacy = 'request_only' THEN
    IF EXISTS (
      SELECT 1 FROM photo_access_requests par
      WHERE par.requester_id = p_viewer
        AND par.owner_id = v_owner_user_id
        AND par.status = 'granted'
    ) THEN RETURN true; END IF;
    RETURN false;
  END IF;

  RETURN false;
END;
$function$;

CREATE OR REPLACE FUNCTION public.can_access_chat_realtime_topic(
  p_topic text,
  p_user_id uuid DEFAULT auth.uid()
)
RETURNS boolean
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $function$
  SELECT p_user_id IS NOT NULL
    AND (
      p_user_id = auth.uid()
      OR coalesce(auth.role(), '') = 'service_role'
    )
    AND EXISTS (
      SELECT 1
      FROM public.matches m
      WHERE p_topic = 'chat:' || m.id::text
        AND (m.user_a = p_user_id OR m.user_b = p_user_id)
        AND coalesce(m.status, 'active') = 'active'
    );
$function$;

-- 3. Blocks cut off photos and photo requests ------------------------------

CREATE OR REPLACE FUNCTION public.get_authorized_photo_paths(
  p_viewer_user_id uuid,
  p_owner_user_ids uuid[],
  p_order_index integer
)
RETURNS TABLE(owner_user_id uuid, storage_path text)
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path TO ''
AS $function$
  SELECT owner.user_id, ph.storage_path
  FROM public.profiles owner
  JOIN public.photos ph ON ph.profile_id = owner.id
  JOIN public.users owner_account ON owner_account.id = owner.user_id
  WHERE auth.role() = 'service_role'
    AND p_order_index BETWEEN 0 AND 3
    AND owner.user_id = ANY(
      ARRAY(
        SELECT DISTINCT requested_id
        FROM unnest(coalesce(p_owner_user_ids, ARRAY[]::uuid[])) requested_id
        LIMIT 50
      )
    )
    AND owner_account.deleted_at IS NULL
    AND private.can_access_incognito_profile(p_viewer_user_id, owner.user_id)
    AND coalesce(owner_account.is_banned, false) = false
    AND ph.order_index = p_order_index
    AND ph.status = 'active'
    AND ph.admin_approved = true
    AND ph.nsfw_cleared = true
    AND public.can_view_photo(p_viewer_user_id, owner.id)
    -- A block in either direction ends every route below except your own.
    AND (
      owner.user_id = p_viewer_user_id
      OR NOT EXISTS (
        SELECT 1
        FROM public.blocks pair_block
        WHERE (pair_block.blocker_id = p_viewer_user_id AND pair_block.blocked_id = owner.user_id)
           OR (pair_block.blocker_id = owner.user_id AND pair_block.blocked_id = p_viewer_user_id)
      )
    )
    AND (
      owner.user_id = p_viewer_user_id
      OR EXISTS (
        SELECT 1
        FROM public.live_discovery_pool candidate
        JOIN public.profiles viewer ON viewer.user_id = p_viewer_user_id
        JOIN public.users viewer_account ON viewer_account.id = viewer.user_id
        WHERE candidate.profile_id = owner.id
          AND candidate.user_id = owner.user_id
          AND owner.user_id <> p_viewer_user_id
          AND viewer.visibility = 'visible'
          AND coalesce(viewer.onboarding_completed, false) = true
          AND viewer.approved_at IS NOT NULL
          AND viewer_account.deleted_at IS NULL
          AND coalesce(viewer_account.is_banned, false) = false
          AND owner.visibility = 'visible'
          AND coalesce(owner.onboarding_completed, false) = true
          AND owner.approved_at IS NOT NULL
          AND candidate.photo_count > 0
          AND lower(candidate.gender::text) <> lower(viewer.gender::text)
          AND NOT EXISTS (
            SELECT 1
            FROM public.blocks b
            WHERE (b.blocker_id = p_viewer_user_id AND b.blocked_id = owner.user_id)
               OR (b.blocker_id = owner.user_id AND b.blocked_id = p_viewer_user_id)
          )
      )
      OR EXISTS (
        SELECT 1
        FROM public.profile_view_daily_seen s
        WHERE s.viewer_user_id = p_viewer_user_id
          AND s.viewed_profile_id = owner.id
          AND s.viewed_on = current_date
      )
      OR EXISTS (
        SELECT 1
        FROM public.interests i
        WHERE (i.sender_id = p_viewer_user_id AND i.receiver_id = owner.user_id)
           OR (i.receiver_id = p_viewer_user_id AND i.sender_id = owner.user_id)
      )
      OR EXISTS (
        SELECT 1
        FROM public.matches m
        WHERE (m.user_a = p_viewer_user_id AND m.user_b = owner.user_id)
           OR (m.user_b = p_viewer_user_id AND m.user_a = owner.user_id)
      )
      OR EXISTS (
        SELECT 1
        FROM public.profile_bookmarks b
        WHERE b.user_id = p_viewer_user_id
          AND b.saved_user_id = owner.user_id
      )
      OR EXISTS (
        SELECT 1
        FROM public.photo_access_requests par
        WHERE par.requester_id = p_viewer_user_id
          AND par.owner_id = owner.user_id
          AND par.status = 'granted'
      )
      OR (
        public.has_active_premium(p_viewer_user_id)
        AND EXISTS (
          SELECT 1
          FROM public.profile_views recent_view
          JOIN public.profiles mine ON mine.id = recent_view.viewed_profile_id
          WHERE mine.user_id = p_viewer_user_id
            AND recent_view.viewer_profile_id = owner.id
            AND recent_view.viewed_at >= now() - interval '7 days'
        )
        AND NOT EXISTS (
          SELECT 1
          FROM public.blocks blocked_pair
          WHERE (blocked_pair.blocker_id = p_viewer_user_id AND blocked_pair.blocked_id = owner.user_id)
             OR (blocked_pair.blocker_id = owner.user_id AND blocked_pair.blocked_id = p_viewer_user_id)
        )
      )
      OR owner.guardian_user_id = p_viewer_user_id
    );
$function$;

CREATE OR REPLACE FUNCTION public.request_photo_access(p_owner_id uuid)
RETURNS TABLE(request_id uuid, request_status text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_requester uuid := auth.uid();
  v_owner uuid;
  v_existing public.photo_access_requests%ROWTYPE;
  v_result public.photo_access_requests%ROWTYPE;
  v_today_count integer;
BEGIN
  IF v_requester IS NULL THEN
    RAISE EXCEPTION 'Authentication required.';
  END IF;

  SELECT p.user_id INTO v_owner
  FROM public.profiles p
  WHERE (p.user_id = p_owner_id OR p.id = p_owner_id)
    AND p.visibility = 'visible'
    AND p.photo_privacy = 'request_only'
  LIMIT 1;

  IF v_owner IS NULL OR v_owner = v_requester THEN
    RAISE EXCEPTION 'This profile is not accepting photo access requests.';
  END IF;

  IF NOT private.can_access_incognito_profile(v_requester, v_owner) THEN
    RAISE EXCEPTION 'This profile is not accepting photo access requests.';
  END IF;

  -- Same message as an unavailable profile, so a block is not revealed.
  IF EXISTS (
    SELECT 1
    FROM public.blocks b
    WHERE (b.blocker_id = v_requester AND b.blocked_id = v_owner)
       OR (b.blocker_id = v_owner AND b.blocked_id = v_requester)
  ) THEN
    RAISE EXCEPTION 'This profile is not accepting photo access requests.';
  END IF;

  SELECT * INTO v_existing
  FROM public.photo_access_requests
  WHERE requester_id = v_requester AND owner_id = v_owner
  FOR UPDATE;

  IF v_existing.id IS NOT NULL AND v_existing.status IN ('pending', 'granted') THEN
    RETURN QUERY SELECT v_existing.id, v_existing.status;
    RETURN;
  END IF;

  SELECT count(*)::integer INTO v_today_count
  FROM public.photo_access_requests
  WHERE requester_id = v_requester
    AND created_at >= date_trunc('day', now());

  IF v_today_count >= 10 THEN
    RAISE EXCEPTION 'You can send up to 10 photo access requests per day.';
  END IF;

  INSERT INTO public.photo_access_requests (
    requester_id, owner_id, status, created_at, responded_at
  ) VALUES (
    v_requester, v_owner, 'pending', now(), NULL
  )
  ON CONFLICT (requester_id, owner_id) DO UPDATE SET
    status = 'pending',
    created_at = now(),
    responded_at = NULL
  RETURNING * INTO v_result;

  RETURN QUERY SELECT v_result.id, v_result.status;
END;
$function$;
