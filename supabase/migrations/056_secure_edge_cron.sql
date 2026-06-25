-- pg_net cannot mint a Supabase JWT. Keep its credential in Vault and verify a
-- SHA-256 hash inside each no-verify-jwt cron Edge Function instead of relying
-- on the usually-unset app.service_role_key database setting.
CREATE TABLE IF NOT EXISTS public.internal_cron_credentials (
  name text PRIMARY KEY,
  secret_hash text NOT NULL,
  rotated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.internal_cron_credentials ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.internal_cron_credentials FROM PUBLIC, anon, authenticated;

DO $$
DECLARE
  v_secret text;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.internal_cron_credentials WHERE name = 'edge_cron'
  ) THEN
    v_secret := encode(extensions.gen_random_bytes(32), 'hex');
    INSERT INTO public.internal_cron_credentials (name, secret_hash)
    VALUES ('edge_cron', encode(extensions.digest(v_secret, 'sha256'), 'hex'));
    PERFORM vault.create_secret(
      v_secret,
      'mithaq_edge_cron_secret',
      'Credential used only by pg_cron to call Mithaq internal Edge Functions.'
    );
  END IF;
END;
$$;

DO $$
BEGIN
  PERFORM cron.unschedule(jobid)
  FROM cron.job
  WHERE jobname IN (
    'trigger_purge_deleted_accounts',
    'dispatch_notifications_minutely'
  );
END;
$$;

SELECT cron.schedule(
  'trigger_purge_deleted_accounts',
  '15 3 * * *',
  $$
    SELECT net.http_post(
      url := 'https://jukpscfxzwttgtxvrbmj.supabase.co/functions/v1/admin-purge-deleted-users',
      body := '{}'::jsonb,
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-cron-secret', (
          SELECT decrypted_secret
          FROM vault.decrypted_secrets
          WHERE name = 'mithaq_edge_cron_secret'
        )
      )
    );
  $$
);

SELECT cron.schedule(
  'dispatch_notifications_minutely',
  '* * * * *',
  $$
    SELECT net.http_post(
      url := 'https://jukpscfxzwttgtxvrbmj.supabase.co/functions/v1/dispatch-notifications',
      body := '{}'::jsonb,
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-cron-secret', (
          SELECT decrypted_secret
          FROM vault.decrypted_secrets
          WHERE name = 'mithaq_edge_cron_secret'
        )
      )
    );
  $$
);
