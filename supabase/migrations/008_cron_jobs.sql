-- ============================================================
-- MIGRATION 008: SCHEDULED JOBS (pg_cron)
-- All cron schedules in one place for easy review.
-- Times are UTC.
-- ============================================================

-- ------------------------------------------------------------
-- 1. Expire pending interests that have passed their 14d window
-- Runs hourly at :00
-- ------------------------------------------------------------
SELECT cron.schedule(
  'expire_interests_hourly',
  '0 * * * *',
  $$
    UPDATE interests
    SET status = 'expired'
    WHERE status = 'pending'
      AND expires_at < now();
  $$
);

-- ------------------------------------------------------------
-- 2. Clean sent notifications older than 30 days
-- Runs daily at 02:30 UTC
-- ------------------------------------------------------------
SELECT cron.schedule(
  'clean_notifications_daily',
  '30 2 * * *',
  $$
    DELETE FROM notifications
    WHERE sent_at IS NOT NULL
      AND scheduled_at < now() - interval '30 days';
  $$
);

-- ------------------------------------------------------------
-- 3. Recompute global rank scores (completeness + recency + boost)
-- Runs nightly at 02:00 UTC
-- ------------------------------------------------------------
SELECT cron.schedule(
  'compute_global_rank_scores_nightly',
  '0 2 * * *',
  $$SELECT compute_global_rank_scores();$$
);

-- ------------------------------------------------------------
-- 4. Refresh the discovery_pool materialized view
-- CONCURRENTLY ensures zero read downtime during refresh.
-- Runs after rank score computation at 02:30 UTC.
-- ------------------------------------------------------------
SELECT cron.schedule(
  'refresh_discovery_pool_daily',
  '30 2 * * *',
  $$REFRESH MATERIALIZED VIEW CONCURRENTLY discovery_pool;$$
);

-- ------------------------------------------------------------
-- 5. Hide profiles inactive for 30+ days
-- Runs daily at 03:00 UTC
-- ------------------------------------------------------------
SELECT cron.schedule(
  'hide_inactive_profiles_daily',
  '0 3 * * *',
  $$SELECT hide_inactive_profiles();$$
);

-- ------------------------------------------------------------
-- 6. Trigger account purge Edge Function (Zombie Auth prevention)
-- NEVER deletes users directly from pg_cron — must call the
-- admin-purge-deleted-users Edge Function which uses
-- supabase.auth.admin.deleteUser() FIRST, then deletes from
-- public.users. This prevents "Zombie Auth" orphaned sessions.
-- Runs daily at 03:15 UTC
-- ------------------------------------------------------------
SELECT cron.schedule(
  'trigger_purge_deleted_accounts',
  '15 3 * * *',
  $$
    SELECT net.http_post(
      url  := 'https://<YOUR_PROJECT_REF>.supabase.co/functions/v1/admin-purge-deleted-users',
      body := '{}'::jsonb,
      headers := jsonb_build_object(
        'Authorization', 'Bearer ' || current_setting('app.service_role_key', true),
        'Content-Type',  'application/json'
      )
    );
  $$
);

-- ------------------------------------------------------------
-- 7. Clean old content violation records (GDPR retention: 90d)
-- Runs weekly on Sundays at 04:00 UTC
-- ------------------------------------------------------------
SELECT cron.schedule(
  'purge_old_content_violations',
  '0 4 * * 0',
  $$
    DELETE FROM content_violations
    WHERE created_at < now() - interval '90 days';
  $$
);

-- ------------------------------------------------------------
-- REVIEW ALL SCHEDULED JOBS:
--   SELECT * FROM cron.job;
-- UNSCHEDULE A JOB:
--   SELECT cron.unschedule('job_name');
-- ------------------------------------------------------------
