-- Audit 1: cache overlapping admin aggregates instead of rescanning growing
-- tables for every browser refresh.

CREATE TABLE IF NOT EXISTS private.admin_metric_snapshots (
  metric_name text PRIMARY KEY,
  payload jsonb NOT NULL,
  generated_at timestamptz NOT NULL DEFAULT now()
);
REVOKE ALL ON private.admin_metric_snapshots FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION private.refresh_admin_metric_snapshots()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_live jsonb;
  v_dashboard jsonb;
  v_health jsonb;
BEGIN
  IF NOT pg_try_advisory_xact_lock(hashtextextended(
    'admin_metric_snapshots', 153
  )) THEN
    RETURN;
  END IF;

  PERFORM set_config('statement_timeout', '45s', true);

  v_dashboard := jsonb_build_object(
    'totalUsers', (SELECT count(*) FROM public.profiles),
    'signupsToday', (
      SELECT count(*) FROM public.users WHERE created_at >= current_date
    ),
    'activeSevenDays', (
      SELECT count(*) FROM public.profiles
      WHERE last_active_at >= now() - interval '7 days'
    ),
    'pendingKyc', (
      SELECT count(*) FROM public.kyc_review_submissions
      WHERE status = 'pending'
    ),
    'openReports', (
      SELECT count(*) FROM public.reports WHERE status = 'pending'
    ),
    'activeSubscriptions', (
      SELECT count(*) FROM public.users
      WHERE subscription_status IN ('active', 'grace')
    ),
    'matchesToday', (
      SELECT count(*) FROM public.matches WHERE created_at >= current_date
    ),
    'messagesToday', (
      SELECT count(*) FROM public.messages WHERE created_at >= current_date
    )
  );

  v_health := jsonb_build_object(
    'dueNotifications', (
      SELECT count(*) FROM public.notifications
      WHERE sent_at IS NULL AND scheduled_at <= now()
    ),
    'futureNotifications', (
      SELECT count(*) FROM public.notifications
      WHERE sent_at IS NULL AND scheduled_at > now()
    ),
    'staleNotifications', (
      SELECT count(*) FROM public.notifications
      WHERE sent_at IS NULL
        AND scheduled_at < now() - interval '10 minutes'
    ),
    'fcmTokenUsers', (
      SELECT count(DISTINCT user_id) FROM public.user_fcm_tokens
    ),
    'pendingKyc', (
      SELECT count(*) FROM public.kyc_review_submissions
      WHERE status = 'pending'
    ),
    'pendingPhotos', (
      SELECT count(*) FROM public.photos WHERE moderation_status = 'pending'
    ),
    'openReports', (
      SELECT count(*) FROM public.reports WHERE status = 'pending'
    ),
    'queuedCampaigns', (
      SELECT count(*) FROM public.admin_push_campaigns WHERE status = 'queued'
    ),
    'publishedContentPages', (
      SELECT count(*) FROM public.app_content_pages WHERE status = 'published'
    ),
    'publishedSuccessStories', (
      SELECT count(*) FROM public.marriage_success_stories
      WHERE status = 'published'
    ),
    'subscriptionEvents24h', (
      SELECT count(*) FROM public.subscription_events
      WHERE created_at >= now() - interval '24 hours'
    ),
    'failedEmails24h', (
      SELECT count(*) FROM public.transactional_email_outbox
      WHERE status = 'failed' AND created_at >= now() - interval '24 hours'
    ),
    'rateLimitRejections1h', (
      SELECT coalesce(sum(rejected_count), 0)
      FROM private.edge_rate_limits
      WHERE bucket_started_at >= now() - interval '1 hour'
    ),
    'databaseUsageMb',
      round(pg_database_size(current_database()) / 1048576.0, 1),
    'storageUsageMb', round((
      SELECT coalesce(sum(
        CASE WHEN metadata->>'size' ~ '^[0-9]+$'
          THEN (metadata->>'size')::bigint ELSE 0 END
      ), 0)
      FROM storage.objects
    ) / 1048576.0, 1),
    'dispatchConsecutiveFailures', coalesce((
      SELECT consecutive_failures
      FROM private.edge_function_health
      WHERE function_name = 'dispatch-notifications'
    ), 0),
    'dispatchHealthy', CASE WHEN EXISTS (
      SELECT 1 FROM private.edge_function_health
      WHERE function_name = 'dispatch-notifications'
        AND consecutive_failures < 3
        AND last_success_at >= now() - interval '15 minutes'
    ) THEN 1 ELSE 0 END,
    'activeStaff', (
      SELECT count(*) FROM public.admin_memberships WHERE status = 'active'
    )
  );

  v_live := jsonb_build_object(
    'generatedAt', extract(epoch FROM now())::bigint,
    'traffic', jsonb_build_object(
      'onlineNow', (
        SELECT count(*) FROM public.user_presence
        WHERE last_seen_at >= now() - interval '12 minutes'
      ),
      'activeToday', (
        SELECT count(*) FROM public.user_presence
        WHERE last_seen_at >= now() - interval '24 hours'
      ),
      'activeSevenDays', (
        SELECT count(*) FROM public.user_presence
        WHERE last_seen_at >= now() - interval '7 days'
      ),
      'signupsLastHour', (
        SELECT count(*) FROM public.users
        WHERE created_at >= now() - interval '1 hour'
      ),
      'signupsToday', v_dashboard->'signupsToday'
    ),
    'engagement', jsonb_build_object(
      'messagesLastHour', (
        SELECT count(*) FROM public.messages
        WHERE created_at >= now() - interval '1 hour'
      ),
      'messagesToday', v_dashboard->'messagesToday',
      'interestsLastHour', (
        SELECT count(*) FROM public.interests
        WHERE created_at >= now() - interval '1 hour'
      ),
      'interestsToday', (
        SELECT count(*) FROM public.interests
        WHERE created_at >= current_date
      ),
      'matchesToday', v_dashboard->'matchesToday'
    ),
    'progress', jsonb_build_object(
      'avgCompletion', coalesce((
        SELECT round(avg(completeness_score))::int FROM public.profiles
      ), 0),
      'completedProfiles', (
        SELECT count(*) FROM public.profiles WHERE onboarding_completed = true
      ),
      'totalProfiles', v_dashboard->'totalUsers',
      'verifiedProfiles', (
        SELECT count(*) FROM public.profiles WHERE kyc_verified = true
      ),
      'pendingKyc', v_dashboard->'pendingKyc',
      'activeSubscribers', v_dashboard->'activeSubscriptions'
    ),
    'queues', jsonb_build_object(
      'openReports', v_health->'openReports',
      'pendingPhotos', v_health->'pendingPhotos',
      'dueNotifications', v_health->'dueNotifications',
      'futureNotifications', v_health->'futureNotifications',
      'sentNotificationsLastHour', (
        SELECT count(*) FROM public.notifications
        WHERE sent_at >= now() - interval '1 hour'
      )
    ),
    'pipeline', jsonb_build_object(
      'completionRate', coalesce((
        SELECT round(
          100.0 * count(*) FILTER (WHERE onboarding_completed = true)
          / nullif(count(*), 0)
        )::int FROM public.profiles
      ), 0),
      'verificationRate', coalesce((
        SELECT round(
          100.0 * count(*) FILTER (WHERE kyc_verified = true)
          / nullif(count(*), 0)
        )::int FROM public.profiles
      ), 0),
      'subscriberRate', coalesce((
        SELECT round(
          100.0 * count(*) FILTER (
            WHERE subscription_status IN ('active', 'grace')
          ) / nullif(count(*), 0)
        )::int FROM public.users
      ), 0),
      'photoClearanceRate', coalesce((
        SELECT round(
          100.0 * count(*) FILTER (WHERE moderation_status = 'approved')
          / nullif(count(*), 0)
        )::int FROM public.photos
      ), 0)
    )
  );

  INSERT INTO private.admin_metric_snapshots(
    metric_name, payload, generated_at
  )
  VALUES
    ('dashboard', v_dashboard, now()),
    ('system_health', v_health, now()),
    ('live_operations', v_live, now())
  ON CONFLICT (metric_name) DO UPDATE
  SET payload = EXCLUDED.payload, generated_at = EXCLUDED.generated_at;
