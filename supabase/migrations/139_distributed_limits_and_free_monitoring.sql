-- Free-tier operational hardening:
--   * atomic Edge Function rate limits shared by every isolate
--   * durable health state for critical background workers
--   * 15-minute quota/backlog snapshots and deduplicated admin alerts

CREATE TABLE IF NOT EXISTS private.edge_rate_limits (
  scope text NOT NULL,
  subject text NOT NULL,
  bucket_started_at timestamptz NOT NULL,
  request_count integer NOT NULL DEFAULT 0 CHECK (request_count >= 0),
  rejected_count integer NOT NULL DEFAULT 0 CHECK (rejected_count >= 0),
  max_requests integer NOT NULL CHECK (max_requests > 0),
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (scope, subject, bucket_started_at)
);

CREATE INDEX IF NOT EXISTS idx_edge_rate_limits_bucket_cleanup
  ON private.edge_rate_limits(bucket_started_at);

REVOKE ALL ON private.edge_rate_limits FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.consume_edge_rate_limit(
  p_scope text,
  p_subject text,
  p_max_requests integer,
  p_window_seconds integer
)
RETURNS TABLE(allowed boolean, remaining integer, reset_at timestamptz)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_bucket timestamptz;
  v_count integer;
BEGIN
  IF p_scope !~ '^[a-z0-9_:-]{1,80}$'
     OR length(p_subject) NOT BETWEEN 1 AND 200
     OR p_max_requests NOT BETWEEN 1 AND 10000
     OR p_window_seconds NOT BETWEEN 1 AND 86400 THEN
    RAISE EXCEPTION 'Invalid rate-limit configuration';
  END IF;

  v_bucket := to_timestamp(
    floor(extract(epoch FROM clock_timestamp()) / p_window_seconds)
      * p_window_seconds
  );

  INSERT INTO private.edge_rate_limits AS limits (
    scope,
    subject,
    bucket_started_at,
    request_count,
    rejected_count,
    max_requests,
    updated_at
  )
  VALUES (p_scope, p_subject, v_bucket, 1, 0, p_max_requests, now())
  ON CONFLICT (scope, subject, bucket_started_at) DO UPDATE
  SET request_count = limits.request_count + 1,
      rejected_count = limits.rejected_count
        + CASE WHEN limits.request_count >= p_max_requests THEN 1 ELSE 0 END,
      max_requests = p_max_requests,
      updated_at = now()
  RETURNING request_count INTO v_count;

  RETURN QUERY SELECT
    v_count <= p_max_requests,
    greatest(p_max_requests - v_count, 0),
    v_bucket + make_interval(secs => p_window_seconds);
END;
$$;

REVOKE ALL ON FUNCTION public.consume_edge_rate_limit(text, text, integer, integer)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.consume_edge_rate_limit(text, text, integer, integer)
  TO service_role;

CREATE TABLE IF NOT EXISTS private.edge_function_health (
  function_name text PRIMARY KEY,
  last_success_at timestamptz,
  last_failure_at timestamptz,
  consecutive_failures integer NOT NULL DEFAULT 0,
  last_error text,
  last_details jsonb NOT NULL DEFAULT '{}'::jsonb,
  updated_at timestamptz NOT NULL DEFAULT now()
);

