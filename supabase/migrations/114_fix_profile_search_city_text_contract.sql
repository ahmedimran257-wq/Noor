-- Global cities use varchar(100); the public search RPC returns text. Keep the
-- boundary explicit so profile search cannot fail with the same drift that
-- previously broke discovery.

CREATE OR REPLACE FUNCTION public.search_profiles_by_name_city(
  p_viewer_id uuid,
  p_first_name text,
  p_city_id integer DEFAULT NULL
)
RETURNS TABLE(
  profile_id uuid,
  first_name text,
  last_name_initial text,
  city_name text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS DISTINCT FROM p_viewer_id THEN
    RAISE EXCEPTION 'Profile search can only be requested for the signed-in user.';
  END IF;

  RETURN QUERY
  SELECT
    p.id,
    p.first_name,
    left(p.last_name, 1),
    c.name::text
  FROM public.profiles p
  LEFT JOIN public.cities c ON p.city_id = c.id
  WHERE p.visibility = 'visible'
    AND p.onboarding_completed = true
    AND p.approved_at IS NOT NULL
    AND p.user_id <> p_viewer_id
    AND p.first_name ILIKE p_first_name || '%'
    AND (p_city_id IS NULL OR p.city_id = p_city_id)
    AND NOT EXISTS (
      SELECT 1
      FROM public.blocks b
      WHERE (b.blocker_id = p_viewer_id AND b.blocked_id = p.user_id)
         OR (b.blocker_id = p.user_id AND b.blocked_id = p_viewer_id)
    )
  ORDER BY p.first_name, p.id
  LIMIT 20;
END;
$$;

REVOKE ALL ON FUNCTION public.search_profiles_by_name_city(
  uuid, text, integer
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.search_profiles_by_name_city(
  uuid, text, integer
) TO authenticated;
