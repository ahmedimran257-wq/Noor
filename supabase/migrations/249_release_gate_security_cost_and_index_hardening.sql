-- Final release-gate hardening:
--   * close remaining pre-auth abuse and account-enumeration surfaces
--   * eliminate idle Edge Function and overly-frequent maintenance work
--   * repair the one remaining per-row auth RLS plan
--   * add foreign-key indexes reported by the live Performance Advisor
--   * remove exact/prefix duplicate indexes that add write amplification

-- ---------------------------------------------------------------------------
-- 1. Privacy-preserving pre-auth rate limits. Only a one-way digest of the
--    request network/user-agent tuple is persisted; raw request metadata is not.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION private.pre_auth_rate_limit_subject(p_scope text)
RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
  v_headers jsonb := coalesce(
    nullif(current_setting('request.headers', true), ''),
    '{}'
  )::jsonb;
  v_network text;
  v_agent text;
BEGIN
  v_network := nullif(trim(split_part(coalesce(
    v_headers ->> 'cf-connecting-ip',
    v_headers ->> 'x-forwarded-for',
    v_headers ->> 'x-real-ip',
    'unknown'
  ), ',', 1)), '');
  v_agent := left(coalesce(nullif(v_headers ->> 'user-agent', ''), 'unknown'), 200);

  RETURN encode(
    extensions.digest(
      convert_to(
        left(coalesce(p_scope, 'preauth'), 40) || ':' ||
          coalesce(v_network, 'unknown') || ':' || v_agent,
        'UTF8'
      ),
      'sha256'
    ),
    'hex'
  );
END;
$$;

REVOKE ALL ON FUNCTION private.pre_auth_rate_limit_subject(text)
  FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION private.enforce_pre_auth_rate_limit(
  p_scope text,
  p_max_requests integer,
  p_window_seconds integer
)
RETURNS void
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
  v_allowed boolean;
