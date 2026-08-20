-- An intentionally idle event-driven worker is healthy when it has no stale
-- queue. Do not report an outage merely because no notification needed to be
-- delivered during the last fifteen minutes.

CREATE OR REPLACE FUNCTION private.notification_dispatch_health()
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  WITH queue AS (
    SELECT
      count(*) FILTER (
        WHERE sent_at IS NULL AND scheduled_at <= now()
      ) AS due_count,
      count(*) FILTER (
        WHERE sent_at IS NULL
          AND scheduled_at < now() - interval '10 minutes'
      ) AS stale_count
    FROM public.notifications
  ), health AS (
    SELECT consecutive_failures, last_success_at, last_failure_at
    FROM private.edge_function_health
    WHERE function_name = 'dispatch-notifications'
  )
  SELECT jsonb_build_object(
    'status', CASE
      WHEN queue.stale_count > 0
        OR coalesce(health.consecutive_failures, 0) >= 3
        THEN 'degraded'
      WHEN queue.due_count = 0
        AND (
          health.last_success_at IS NULL
          OR health.last_success_at < now() - interval '15 minutes'
        ) THEN 'idle'
      ELSE 'healthy'
    END,
    'due', queue.due_count,
    'stale', queue.stale_count,
    'consecutive_failures', coalesce(health.consecutive_failures, 0),
    'last_success_at', health.last_success_at,
    'last_failure_at', health.last_failure_at
  )
  FROM queue
  LEFT JOIN health ON true;
$$;

REVOKE ALL ON FUNCTION private.notification_dispatch_health()
  FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.audit_settings_wiring()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_jobs jsonb;
  v_dispatch jsonb;
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'service_role_required' USING ERRCODE = '42501';
  END IF;

  SELECT coalesce(jsonb_object_agg(jobname, active), '{}'::jsonb)
  INTO v_jobs
  FROM cron.job
  WHERE jobname IN (
    'dispatch_notifications_fallback_5m',
    'discovery_notifications_bounded_5m',
    'process_interest_expiry_hourly',
    'process_member_reminders_daily',
    'profile-nudge-daily',
    'refresh_admin_metric_snapshots_5m'
  );

  v_dispatch := private.notification_dispatch_health();

  RETURN jsonb_build_object(
    'cron_jobs', v_jobs,
    'notification_dispatch_status', v_dispatch,
    'notification_dispatch_healthy',
      v_dispatch->>'status' IN ('healthy', 'idle'),
    'stale_notifications', (v_dispatch->>'stale')::bigint,
    'fcm_token_users', (
      SELECT count(DISTINCT user_id) FROM public.user_fcm_tokens
    ),
    'guardian_atomic_save',
      to_regprocedure(
        'public.save_my_guardian_configuration(boolean,boolean,text,text,text)'
      ) IS NOT NULL,
    'photo_privacy_context',
      to_regprocedure('public.get_photo_access_context(uuid)') IS NOT NULL,
    'photo_request_management',
      to_regprocedure('public.get_incoming_photo_access_requests()') IS NOT NULL,
    'profile_pause',
      to_regprocedure('public.set_profile_pause(boolean)') IS NOT NULL,
    'personal_data_export',
      to_regprocedure('public.download_my_data(text)') IS NOT NULL,
    'weekly_boost',
      to_regprocedure('public.activate_profile_boost()') IS NOT NULL
  );
END;
$$;

REVOKE ALL ON FUNCTION public.audit_settings_wiring()
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.audit_settings_wiring()
  TO service_role;

-- Keep the existing admin snapshot implementation but make its dispatch
-- health test idle-aware. The exact anchor is asserted to prevent a silent
-- no-op if that function is refactored later.
DO $migration$
DECLARE
  v_signature regprocedure :=
    'private.refresh_admin_metric_snapshots()'::regprocedure;
  v_definition text;
  v_old text := $$AND last_success_at >= now() - interval '15 minutes'$$;
  v_new text := $$AND (
          last_success_at >= now() - interval '15 minutes'
          OR NOT EXISTS (
            SELECT 1 FROM public.notifications queued
            WHERE queued.sent_at IS NULL
              AND queued.scheduled_at < now() - interval '10 minutes'
          )
        )$$;
BEGIN
  SELECT pg_get_functiondef(v_signature) INTO v_definition;
  IF position(v_old IN v_definition) = 0 THEN
    RAISE EXCEPTION 'admin_dispatch_health_patch_anchor_not_found';
  END IF;
  EXECUTE replace(v_definition, v_old, v_new);
  PERFORM private.refresh_admin_metric_snapshots();
END;
$migration$;

NOTIFY pgrst, 'reload schema';
