-- Keep government-ID KYC separate from the passive profile-photo badge.
-- Every consumer reads this contract instead of interpreting
-- profiles.verification_status, which belongs to the independent face check.

CREATE OR REPLACE FUNCTION private.current_kyc_status(p_user_id uuid)
RETURNS TABLE(
  status text,
  method text,
  assurance_level text,
  submitted_at timestamptz,
  reviewed_at timestamptz,
  reason text,
  can_submit boolean
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT
    CASE
      WHEN coalesce(p.kyc_verified, false) THEN 'approved'
      WHEN latest.source = 'manual' THEN CASE latest.decision
        WHEN 'pending' THEN 'pending_review'
        WHEN 'approved' THEN 'approved'
        WHEN 'rejected' THEN 'rejected'
        WHEN 'resubmit' THEN 'resubmit_required'
        WHEN 'expired' THEN 'expired'
        ELSE 'not_started'
      END
      WHEN latest.source = 'digilocker' THEN CASE latest.decision
        WHEN 'verified' THEN 'approved'
        WHEN 'identity_mismatch' THEN 'rejected'
        WHEN 'insufficient_evidence' THEN 'resubmit_required'
        ELSE 'not_started'
      END
      ELSE 'not_started'
    END::text AS status,
    CASE
      WHEN coalesce(p.kyc_verified, false) THEN coalesce(p.kyc_method, latest.method)
      ELSE latest.method
    END::text AS method,
    CASE
      WHEN coalesce(p.kyc_verified, false) THEN coalesce(p.kyc_assurance_level, 'none')
      WHEN latest.source = 'manual' AND latest.decision = 'approved'
        THEN 'manual_document_review'
      WHEN latest.source = 'digilocker' AND latest.decision = 'verified'
        THEN 'government_document_match'
      ELSE 'none'
    END::text AS assurance_level,
    latest.submitted_at,
    latest.reviewed_at,
    latest.reason,
    (
      NOT coalesce(p.kyc_verified, false)
      AND NOT (
        latest.source = 'manual'
        AND latest.decision = 'pending'
      )
    )::boolean AS can_submit
  FROM public.profiles p
  LEFT JOIN LATERAL (
    SELECT event.source,
           event.decision,
           event.method,
           event.submitted_at,
           event.reviewed_at,
           event.reason
    FROM (
      SELECT
        'manual'::text AS source,
        submission.status::text AS decision,
        'manual_review_v1'::text AS method,
        submission.submitted_at,
        submission.reviewed_at,
        submission.review_reason::text AS reason,
        coalesce(submission.reviewed_at, submission.submitted_at) AS event_at
      FROM public.kyc_review_submissions submission
      WHERE submission.user_id = p_user_id

      UNION ALL

      SELECT
        'digilocker'::text AS source,
        evidence.decision::text AS decision,
        'digilocker_evidence_v2'::text AS method,
        evidence.created_at AS submitted_at,
        evidence.verified_at AS reviewed_at,
        CASE evidence.decision
          WHEN 'identity_mismatch'
            THEN 'Your profile details did not match the verified identity document.'
          WHEN 'insufficient_evidence'
            THEN 'DigiLocker did not return enough verified document evidence.'
          ELSE NULL
        END::text AS reason,
        evidence.created_at AS event_at
      FROM public.identity_verification_evidence evidence
      WHERE evidence.user_id = p_user_id
    ) event
    ORDER BY event.event_at DESC
    LIMIT 1
  ) latest ON true
  WHERE p.user_id = p_user_id;
$$;

COMMENT ON FUNCTION private.current_kyc_status(uuid) IS
  'Authoritative government-ID KYC lifecycle derived from auditable manual or DigiLocker evidence. It deliberately ignores the separate face/photo verification status.';

REVOKE ALL ON FUNCTION private.current_kyc_status(uuid)
  FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.get_my_kyc_status()
RETURNS TABLE(
  status text,
  method text,
  assurance_level text,
  submitted_at timestamptz,
  reviewed_at timestamptz,
  reason text,
  can_submit boolean
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  RETURN QUERY
  SELECT *
  FROM private.current_kyc_status(auth.uid());
END;
$$;

COMMENT ON FUNCTION public.get_my_kyc_status() IS
  'Returns only the signed-in user''s authoritative government-ID KYC lifecycle.';

REVOKE ALL ON FUNCTION public.get_my_kyc_status()
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_kyc_status()
  TO authenticated;

DROP FUNCTION IF EXISTS public.admin_user_directory_page(text, integer, integer);

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
  kyc_status text,
  kyc_status_reason text,
  kyc_submitted_at timestamptz,
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

  INSERT INTO public.admin_audit_log(admin_id, actor_role, action_type, details)
  VALUES (
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
      coalesce(p.has_verification_badge, false) AS has_verification_badge,
      kyc.status::text AS kyc_status,
      kyc.reason::text AS kyc_status_reason,
      kyc.submitted_at AS kyc_submitted_at,
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
    LEFT JOIN LATERAL private.current_kyc_status(u.id) kyc ON true
    WHERE
      v_query = ''
      OR concat_ws(
        ' ',
        p.first_name,
        p.last_name,
        u.email,
        u.id::text
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
    coalesce(d.kyc_status, 'not_started')::text,
    d.kyc_status_reason,
    d.kyc_submitted_at,
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

REVOKE ALL ON FUNCTION public.admin_user_directory_page(text, integer, integer)
  FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_user_directory_page(text, integer, integer)
  TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_dashboard_metrics()
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT CASE WHEN public.is_active_admin() THEN jsonb_build_object(
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
      SELECT count(*) FROM public.users WHERE subscription_status = 'active'
    ),
    'matchesToday', (
      SELECT count(*) FROM public.matches WHERE created_at >= current_date
    ),
    'messagesToday', (
      SELECT count(*) FROM public.messages WHERE created_at >= current_date
    )
  ) ELSE NULL END;
$$;

REVOKE ALL ON FUNCTION public.admin_dashboard_metrics() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_dashboard_metrics() TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_system_health()
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT CASE WHEN public.is_active_admin() THEN jsonb_build_object(
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
        CASE
          WHEN metadata->>'size' ~ '^[0-9]+$'
            THEN (metadata->>'size')::bigint
          ELSE 0
        END
      ), 0)
      FROM storage.objects
    ) / 1048576.0, 1),
    'dispatchConsecutiveFailures', coalesce((
      SELECT consecutive_failures
      FROM private.edge_function_health
      WHERE function_name = 'dispatch-notifications'
    ), 0),
    'dispatchHealthy', CASE WHEN EXISTS (
      SELECT 1
      FROM private.edge_function_health
      WHERE function_name = 'dispatch-notifications'
        AND consecutive_failures < 3
        AND last_success_at >= now() - interval '15 minutes'
    ) THEN 1 ELSE 0 END,
    'activeStaff', (
      SELECT count(*) FROM public.admin_memberships WHERE status = 'active'
    )
  ) ELSE NULL END;
