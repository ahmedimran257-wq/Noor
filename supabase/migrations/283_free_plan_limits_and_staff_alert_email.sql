-- Silarah — free-plan limits on the admin System page, alerts at 70 % and
-- 85 %, and staff email when an alert first fires.
--
-- Everything is computed in the existing 15-minute jobs; nothing new polls.
-- Limits that SQL cannot see (bandwidth, edge invocations) stay on the
-- Supabase Usage page.
--
-- Also fixes a false alarm: capture_operational_health marked the push
-- dispatcher unhealthy whenever it had not succeeded in 15 minutes, but the
-- dispatcher only runs when something is due, so every quiet quarter hour
-- raised "unhealthy with 0 consecutive failures". It now matches the admin
-- dashboard: unhealthy means repeated failures, or notifications waiting
-- with no recent success.

-- Free plan allowances in one place. Update when the plan changes.
CREATE OR REPLACE FUNCTION private.free_plan_limits()
RETURNS jsonb
LANGUAGE sql
IMMUTABLE
SET search_path = ''
AS $$
  SELECT jsonb_build_object(
    'databaseMb', 500,
    'storageMb', 1024,
    'monthlyActiveUsers', 50000,
    'dbConnections', 60
  );
$$;
REVOKE ALL ON FUNCTION private.free_plan_limits() FROM PUBLIC, anon, authenticated;

ALTER TABLE private.operational_health_snapshots
  ADD COLUMN IF NOT EXISTS online_members integer,
  ADD COLUMN IF NOT EXISTS db_connections integer,
  ADD COLUMN IF NOT EXISTS monthly_active_users integer;

-- Staff alert email queue
CREATE TABLE IF NOT EXISTS private.staff_alert_emails (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  alert_key text NOT NULL,
  message text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  claimed_at timestamptz,
  sent_at timestamptz,
  attempts smallint NOT NULL DEFAULT 0,
  last_error text
);
CREATE INDEX IF NOT EXISTS idx_staff_alert_emails_pending
  ON private.staff_alert_emails(created_at)
  WHERE sent_at IS NULL;
ALTER TABLE private.staff_alert_emails ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON private.staff_alert_emails FROM PUBLIC, anon, authenticated;

