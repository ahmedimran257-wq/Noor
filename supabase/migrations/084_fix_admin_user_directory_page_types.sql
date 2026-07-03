-- Keep the admin user directory RPC return structure exact. PostgreSQL requires
-- every RETURN QUERY column type to match RETURNS TABLE exactly; varchar/domain
-- columns from profiles/users must be cast to text to avoid runtime 500s.
CREATE OR REPLACE FUNCTION public.admin_user_directory_page(
  p_query text DEFAULT '',
  p_limit integer DEFAULT 50,
  p_offset integer DEFAULT 0
)
RETURNS TABLE(
  user_id uuid,
  profile_id uuid,
  name text,
  email text,
  country_code text,
  gender text,
  joined_at timestamptz,
  last_active_at timestamptz,
  onboarding_step int,
  completeness_score int,
  visibility text,
  is_banned boolean,
  subscription_status text,
  verification_status text,
  has_verification_badge boolean,
  total_count bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_limit integer := least(greatest(coalesce(p_limit, 50), 1), 50);
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_query text := trim(coalesce(p_query, ''));
BEGIN
  IF NOT public.is_active_admin() THEN
    RAISE EXCEPTION 'Staff authorization required';
  END IF;

  INSERT INTO public.admin_audit_log(admin_id, actor_role, action_type, details)
  VALUES (
    auth.uid(),
    public.current_admin_role(),
    'admin_user_directory_read',
    jsonb_build_object('query_present', v_query <> '', 'limit', v_limit, 'offset', v_offset)
  );

  RETURN QUERY
  SELECT
    u.id::uuid AS user_id,
    p.id::uuid AS profile_id,
    public.mask_admin_name(concat_ws(' ', p.first_name, p.last_name))::text AS name,
    public.mask_admin_email(u.email::text)::text AS email,
    p.country_code::text AS country_code,
    p.gender::text AS gender,
    u.created_at::timestamptz AS joined_at,
    p.last_active_at::timestamptz AS last_active_at,
    p.onboarding_step::int AS onboarding_step,
    p.completeness_score::int AS completeness_score,
    p.visibility::text AS visibility,
    coalesce(u.is_banned, false)::boolean AS is_banned,
    u.subscription_status::text AS subscription_status,
    p.verification_status::text AS verification_status,
    coalesce(p.has_verification_badge, false)::boolean AS has_verification_badge,
    count(*) OVER ()::bigint AS total_count
  FROM public.users u
  JOIN public.profiles p ON p.user_id = u.id
  WHERE
    v_query = ''
    OR concat_ws(' ', p.first_name, p.last_name, u.email, u.id::text) ILIKE '%' || v_query || '%'
  ORDER BY u.created_at DESC
  LIMIT v_limit OFFSET v_offset;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_user_directory_page(text, integer, integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_user_directory_page(text, integer, integer) TO authenticated;
