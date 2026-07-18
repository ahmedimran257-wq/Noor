-- Complete the profile-photo privacy workflow with server-authoritative RPCs.
-- The client never decides whether a viewer may receive a signed photo URL.

CREATE OR REPLACE FUNCTION public.get_photo_access_context(p_owner_id uuid)
RETURNS TABLE (
  photo_privacy text,
  is_mutual boolean,
  request_status text,
  can_view boolean,
  photo_count integer
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_viewer uuid := auth.uid();
  v_profile_id uuid;
  v_privacy text;
BEGIN
  IF v_viewer IS NULL THEN
    RAISE EXCEPTION 'Authentication required.';
  END IF;

  SELECT p.id, p.photo_privacy
  INTO v_profile_id, v_privacy
  FROM public.profiles p
  WHERE (p.user_id = p_owner_id OR p.id = p_owner_id)
    AND (p.user_id = v_viewer OR p.visibility = 'visible')
  LIMIT 1;

  IF v_profile_id IS NULL THEN
    RAISE EXCEPTION 'Profile is unavailable.';
  END IF;

  RETURN QUERY
  SELECT
    v_privacy,
    EXISTS (
      SELECT 1
      FROM public.matches m
      JOIN public.profiles owner_profile ON owner_profile.id = v_profile_id
      WHERE m.status = 'active'
        AND (
          (m.user_a = v_viewer AND m.user_b = owner_profile.user_id)
          OR (m.user_b = v_viewer AND m.user_a = owner_profile.user_id)
        )
    ),
    (
      SELECT par.status
      FROM public.photo_access_requests par
      JOIN public.profiles owner_profile ON owner_profile.id = v_profile_id
      WHERE par.requester_id = v_viewer
        AND par.owner_id = owner_profile.user_id
      LIMIT 1
    ),
    public.can_view_photo(v_viewer, v_profile_id),
    (
      SELECT count(*)::integer
      FROM public.photos ph
      WHERE ph.profile_id = v_profile_id
        AND ph.status = 'active'
        AND ph.admin_approved = true
        AND ph.nsfw_cleared = true
    );
END;
$$;

CREATE OR REPLACE FUNCTION public.request_photo_access(p_owner_id uuid)
RETURNS TABLE (request_id uuid, request_status text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
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
$$;

CREATE OR REPLACE FUNCTION public.respond_to_photo_access_request(
  p_request_id uuid,
  p_decision text
)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_owner uuid := auth.uid();
  v_status text;
BEGIN
  IF v_owner IS NULL THEN RAISE EXCEPTION 'Authentication required.'; END IF;
  IF p_decision NOT IN ('granted', 'denied') THEN
    RAISE EXCEPTION 'Decision must be granted or denied.';
  END IF;

  UPDATE public.photo_access_requests
  SET status = p_decision, responded_at = now()
  WHERE id = p_request_id
    AND owner_id = v_owner
    AND status IN ('pending', 'denied', 'revoked')
  RETURNING status INTO v_status;

  IF v_status IS NULL THEN RAISE EXCEPTION 'Photo request is unavailable.'; END IF;
  RETURN v_status;
END;
$$;

CREATE OR REPLACE FUNCTION public.revoke_photo_access(p_request_id uuid)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_status text;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required.'; END IF;
  UPDATE public.photo_access_requests
  SET status = 'revoked', responded_at = now()
  WHERE id = p_request_id
    AND owner_id = auth.uid()
    AND status = 'granted'
  RETURNING status INTO v_status;
  IF v_status IS NULL THEN RAISE EXCEPTION 'Granted access was not found.'; END IF;
  RETURN v_status;
END;
$$;

CREATE OR REPLACE FUNCTION public.cancel_photo_access_request(p_owner_id uuid)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_status text;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required.'; END IF;
  UPDATE public.photo_access_requests par
  SET status = 'revoked', responded_at = now()
  FROM public.profiles owner_profile
  WHERE par.requester_id = auth.uid()
    AND par.owner_id = owner_profile.user_id
    AND (owner_profile.user_id = p_owner_id OR owner_profile.id = p_owner_id)
    AND par.status = 'pending'
  RETURNING par.status INTO v_status;
  IF v_status IS NULL THEN RAISE EXCEPTION 'Pending request was not found.'; END IF;
  RETURN v_status;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_incoming_photo_access_requests()
RETURNS TABLE (
  request_id uuid,
  requester_id uuid,
  first_name text,
  last_name_initial text,
  status text,
  created_at timestamptz,
  responded_at timestamptz
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    par.id,
    par.requester_id,
    coalesce(p.first_name, 'Member'),
    left(coalesce(p.last_name, ''), 1),
    par.status,
    par.created_at,
    par.responded_at
  FROM public.photo_access_requests par
  LEFT JOIN public.profiles p ON p.user_id = par.requester_id
  WHERE par.owner_id = auth.uid()
  ORDER BY
    CASE par.status WHEN 'pending' THEN 0 WHEN 'granted' THEN 1 ELSE 2 END,
    par.created_at DESC;
$$;

-- Notify on first request and on a legitimate retry after denial/revocation.
CREATE OR REPLACE FUNCTION public.notify_photo_access_request()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_requester_name text;
BEGIN
  IF NEW.status <> 'pending' OR
     (TG_OP = 'UPDATE' AND OLD.status = NEW.status) THEN
    RETURN NEW;
  END IF;
  SELECT first_name INTO v_requester_name
  FROM public.profiles WHERE user_id = NEW.requester_id;
  PERFORM public.queue_notification(
    NEW.owner_id,
    'photo_access_request',
    'Photo access request',
    format('%s would like to see your photos', coalesce(v_requester_name, 'Someone')),
    'silarah://photo-requests'
  );
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_photo_access_request ON public.photo_access_requests;
CREATE TRIGGER trg_notify_photo_access_request
  AFTER INSERT OR UPDATE OF status ON public.photo_access_requests
  FOR EACH ROW EXECUTE FUNCTION public.notify_photo_access_request();

CREATE OR REPLACE FUNCTION public.notify_photo_access_granted()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_owner_name text;
BEGIN
  IF NEW.status = 'granted' AND OLD.status IS DISTINCT FROM 'granted' THEN
    SELECT first_name INTO v_owner_name
    FROM public.profiles WHERE user_id = NEW.owner_id;
    PERFORM public.queue_notification(
      NEW.requester_id,
      'photo_access_granted',
      'Photo access granted',
      format('%s has shared their photos with you', coalesce(v_owner_name, 'Someone')),
      format('silarah://profile/%s', NEW.owner_id)
    );
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_photo_access_granted ON public.photo_access_requests;
CREATE TRIGGER trg_notify_photo_access_granted
  AFTER UPDATE OF status ON public.photo_access_requests
  FOR EACH ROW EXECUTE FUNCTION public.notify_photo_access_granted();

REVOKE ALL ON FUNCTION public.get_photo_access_context(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.request_photo_access(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.respond_to_photo_access_request(uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.revoke_photo_access(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.cancel_photo_access_request(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_incoming_photo_access_requests() FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.get_photo_access_context(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.request_photo_access(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.respond_to_photo_access_request(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.revoke_photo_access(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.cancel_photo_access_request(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_incoming_photo_access_requests() TO authenticated;

-- Deliver owner request-list changes without a manual refresh. Guard the
-- publication edit so the migration stays idempotent across environments.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'photo_access_requests'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.photo_access_requests;
  END IF;
END;
$$;
