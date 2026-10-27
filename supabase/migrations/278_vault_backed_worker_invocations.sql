-- Migrations 141/203 moved the project URL into Vault (silarah_supabase_url)
-- and taught the notification workers to read it, but three callers still
-- read only the unset app.supabase_url database setting:
--   * private.invoke_storage_lifecycle_worker() never posted, so photo and
--     account storage deletions queued since July were never processed, and
--     it raised a "configuration is incomplete" admin alert every 6 hours
--     (691 unread alerts in production);
--   * the profile-nudge-daily cron failed every day on a NULL url, rolling
--     back the nudges it had just created;
--   * the monthly brevo_api_key_keepalive cron had the same NULL url.
-- One helper now resolves the URL and cron credential the same way the
-- notification dispatcher does, and all three callers use it.

CREATE OR REPLACE FUNCTION private.invoke_edge_worker(p_function text, p_alert_key text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_url text;
  v_secret text;
BEGIN
  IF p_function !~ '^[a-z0-9-]{3,64}$' THEN
    RAISE EXCEPTION 'invalid_edge_function_name' USING ERRCODE = '22023';
  END IF;

  v_url := nullif(rtrim(current_setting('app.supabase_url', true), '/'), '');
  IF v_url IS NULL THEN
    SELECT rtrim(decrypted_secret, '/') INTO v_url
    FROM vault.decrypted_secrets
    WHERE name = 'silarah_supabase_url'
    LIMIT 1;
  END IF;

  SELECT decrypted_secret INTO v_secret
  FROM vault.decrypted_secrets
  WHERE name IN ('silarah_edge_cron_secret', 'mithaq_edge_cron_secret')
  ORDER BY (name = 'silarah_edge_cron_secret') DESC
  LIMIT 1;

  IF v_url IS NULL OR nullif(v_secret, '') IS NULL THEN
    PERFORM private.set_operational_alert(
      p_alert_key,
      format('The %s worker is not configured. Set the project URL and private cron credential in Vault.', p_function),
      1,
      true
    );
    RETURN false;
  END IF;
  IF v_url !~ '^https://[a-z0-9-]+[.]supabase[.]co$' THEN
    PERFORM private.set_operational_alert(
      p_alert_key,
      format('The %s worker URL is invalid. No request was sent.', p_function),
      1,
      true
    );
    RETURN false;
  END IF;

  PERFORM private.set_operational_alert(
    p_alert_key,
    format('The %s worker configuration is healthy.', p_function),
    0,
    false
  );
  PERFORM net.http_post(
    url := v_url || '/functions/v1/' || p_function,
    body := '{}'::jsonb,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-cron-secret', v_secret
    ),
    timeout_milliseconds := 10000
  );
  RETURN true;
END;
$$;

REVOKE ALL ON FUNCTION private.invoke_edge_worker(text, text)
  FROM PUBLIC, anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION private.invoke_storage_lifecycle_worker()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  -- Stay idle (no HTTP call) unless there is deletion or reservation work.
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

  PERFORM private.invoke_edge_worker('storage-lifecycle-worker', 'storage_lifecycle_worker');
END;
$$;

REVOKE ALL ON FUNCTION private.invoke_storage_lifecycle_worker()
  FROM PUBLIC, anon, authenticated;

DO $$
DECLARE
  v_job bigint;
BEGIN
  SELECT jobid INTO v_job FROM cron.job WHERE jobname = 'profile-nudge-daily';
  IF v_job IS NOT NULL THEN
    PERFORM cron.alter_job(
      v_job,
      command := $cmd$SELECT public.dispatch_profile_nudges(); SELECT private.invoke_edge_worker('dispatch-notifications', 'profile_nudge_dispatch');$cmd$
    );
  END IF;

  SELECT jobid INTO v_job FROM cron.job WHERE jobname = 'brevo_api_key_keepalive';
  IF v_job IS NOT NULL THEN
    PERFORM cron.alter_job(
      v_job,
      command := $cmd$SELECT private.invoke_edge_worker('brevo-key-keepalive', 'brevo_key_keepalive');$cmd$
    );
  END IF;
END;
$$;
