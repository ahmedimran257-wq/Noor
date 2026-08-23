-- Migration 245 intentionally removed broad execution from private schemas,
-- but these two helpers are the row selectors behind SECURITY INVOKER views.
-- The api_private schema is not exposed by PostgREST, so authenticated members
-- still cannot invoke the helpers as RPC endpoints. They need EXECUTE solely so
-- the two public views can evaluate their caller-scoped projections.
REVOKE ALL ON FUNCTION api_private.get_my_profile_private_rows()
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION api_private.get_my_profile_private_rows()
  TO authenticated;

REVOKE ALL ON FUNCTION api_private.get_my_guardian_ward_rows()
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION api_private.get_my_guardian_ward_rows()
  TO authenticated;

NOTIFY pgrst, 'reload schema';
