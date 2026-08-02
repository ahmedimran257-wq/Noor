-- Resolve the two application-owned Security Advisor findings without
-- reopening direct member access to the private profiles table, and assert
-- that the remaining PostGIS finding belongs to Supabase's managed extension.

-- `spatial_ref_sys` is a PostGIS catalog containing public coordinate-system
-- definitions. Supabase creates it under its non-assumable `supabase_admin`
-- role and marks PostGIS non-relocatable, so application migrations cannot
-- enable RLS or move it. Fail closed if that ownership ever changes; the
-- matching Advisor item is documented/dismissed as platform-managed.
DO $migration$
DECLARE
  v_owner text;
  v_extension_owner text;
  v_relocatable boolean;
BEGIN
  SELECT
    c.relowner::regrole::text,
    e.extowner::regrole::text,
    e.extrelocatable
  INTO v_owner, v_extension_owner, v_relocatable
  FROM pg_class c
  JOIN pg_depend d
    ON d.classid = 'pg_class'::regclass
   AND d.objid = c.oid
   AND d.deptype = 'e'
  JOIN pg_extension e ON e.oid = d.refobjid
  WHERE c.oid = 'public.spatial_ref_sys'::regclass
    AND e.extname = 'postgis';

  IF v_owner IS DISTINCT FROM 'supabase_admin'
    OR v_extension_owner IS DISTINCT FROM 'supabase_admin'
    OR v_relocatable IS DISTINCT FROM false THEN
    RAISE EXCEPTION 'unexpected_spatial_ref_sys_ownership';
  END IF;
END;
$migration$;

-- PostgreSQL views use their owner's privileges by default. Keep the existing
-- PostgREST view contracts, but make the views SECURITY INVOKER and source
-- their already-authorized rows from narrow, authenticated functions. This
-- avoids granting SELECT on public.profiles, which would expose every private
-- column of a guardian's ward through row-only RLS.
CREATE OR REPLACE FUNCTION public.get_my_profile_private_rows()
RETURNS SETOF public.profiles
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT p.*
  FROM public.profiles p
  WHERE auth.uid() IS NOT NULL
    AND p.user_id = auth.uid();
$$;

REVOKE ALL ON FUNCTION public.get_my_profile_private_rows()
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_profile_private_rows()
  TO authenticated;

CREATE OR REPLACE FUNCTION public.get_my_guardian_ward_rows()
RETURNS TABLE(
  id uuid,
  user_id uuid,
  first_name text,
  last_name_initial text,
  visibility text
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT
    p.id,
    p.user_id,
    p.first_name,
    left(p.last_name, 1),
    p.visibility
  FROM public.profiles p
  WHERE auth.uid() IS NOT NULL
    AND p.guardian_user_id = auth.uid();
$$;

REVOKE ALL ON FUNCTION public.get_my_guardian_ward_rows()
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_guardian_ward_rows()
  TO authenticated;

DROP VIEW IF EXISTS public.my_profile_private;
CREATE VIEW public.my_profile_private
WITH (security_invoker = true, security_barrier = true)
AS
SELECT row_data.*
FROM public.get_my_profile_private_rows() AS row_data;

REVOKE ALL ON public.my_profile_private FROM PUBLIC, anon;
GRANT SELECT ON public.my_profile_private TO authenticated;

DROP VIEW IF EXISTS public.my_guardian_wards;
CREATE VIEW public.my_guardian_wards
WITH (security_invoker = true, security_barrier = true)
AS
SELECT row_data.*
FROM public.get_my_guardian_ward_rows() AS row_data;

REVOKE ALL ON public.my_guardian_wards FROM PUBLIC, anon;
GRANT SELECT ON public.my_guardian_wards TO authenticated;

NOTIFY pgrst, 'reload schema';

COMMENT ON FUNCTION public.get_my_profile_private_rows() IS
  'Returns only the authenticated member private profile row for the security-invoker compatibility view.';
COMMENT ON FUNCTION public.get_my_guardian_ward_rows() IS
  'Returns the minimum guardian ward projection for the authenticated guardian.';
