-- Brevo's "No expiration" API keys still expire after 90 days without API
-- activity. Exercise the server-only credential monthly with a read-only
-- account health check so production mail does not depend on a manual reminder.
DO $$
BEGIN
  PERFORM cron.unschedule(jobid)
  FROM cron.job
  WHERE jobname = 'brevo_api_key_keepalive';
END;
$$;

SELECT cron.schedule(
  'brevo_api_key_keepalive',
  '10 4 1 * *',
  $$
    SELECT net.http_post(
      url := current_setting('app.supabase_url', true) || '/functions/v1/brevo-key-keepalive',
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