$$;

REVOKE ALL ON FUNCTION public.admin_system_health() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_system_health() TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_live_operations_snapshot()
RETURNS jsonb
LANGUAGE sql
VOLATILE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT CASE WHEN public.is_active_admin() THEN jsonb_build_object(
    'generatedAt', extract(epoch FROM now())::bigint,
    'traffic', jsonb_build_object(
      'onlineNow', (
        SELECT count(*) FROM public.user_presence
        WHERE last_seen_at >= now() - interval '2 minutes'
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
      'signupsToday', (
        SELECT count(*) FROM public.users
        WHERE created_at >= date_trunc('day', now())
      )
    ),
    'engagement', jsonb_build_object(
      'messagesLastHour', (
        SELECT count(*) FROM public.messages
        WHERE created_at >= now() - interval '1 hour'
      ),
      'messagesToday', (
        SELECT count(*) FROM public.messages
        WHERE created_at >= date_trunc('day', now())
      ),
      'interestsLastHour', (
        SELECT count(*) FROM public.interests
        WHERE created_at >= now() - interval '1 hour'
      ),
      'interestsToday', (
        SELECT count(*) FROM public.interests
        WHERE created_at >= date_trunc('day', now())
      ),
      'matchesToday', (
        SELECT count(*) FROM public.matches
        WHERE created_at >= date_trunc('day', now())
      )
    ),
    'progress', jsonb_build_object(
      'avgCompletion', coalesce((
        SELECT round(avg(completeness_score))::int FROM public.profiles
      ), 0),
      'completedProfiles', (
        SELECT count(*) FROM public.profiles
        WHERE onboarding_completed = true
      ),
      'totalProfiles', (SELECT count(*) FROM public.profiles),
      'verifiedProfiles', (
        SELECT count(*) FROM public.profiles WHERE kyc_verified = true
      ),
      'pendingKyc', (
        SELECT count(*) FROM public.kyc_review_submissions
        WHERE status = 'pending'
      ),
      'activeSubscribers', (
        SELECT count(*) FROM public.users
        WHERE subscription_status IN ('active','grace')
      )
    ),
    'queues', jsonb_build_object(
      'openReports', (
        SELECT count(*) FROM public.reports WHERE status = 'pending'
      ),
      'pendingPhotos', (
        SELECT count(*) FROM public.photos WHERE moderation_status = 'pending'
      ),
      'dueNotifications', (
        SELECT count(*) FROM public.notifications
        WHERE sent_at IS NULL AND scheduled_at <= now()
      ),
      'futureNotifications', (
        SELECT count(*) FROM public.notifications
        WHERE sent_at IS NULL AND scheduled_at > now()
      ),
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
        )::int
        FROM public.profiles
      ), 0),
      'verificationRate', coalesce((
        SELECT round(
          100.0 * count(*) FILTER (WHERE kyc_verified = true)
          / nullif(count(*), 0)
        )::int
        FROM public.profiles
      ), 0),
      'subscriberRate', coalesce((
        SELECT round(
          100.0 * count(*) FILTER (
            WHERE subscription_status IN ('active','grace')
          ) / nullif(count(*), 0)
        )::int
        FROM public.users
      ), 0),
      'photoClearanceRate', coalesce((
        SELECT round(
          100.0 * count(*) FILTER (WHERE moderation_status = 'approved')
          / nullif(count(*), 0)
        )::int
        FROM public.photos
      ), 0)
    )
  ) ELSE NULL END;
$$;

REVOKE ALL ON FUNCTION public.admin_live_operations_snapshot() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_live_operations_snapshot()
  TO authenticated;
