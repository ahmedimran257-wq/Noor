-- Read-only companion to the staging architecture audit. Never edits a
-- PostGIS-owned function to silence a static analyzer diagnostic.
WITH extension_ownership AS (
SELECT p.oid::regprocedure::text AS function_signature, e.extname AS extension
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
LEFT JOIN pg_depend d ON d.classid = 'pg_proc'::regclass
  AND d.objid = p.oid AND d.refclassid = 'pg_extension'::regclass AND d.deptype = 'e'
LEFT JOIN pg_extension e ON e.oid = d.refobjid
WHERE n.nspname = 'public' AND p.proname IN
  ('st_findextent', 'populate_geometry_columns', 'postgis_full_version', 'lockrow', 'addauth')
ORDER BY function_signature
), function_grants AS (

SELECT p.oid::regprocedure::text AS function_signature, p.prosecdef AS security_definer,
  p.proconfig AS function_settings,
  has_function_privilege('anon', p.oid, 'EXECUTE') AS anon_execute,
  has_function_privilege('authenticated', p.oid, 'EXECUTE') AS member_execute
FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE (n.nspname = 'public' AND p.proname = 'send_chat_message_idempotent')
   OR (n.nspname = 'private' AND p.proname = 'guard_chat_send_rate')
)

SELECT jsonb_build_object(
  'extension_ownership', (SELECT jsonb_agg(to_jsonb(e)) FROM extension_ownership e),
  'function_grants', (SELECT jsonb_agg(to_jsonb(f)) FROM function_grants f),
  'anon_receipts', has_table_privilege('anon', 'private.chat_send_receipts', 'SELECT'),
  'member_receipts', has_table_privilege('authenticated', 'private.chat_send_receipts', 'SELECT'),
  'remaining_disposable_architecture_accounts', (SELECT count(*)
FROM auth.users
WHERE email LIKE '%@staging.silarah.invalid'
  AND raw_user_meta_data->>'staging_extended_load_run' = '1788597326897-irfnya5k'),
  'orphan_receipts', (SELECT count(*)
FROM private.chat_send_receipts r
LEFT JOIN public.messages m ON m.id = r.message_id
LEFT JOIN public.users u ON u.id = r.actor_id
WHERE m.id IS NULL OR u.id IS NULL)
) AS architecture_database_verification;
