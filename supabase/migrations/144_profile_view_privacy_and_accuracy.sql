-- SILARAH — Profile-view accuracy and Premium identity privacy
-- Aggregate counts are free. Identifying the people who viewed a profile is a
-- Premium capability and is enforced in Postgres, not merely hidden in Flutter.

DROP POLICY IF EXISTS profile_views_select ON public.profile_views;
DROP POLICY IF EXISTS profile_views_select_premium_owner ON public.profile_views;

CREATE POLICY profile_views_select_premium_owner
  ON public.profile_views
  FOR SELECT
  TO authenticated
  USING (
    viewed_profile_id = (
      SELECT p.id FROM public.profiles p
      WHERE p.user_id = auth.uid()
      LIMIT 1
    )
    AND public.has_active_premium(auth.uid())
  );

CREATE OR REPLACE FUNCTION public.get_my_profile_view_summary()
RETURNS TABLE(viewer_count bigint)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT count(DISTINCT pv.viewer_profile_id)::bigint AS viewer_count
  FROM public.profile_views pv
  JOIN public.profiles mine ON mine.id = pv.viewed_profile_id
  WHERE mine.user_id = auth.uid()
    AND pv.viewed_at >= now() - interval '7 days';
$$;

CREATE OR REPLACE FUNCTION public.get_my_profile_viewers(
  p_limit integer DEFAULT 50
)
RETURNS TABLE(
  viewer_user_id uuid,
  first_name text,
  last_name text,
  date_of_birth date,
  gender text,
  is_verified boolean,
  bio text,
  photo_privacy text,
  sect text,
  deen_level text,
  city_name text,
  viewed_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
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
    ORDER BY pv.viewer_profile_id, pv.viewed_at DESC
  ) recent
  ORDER BY recent.viewed_at DESC
  LIMIT least(greatest(coalesce(p_limit, 50), 1), 100);
END;
$$;

REVOKE ALL ON FUNCTION public.get_my_profile_view_summary() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_my_profile_viewers(integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_my_profile_view_summary() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_profile_viewers(integer) TO authenticated;

COMMENT ON FUNCTION public.get_my_profile_view_summary() IS
  'Free weekly distinct viewer count for the authenticated profile owner.';
COMMENT ON FUNCTION public.get_my_profile_viewers(integer) IS
  'Premium-only weekly distinct viewer identities, enforced server-side.';
