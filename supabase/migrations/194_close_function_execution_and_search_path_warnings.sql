-- Close the remaining application-owned Security Advisor findings.
--
-- PostgreSQL grants EXECUTE on new functions to PUBLIC by default. Older
-- migrations predate the explicit RPC allowlist, so remove that inherited
-- grant from every application-owned SECURITY DEFINER routine. Anonymous
-- execution remains available only for the narrow pre-auth flows listed
-- below; existing authenticated/service-role grants are preserved.
DO $migration$
DECLARE
  v_function record;
  v_identity text;
  v_anonymous_allowlist constant text[] := ARRAY[
    'begin_signup_consent_transaction',
    'bind_signup_consent_transaction',
    'email_is_registered',
    'email_registration_status',
    'search_cities',
    'search_regions',
    'validate_referral_code'
  ];
BEGIN
  FOR v_function IN
    SELECT p.oid, p.proname, pg_get_function_identity_arguments(p.oid) AS args
    FROM pg_proc AS p
    JOIN pg_namespace AS n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.prosecdef
      AND NOT EXISTS (
        SELECT 1
        FROM pg_depend AS d
        WHERE d.classid = 'pg_proc'::regclass
          AND d.objid = p.oid
          AND d.deptype = 'e'
      )
  LOOP
    v_identity := format('%I.%I(%s)', 'public', v_function.proname, v_function.args);
    EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM PUBLIC', v_identity);

    IF NOT (v_function.proname = ANY (v_anonymous_allowlist)) THEN
      EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM anon', v_identity);
    END IF;
  END LOOP;
END;
$migration$;

-- These invoker/helper routines intentionally use public objects. Pinning a
-- safe search path keeps their current behavior while preventing caller
-- controlled object resolution.
ALTER FUNCTION public.cities_searchvector_trigger()
  SET search_path TO pg_catalog, public;
ALTER FUNCTION public.get_nearby_matches(numeric, numeric, numeric)
  SET search_path TO pg_catalog, public;
ALTER FUNCTION public.mask_admin_email(text)
  SET search_path TO pg_catalog, public;
ALTER FUNCTION public.mask_admin_name(text)
  SET search_path TO pg_catalog, public;
ALTER FUNCTION public.chat_safety_check(text)
  SET search_path TO pg_catalog, public;
ALTER FUNCTION public.get_profile_view_quota()
  SET search_path TO pg_catalog, public;

-- Prevent untrusted API roles from creating shadow objects in the exposed
-- schema. Supabase owners and migration roles retain control.
REVOKE CREATE ON SCHEMA public FROM PUBLIC, anon, authenticated;
