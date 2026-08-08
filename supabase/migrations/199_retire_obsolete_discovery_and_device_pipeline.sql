-- Remove superseded discovery infrastructure and unsafe compatibility RPCs.
-- Interactive discovery has used live_discovery_pool since migration 132.

DO $migration$
DECLARE
  v_job record;
BEGIN
  IF to_regclass('cron.job') IS NULL THEN
    RETURN;
  END IF;

  FOR v_job IN
    SELECT jobid
    FROM cron.job
    WHERE jobname IN (
      'refresh_discovery_pool_daily',
      'refresh_recommendations_recent_viewers_10m'
    )
  LOOP
    PERFORM cron.unschedule(v_job.jobid);
  END LOOP;
END;
$migration$;

-- Profile projections authorize active relationships and explicitly viewed
-- profiles. The retired recommendations table must not remain on this path.
CREATE OR REPLACE FUNCTION public.get_authorized_member_profiles(
  p_user_ids uuid[]
)
RETURNS SETOF jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_me uuid := auth.uid();
  v_ids uuid[];
BEGIN
  PERFORM private.assert_authenticated();
  v_ids := ARRAY(
    SELECT DISTINCT requested_id
    FROM unnest(coalesce(p_user_ids, ARRAY[]::uuid[])) requested_id
    WHERE requested_id IS NOT NULL
    LIMIT 50
  );
  IF cardinality(v_ids) = 0 THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT jsonb_build_object(
    'id', p.id,
    'user_id', p.user_id,
    'first_name', p.first_name,
    'last_name', p.last_name,
    'last_name_initial', left(coalesce(p.last_name, ''), 1),
    'age', date_part('year', age(current_date, p.date_of_birth))::integer,
    'gender', p.gender,
    'city_name', c.name,
    'country_code', p.country_code,
    'sect', p.sect,
    'deen_level', p.deen_level,
    'photo_privacy', p.photo_privacy,
    'bio', p.bio,
    'profession', p.profession,
    'education_level', p.education_level,
    'education_rank', p.education_rank,
    'family_type', p.family_type,
    'previously_married', p.previously_married,
    'children_count', p.children_count,
    'mother_tongue', p.mother_tongue,
    'community', p.community,
    'diet_type', p.diet_type,
    'living_expectation', p.living_expectation,
    'quran_memorization', p.quran_memorization,
    'religious_education', p.religious_education,
    'marriage_timeline', p.marriage_timeline,
    'willing_to_relocate', p.willing_to_relocate,
    'height_cm', p.height_cm,
    'complexion', p.complexion,
    'smoking_habit', p.smoking_habit,
    'vaping_habit', p.vaping_habit,
    'hookah_habit', p.hookah_habit,
    'languages', coalesce(p.languages, ARRAY[]::text[]),
    'interests', coalesce(p.interests, ARRAY[]::text[]),
    'last_active_at', p.last_active_at,
    'is_verified', p.is_verified
  )
  FROM public.profiles p
  JOIN public.users u ON u.id = p.user_id
  LEFT JOIN public.cities c ON c.id = p.city_id
  WHERE p.user_id = ANY(v_ids)
    AND coalesce(u.is_banned, false) = false
    AND u.deleted_at IS NULL
    AND (
      p.user_id = v_me
      OR EXISTS (
        SELECT 1 FROM public.profile_view_daily_seen s
        WHERE s.viewer_user_id = v_me
          AND s.viewed_profile_id = p.id
          AND s.viewed_on = current_date
      )
      OR EXISTS (
        SELECT 1 FROM public.interests i
        WHERE (i.sender_id = v_me AND i.receiver_id = p.user_id)
           OR (i.receiver_id = v_me AND i.sender_id = p.user_id)
      )
      OR EXISTS (
        SELECT 1 FROM public.matches m
        WHERE (m.user_a = v_me AND m.user_b = p.user_id)
           OR (m.user_b = v_me AND m.user_a = p.user_id)
      )
      OR EXISTS (
        SELECT 1 FROM public.profile_bookmarks b
        WHERE b.user_id = v_me AND b.saved_user_id = p.user_id
      )
      OR EXISTS (
        SELECT 1 FROM public.photo_access_requests par
        WHERE par.requester_id = v_me
          AND par.owner_id = p.user_id
          AND par.status = 'granted'
      )
      OR EXISTS (
        SELECT 1 FROM public.blocks b
        WHERE (b.blocker_id = v_me AND b.blocked_id = p.user_id)
           OR (b.blocked_id = v_me AND b.blocker_id = p.user_id)
      )
      OR EXISTS (
        SELECT 1 FROM public.reports r
        WHERE r.reporter_id = v_me AND r.reported_user_id = p.user_id
      )
      OR p.guardian_user_id = v_me
      OR EXISTS (
        SELECT 1
        FROM public.guardian_chat_mirrors gcm
        JOIN public.matches gm ON gm.id = gcm.match_id
        WHERE gcm.guardian_id = v_me
          AND (
            p.user_id = gcm.ward_id
            OR (gm.user_a = gcm.ward_id AND p.user_id = gm.user_b)
            OR (gm.user_b = gcm.ward_id AND p.user_id = gm.user_a)
          )
      )
    )
  ORDER BY array_position(v_ids, p.user_id);