-- An alert reaches the admin inbox when it fires and every 6 hours while it
-- stays active (unchanged). Email goes out only when it newly fires, so a
-- limit that stays at 72 % does not mail staff four times a day.
CREATE OR REPLACE FUNCTION private.set_operational_alert(
  p_key text,
  p_message text,
  p_value bigint,
  p_active boolean
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_previous private.operational_alert_state%ROWTYPE;
  v_newly_active boolean;
BEGIN
  SELECT * INTO v_previous
  FROM private.operational_alert_state
  WHERE alert_key = p_key
  FOR UPDATE;

  v_newly_active := p_active AND (NOT FOUND OR NOT v_previous.is_active);

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

  -- The worker's own configuration alert must not try to wake the worker.
  IF v_newly_active AND p_key <> 'staff_alert_email_worker' THEN
    INSERT INTO private.staff_alert_emails(alert_key, message)
    VALUES (p_key, left(p_message, 2000));
    PERFORM private.invoke_edge_worker(
      'staff-alert-email',
      'staff_alert_email_worker'
    );
  END IF;
END;
$function$;
REVOKE ALL ON FUNCTION private.set_operational_alert(text, text, bigint, boolean)
  FROM PUBLIC, anon, authenticated;

-- One limit, two alert levels.
CREATE OR REPLACE FUNCTION private.set_limit_alerts(
  p_key text,
  p_label text,
  p_value numeric,
  p_limit numeric,
  p_unit text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_percent numeric := CASE WHEN p_limit > 0 THEN 100 * p_value / p_limit ELSE 0 END;
  v_message text := format(
    '%s reached %s%s of the %s%s free-plan allowance (%s%%). Plan the upgrade to Supabase Pro.',
    p_label, round(p_value, 1), p_unit, p_limit, p_unit, round(v_percent)
  );
BEGIN
  PERFORM private.set_operational_alert(
    p_key || '_70', v_message, round(v_percent)::bigint, v_percent >= 70
  );
  PERFORM private.set_operational_alert(
    p_key || '_85', v_message, round(v_percent)::bigint, v_percent >= 85
  );
END;
$$;
REVOKE ALL ON FUNCTION private.set_limit_alerts(text, text, numeric, numeric, text)
  FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION private.capture_operational_health()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_limits jsonb := private.free_plan_limits();
  v_database_bytes bigint;
  v_storage_bytes bigint;
  v_stale_due bigint;
  v_failed_emails bigint;
  v_rate_rejections bigint;
  v_dispatch_failures integer := 0;
  v_dispatch_last_success timestamptz;
  v_dispatch_unhealthy boolean := false;
  v_dispatch_seen boolean := false;
  v_online integer;
  v_connections integer;
  v_monthly_active integer;
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

  -- The dispatcher only runs when work is due, so a quiet period without a
  -- success is normal. It is unhealthy after repeated failures, or when
  -- notifications are waiting and nothing has been sent recently.
  IF v_dispatch_seen THEN
    v_dispatch_unhealthy := v_dispatch_failures >= 3
      OR (
        v_stale_due > 0
        AND (
          v_dispatch_last_success IS NULL
          OR v_dispatch_last_success < now() - interval '15 minutes'
        )
      );
  END IF;

  -- Members whose app has sent its heartbeat (every 10 minutes while open).
  SELECT count(*) INTO v_online
  FROM public.user_presence
  WHERE last_seen_at >= now() - interval '12 minutes';

  SELECT count(*) INTO v_monthly_active
  FROM public.user_presence
  WHERE last_seen_at >= now() - interval '30 days';

  SELECT count(*) INTO v_connections FROM pg_catalog.pg_stat_activity;

  INSERT INTO private.operational_health_snapshots (
    database_bytes,
    storage_bytes,
    stale_due_notifications,
    failed_emails_24h,
    rate_limit_rejections_1h,
    dispatch_consecutive_failures,
    dispatch_last_success_at,
    online_members,
    db_connections,
    monthly_active_users
  )
  VALUES (
    v_database_bytes,
    v_storage_bytes,
    v_stale_due,
    v_failed_emails,
    v_rate_rejections,
    v_dispatch_failures,
    v_dispatch_last_success,
    v_online,
    v_connections,
    v_monthly_active
  );

  PERFORM private.set_limit_alerts(
    'database_usage', 'Database size',
    round(v_database_bytes / 1048576.0, 1), (v_limits->>'databaseMb')::numeric, ' MB'
  );
  PERFORM private.set_limit_alerts(
    'storage_usage', 'Photo storage',
    round(v_storage_bytes / 1048576.0, 1), (v_limits->>'storageMb')::numeric, ' MB'
  );
  PERFORM private.set_limit_alerts(
    'monthly_active_users', 'Monthly active members',
    v_monthly_active, (v_limits->>'monthlyActiveUsers')::numeric, ''
  );
  PERFORM private.set_limit_alerts(
    'db_connections', 'Database connections',
    v_connections, (v_limits->>'dbConnections')::numeric, ''
  );
  -- The single 80 % alerts are replaced by the two levels above.
  PERFORM private.set_operational_alert('database_usage', 'retired', 0, false);
  PERFORM private.set_operational_alert('storage_usage', 'retired', 0, false);

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
    format('Notification dispatch is unhealthy: %s consecutive failures, %s notifications waiting.', v_dispatch_failures, v_stale_due),
    v_dispatch_failures,
    v_dispatch_unhealthy
  );

  DELETE FROM private.edge_rate_limits
  WHERE bucket_started_at < now() - interval '2 days';
  DELETE FROM private.operational_health_snapshots
  WHERE captured_at < now() - interval '7 days';
END;
$function$;
REVOKE ALL ON FUNCTION private.capture_operational_health()
  FROM PUBLIC, anon, authenticated;

-- System page: add a freePlan block to the 15-minute system_health snapshot.
-- Only this one anchor changes inside the deployed function.
DO $migration$
DECLARE
  v_original text;
  v_updated text;
  v_anchor text := $a$    'activeStaff', (
      SELECT count(*) FROM public.admin_memberships
      WHERE status = 'active'
    )
  );$a$;