END;
$$;
REVOKE ALL ON FUNCTION private.refresh_admin_metric_snapshots() FROM PUBLIC;

CREATE OR REPLACE FUNCTION public.admin_dashboard_metrics()
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT CASE WHEN public.is_active_admin()
    THEN (SELECT payload FROM private.admin_metric_snapshots
          WHERE metric_name = 'dashboard')
    ELSE NULL END;
$$;

CREATE OR REPLACE FUNCTION public.admin_system_health()
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT CASE WHEN public.is_active_admin()
    THEN (SELECT payload FROM private.admin_metric_snapshots
          WHERE metric_name = 'system_health')
    ELSE NULL END;
$$;

CREATE OR REPLACE FUNCTION public.admin_live_operations_snapshot()
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT CASE WHEN public.is_active_admin()
    THEN (SELECT payload FROM private.admin_metric_snapshots
          WHERE metric_name = 'live_operations')
    ELSE NULL END;
$$;

REVOKE ALL ON FUNCTION public.admin_dashboard_metrics() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_system_health() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_live_operations_snapshot() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_dashboard_metrics() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_system_health() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_live_operations_snapshot()
  TO authenticated;

SELECT private.refresh_admin_metric_snapshots();

DO $$
DECLARE v_job record;
BEGIN
  FOR v_job IN
    SELECT jobid FROM cron.job
    WHERE jobname = 'refresh_admin_metric_snapshots_5m'
  LOOP
    PERFORM cron.unschedule(v_job.jobid);
  END LOOP;
  PERFORM cron.schedule(
    'refresh_admin_metric_snapshots_5m',
    '*/5 * * * *',
    'SELECT private.refresh_admin_metric_snapshots();'
  );
END;
$$;