REVOKE ALL ON private.edge_function_health FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.record_edge_function_result(
  p_function_name text,
  p_success boolean,
  p_error text DEFAULT NULL,
  p_details jsonb DEFAULT '{}'::jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF p_function_name NOT IN (
    'dispatch-notifications',
    'get-signed-url',
    'validate-photo-upload',
    'translate-message',
    'process-kyc',
    'digilocker-verify'
  ) THEN
    RAISE EXCEPTION 'Unknown Edge Function health key';
  END IF;

  INSERT INTO private.edge_function_health AS health (
    function_name,
    last_success_at,
    last_failure_at,
    consecutive_failures,
    last_error,
    last_details,
    updated_at
  )
  VALUES (
    p_function_name,
    CASE WHEN p_success THEN now() ELSE NULL END,
    CASE WHEN p_success THEN NULL ELSE now() END,
    CASE WHEN p_success THEN 0 ELSE 1 END,
    CASE WHEN p_success THEN NULL ELSE left(coalesce(p_error, 'Unknown failure'), 1000) END,
    coalesce(p_details, '{}'::jsonb),
    now()
  )
  ON CONFLICT (function_name) DO UPDATE
  SET last_success_at = CASE
        WHEN p_success THEN now()
        ELSE health.last_success_at
      END,
      last_failure_at = CASE
        WHEN p_success THEN health.last_failure_at
        ELSE now()
      END,
      consecutive_failures = CASE
        WHEN p_success THEN 0
        ELSE health.consecutive_failures + 1
      END,
      last_error = CASE
        WHEN p_success THEN NULL
        ELSE left(coalesce(p_error, 'Unknown failure'), 1000)
      END,
      last_details = coalesce(p_details, '{}'::jsonb),
      updated_at = now();
END;
$$;

REVOKE ALL ON FUNCTION public.record_edge_function_result(text, boolean, text, jsonb)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.record_edge_function_result(text, boolean, text, jsonb)
  TO service_role;

CREATE TABLE IF NOT EXISTS private.operational_health_snapshots (
  captured_at timestamptz PRIMARY KEY DEFAULT now(),
  database_bytes bigint NOT NULL,
  storage_bytes bigint NOT NULL,
  stale_due_notifications bigint NOT NULL,
  failed_emails_24h bigint NOT NULL,
  rate_limit_rejections_1h bigint NOT NULL,
  dispatch_consecutive_failures integer NOT NULL,
  dispatch_last_success_at timestamptz
);

CREATE INDEX IF NOT EXISTS idx_operational_health_snapshots_captured
  ON private.operational_health_snapshots(captured_at DESC);

CREATE TABLE IF NOT EXISTS private.operational_alert_state (
  alert_key text PRIMARY KEY,
  is_active boolean NOT NULL DEFAULT false,
  last_value bigint,
  last_alerted_at timestamptz,
  updated_at timestamptz NOT NULL DEFAULT now()
);

REVOKE ALL ON private.operational_health_snapshots
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON private.operational_alert_state
  FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION private.set_operational_alert(
  p_key text,
  p_message text,
  p_value bigint,
  p_active boolean
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_previous private.operational_alert_state%ROWTYPE;
BEGIN
  SELECT * INTO v_previous
  FROM private.operational_alert_state
  WHERE alert_key = p_key
  FOR UPDATE;

  IF p_active AND (
    NOT FOUND
    OR NOT v_previous.is_active
    OR v_previous.last_alerted_at < now() - interval '6 hours'
  ) THEN
    INSERT INTO public.admin_notifications(type, message)
    VALUES ('system_health_alert', left(p_message, 2000));
  END IF;

  INSERT INTO private.operational_alert_state AS state (
    alert_key,
    is_active,
    last_value,
    last_alerted_at,
    updated_at
  )
  VALUES (
    p_key,
    p_active,
    p_value,
    CASE WHEN p_active THEN now() ELSE NULL END,
    now()
  )
  ON CONFLICT (alert_key) DO UPDATE
  SET is_active = p_active,
      last_value = p_value,
      last_alerted_at = CASE
        WHEN p_active AND (
          NOT state.is_active
          OR state.last_alerted_at < now() - interval '6 hours'
        ) THEN now()
        WHEN NOT p_active THEN NULL
        ELSE state.last_alerted_at
      END,
      updated_at = now();
END;
$$;

REVOKE ALL ON FUNCTION private.set_operational_alert(text, text, bigint, boolean)
  FROM PUBLIC;

CREATE OR REPLACE FUNCTION private.capture_operational_health()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_database_bytes bigint;
  v_storage_bytes bigint;
  v_stale_due bigint;
  v_failed_emails bigint;
  v_rate_rejections bigint;
  v_dispatch_failures integer := 0;
  v_dispatch_last_success timestamptz;
  v_dispatch_unhealthy boolean := false;
  v_dispatch_seen boolean := false;
BEGIN
  SELECT pg_database_size(current_database()) INTO v_database_bytes;

  SELECT coalesce(sum(
    CASE
      WHEN metadata->>'size' ~ '^[0-9]+$' THEN (metadata->>'size')::bigint
      ELSE 0
    END
  ), 0)
  INTO v_storage_bytes
  FROM storage.objects;

  SELECT count(*) INTO v_stale_due
  FROM public.notifications
  WHERE sent_at IS NULL
    AND scheduled_at < now() - interval '10 minutes';

  SELECT count(*) INTO v_failed_emails
  FROM public.transactional_email_outbox
  WHERE status = 'failed'
    AND created_at >= now() - interval '24 hours';

  SELECT coalesce(sum(rejected_count), 0) INTO v_rate_rejections
  FROM private.edge_rate_limits
  WHERE bucket_started_at >= now() - interval '1 hour';

  SELECT
    coalesce(max(consecutive_failures), 0),
    max(last_success_at),
    count(*) > 0
  INTO v_dispatch_failures, v_dispatch_last_success, v_dispatch_seen
  FROM private.edge_function_health
  WHERE function_name = 'dispatch-notifications';

  IF v_dispatch_seen THEN
    v_dispatch_unhealthy := v_dispatch_failures >= 3
      OR v_dispatch_last_success IS NULL
      OR v_dispatch_last_success < now() - interval '15 minutes';
  END IF;

  INSERT INTO private.operational_health_snapshots (
    database_bytes,
    storage_bytes,
    stale_due_notifications,
    failed_emails_24h,
    rate_limit_rejections_1h,
    dispatch_consecutive_failures,
    dispatch_last_success_at
  )
  VALUES (
    v_database_bytes,
    v_storage_bytes,
    v_stale_due,
    v_failed_emails,
    v_rate_rejections,
    v_dispatch_failures,
    v_dispatch_last_success
  );

  PERFORM private.set_operational_alert(
    'database_usage',
    format('Database usage reached %s MB of the 500 MB free-tier allowance.', round(v_database_bytes / 1048576.0, 1)),
    v_database_bytes,
    v_database_bytes >= 400 * 1024 * 1024
  );
  PERFORM private.set_operational_alert(
    'storage_usage',
    format('Storage usage reached %s MB of the 1 GB free-tier allowance.', round(v_storage_bytes / 1048576.0, 1)),
    v_storage_bytes,
    v_storage_bytes >= 800 * 1024 * 1024
  );
  PERFORM private.set_operational_alert(
    'notification_backlog',
    format('%s notifications have been due for more than 10 minutes.', v_stale_due),
    v_stale_due,
    v_stale_due >= 10
  );
  PERFORM private.set_operational_alert(
    'transactional_email_failures',
    format('%s transactional emails failed during the last 24 hours.', v_failed_emails),
    v_failed_emails,
    v_failed_emails >= 3
  );
  PERFORM private.set_operational_alert(
    'rate_limit_rejections',
    format('%s requests were blocked by distributed rate limits during the last hour.', v_rate_rejections),
    v_rate_rejections,
    v_rate_rejections >= 50
  );
  PERFORM private.set_operational_alert(
    'notification_dispatch_health',
    format('Notification dispatch is unhealthy with %s consecutive failures.', v_dispatch_failures),
    v_dispatch_failures,
    v_dispatch_unhealthy
  );

  DELETE FROM private.edge_rate_limits
  WHERE bucket_started_at < now() - interval '2 days';
  DELETE FROM private.operational_health_snapshots
  WHERE captured_at < now() - interval '7 days';
END;
$$;

REVOKE ALL ON FUNCTION private.capture_operational_health() FROM PUBLIC;

CREATE OR REPLACE FUNCTION public.admin_system_health()
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT CASE WHEN public.is_active_admin() THEN jsonb_build_object(
    'dueNotifications', (SELECT count(*) FROM public.notifications WHERE sent_at IS NULL AND scheduled_at <= now()),
    'futureNotifications', (SELECT count(*) FROM public.notifications WHERE sent_at IS NULL AND scheduled_at > now()),
    'staleNotifications', (SELECT count(*) FROM public.notifications WHERE sent_at IS NULL AND scheduled_at < now() - interval '10 minutes'),
    'fcmTokenUsers', (SELECT count(DISTINCT user_id) FROM public.user_fcm_tokens),
    'pendingKyc', (SELECT count(*) FROM public.profiles WHERE verification_status = 'pending_review'),
    'pendingPhotos', (SELECT count(*) FROM public.photos WHERE moderation_status = 'pending'),
    'openReports', (SELECT count(*) FROM public.reports WHERE status = 'pending'),
    'queuedCampaigns', (SELECT count(*) FROM public.admin_push_campaigns WHERE status = 'queued'),
    'publishedContentPages', (SELECT count(*) FROM public.app_content_pages WHERE status = 'published'),
    'publishedSuccessStories', (SELECT count(*) FROM public.marriage_success_stories WHERE status = 'published'),
    'subscriptionEvents24h', (SELECT count(*) FROM public.subscription_events WHERE created_at >= now() - interval '24 hours'),
    'failedEmails24h', (SELECT count(*) FROM public.transactional_email_outbox WHERE status = 'failed' AND created_at >= now() - interval '24 hours'),
    'rateLimitRejections1h', (SELECT coalesce(sum(rejected_count), 0) FROM private.edge_rate_limits WHERE bucket_started_at >= now() - interval '1 hour'),
    'databaseUsageMb', round(pg_database_size(current_database()) / 1048576.0, 1),
    'storageUsageMb', round((SELECT coalesce(sum(CASE WHEN metadata->>'size' ~ '^[0-9]+$' THEN (metadata->>'size')::bigint ELSE 0 END), 0) FROM storage.objects) / 1048576.0, 1),
    'dispatchConsecutiveFailures', coalesce((SELECT consecutive_failures FROM private.edge_function_health WHERE function_name = 'dispatch-notifications'), 0),
    'dispatchHealthy', CASE WHEN EXISTS (
      SELECT 1 FROM private.edge_function_health
      WHERE function_name = 'dispatch-notifications'
        AND consecutive_failures < 3
        AND last_success_at >= now() - interval '15 minutes'
    ) THEN 1 ELSE 0 END,
    'activeStaff', (SELECT count(*) FROM public.admin_memberships WHERE status = 'active')
  ) ELSE NULL END;
$$;

REVOKE ALL ON FUNCTION public.admin_system_health() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_system_health() TO authenticated;

DO $$
DECLARE
  v_job record;
BEGIN
  FOR v_job IN SELECT jobid FROM cron.job WHERE jobname = 'capture_operational_health_15m'
  LOOP
    PERFORM cron.unschedule(v_job.jobid);
  END LOOP;

  PERFORM cron.schedule(
    'capture_operational_health_15m',
    '*/15 * * * *',
    'SELECT private.capture_operational_health();'
  );
END;
$$;

SELECT private.capture_operational_health();
