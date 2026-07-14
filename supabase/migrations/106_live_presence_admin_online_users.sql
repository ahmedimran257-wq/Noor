-- Live presence for admin operations.
-- The app records an authenticated heartbeat; admin reads a masked live list.

CREATE TABLE IF NOT EXISTS public.user_presence (
  user_id uuid PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
  last_seen_at timestamptz NOT NULL DEFAULT now(),
  app_state text NOT NULL DEFAULT 'foreground'
    CHECK (app_state IN ('foreground', 'background', 'inactive')),
  platform text,
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_user_presence_last_seen
  ON public.user_presence (last_seen_at DESC);

ALTER TABLE public.user_presence ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS user_presence_own_select ON public.user_presence;
CREATE POLICY user_presence_own_select
  ON public.user_presence FOR SELECT
  USING (user_id = auth.uid());

CREATE OR REPLACE FUNCTION public.record_user_presence(
  p_app_state text DEFAULT 'foreground',
  p_platform text DEFAULT NULL
)
RETURNS timestamptz
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_now timestamptz := now();
  v_state text := coalesce(nullif(trim(p_app_state), ''), 'foreground');
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  IF v_state NOT IN ('foreground', 'background', 'inactive') THEN
    v_state := 'foreground';
  END IF;

  INSERT INTO public.user_presence (user_id, last_seen_at, app_state, platform, updated_at)
  VALUES (v_user_id, v_now, v_state, nullif(trim(coalesce(p_platform, '')), ''), v_now)
  ON CONFLICT (user_id) DO UPDATE
    SET last_seen_at = EXCLUDED.last_seen_at,
        app_state = EXCLUDED.app_state,
        platform = coalesce(EXCLUDED.platform, public.user_presence.platform),
        updated_at = EXCLUDED.updated_at;

  UPDATE public.profiles
  SET last_active_at = v_now
  WHERE user_id = v_user_id;

  RETURN v_now;
END;
$$;

REVOKE ALL ON FUNCTION public.record_user_presence(text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.record_user_presence(text, text) TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_online_users(p_limit integer DEFAULT 25)
RETURNS TABLE(
  user_id uuid,
  profile_id uuid,
  name text,
  email text,
  country_code text,
  gender text,
  last_seen_at timestamptz,
  app_state text,
  platform text,
  visibility text,
  verification_status text,
  subscription_status text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_active_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  RETURN QUERY
  SELECT
    up.user_id,
    p.id AS profile_id,
    public.mask_admin_name(concat_ws(' ', p.first_name, p.last_name)) AS name,
    public.mask_admin_email(u.email) AS email,
    coalesce(p.country_code, u.country_code)::text AS country_code,
    coalesce(p.gender, u.gender)::text AS gender,
    up.last_seen_at,
    up.app_state,
    up.platform,
    coalesce(p.visibility, 'profile_pending')::text AS visibility,
    coalesce(p.verification_status, 'unverified')::text AS verification_status,
    coalesce(u.subscription_status, 'none')::text AS subscription_status
  FROM public.user_presence up
  JOIN public.users u ON u.id = up.user_id
  LEFT JOIN public.profiles p ON p.user_id = up.user_id
  WHERE up.last_seen_at >= now() - interval '15 minutes'
  ORDER BY up.last_seen_at DESC
  LIMIT least(greatest(coalesce(p_limit, 25), 1), 100);
END;
$$;

REVOKE ALL ON FUNCTION public.admin_online_users(integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_online_users(integer) TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_live_operations_snapshot()
RETURNS jsonb
LANGUAGE sql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT CASE WHEN public.is_active_admin() THEN jsonb_build_object(
    'generatedAt', extract(epoch FROM now())::bigint,
    'traffic', jsonb_build_object(
      'onlineNow', (
        SELECT count(*) FROM user_presence
        WHERE last_seen_at >= now() - interval '2 minutes'
      ),
      'activeToday', (
        SELECT count(*) FROM user_presence
        WHERE last_seen_at >= now() - interval '24 hours'
      ),
      'activeSevenDays', (
        SELECT count(*) FROM user_presence
        WHERE last_seen_at >= now() - interval '7 days'
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
