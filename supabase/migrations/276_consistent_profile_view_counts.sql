-- The profile-view badge (get_my_profile_view_summary) counted every viewer
-- in the last 7 days, while the viewer list (get_my_profile_viewers) showed
-- only visible profiles. A viewer who later paused, was suspended or was
-- deleted inflated the badge but never appeared in the list, so members saw
-- "2" and then an empty page. Both now apply one eligibility rule: the
-- viewer's profile is visible and no block exists in either direction.

CREATE OR REPLACE FUNCTION public.get_my_profile_view_summary()
 RETURNS TABLE(viewer_count bigint, unseen_viewer_count bigint)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_user_id uuid := private.assert_authenticated();
  v_last_seen_at timestamptz;
BEGIN
  INSERT INTO private.profile_view_activity_state(user_id)
  VALUES (v_user_id)
  ON CONFLICT (user_id) DO NOTHING;

  SELECT state.last_seen_at
  INTO v_last_seen_at
  FROM private.profile_view_activity_state state
  WHERE state.user_id = v_user_id;

  RETURN QUERY
  SELECT
    count(DISTINCT pv.viewer_profile_id)::bigint AS viewer_count,
    count(DISTINCT pv.viewer_profile_id)
      FILTER (WHERE pv.viewed_at > v_last_seen_at)::bigint
      AS unseen_viewer_count
  FROM public.profile_views pv
  JOIN public.profiles mine ON mine.id = pv.viewed_profile_id
  JOIN public.profiles viewer ON viewer.id = pv.viewer_profile_id
  WHERE mine.user_id = v_user_id
    AND pv.viewed_at >= now() - interval '7 days'
    AND viewer.visibility = 'visible'
    AND NOT EXISTS (
      SELECT 1 FROM public.blocks b
      WHERE (b.blocker_id = v_user_id AND b.blocked_id = viewer.user_id)
         OR (b.blocker_id = viewer.user_id AND b.blocked_id = v_user_id)
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_my_profile_viewers(p_limit integer DEFAULT 50)
 RETURNS TABLE(viewer_user_id uuid, first_name text, last_name text, date_of_birth date, gender text, is_verified boolean, bio text, photo_privacy text, sect text, deen_level text, city_name text, viewed_at timestamp with time zone)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = 'P0001';
  END IF;
  IF NOT public.has_active_premium(auth.uid()) THEN
    RAISE EXCEPTION 'premium_required' USING ERRCODE = 'P0001';
  END IF;

  RETURN QUERY
  SELECT recent.viewer_user_id,
         recent.first_name,
         recent.last_name,
         recent.date_of_birth,
         recent.gender,
         recent.is_verified,
         recent.bio,
         recent.photo_privacy,
         recent.sect,
         recent.deen_level,
         recent.city_name,
         recent.viewed_at
  FROM (
    SELECT DISTINCT ON (pv.viewer_profile_id)
      viewer.user_id AS viewer_user_id,
      viewer.first_name::text,
      viewer.last_name::text,
      viewer.date_of_birth,
      viewer.gender::text,
      coalesce(viewer.is_verified, false) AS is_verified,
      coalesce(viewer.bio, '')::text AS bio,
      viewer.photo_privacy::text,
      viewer.sect::text,
      viewer.deen_level::text,
      city.name::text AS city_name,
      pv.viewed_at
    FROM public.profile_views pv
    JOIN public.profiles mine ON mine.id = pv.viewed_profile_id
    JOIN public.profiles viewer ON viewer.id = pv.viewer_profile_id
    LEFT JOIN public.cities city ON city.id = viewer.city_id
    WHERE mine.user_id = auth.uid()
      AND pv.viewed_at >= now() - interval '7 days'
      AND viewer.visibility = 'visible'
      AND NOT EXISTS (
        SELECT 1 FROM public.blocks b
        WHERE (b.blocker_id = auth.uid() AND b.blocked_id = viewer.user_id)
           OR (b.blocker_id = viewer.user_id AND b.blocked_id = auth.uid())
      )
    ORDER BY pv.viewer_profile_id, pv.viewed_at DESC
  ) recent
  ORDER BY recent.viewed_at DESC
  LIMIT least(greatest(coalesce(p_limit, 50), 1), 100);
END;
$function$;
