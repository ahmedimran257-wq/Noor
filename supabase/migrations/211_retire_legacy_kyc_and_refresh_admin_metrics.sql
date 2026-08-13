-- Permanently retire the unused government-ID/KYC pipeline.
--
-- This migration is deliberately fail-closed: it refuses to remove either
-- the legacy ledger or its private buckets if unexpected evidence exists.
-- The current smile/blink photo-review pipeline is independent and remains.

DO $migration$
BEGIN
  IF to_regclass('public.kyc_review_submissions') IS NOT NULL
    AND EXISTS (SELECT 1 FROM public.kyc_review_submissions) THEN
    RAISE EXCEPTION
      'legacy_kyc_cleanup_blocked_nonempty_submission_ledger';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM storage.objects
    WHERE bucket_id IN ('kyc-documents', 'selfie-verifications')
  ) THEN
    RAISE EXCEPTION 'legacy_kyc_cleanup_blocked_nonempty_storage';
  END IF;
END;
$migration$;

DO $migration$
DECLARE
  v_job record;
BEGIN
  IF to_regclass('cron.job') IS NULL THEN
    RETURN;
  END IF;
  FOR v_job IN
    SELECT jobid
    FROM cron.job
    WHERE jobname = 'purge_kyc_documents_daily'
  LOOP
    PERFORM cron.unschedule(v_job.jobid);
  END LOOP;
END;
$migration$;

DROP TRIGGER IF EXISTS trg_lock_identity_during_kyc_review
  ON public.profiles;

