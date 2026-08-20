-- Settings wiring audit: make every visible reminder and guardian control
-- correspond to an enforceable server behavior before production fixtures.

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS last_inactive_nudge_at timestamptz;

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS boost_last_activated_at timestamptz,
  ADD COLUMN IF NOT EXISTS boost_ready_notified_at timestamptz;

-- The owner projection expands the profiles composite at view-creation time.
-- Recreate it so the app can read the new cooldown timestamp without granting
-- direct table access.
DROP VIEW IF EXISTS public.my_profile_private;
CREATE VIEW public.my_profile_private
WITH (security_invoker = true, security_barrier = true)
AS
SELECT row_data.*
FROM public.get_my_profile_private_rows() AS row_data;
REVOKE ALL ON public.my_profile_private FROM PUBLIC, anon;
GRANT SELECT ON public.my_profile_private TO authenticated;

UPDATE public.profiles
SET boost_last_activated_at = boost_expires_at - interval '2 hours'
WHERE boost_last_activated_at IS NULL
  AND boost_expires_at IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_profiles_weekly_boost_ready
  ON public.profiles(boost_last_activated_at, id)
  WHERE boost_last_activated_at IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_profiles_inactive_nudge_due
  ON public.profiles(last_active_at, user_id)
  WHERE visibility = 'visible';

-- One profile boost is available per rolling seven-day window. This applies
-- equally to women (free product access) and entitled men; payment status
-- decides eligibility, never the cooldown itself.
CREATE OR REPLACE FUNCTION public.activate_profile_boost()
RETURNS TABLE (boost_expires_at timestamptz)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_gender text;
  v_subscription text;
  v_subscription_expires timestamptz;
  v_profile public.profiles%ROWTYPE;
  v_expires timestamptz;
  v_next_available timestamptz;
BEGIN
  PERFORM private.assert_authenticated();

  SELECT lower(u.gender::text), u.subscription_status,
         u.subscription_expires_at
  INTO v_gender, v_subscription, v_subscription_expires
  FROM public.users u
  WHERE u.id = auth.uid();

  SELECT * INTO v_profile
  FROM public.profiles
  WHERE user_id = auth.uid()
  FOR UPDATE;

  IF NOT FOUND OR v_profile.visibility IS DISTINCT FROM 'visible' THEN
    RAISE EXCEPTION 'Your profile must be live before it can be boosted.'
      USING ERRCODE = 'P0001';
  END IF;
  IF v_gender IS DISTINCT FROM 'female'
     AND NOT (
       v_subscription IN ('active', 'grace')
       AND (v_subscription_expires IS NULL OR v_subscription_expires > now())
     ) THEN
    RAISE EXCEPTION 'An active subscription is required to boost this profile.'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_profile.is_boosted = true
     AND v_profile.boost_expires_at > now() THEN
    RETURN QUERY SELECT v_profile.boost_expires_at;
    RETURN;
  END IF;

  v_next_available := v_profile.boost_last_activated_at + interval '7 days';
  IF v_profile.boost_last_activated_at IS NOT NULL
     AND v_next_available > now() THEN
    RAISE EXCEPTION 'Your next weekly boost is available on %.',
      to_char(v_next_available AT TIME ZONE 'Asia/Kolkata',
              'DD Mon YYYY, HH12:MI AM')
      USING ERRCODE = 'P0001';
  END IF;

  v_expires := now() + interval '2 hours';
  PERFORM set_config('silarah.allow_boost_mutation', 'yes', true);
  UPDATE public.profiles
  SET is_boosted = true,
      boost_expires_at = v_expires,
      boost_last_activated_at = now(),
      boost_ready_notified_at = NULL,
      updated_at = now()
  WHERE id = v_profile.id;

  RETURN QUERY SELECT v_expires;
END;
$$;

REVOKE ALL ON FUNCTION public.activate_profile_boost()
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.activate_profile_boost()
  TO authenticated;

