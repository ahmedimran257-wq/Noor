-- Route every database-originated notification wake-up through one guarded
-- function. The project URL is environment configuration, never hardcoded in
-- migrations, so a future staging database cannot call production.

CREATE OR REPLACE FUNCTION private.invoke_notification_dispatch()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_secret text;
  v_url text;
BEGIN
  v_url := nullif(current_setting('app.supabase_url', true), '');
  SELECT decrypted_secret INTO v_secret
  FROM vault.decrypted_secrets
  WHERE name IN ('silarah_edge_cron_secret', 'mithaq_edge_cron_secret')
  ORDER BY (name = 'silarah_edge_cron_secret') DESC
  LIMIT 1;

  IF v_url IS NULL OR nullif(v_secret, '') IS NULL THEN
    PERFORM private.set_operational_alert(
      'edge_cron_configuration',
      'Notification worker configuration is incomplete. Set app.supabase_url and the private cron credential.',
      1,
      true
    );
    RETURN;
  END IF;

  PERFORM private.set_operational_alert(
    'edge_cron_configuration',
    'Notification worker configuration is healthy.',
    0,
    false
  );

  PERFORM net.http_post(
    url := v_url || '/functions/v1/dispatch-notifications',
    body := '{}'::jsonb,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-cron-secret', v_secret
    ),
    timeout_milliseconds := 10000
  );
END;
$$;

REVOKE ALL ON FUNCTION private.invoke_notification_dispatch() FROM PUBLIC;

CREATE OR REPLACE FUNCTION private.wake_notification_dispatch()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  UPDATE private.notification_dispatch_state
  SET last_wake_at = clock_timestamp()
  WHERE singleton = true
    AND (
      last_wake_at IS NULL
      OR last_wake_at < clock_timestamp() - interval '20 seconds'
    );

  IF FOUND THEN
    PERFORM private.invoke_notification_dispatch();
  END IF;
  RETURN NULL;
END;
$$;

REVOKE ALL ON FUNCTION private.wake_notification_dispatch() FROM PUBLIC;

DO $$
DECLARE
  v_job record;
BEGIN
  FOR v_job IN
    SELECT jobid FROM cron.job
    WHERE jobname = 'dispatch_notifications_fallback_5m'
  LOOP
    PERFORM cron.unschedule(v_job.jobid);
  END LOOP;

  PERFORM cron.schedule(
    'dispatch_notifications_fallback_5m',
    '*/5 * * * *',
    'SELECT private.invoke_notification_dispatch();'
  );
END;
$$;