BEGIN
  SELECT limits.allowed
  INTO v_allowed
  FROM public.consume_edge_rate_limit(
    p_scope,
    private.pre_auth_rate_limit_subject(p_scope),
    p_max_requests,
    p_window_seconds
  ) AS limits;

  IF NOT coalesce(v_allowed, false) THEN
    RAISE EXCEPTION 'rate_limit_exceeded'
      USING ERRCODE = 'P0001';
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION private.enforce_pre_auth_rate_limit(text, integer, integer)
  FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.begin_signup_consent_transaction(
  p_policy_version text,
  p_acceptances jsonb
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_id uuid;
  v_required constant text[] := ARRAY[
    'terms_of_service',
    'privacy_policy',
    'community_guidelines',
    'age_verification',
    'special_category_religious'
  ];
  v_key text;
BEGIN
  -- Twenty attempts per network/browser in fifteen minutes permits retries and
  -- shared households while bounding anonymous transaction-row creation.
  PERFORM private.enforce_pre_auth_rate_limit('signup_consent', 20, 900);

  IF trim(coalesce(p_policy_version, '')) <> '2.3.0'
    OR jsonb_typeof(p_acceptances) <> 'object'
    OR (SELECT count(*) FROM jsonb_object_keys(p_acceptances)) <> 5 THEN
    RAISE EXCEPTION 'invalid_consent_transaction' USING ERRCODE = 'P0001';
  END IF;

  FOREACH v_key IN ARRAY v_required LOOP
    IF p_acceptances ->> v_key <> 'true' THEN
      RAISE EXCEPTION 'required_consent_missing' USING ERRCODE = 'P0001';
    END IF;
  END LOOP;

  INSERT INTO private.signup_consent_transactions(policy_version, acceptances)
  VALUES ('2.3.0', p_acceptances)
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

REVOKE ALL ON FUNCTION public.begin_signup_consent_transaction(text, jsonb)
  FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.begin_signup_consent_transaction(text, jsonb)
  TO anon, authenticated;

CREATE OR REPLACE FUNCTION public.validate_referral_code(p_code text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_code text := upper(trim(coalesce(p_code, '')));
BEGIN
  IF v_code !~ '^[A-Z0-9]{6}$' THEN
    RETURN false;
  END IF;

  -- The endpoint intentionally reveals only exact-code existence. The higher
  -- read limit supports normal typing/retries but prevents code-space scraping.
  PERFORM private.enforce_pre_auth_rate_limit('referral_validate', 120, 900);

  RETURN EXISTS (
    SELECT 1
    FROM public.referral_codes rc
    WHERE rc.code = v_code
  );
END;
$$;

REVOKE ALL ON FUNCTION public.validate_referral_code(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.validate_referral_code(text)
  TO anon, authenticated;

COMMENT ON FUNCTION public.validate_referral_code(text) IS
  'Rate-limited exact-code existence check; returns no owner or usage data.';

-- Old builds used these email-existence oracles. Current clients use the
-- provider's uniform OTP response, so remove the dead routines completely.
DROP FUNCTION IF EXISTS public.email_is_registered(text);
DROP FUNCTION IF EXISTS public.email_registration_status(text);

-- ---------------------------------------------------------------------------
-- 2. Public launch configuration contains no member data. Use ordinary RLS
--    reads instead of a SECURITY DEFINER boundary so Advisor can verify it.
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS launch_countries_public_read ON public.launch_countries;
CREATE POLICY launch_countries_public_read
  ON public.launch_countries
  FOR SELECT TO anon, authenticated
  USING (true);

GRANT SELECT ON public.launch_countries TO anon, authenticated;
GRANT SELECT ON public.countries TO anon, authenticated;

CREATE OR REPLACE FUNCTION public.get_launch_configuration()
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = ''
AS $$
  SELECT jsonb_build_object(
    'market_mode', CASE WHEN count(*) = 1 THEN 'single_country' ELSE 'global' END,
    'enabled_countries', coalesce(
      jsonb_agg(lc.country_code ORDER BY c.display_priority DESC, c.name),
      '[]'::jsonb
    ),
    'default_country', CASE
      WHEN bool_or(lc.country_code = 'IN') THEN 'IN'
      ELSE min(lc.country_code)
    END,
    'country_count', count(*)
  )
  FROM public.launch_countries lc
  JOIN public.countries c ON c.iso_code = lc.country_code
  WHERE lc.enabled = true;
$$;

REVOKE ALL ON FUNCTION public.get_launch_configuration() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_launch_configuration() TO anon, authenticated;

-- Evaluate auth.uid() once per statement, not once per export row.
DROP POLICY IF EXISTS data_export_requests_select_own
  ON public.data_export_requests;
CREATE POLICY data_export_requests_select_own
  ON public.data_export_requests
  FOR SELECT TO authenticated
  USING (user_id = (SELECT auth.uid()));

-- ---------------------------------------------------------------------------
-- 3. Do not wake an Edge Function when no temporary captures are due. The
--    five-minute legal deletion cadence remains unchanged when work exists.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION private.invoke_photo_verification_purge_worker()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_secret text;
  v_url text;
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM public.photo_verification_submissions s
    WHERE s.captures_purged_at IS NULL
      AND s.purge_after <= now()
      AND s.purge_attempts < 12
      AND (
        s.purge_status IN ('pending', 'failed')
        OR (
          s.purge_status = 'deleting'
          AND s.purge_claimed_at < now() - interval '10 minutes'
        )
      )
  ) THEN
    RETURN;
  END IF;

  v_url := nullif(current_setting('app.supabase_url', true), '');
  IF v_url IS NULL THEN
    SELECT decrypted_secret INTO v_url
    FROM vault.decrypted_secrets
    WHERE name = 'silarah_supabase_url'
    LIMIT 1;
  END IF;

  SELECT decrypted_secret INTO v_secret
  FROM vault.decrypted_secrets
  WHERE name IN ('silarah_edge_cron_secret', 'mithaq_edge_cron_secret')
  ORDER BY (name = 'silarah_edge_cron_secret') DESC
  LIMIT 1;

  IF v_url ~ '^https://[a-z0-9-]+[.]supabase[.]co$'
    AND nullif(v_secret, '') IS NOT NULL THEN
    PERFORM net.http_post(
      url := v_url || '/functions/v1/purge-photo-verification-captures',
      body := '{}'::jsonb,
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-cron-secret', v_secret
      ),
      timeout_milliseconds := 10000
    );
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION private.invoke_photo_verification_purge_worker()
  FROM PUBLIC, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 4. Lower non-urgent maintenance frequency and skip ranking work completely
--    when no unprocessed interaction exists.
-- ---------------------------------------------------------------------------
DO $migration$
DECLARE v_job record;
BEGIN
  IF to_regclass('cron.job') IS NULL THEN RETURN; END IF;

  FOR v_job IN
    SELECT jobid FROM cron.job
    WHERE jobname IN (
      'refresh_admin_metric_snapshots_5m',
      'refresh_admin_metric_snapshots_15m'
    )
  LOOP
    PERFORM cron.unschedule(v_job.jobid);
  END LOOP;
  PERFORM cron.schedule(
    'refresh_admin_metric_snapshots_15m',
    '*/15 * * * *',
    'SELECT private.refresh_admin_metric_snapshots();'
  );

  FOR v_job IN
    SELECT jobid FROM cron.job
    WHERE jobname IN ('compute_glicko2_batch', 'compute_glicko2_batch_15m')
  LOOP
    PERFORM cron.unschedule(v_job.jobid);
  END LOOP;
  PERFORM cron.schedule(
    'compute_glicko2_batch_15m',
    '*/15 * * * *',
    'SELECT public.compute_glicko2_batch() WHERE EXISTS (SELECT 1 FROM public.glicko_interactions WHERE processed = false);'
  );
END;
$migration$;

-- ---------------------------------------------------------------------------
-- 5. Bound operational/temp history. This never deletes profiles, messages,
--    subscriptions, reports, consents, or unprocessed ranking interactions.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION private.cleanup_operational_history()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_cron bigint := 0;
  v_jobs bigint := 0;
  v_signup bigint := 0;
  v_rank bigint := 0;
BEGIN
  DELETE FROM cron.job_run_details
  WHERE end_time IS NOT NULL
    AND end_time < now() - interval '14 days';
  GET DIAGNOSTICS v_cron = ROW_COUNT;

  DELETE FROM private.job_runs
  WHERE finished_at IS NOT NULL
    AND finished_at < now() - interval '30 days';
  GET DIAGNOSTICS v_jobs = ROW_COUNT;

  DELETE FROM private.signup_consent_transactions
  WHERE (
      consumed_at IS NULL
      AND expires_at < now() - interval '1 day'
    ) OR (
      consumed_at IS NOT NULL
      AND consumed_at < now() - interval '30 days'
    );
  GET DIAGNOSTICS v_signup = ROW_COUNT;

  DELETE FROM public.glicko_interactions
  WHERE processed = true
    AND created_at < now() - interval '90 days';
  GET DIAGNOSTICS v_rank = ROW_COUNT;

  RETURN jsonb_build_object(
    'cron_history_deleted', v_cron,
    'worker_history_deleted', v_jobs,
    'temporary_signup_transactions_deleted', v_signup,
    'processed_ranking_events_deleted', v_rank
  );
END;
$$;

REVOKE ALL ON FUNCTION private.cleanup_operational_history()
  FROM PUBLIC, anon, authenticated;

DO $migration$
DECLARE v_job record;
BEGIN
  IF to_regclass('cron.job') IS NULL THEN RETURN; END IF;
  FOR v_job IN
    SELECT jobid FROM cron.job
    WHERE jobname = 'cleanup_operational_history_daily'
  LOOP
    PERFORM cron.unschedule(v_job.jobid);
  END LOOP;
  PERFORM cron.schedule(
    'cleanup_operational_history_daily',
    '37 2 * * *',
    'SELECT private.cleanup_operational_history();'
  );
END;
$migration$;

-- Compact existing eligible operational history immediately; a verified
-- logical backup exists before this migration is applied.
SELECT private.cleanup_operational_history();

-- ---------------------------------------------------------------------------
-- 6. Foreign-key indexes for delete/update checks and operational joins.
-- ---------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_admin_session_boundaries_admin
  ON private.admin_session_boundaries(admin_id);
CREATE INDEX IF NOT EXISTS idx_discovery_availability_candidate_profile
  ON private.discovery_availability_events(candidate_profile_id);
CREATE INDEX IF NOT EXISTS idx_guardian_match_approvals_ward
  ON private.guardian_match_approvals(ward_id);
CREATE INDEX IF NOT EXISTS idx_guardian_match_approvals_guardian
  ON private.guardian_match_approvals(guardian_id);
CREATE INDEX IF NOT EXISTS idx_interest_expiry_events_recipient
  ON private.interest_expiry_events(recipient_id);
CREATE INDEX IF NOT EXISTS idx_match_closure_operations_actor
  ON private.match_closure_operations(actor_id);
CREATE INDEX IF NOT EXISTS idx_match_closure_operations_message
  ON private.match_closure_operations(message_id);
CREATE INDEX IF NOT EXISTS idx_signup_consent_transactions_consumed_by
  ON private.signup_consent_transactions(consumed_by)
  WHERE consumed_by IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_storage_deletion_jobs_photo
  ON private.storage_deletion_jobs(photo_id)
  WHERE photo_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_storage_deletion_jobs_user
  ON private.storage_deletion_jobs(user_id)
  WHERE user_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_upload_reservations_user
  ON private.upload_reservations(user_id);
CREATE INDEX IF NOT EXISTS idx_upload_reservations_profile
  ON private.upload_reservations(profile_id)
  WHERE profile_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_upload_reservations_replaced_photo
  ON private.upload_reservations(replaced_photo_id)
  WHERE replaced_photo_id IS NOT NULL;

-- Exact or left-prefix duplicates confirmed against the live index catalogue.
DROP INDEX IF EXISTS public.idx_profiles_user;
DROP INDEX IF EXISTS public.idx_blocks_both_directions;
DROP INDEX IF EXISTS public.idx_users_phone;
DROP INDEX IF EXISTS private.idx_operational_health_snapshots_captured;
DROP INDEX IF EXISTS public.idx_income_brackets_country;
DROP INDEX IF EXISTS public.idx_fcm_tokens_user;
DROP INDEX IF EXISTS public.idx_guardian_mirrors_match;

-- ---------------------------------------------------------------------------
-- 7. Keep the service-role wiring audit aligned with current job names and add
--    explicit cost-control evidence. No member or secret values are exposed.
-- ---------------------------------------------------------------------------
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
    'capture_operational_health_15m',
    'cleanup_operational_history_daily',
    'compute_glicko2_batch_15m',
    'dispatch_notifications_fallback_5m',
    'discovery_notifications_bounded_5m',
    'photo_verification_capture_purge',
    'process_interest_expiry_5m',
    'process_member_reminders_daily',
    'profile-nudge-daily',
    'refresh_admin_metric_snapshots_15m'
  );

  v_dispatch := private.notification_dispatch_health();

  RETURN jsonb_build_object(
    'cron_jobs', v_jobs,
    'notification_dispatch_status', v_dispatch,
    'notification_dispatch_healthy',
      v_dispatch ->> 'status' IN ('healthy', 'idle'),
    'stale_notifications', (v_dispatch ->> 'stale')::bigint,
    'fcm_token_users', (
      SELECT count(DISTINCT user_id) FROM public.user_fcm_tokens
    ),
    'india_timezone_mismatches', (
      SELECT count(*)
      FROM public.users
      WHERE upper(coalesce(country_code, '')) IN ('IN', 'IND')
        AND timezone <> 'Asia/Kolkata'
    ),
    'photo_purge_due', (
      SELECT count(*)
      FROM public.photo_verification_submissions s
      WHERE s.captures_purged_at IS NULL
        AND s.purge_after <= now()
        AND s.purge_attempts < 12
        AND (
          s.purge_status IN ('pending', 'failed')
          OR (
            s.purge_status = 'deleting'
            AND s.purge_claimed_at < now() - interval '10 minutes'
          )
        )
    ),
    'unprocessed_ranking_events', (
      SELECT count(*) FROM public.glicko_interactions WHERE processed = false
    ),
    'pre_auth_rate_limits',
      to_regprocedure(
        'private.enforce_pre_auth_rate_limit(text,integer,integer)'
      ) IS NOT NULL,
    'idle_photo_worker_guard', true,
    'operational_retention',
      to_regprocedure('private.cleanup_operational_history()') IS NOT NULL,
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

COMMENT ON FUNCTION public.begin_signup_consent_transaction(text, jsonb) IS
  'Rate-limited pre-auth legal-consent transaction; stores no network address.';
COMMENT ON FUNCTION public.get_launch_configuration() IS
  'RLS-backed public launch-market configuration with no member data.';
COMMENT ON FUNCTION private.invoke_photo_verification_purge_worker() IS
  'Invokes capture purge only when a due row exists; preserves the five-minute deletion cadence.';
COMMENT ON FUNCTION private.cleanup_operational_history() IS
  'Bounded cleanup for scheduler logs, worker logs, temporary signup rows, and already-processed ranking events.';

NOTIFY pgrst, 'reload schema';