-- Guardian configuration is a single transaction. A phone-encryption failure
-- can no longer leave Guardian Mode enabled without a usable invitation, and
-- disabling the mode clears authorization through the existing lifecycle
-- trigger.
CREATE OR REPLACE FUNCTION public.save_my_guardian_configuration(
  p_enabled boolean,
  p_can_reply boolean DEFAULT false,
  p_name text DEFAULT NULL,
  p_relationship text DEFAULT NULL,
  p_phone text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid := private.assert_authenticated();
  v_profile public.profiles%ROWTYPE;
BEGIN
  PERFORM public.set_my_guardian_settings(
    p_enabled,
    p_can_reply,
    p_name,
    p_relationship,
    NULL::text,
    NULL::text,
    NULL::text
  );

  SELECT * INTO v_profile
  FROM public.profiles
  WHERE user_id = v_user_id
  FOR UPDATE;

  IF p_enabled AND nullif(trim(p_phone), '') IS NOT NULL THEN
    PERFORM public.set_guardian_phone(v_profile.id, trim(p_phone));
    SELECT * INTO v_profile
    FROM public.profiles
    WHERE id = v_profile.id;
  ELSIF p_enabled
    AND v_profile.guardian_phone_encrypted IS NULL
    AND v_profile.guardian_user_id IS NULL THEN
    RAISE EXCEPTION 'A guardian phone number is required.'
      USING ERRCODE = 'P0001';
  END IF;

  RETURN jsonb_build_object(
    'enabled', p_enabled,
    'mode', v_profile.guardian_mode,
    'linked', v_profile.guardian_user_id IS NOT NULL,
    'phone_configured', v_profile.guardian_phone_encrypted IS NOT NULL,
    'invitation_expires_at', v_profile.guardian_invitation_expires_at
  );
END;
$$;

REVOKE ALL ON FUNCTION public.save_my_guardian_configuration(
  boolean, boolean, text, text, text
) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.save_my_guardian_configuration(
  boolean, boolean, text, text, text
) TO authenticated;

-- Cost-bounded daily reminders. Each inactivity episode and each weekly boost
-- cycle is claimed atomically, so retries and overlapping cron runs cannot
-- create duplicate notifications.
CREATE OR REPLACE FUNCTION private.process_member_reminders(
  p_batch_size integer DEFAULT 500
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_limit integer := greatest(1, least(coalesce(p_batch_size, 500), 2000));
  v_member record;
  v_inactive integer := 0;
  v_boost integer := 0;
BEGIN
  IF NOT pg_try_advisory_xact_lock(
    hashtextextended('member_reminders', 220)
  ) THEN
    RETURN jsonb_build_object('busy', true, 'inactive', 0, 'boost', 0);
  END IF;

  FOR v_member IN
    SELECT u.id
    FROM public.users u
    JOIN public.profiles p ON p.user_id = u.id
    LEFT JOIN public.notification_prefs prefs ON prefs.user_id = u.id
    WHERE u.deleted_at IS NULL
      AND coalesce(u.is_banned, false) = false
      AND coalesce(u.is_shadowbanned, false) = false
      AND p.visibility = 'visible'
      AND p.last_active_at <= now() - interval '7 days'
      AND p.last_active_at > now() - interval '30 days'
      AND coalesce(prefs.inactive_nudge, true) = true
      AND (
        u.last_inactive_nudge_at IS NULL
        OR u.last_inactive_nudge_at < p.last_active_at
      )
    ORDER BY p.last_active_at, u.id
    FOR UPDATE OF u SKIP LOCKED
    LIMIT v_limit
  LOOP
    UPDATE public.users
    SET last_inactive_nudge_at = now()
    WHERE id = v_member.id;
    PERFORM public.queue_notification(
      v_member.id,
      'inactive_nudge',
      'See what is new on Silarah',
      'Your profile has been quiet for a week. Open Discovery to see current compatible profiles.',
      'silarah://discover'
    );
    v_inactive := v_inactive + 1;
  END LOOP;

  FOR v_member IN
    SELECT p.id AS profile_id, p.user_id
    FROM public.profiles p
    JOIN public.users u ON u.id = p.user_id
    LEFT JOIN public.notification_prefs prefs ON prefs.user_id = u.id
    WHERE u.deleted_at IS NULL
      AND coalesce(u.is_banned, false) = false
      AND p.visibility = 'visible'
      AND p.boost_last_activated_at IS NOT NULL
      AND p.boost_last_activated_at <= now() - interval '7 days'
      AND (
        p.boost_ready_notified_at IS NULL
        OR p.boost_ready_notified_at < p.boost_last_activated_at
      )
      AND coalesce(prefs.boost_available, true) = true
      AND (
        lower(u.gender::text) = 'female'
        OR (
          u.subscription_status IN ('active', 'grace')
          AND (
            u.subscription_expires_at IS NULL
            OR u.subscription_expires_at > now()
          )
        )
      )
    ORDER BY p.boost_last_activated_at, p.id
    FOR UPDATE OF p SKIP LOCKED
    LIMIT v_limit
  LOOP
    UPDATE public.profiles
    SET boost_ready_notified_at = now()
    WHERE id = v_member.profile_id;
    PERFORM public.queue_notification(
      v_member.user_id,
      'boost_ready',
      'Your weekly boost is ready',
      'Activate it from your profile to receive two hours of priority placement.',
      'silarah://profile'
    );
    v_boost := v_boost + 1;
  END LOOP;

  RETURN jsonb_build_object(
    'busy', false,
    'inactive', v_inactive,
    'boost', v_boost
  );
END;
$$;

REVOKE ALL ON FUNCTION private.process_member_reminders(integer)
  FROM PUBLIC, anon, authenticated;

DO $migration$
DECLARE
  v_job record;
BEGIN
  FOR v_job IN
    SELECT jobid FROM cron.job
    WHERE jobname = 'process_member_reminders_daily'
  LOOP
    PERFORM cron.unschedule(v_job.jobid);
  END LOOP;
  PERFORM cron.schedule(
    'process_member_reminders_daily',
    '15 6 * * *',
    'SELECT private.process_member_reminders(500);'
  );
END;
$migration$;

-- Service-role diagnostic used before fixture creation and during operations.
-- It exposes configuration health, never member data or secret values.
CREATE OR REPLACE FUNCTION public.audit_settings_wiring()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_jobs jsonb;
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

  RETURN jsonb_build_object(
    'cron_jobs', v_jobs,
    'notification_dispatch_healthy', EXISTS (
      SELECT 1 FROM private.edge_function_health
      WHERE function_name = 'dispatch-notifications'
        AND consecutive_failures < 3
        AND last_success_at >= now() - interval '15 minutes'
    ),
    'stale_notifications', (
      SELECT count(*) FROM public.notifications
      WHERE sent_at IS NULL
        AND scheduled_at < now() - interval '10 minutes'
    ),
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

COMMENT ON FUNCTION private.process_member_reminders(integer) IS
  'Bounded, idempotent inactivity and weekly-boost reminder producer.';
COMMENT ON FUNCTION public.audit_settings_wiring() IS
  'Service-role-only configuration health for Settings controls and workers.';

NOTIFY pgrst, 'reload schema';
