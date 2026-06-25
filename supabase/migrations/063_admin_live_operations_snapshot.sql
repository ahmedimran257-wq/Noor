-- Premium admin live operations snapshot.
-- Every value is derived from first-party Supabase tables; no placeholder traffic.

CREATE OR REPLACE FUNCTION public.admin_live_operations_snapshot()
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT CASE WHEN public.is_active_admin() THEN jsonb_build_object(
    'generatedAt', extract(epoch FROM now())::bigint,
    'traffic', jsonb_build_object(
      'onlineNow', (
        SELECT count(*) FROM profiles
        WHERE last_active_at >= now() - interval '15 minutes'
      ),
      'activeToday', (
        SELECT count(*) FROM profiles
        WHERE last_active_at >= now() - interval '24 hours'
      ),
      'activeSevenDays', (
        SELECT count(*) FROM profiles
        WHERE last_active_at >= now() - interval '7 days'
      ),
      'signupsLastHour', (
        SELECT count(*) FROM users
        WHERE created_at >= now() - interval '1 hour'
      ),
      'signupsToday', (
        SELECT count(*) FROM users
        WHERE created_at >= date_trunc('day', now())
      )
    ),
    'engagement', jsonb_build_object(
      'messagesLastHour', (
        SELECT count(*) FROM messages
        WHERE created_at >= now() - interval '1 hour'
      ),
      'messagesToday', (
        SELECT count(*) FROM messages
        WHERE created_at >= date_trunc('day', now())
      ),
      'interestsLastHour', (
        SELECT count(*) FROM interests
        WHERE created_at >= now() - interval '1 hour'
      ),
      'interestsToday', (
        SELECT count(*) FROM interests
        WHERE created_at >= date_trunc('day', now())
      ),
      'matchesToday', (
        SELECT count(*) FROM matches
        WHERE created_at >= date_trunc('day', now())
      )
    ),
    'progress', jsonb_build_object(
      'avgCompletion', coalesce((
        SELECT round(avg(completeness_score))::int FROM profiles
      ), 0),
      'completedProfiles', (
        SELECT count(*) FROM profiles
        WHERE onboarding_completed = true
      ),
      'totalProfiles', (
        SELECT count(*) FROM profiles
      ),
      'verifiedProfiles', (
        SELECT count(*) FROM profiles
        WHERE verification_status = 'verified'
      ),
      'pendingKyc', (
        SELECT count(*) FROM profiles
        WHERE verification_status = 'pending_review'
      ),
      'activeSubscribers', (
        SELECT count(*) FROM users
        WHERE subscription_status IN ('active','grace')
      )
    ),
    'queues', jsonb_build_object(
      'openReports', (
        SELECT count(*) FROM reports
        WHERE status = 'pending'
      ),
      'pendingPhotos', (
        SELECT count(*) FROM photos
        WHERE moderation_status = 'pending'
      ),
      'dueNotifications', (
        SELECT count(*) FROM notifications
        WHERE sent_at IS NULL AND scheduled_at <= now()
      ),
      'futureNotifications', (
        SELECT count(*) FROM notifications
        WHERE sent_at IS NULL AND scheduled_at > now()
      ),
      'sentNotificationsLastHour', (
        SELECT count(*) FROM notifications
        WHERE sent_at >= now() - interval '1 hour'
      )
    ),
    'pipeline', jsonb_build_object(
      'completionRate', coalesce((
        SELECT round(100.0 * count(*) FILTER (WHERE onboarding_completed = true) / nullif(count(*), 0))::int
        FROM profiles
      ), 0),
      'verificationRate', coalesce((
        SELECT round(100.0 * count(*) FILTER (WHERE verification_status = 'verified') / nullif(count(*), 0))::int
        FROM profiles
      ), 0),
      'subscriberRate', coalesce((
        SELECT round(100.0 * count(*) FILTER (WHERE subscription_status IN ('active','grace')) / nullif(count(*), 0))::int
        FROM users
      ), 0),
      'photoClearanceRate', coalesce((
        SELECT round(100.0 * count(*) FILTER (WHERE moderation_status = 'approved') / nullif(count(*), 0))::int
        FROM photos
      ), 0)
    )
  ) ELSE NULL END;
$$;

REVOKE ALL ON FUNCTION public.admin_live_operations_snapshot() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_live_operations_snapshot() TO authenticated;
