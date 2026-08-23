-- Keep anonymous execution limited to the four deliberately pre-auth flows.
-- Every other app-owned SECURITY DEFINER routine requires a signed-in member
-- or service role. This also repairs future default-grant drift in one place.
DO $$
DECLARE
  fn record;
BEGIN
  FOR fn IN
    SELECT p.oid::regprocedure AS signature
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.prosecdef
      AND NOT EXISTS (
        SELECT 1 FROM pg_depend d
        WHERE d.classid = 'pg_proc'::regclass
          AND d.objid = p.oid
          AND d.deptype = 'e'
      )
      AND p.proname NOT IN (
        'begin_signup_consent_transaction',
        'bind_signup_consent_transaction',
        'get_launch_configuration',
        'validate_referral_code'
      )
  LOOP
    EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM PUBLIC, anon', fn.signature);
  END LOOP;
END;
$$;

-- Private helpers are never callable over the Data API even if a function was
-- created before the project-wide default privileges were hardened.
DO $$
DECLARE
  fn record;
BEGIN
  FOR fn IN
    SELECT p.oid::regprocedure AS signature
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname IN ('private', 'api_private')
  LOOP
    EXECUTE format(
      'REVOKE EXECUTE ON FUNCTION %s FROM PUBLIC, anon, authenticated',
      fn.signature
    );
  END LOOP;
END;
$$;

-- spatial_ref_sys and st_estimatedextent are owned by Supabase's managed
-- PostGIS extension. The project migration role must not alter their ACL/RLS
-- or move the extension schema. They remain an explicit managed-extension
-- Advisor exception; all app-owned objects are handled above.

NOTIFY pgrst, 'reload schema';