-- The staff directory never displayed the three legacy KYC fields. Removing
-- them from the RPC also removes its dependency on current_kyc_status().
DROP FUNCTION IF EXISTS public.admin_user_directory_page(
  text, integer, integer
);
CREATE FUNCTION public.admin_user_directory_page(
  p_query text DEFAULT '',
  p_limit integer DEFAULT 50,
  p_offset integer DEFAULT 0
)
RETURNS TABLE(
  user_id uuid,
  profile_id uuid,
  name text,
  email text,
  country_code text,
  gender text,
  joined_at timestamptz,
  last_active_at timestamptz,
  onboarding_step int,
  completeness_score int,
  visibility text,
  is_banned boolean,
  is_shadowbanned boolean,
  subscription_status text,
  verification_status text,
  has_verification_badge boolean,
  can_approve_profile boolean,
  approval_block_reason text,
  total_count bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_limit integer := least(greatest(coalesce(p_limit, 50), 1), 50);
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_query text := trim(coalesce(p_query, ''));
BEGIN
  IF NOT public.is_active_admin() THEN
    RAISE EXCEPTION 'Staff authorization required';
  END IF;

  INSERT INTO public.admin_audit_log(
    admin_id, actor_role, action_type, details
  ) VALUES (
    auth.uid(),
    public.current_admin_role(),
    'admin_user_directory_read',
    jsonb_build_object(
      'query_present', v_query <> '',
      'limit', v_limit,
      'offset', v_offset
    )
  );

  RETURN QUERY
  WITH directory AS (
    SELECT
      u.id AS user_id,
      p.id AS profile_id,
      public.mask_admin_name(
        concat_ws(' ', p.first_name, p.last_name)
      )::text AS name,
      public.mask_admin_email(u.email::text)::text AS email,
      p.country_code::text AS country_code,
      p.gender::text AS gender,
      u.created_at AS joined_at,
      p.last_active_at AS last_active_at,
      p.onboarding_step::int AS onboarding_step,
      p.completeness_score::int AS completeness_score,
      p.visibility::text AS visibility,
      coalesce(u.is_banned, false) AS is_banned,
      coalesce(u.is_shadowbanned, false) AS is_shadowbanned,
      u.subscription_status::text AS subscription_status,
      p.verification_status::text AS verification_status,
      coalesce(p.has_verification_badge, false)
        AS has_verification_badge,
      coalesce(p.onboarding_completed, false) AS onboarding_completed,
      p.marriage_timeline,
      EXISTS (
        SELECT 1
        FROM public.photos ph
        WHERE ph.profile_id = p.id
          AND ph.order_index = 0
          AND ph.admin_approved = true
          AND ph.nsfw_cleared = true
          AND coalesce(ph.status, 'active') = 'active'
      ) AS has_safe_primary_photo
    FROM public.users u
    JOIN public.profiles p ON p.user_id = u.id
    WHERE v_query = ''
      OR concat_ws(
        ' ', p.first_name, p.last_name, u.email, u.id::text
      ) ILIKE '%' || v_query || '%'
  )
  SELECT
    d.user_id::uuid,
    d.profile_id::uuid,
    d.name,
    d.email,
    d.country_code,
    d.gender,
    d.joined_at::timestamptz,
    d.last_active_at::timestamptz,
    d.onboarding_step,
    d.completeness_score,
    d.visibility,
    d.is_banned::boolean,
    d.is_shadowbanned::boolean,
    d.subscription_status,
    d.verification_status,
    d.has_verification_badge::boolean,
    (
      NOT d.is_banned
      AND d.onboarding_completed
      AND d.visibility NOT IN ('suspended', 'deactivated')
      AND d.has_safe_primary_photo
      AND d.marriage_timeline IS NOT NULL
    )::boolean AS can_approve_profile,
    CASE
      WHEN d.is_banned THEN 'Banned users cannot be made visible.'
      WHEN d.onboarding_completed IS DISTINCT FROM true
        THEN 'Onboarding must be complete.'
      WHEN d.visibility IN ('suspended', 'deactivated')
        THEN 'Restore the account first.'
      WHEN d.has_safe_primary_photo IS DISTINCT FROM true
        THEN 'A safe primary photo is required.'
      WHEN d.marriage_timeline IS NULL
        THEN 'Marriage timeline is required.'
      ELSE NULL
    END::text AS approval_block_reason,
    count(*) OVER ()::bigint AS total_count
  FROM directory d
  ORDER BY d.joined_at DESC
  LIMIT v_limit OFFSET v_offset;
END;
$$;
REVOKE ALL ON FUNCTION public.admin_user_directory_page(
  text, integer, integer
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_user_directory_page(
  text, integer, integer
) TO authenticated;

-- Replace the five-minute staff snapshot with photo-verification metrics.
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
    'pendingPhotoChecks', (
      SELECT count(*) FROM public.photo_verification_submissions
      WHERE status = 'pending' AND reviewed_at IS NULL
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
    'pendingPhotoChecks', v_dashboard->'pendingPhotoChecks',
    'pendingPhotos', (
      SELECT count(*) FROM public.photos
      WHERE moderation_status = 'pending'
    ),
    'openReports', v_dashboard->'openReports',
    'queuedCampaigns', (
      SELECT count(*) FROM public.admin_push_campaigns
      WHERE status = 'queued'
    ),
    'publishedContentPages', (
      SELECT count(*) FROM public.app_content_pages
      WHERE status = 'published'
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
      WHERE status = 'failed'
        AND created_at >= now() - interval '24 hours'
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
      SELECT count(*) FROM public.admin_memberships
      WHERE status = 'active'
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
        SELECT count(*) FROM public.profiles
        WHERE onboarding_completed = true
      ),
      'totalProfiles', v_dashboard->'totalUsers',
      'photoVerifiedProfiles', (
        SELECT count(*) FROM public.profiles
        WHERE photo_verified_at IS NOT NULL
          AND photo_verification_paused_at IS NULL
      ),
      'pendingPhotoChecks', v_dashboard->'pendingPhotoChecks',
      'activeSubscribers', v_dashboard->'activeSubscriptions'
    ),
    'queues', jsonb_build_object(
      'openReports', v_health->'openReports',
      'pendingPhotos', v_health->'pendingPhotos',
      'pendingPhotoChecks', v_health->'pendingPhotoChecks',
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
          100.0 * count(*) FILTER (
            WHERE photo_verified_at IS NOT NULL
              AND photo_verification_paused_at IS NULL
          ) / nullif(count(*), 0)
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
  ) VALUES
    ('dashboard', v_dashboard, now()),
    ('system_health', v_health, now()),
    ('live_operations', v_live, now())
  ON CONFLICT (metric_name) DO UPDATE
  SET payload = EXCLUDED.payload,
      generated_at = EXCLUDED.generated_at;
END;
$$;
REVOKE ALL ON FUNCTION private.refresh_admin_metric_snapshots()
  FROM PUBLIC;

DROP FUNCTION IF EXISTS public.get_my_kyc_status();
DROP FUNCTION IF EXISTS public.submit_manual_kyc_for_review(
  uuid, text, text, text, text, date, numeric
);
DROP FUNCTION IF EXISTS public.admin_kyc_queue(integer);
DROP FUNCTION IF EXISTS public.admin_review_kyc(
  uuid, text, text, boolean, boolean, boolean, boolean, boolean
);
DROP FUNCTION IF EXISTS public.checkout_kyc_document_purges(integer);
DROP FUNCTION IF EXISTS public.record_kyc_purge_object_result(
  uuid, text, boolean, text
);
DROP FUNCTION IF EXISTS public.finish_kyc_document_purge(uuid);
DROP FUNCTION IF EXISTS public.consume_kyc_upload_reservations(
  uuid, text, text, integer, text, text, integer
);
DROP FUNCTION IF EXISTS public.lock_identity_during_kyc_review();
DROP FUNCTION IF EXISTS private.current_kyc_status(uuid);

DROP VIEW IF EXISTS public.my_profile_private;

DROP INDEX IF EXISTS public.idx_profiles_kyc_verified;
ALTER TABLE public.profiles
  DROP COLUMN IF EXISTS kyc_manual_review_id,
  DROP COLUMN IF EXISTS kyc_verified,
  DROP COLUMN IF EXISTS kyc_method,
  DROP COLUMN IF EXISTS kyc_assurance_level,
  DROP COLUMN IF EXISTS face_similarity,
  DROP COLUMN IF EXISTS kyc_id_type,
  DROP COLUMN IF EXISTS kyc_country_code,
  DROP COLUMN IF EXISTS kyc_selfie_storage_path,
  DROP COLUMN IF EXISTS kyc_id_photo_storage_path;

DROP TABLE IF EXISTS public.kyc_review_submissions;

CREATE VIEW public.my_profile_private
WITH (security_invoker = true, security_barrier = true)
AS
SELECT row_data.*
FROM public.get_my_profile_private_rows() AS row_data;
REVOKE ALL ON public.my_profile_private FROM PUBLIC, anon;
GRANT SELECT ON public.my_profile_private TO authenticated;

-- Signed upload reservations now accept profile photos only. Temporary
-- photo-verification captures use their dedicated service-role endpoint.
DELETE FROM private.upload_reservations
WHERE purpose IN ('kyc_selfie', 'kyc_id', 'badge_selfie');

ALTER TABLE private.upload_reservations
  DROP CONSTRAINT IF EXISTS upload_reservations_purpose_check;
ALTER TABLE private.upload_reservations
  ADD CONSTRAINT upload_reservations_purpose_check
  CHECK (purpose = 'profile_photo');

CREATE OR REPLACE FUNCTION public.reserve_upload(
  p_user_id uuid,
  p_bucket_id text,
  p_purpose text,
  p_storage_path text,
  p_expected_mime text,
  p_max_bytes integer,
  p_order_index integer DEFAULT NULL
)
RETURNS TABLE(reservation_id uuid, replaced_photo_id uuid)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_profile_id uuid;
  v_replaced uuid;
  v_id uuid;
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'service_role_required' USING ERRCODE = 'P0001';
  END IF;
  IF p_user_id IS NULL
    OR p_storage_path !~ (
      '^' || p_user_id::text || '/[A-Za-z0-9_-]+[.](jpg|jpeg)$'
    )
    OR p_purpose <> 'profile_photo'
    OR p_bucket_id <> 'profile-photos'
    OR p_order_index NOT BETWEEN 0 AND 3
    OR p_expected_mime <> 'image/jpeg'
    OR p_max_bytes NOT BETWEEN 1 AND 10485760 THEN
    RAISE EXCEPTION 'invalid_profile_upload_contract'
      USING ERRCODE = 'P0001';
  END IF;

  PERFORM pg_advisory_xact_lock(hashtextextended(
    p_user_id::text || ':' || p_order_index::text, 76
  ));

  SELECT id INTO v_profile_id
  FROM public.profiles
  WHERE user_id = p_user_id;
  IF v_profile_id IS NULL THEN
    RAISE EXCEPTION 'profile_not_found' USING ERRCODE = 'P0001';
  END IF;

  SELECT id INTO v_replaced
  FROM public.photos
  WHERE profile_id = v_profile_id
    AND order_index = p_order_index
    AND status = 'active'
  FOR UPDATE;

  IF EXISTS (
    SELECT 1 FROM public.photos
    WHERE profile_id = v_profile_id
      AND order_index = p_order_index
      AND status = 'pending_review'
  ) THEN
    RAISE EXCEPTION 'photo_review_already_pending'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_replaced IS NULL AND (
    SELECT count(*) FROM public.photos
    WHERE profile_id = v_profile_id AND status = 'active'
  ) >= 4 THEN
    RAISE EXCEPTION 'photo_quota_reached' USING ERRCODE = 'P0001';
  END IF;

  UPDATE private.upload_reservations
  SET status = 'superseded'
  WHERE user_id = p_user_id
    AND purpose = 'profile_photo'
    AND order_index = p_order_index
    AND status = 'reserved';

  INSERT INTO private.upload_reservations(
    user_id, profile_id, bucket_id, purpose, order_index, storage_path,
    expected_mime, max_bytes, replaced_photo_id
  ) VALUES (
    p_user_id, v_profile_id, p_bucket_id, p_purpose, p_order_index,
    p_storage_path, p_expected_mime, p_max_bytes, v_replaced
  ) RETURNING id INTO v_id;

  RETURN QUERY SELECT v_id, v_replaced;
END;
$$;
REVOKE ALL ON FUNCTION public.reserve_upload(
  uuid, text, text, text, text, integer, integer
) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.reserve_upload(
  uuid, text, text, text, text, integer, integer
) TO service_role;

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
    'translate-message'
  ) THEN
    RAISE EXCEPTION 'Unknown Edge Function health key';
  END IF;

  INSERT INTO private.edge_function_health AS health(
    function_name, last_success_at, last_failure_at,
    consecutive_failures, last_error, last_details, updated_at
  ) VALUES (
    p_function_name,
    CASE WHEN p_success THEN now() ELSE NULL END,
    CASE WHEN p_success THEN NULL ELSE now() END,
    CASE WHEN p_success THEN 0 ELSE 1 END,
    CASE WHEN p_success THEN NULL
         ELSE left(coalesce(p_error, 'Unknown failure'), 1000) END,
    coalesce(p_details, '{}'::jsonb),
    now()
  )
  ON CONFLICT (function_name) DO UPDATE
  SET last_success_at = CASE WHEN p_success THEN now()
                             ELSE health.last_success_at END,
      last_failure_at = CASE WHEN p_success THEN health.last_failure_at
                             ELSE now() END,
      consecutive_failures = CASE WHEN p_success THEN 0
                                  ELSE health.consecutive_failures + 1 END,
      last_error = CASE WHEN p_success THEN NULL
                        ELSE left(coalesce(p_error, 'Unknown failure'), 1000)
                   END,
      last_details = coalesce(p_details, '{}'::jsonb),
      updated_at = now();
END;
$$;
REVOKE ALL ON FUNCTION public.record_edge_function_result(
  text, boolean, text, jsonb
) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.record_edge_function_result(
  text, boolean, text, jsonb
) TO service_role;

DELETE FROM private.edge_function_health
WHERE function_name IN ('process-kyc', 'digilocker-verify');

SELECT private.refresh_admin_metric_snapshots();

COMMENT ON FUNCTION public.reserve_upload(
  uuid, text, text, text, text, integer, integer
) IS 'Service-only profile-photo reservation. Identity-document purposes are permanently rejected.';
