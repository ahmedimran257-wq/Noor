-- A member may lose connectivity after a photo is finalized but before the
-- onboarding step advances. Allow the private media worker to return that
-- member's own active or pending-review slots so onboarding can resume without
-- another upload. No other viewer receives unapproved media.

CREATE OR REPLACE FUNCTION public.get_my_photo_management_paths(
  p_user_id uuid
)
RETURNS TABLE(order_index integer, storage_path text)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT ph.order_index, ph.storage_path
  FROM public.profiles p
  JOIN public.photos ph ON ph.profile_id = p.id
  JOIN public.users u ON u.id = p.user_id
  WHERE auth.role() = 'service_role'
    AND p.user_id = p_user_id
    AND u.deleted_at IS NULL
    AND coalesce(u.is_banned, false) = false
    AND ph.order_index BETWEEN 0 AND 3
    AND ph.status IN ('active', 'pending_review')
    AND nullif(trim(ph.storage_path), '') IS NOT NULL
  ORDER BY ph.order_index;
$$;

REVOKE ALL ON FUNCTION public.get_my_photo_management_paths(uuid)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_photo_management_paths(uuid)
  TO service_role;

NOTIFY pgrst, 'reload schema';
