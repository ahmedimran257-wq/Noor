-- Quiet hours must follow the member's launch-market timezone. Existing India
-- accounts inherited the historical UTC default, which delayed local daytime
-- notifications until 13:30 IST when quiet hours ended at 08:00 UTC.

UPDATE public.users
SET timezone = 'Asia/Kolkata'
WHERE upper(coalesce(country_code, '')) IN ('IN', 'IND')
  AND coalesce(timezone, 'UTC') IN ('UTC', 'Etc/UTC');

CREATE OR REPLACE FUNCTION private.enforce_india_user_timezone()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF upper(coalesce(NEW.country_code, '')) IN ('IN', 'IND')
    AND coalesce(NEW.timezone, 'UTC') IN ('UTC', 'Etc/UTC') THEN
    NEW.timezone := 'Asia/Kolkata';
  END IF;
  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION private.enforce_india_user_timezone()
  FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS enforce_india_user_timezone ON public.users;
CREATE TRIGGER enforce_india_user_timezone
BEFORE INSERT OR UPDATE OF country_code, timezone ON public.users
FOR EACH ROW
EXECUTE FUNCTION private.enforce_india_user_timezone();

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
    'india_timezone_mismatches', (
      SELECT count(*)
      FROM public.users
      WHERE upper(coalesce(country_code, '')) IN ('IN', 'IND')
        AND timezone <> 'Asia/Kolkata'
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

NOTIFY pgrst, 'reload schema';
