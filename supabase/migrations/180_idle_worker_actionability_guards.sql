-- Only wake recovery workers when their checkout functions can do useful work.
-- This prevents permanently ineligible rows from producing an Edge invocation
-- every five minutes while preserving stale-lease recovery.

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
  IF NOT EXISTS (
    SELECT 1
    FROM public.notifications n
    WHERE n.sent_at IS NULL
      AND n.scheduled_at <= now()
      AND (
        (
          n.delivery_status = 'processing'
          AND n.processing_at < now() - interval '5 minutes'
        )
        OR (
          n.delivery_status = 'pending'
          AND (
            NOT public.notification_push_enabled(n.user_id, n.type)
            OR (
              n.next_attempt_at <= now()
              AND n.attempt_count < 8
            )
          )
        )
      )
    LIMIT 1
  ) THEN
    RETURN;
  END IF;

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

CREATE OR REPLACE FUNCTION private.invoke_storage_lifecycle_worker()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_secret text;
  v_url text;
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM private.storage_deletion_jobs j
    WHERE (
      j.status IN ('pending', 'failed')
      AND j.next_attempt_at <= now()
    ) OR (
      j.status = 'processing'
      AND j.processing_at < now() - interval '5 minutes'
    )
    LIMIT 1
  ) AND NOT EXISTS (
    SELECT 1
    FROM private.upload_reservations r
    WHERE r.status = 'reserved'
      AND r.expires_at <= now()
    LIMIT 1
  ) THEN
    RETURN;
  END IF;

  v_url := nullif(current_setting('app.supabase_url', true), '');
  SELECT decrypted_secret INTO v_secret
  FROM vault.decrypted_secrets
  WHERE name IN ('silarah_edge_cron_secret', 'mithaq_edge_cron_secret')
  ORDER BY (name = 'silarah_edge_cron_secret') DESC
  LIMIT 1;

  IF v_url IS NULL OR nullif(v_secret, '') IS NULL THEN
    PERFORM private.set_operational_alert(
      'storage_lifecycle_worker',
      'Storage lifecycle worker configuration is incomplete. Set app.supabase_url and the private cron credential.',
      1,
      true
    );
  ELSE
    PERFORM private.set_operational_alert(
      'storage_lifecycle_worker',
      'Storage lifecycle worker configuration is healthy.',
      0,
      false
    );
    PERFORM net.http_post(
      url := v_url || '/functions/v1/storage-lifecycle-worker',
      body := '{}'::jsonb,
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-cron-secret', v_secret
      ),
      timeout_milliseconds := 10000
    );
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION private.invoke_storage_lifecycle_worker() FROM PUBLIC;
