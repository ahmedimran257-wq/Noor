-- Environment URLs belong in Vault, not portable migrations. Keep support for
-- a database setting in local development and prefer the Vault fallback on
-- hosted projects.

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
  IF v_url IS NULL THEN
    SELECT decrypted_secret INTO v_url
    FROM vault.decrypted_secrets
    WHERE name = 'silarah_supabase_url'
    LIMIT 1;
  END IF;

  SELECT decrypted_secret INTO v_secret
  FROM vault.decrypted_secrets
  WHERE name IN ('silarah_edge_cron_secret', 'mithaq_edge_cron_secret')
  ORDER BY (name = 'silarah_edge_cron_secret') DESC
  LIMIT 1;

  IF nullif(v_url, '') IS NULL OR nullif(v_secret, '') IS NULL THEN
    PERFORM private.set_operational_alert(
      'edge_cron_configuration',
      'Notification worker configuration is incomplete. Configure silarah_supabase_url and the private cron credential in Vault.',
      1,
      true
    );
    RETURN;
  END IF;

  IF v_url !~ '^https://[a-z0-9-]+[.]supabase[.]co$' THEN
    PERFORM private.set_operational_alert(
      'edge_cron_configuration',
      'Notification worker URL is invalid. No request was sent.',
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