END;
$$;

REVOKE ALL ON FUNCTION public.get_authorized_member_profiles(uuid[])
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_authorized_member_profiles(uuid[])
  TO authenticated;

CREATE OR REPLACE FUNCTION public.get_authorized_photo_paths(
  p_viewer_user_id uuid,
  p_owner_user_ids uuid[],
  p_order_index integer
)
RETURNS TABLE(owner_user_id uuid, storage_path text)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
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
    AND coalesce(owner_account.is_banned, false) = false
    AND ph.order_index = p_order_index
    AND ph.status = 'active'
    AND ph.admin_approved = true
    AND ph.nsfw_cleared = true
    AND public.can_view_photo(p_viewer_user_id, owner.id)
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
        SELECT 1 FROM public.profile_view_daily_seen s
        WHERE s.viewer_user_id = p_viewer_user_id
          AND s.viewed_profile_id = owner.id
          AND s.viewed_on = current_date
      )
      OR EXISTS (
        SELECT 1 FROM public.interests i
        WHERE (i.sender_id = p_viewer_user_id AND i.receiver_id = owner.user_id)
           OR (i.receiver_id = p_viewer_user_id AND i.sender_id = owner.user_id)
      )
      OR EXISTS (
        SELECT 1 FROM public.matches m
        WHERE (m.user_a = p_viewer_user_id AND m.user_b = owner.user_id)
           OR (m.user_b = p_viewer_user_id AND m.user_a = owner.user_id)
      )
      OR EXISTS (
        SELECT 1 FROM public.profile_bookmarks b
        WHERE b.user_id = p_viewer_user_id
          AND b.saved_user_id = owner.user_id
      )
      OR EXISTS (
        SELECT 1 FROM public.photo_access_requests par
        WHERE par.requester_id = p_viewer_user_id
          AND par.owner_id = owner.user_id
          AND par.status = 'granted'
      )
      OR owner.guardian_user_id = p_viewer_user_id
    );
$$;

REVOKE ALL ON FUNCTION public.get_authorized_photo_paths(uuid, uuid[], integer)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_authorized_photo_paths(uuid, uuid[], integer)
  TO service_role;

COMMENT ON FUNCTION public.get_authorized_photo_paths(uuid, uuid[], integer) IS
  'Service-only private photo paths for live discovery candidates and established member relationships.';

DROP FUNCTION IF EXISTS public.refresh_recommendations_for_recent_viewers(integer) RESTRICT;
DROP FUNCTION IF EXISTS public.refresh_recommendations_for_viewer(uuid, integer, integer) RESTRICT;
DROP FUNCTION IF EXISTS public.get_discovery_feed_global_pool(uuid, double precision, uuid, integer, jsonb) RESTRICT;
DROP FUNCTION IF EXISTS public.get_new_arrivals(text, uuid) RESTRICT;
DROP FUNCTION IF EXISTS public.mutual_dealbreakers_match(uuid, uuid) RESTRICT;
DROP FUNCTION IF EXISTS public.directional_preference_score(uuid, uuid) RESTRICT;

-- These client-callable compatibility functions exposed raw profile rows or
-- trusted a client-supplied verification result. Both flows are retired.
DROP FUNCTION IF EXISTS public.get_nearby_matches(numeric, numeric, numeric) RESTRICT;
DROP FUNCTION IF EXISTS public.submit_selfie_verification(text, text) RESTRICT;

DROP TABLE IF EXISTS public.recommendations RESTRICT;
DROP MATERIALIZED VIEW IF EXISTS public.discovery_pool RESTRICT;
DROP TABLE IF EXISTS public.user_devices RESTRICT;

DROP INDEX IF EXISTS public.idx_profiles_approved_recent;

COMMENT ON VIEW public.live_discovery_pool IS
  'Canonical immediately consistent discovery source for interactive and administrative discovery.';