BEGIN
  SELECT replace(pg_get_functiondef(
    'private.refresh_admin_metric_snapshots()'::regprocedure
  ), E'\r\n', E'\n') INTO v_original;
  IF position(v_anchor IN v_original) = 0 THEN
    RAISE EXCEPTION 'refresh_admin_metric_snapshots_anchor_missing';
  END IF;
  IF position('''freePlan''' IN v_original) > 0 THEN
    RETURN;
  END IF;
  v_updated := replace(v_original, v_anchor, $r$    'activeStaff', (
      SELECT count(*) FROM public.admin_memberships
      WHERE status = 'active'
    ),
    'freePlan', (
      SELECT private.free_plan_limits() || jsonb_build_object(
        'databaseUsedMb',
          round(pg_database_size(current_database()) / 1048576.0, 1),
        'storageUsedMb', round((
          SELECT coalesce(sum(
            CASE WHEN metadata->>'size' ~ '^[0-9]+$'
              THEN (metadata->>'size')::bigint ELSE 0 END
          ), 0)
          FROM storage.objects
        ) / 1048576.0, 1),
        'monthlyActiveUsed', (
          SELECT count(*) FROM public.user_presence
          WHERE last_seen_at >= now() - interval '30 days'
        ),
        'onlineNow', (
          SELECT count(*) FROM public.user_presence
          WHERE last_seen_at >= now() - interval '12 minutes'
        ),
        'peakOnline24h', coalesce((
          SELECT max(online_members) FROM private.operational_health_snapshots
          WHERE captured_at >= now() - interval '24 hours'
        ), 0),
        'dbConnectionsNow',
          (SELECT count(*) FROM pg_catalog.pg_stat_activity),
        'peakDbConnections24h', coalesce((
          SELECT max(db_connections) FROM private.operational_health_snapshots
          WHERE captured_at >= now() - interval '24 hours'
        ), 0)
      )
    )
  );$r$);
  EXECUTE v_updated;
END;
$migration$;

-- Worker RPCs (service role only)
CREATE OR REPLACE FUNCTION public.claim_staff_alert_emails(p_limit integer DEFAULT 10)
RETURNS TABLE(id bigint, alert_key text, message text, created_at timestamptz, recipients text[])
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_recipients text[];
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'service_role_required' USING ERRCODE = '42501';
  END IF;

  SELECT coalesce(array_agg(DISTINCT lower(u.email)), ARRAY[]::text[])
  INTO v_recipients
  FROM public.admin_memberships m
  JOIN auth.users u ON u.id = m.user_id
  WHERE m.status = 'active'
    AND u.email IS NOT NULL;

  RETURN QUERY
  UPDATE private.staff_alert_emails e
  SET claimed_at = now(),
      attempts = e.attempts + 1
  WHERE e.id IN (
    SELECT q.id FROM private.staff_alert_emails q
    WHERE q.sent_at IS NULL
      AND q.attempts < 5
      AND (q.claimed_at IS NULL OR q.claimed_at < now() - interval '5 minutes')
    ORDER BY q.created_at
    LIMIT least(greatest(coalesce(p_limit, 10), 1), 25)
    FOR UPDATE SKIP LOCKED
  )
  RETURNING e.id, e.alert_key, e.message, e.created_at, v_recipients;
END;
$$;
REVOKE ALL ON FUNCTION public.claim_staff_alert_emails(integer)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.claim_staff_alert_emails(integer) TO service_role;

CREATE OR REPLACE FUNCTION public.complete_staff_alert_email(
  p_id bigint,
  p_sent boolean,
  p_error text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'service_role_required' USING ERRCODE = '42501';
  END IF;
  UPDATE private.staff_alert_emails
  SET sent_at = CASE WHEN p_sent THEN now() ELSE NULL END,
      claimed_at = CASE WHEN p_sent THEN claimed_at ELSE NULL END,
      last_error = CASE WHEN p_sent THEN NULL ELSE left(p_error, 500) END
  WHERE id = p_id;
END;
$$;
REVOKE ALL ON FUNCTION public.complete_staff_alert_email(bigint, boolean, text)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.complete_staff_alert_email(bigint, boolean, text)
  TO service_role;

-- Retry anything a failed wake-up left behind, alongside the health capture.
CREATE OR REPLACE FUNCTION private.retry_staff_alert_emails()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM private.staff_alert_emails
    WHERE sent_at IS NULL
      AND attempts < 5
      AND created_at < now() - interval '10 minutes'
      AND (claimed_at IS NULL OR claimed_at < now() - interval '5 minutes')
  ) THEN
    PERFORM private.invoke_edge_worker('staff-alert-email', 'staff_alert_email_worker');
  END IF;
  DELETE FROM private.staff_alert_emails
  WHERE created_at < now() - interval '30 days';
END;
$$;
REVOKE ALL ON FUNCTION private.retry_staff_alert_emails()
  FROM PUBLIC, anon, authenticated;

DO $$
DECLARE v_job record;
BEGIN
  IF to_regclass('cron.job') IS NULL THEN RETURN; END IF;
  FOR v_job IN SELECT jobid FROM cron.job WHERE jobname = 'retry_staff_alert_emails_hourly' LOOP
    PERFORM cron.unschedule(v_job.jobid);
  END LOOP;
  PERFORM cron.schedule(
    'retry_staff_alert_emails_hourly',
    '23 * * * *',
    'SELECT private.retry_staff_alert_emails();'
  );
END;
$$;

COMMENT ON TABLE private.staff_alert_emails IS
  'Staff emails for operational alerts, queued when an alert newly fires.';
