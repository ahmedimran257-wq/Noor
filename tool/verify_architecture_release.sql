-- Read-only release verification. Run on staging and production, then compare
-- function digests before certifying that the tested implementation is live.
WITH inspected_functions AS (
  SELECT p.oid::regprocedure::text AS signature,
    md5(pg_get_functiondef(p.oid)) AS definition_digest,
    p.prosecdef AS security_definer,
    p.proconfig AS settings,
    has_function_privilege('anon', p.oid, 'EXECUTE') AS anon_execute,
    has_function_privilege('authenticated', p.oid, 'EXECUTE') AS member_execute
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE (n.nspname = 'private' AND p.proname IN (
    'sync_incognito_entitlement_trigger', 'touch_discovery_member', 'guard_chat_send_rate'
  )) OR (n.nspname = 'public' AND p.proname IN (
    'send_chat_message_idempotent', 'send_chat_message', 'send_guardian_chat_message'
  ))
)
SELECT jsonb_build_object(
  'migrations', (SELECT jsonb_agg(version ORDER BY version)
    FROM supabase_migrations.schema_migrations WHERE version IN ('256', '257', '258')),
  'functions', (SELECT jsonb_agg(to_jsonb(f) ORDER BY f.signature) FROM inspected_functions f),
  'rate_trigger_enabled', EXISTS (
    SELECT 1 FROM pg_trigger
    WHERE tgrelid = 'public.messages'::regclass
      AND tgname = 'guard_chat_send_rate' AND tgenabled IN ('O', 'A')
      AND tgfoid = 'private.guard_chat_send_rate()'::regprocedure
      AND NOT tgisinternal
  ),
  'receipt_constraints', (SELECT jsonb_agg(pg_get_constraintdef(oid) ORDER BY conname)
    FROM pg_constraint WHERE conrelid = 'private.chat_send_receipts'::regclass),
  'receipt_indexes', (SELECT jsonb_agg(indexname ORDER BY indexname)
    FROM pg_indexes WHERE schemaname = 'private' AND tablename = 'chat_send_receipts'),
  'anon_receipts', has_table_privilege('anon', 'private.chat_send_receipts', 'SELECT'),
  'member_receipts', has_table_privilege('authenticated', 'private.chat_send_receipts', 'SELECT')
) AS architecture_release_verification;
