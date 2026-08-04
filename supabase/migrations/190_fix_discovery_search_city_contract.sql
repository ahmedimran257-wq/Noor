-- PL/pgSQL enforces the declared table contract at runtime. cities.name is a
-- varchar in the current schema, so cast the projected value to the text type
-- promised by search_profiles_by_name_city.
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
SET search_path = ''
AS $$
BEGIN
  IF auth.uid() IS DISTINCT FROM p_viewer_id THEN
    RAISE EXCEPTION 'unauthorized_profile_search' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT
    p.id,
    p.first_name,
    left(coalesce(p.last_name, ''), 1),
    coalesce(city.name, '')::text
  FROM public.profiles p
  JOIN public.users account ON account.id = p.user_id
  LEFT JOIN public.cities city ON city.id = p.city_id
  WHERE p.visibility = 'visible'
    AND p.onboarding_completed = true
    AND p.approved_at IS NOT NULL
    AND account.deleted_at IS NULL
    AND coalesce(account.is_banned, false) = false
    AND coalesce(account.is_shadowbanned, false) = false
    AND p.user_id <> p_viewer_id
    AND p.first_name ILIKE p_first_name || '%'
    AND (p_city_id IS NULL OR p.city_id = p_city_id)
    AND EXISTS (
      SELECT 1 FROM public.photos ph
      WHERE ph.profile_id = p.id
        AND ph.order_index = 0
        AND ph.status = 'active'
        AND ph.admin_approved = true
        AND ph.nsfw_cleared = true
    )
    AND NOT EXISTS (
      SELECT 1 FROM public.blocks b
      WHERE (b.blocker_id = p_viewer_id AND b.blocked_id = p.user_id)
         OR (b.blocker_id = p.user_id AND b.blocked_id = p_viewer_id)
    )
    AND NOT EXISTS (
      SELECT 1 FROM public.reports r
      WHERE r.reporter_id = p_viewer_id
        AND r.reported_user_id = p.user_id
    )
    AND NOT EXISTS (
      SELECT 1 FROM public.matches m
      WHERE (
        (m.user_a = p_viewer_id AND m.user_b = p.user_id)
        OR (m.user_b = p_viewer_id AND m.user_a = p.user_id)
      )
        AND m.status IN ('blocked','reported')
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

COMMENT ON FUNCTION public.search_profiles_by_name_city(uuid, text, integer) IS
  'Authorized visible-profile search with safety exclusions and an exact text return contract.';
