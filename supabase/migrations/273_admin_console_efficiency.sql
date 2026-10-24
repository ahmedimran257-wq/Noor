-- Admin console efficiency pass.
--
-- Before this migration every staff page load spent two GoTrue user lookups,
-- one session-boundary RPC (which always wrote last_seen_at), one membership
-- read and one factor listing per requireAdmin() call, and layouts and pages
-- each called requireAdmin(). admin_console_context() answers all of those in
-- one round trip from the verified JWT, throttles the boundary write and adds
-- the queue counts the navigation shows. Every check that
-- assert_admin_session_boundary() and is_active_admin() perform is kept.
--
-- Long lists move to keyset pagination (no OFFSET, no count(*) OVER ()), and
-- the matches/subscriptions summaries stop reporting capped or mislabelled
-- totals.

-- ---------------------------------------------------------------------------
-- Indexes for the keyset feeds and the counters below.
-- ---------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_users_admin_directory_keyset
  ON public.users (created_at DESC, id DESC);

CREATE INDEX IF NOT EXISTS idx_admin_audit_log_feed_keyset
  ON public.admin_audit_log (created_at DESC, id DESC);

CREATE INDEX IF NOT EXISTS idx_admin_notifications_feed_keyset
  ON public.admin_notifications (created_at DESC, id DESC);

CREATE INDEX IF NOT EXISTS idx_reports_pending_queue
  ON public.reports (created_at, id)
  WHERE status = 'pending';

CREATE INDEX IF NOT EXISTS idx_admin_login_attempts_time
  ON public.admin_login_attempts (created_at DESC)
  INCLUDE (success);

-- ---------------------------------------------------------------------------
-- One-call staff context: session boundary, membership, MFA state, identity
-- and the queue counts the navigation needs.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_console_context(p_session_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_admin_id uuid := auth.uid();
  v_session_id uuid := nullif(auth.jwt()->>'session_id', '')::uuid;
  v_aal text := coalesce(auth.jwt()->>'aal', 'aal1');
  v_deadline timestamptz;
  v_role text;
  v_mfa_required boolean;
  v_email text;
  v_has_totp boolean;
  v_boundary_ok boolean;
  v_counts jsonb := '{}'::jsonb;
BEGIN
  IF v_admin_id IS NULL OR p_session_id IS NULL
    OR p_session_id IS DISTINCT FROM v_session_id THEN
    RETURN jsonb_build_object('allowed', false, 'reason', 'session');
  END IF;

  v_deadline := private.admin_session_deadline();
  IF v_deadline IS NULL OR v_deadline <= now() THEN
    RETURN jsonb_build_object('allowed', false, 'reason', 'session');
  END IF;

  SELECT membership.role, membership.mfa_required
  INTO v_role, v_mfa_required
  FROM public.admin_memberships membership
  WHERE membership.user_id = v_admin_id
    AND membership.status = 'active';

  IF v_role IS NULL THEN
    RETURN jsonb_build_object('allowed', false, 'reason', 'not_staff');
  END IF;

  -- Same boundary contract as assert_admin_session_boundary(): the session
  -- row is bound to its owner and never outlives the Auth session deadline.
  INSERT INTO private.admin_session_boundaries(session_id, admin_id, expires_at)
  VALUES (p_session_id, v_admin_id, v_deadline)
  ON CONFLICT (session_id) DO NOTHING;

  SELECT boundary.admin_id = v_admin_id AND boundary.expires_at > now()
  INTO v_boundary_ok
  FROM private.admin_session_boundaries boundary
  WHERE boundary.session_id = p_session_id;

  IF NOT coalesce(v_boundary_ok, false) THEN
    RETURN jsonb_build_object('allowed', false, 'reason', 'session');
  END IF;

  -- last_seen_at is informational; one write per minute is enough and keeps
  -- page loads from generating a row update each time.
  UPDATE private.admin_session_boundaries boundary
  SET last_seen_at = now(),
      expires_at = least(boundary.expires_at, v_deadline)
  WHERE boundary.session_id = p_session_id
    AND (boundary.last_seen_at < now() - interval '1 minute'
      OR boundary.expires_at > v_deadline);

  SELECT account.email::text INTO v_email
  FROM auth.users account
  WHERE account.id = v_admin_id;

  SELECT EXISTS (
    SELECT 1 FROM auth.mfa_factors factor
    WHERE factor.user_id = v_admin_id
      AND factor.factor_type = 'totp'
      AND factor.status = 'verified'
  ) INTO v_has_totp;

  -- Counts are only useful (and only safe to expose) to a fully verified
  -- session. Each count is capped so a large backlog never scans the table.
  IF v_aal = 'aal2' THEN
    v_counts := jsonb_build_object(
      'unreadInbox', (
        SELECT count(*) FROM (
          SELECT 1 FROM public.admin_notifications n
          WHERE n.is_read = false LIMIT 1000
        ) capped
      )
    );

    IF v_role IN ('super_admin', 'moderator') THEN
      v_counts := v_counts || jsonb_build_object(
        'openReports', (
          SELECT count(*) FROM (
            SELECT 1 FROM public.reports r
            JOIN public.profiles p ON p.user_id = r.reported_user_id
            WHERE r.status = 'pending' LIMIT 1000
          ) capped
        ),
        'messageReports', (
          SELECT count(*) FROM (
            SELECT 1 FROM public.message_reports mr
            JOIN public.messages m ON m.id = mr.message_id
            WHERE mr.status = 'pending' LIMIT 1000
          ) capped
        ),
        'pendingPhotos', (
          SELECT count(*) FROM (
            SELECT 1 FROM public.photo_moderation_queue q
            JOIN public.photos ph ON ph.id = q.photo_id
            JOIN public.profiles p ON p.user_id = q.user_id
            WHERE q.status = 'pending_review' LIMIT 1000
          ) capped
        ),
        -- Mirrors admin_photo_verification_queue(): expired or purged
        -- submissions cannot be reviewed, so they are not "waiting".
        'photoChecks', (
          SELECT count(*) FROM (
            SELECT 1 FROM public.photo_verification_submissions s
            WHERE s.status = 'pending'
              AND s.captures_purged_at IS NULL
              AND s.review_deadline > now()
            LIMIT 1000
          ) capped
        )
      );
    END IF;

    IF v_role IN ('super_admin', 'support') THEN
      v_counts := v_counts || jsonb_build_object(
        'privacyOpen', (
          SELECT count(*) FROM (
            SELECT 1 FROM public.privacy_requests pr
            WHERE pr.status <> 'resolved' LIMIT 1000
          ) capped
        ),
        'privacyOverdue', (
          SELECT count(*) FROM (
            SELECT 1 FROM public.privacy_requests pr
            WHERE pr.status <> 'resolved' AND pr.due_at < now() LIMIT 1000
          ) capped
        )
      );
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'allowed', true,
    'adminId', v_admin_id,
    'email', v_email,
    'role', v_role,
    'mfaRequired', v_mfa_required,
    'aal', v_aal,
    'hasVerifiedTotp', v_has_totp,
    'expiresAt', v_deadline,
    'counts', v_counts
  );
END;
$$;

REVOKE ALL ON FUNCTION public.admin_console_context(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_console_context(uuid) TO authenticated;

COMMENT ON FUNCTION public.admin_console_context(uuid) IS
  'One-call staff context: binds the session like assert_admin_session_boundary(), returns role, MFA state and capped queue counts.';

-- ---------------------------------------------------------------------------
-- Dashboard: three RPCs become one.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_dashboard_overview(p_online_limit integer DEFAULT 12)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF NOT public.is_active_admin() THEN
    RAISE EXCEPTION 'staff_authorization_required' USING ERRCODE = '42501';
  END IF;

  RETURN jsonb_build_object(
    'metrics', (
      SELECT snapshot.payload - 'pendingKyc' - 'pendingPhotoChecks'
      FROM private.admin_metric_snapshots snapshot
      WHERE snapshot.metric_name = 'dashboard'
    ),
    'live', (
      SELECT snapshot.payload
      FROM private.admin_metric_snapshots snapshot
      WHERE snapshot.metric_name = 'live_operations'
    ),
    'onlineUsers', coalesce((
      SELECT jsonb_agg(to_jsonb(online) ORDER BY online.last_seen_at DESC)
      FROM public.admin_online_users(least(greatest(coalesce(p_online_limit, 12), 1), 50)) online
    ), '[]'::jsonb)
  );
END;
$$;

REVOKE ALL ON FUNCTION public.admin_dashboard_overview(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_dashboard_overview(integer) TO authenticated;

-- ---------------------------------------------------------------------------
-- Member directory with keyset pagination. Keeps the audited read, masking
-- and approval diagnostics of admin_user_directory_page(); the photo check
-- now runs only for the returned rows.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_user_directory_keyset(
  p_query text DEFAULT '',
  p_limit integer DEFAULT 50,
  p_cursor_joined_at timestamptz DEFAULT NULL,
  p_cursor_id uuid DEFAULT NULL
)
RETURNS TABLE(
  user_id uuid, profile_id uuid, name text, email text, country_code text,
  gender text, joined_at timestamptz, last_active_at timestamptz,
  onboarding_step integer, completeness_score integer, visibility text,
  is_banned boolean, is_shadowbanned boolean, subscription_status text,
  verification_status text, has_verification_badge boolean,
  can_approve_profile boolean, approval_block_reason text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_limit integer := least(greatest(coalesce(p_limit, 50), 1), 100);
  v_query text := trim(coalesce(p_query, ''));
  v_pattern text;
BEGIN
  IF NOT public.is_active_admin() THEN
    RAISE EXCEPTION 'staff_authorization_required' USING ERRCODE = '42501';
  END IF;
  IF (p_cursor_joined_at IS NULL) <> (p_cursor_id IS NULL) THEN
    RAISE EXCEPTION 'invalid_cursor' USING ERRCODE = '22023';
  END IF;

  v_pattern := '%' || replace(replace(replace(lower(v_query), '\', '\\'), '%', '\%'), '_', '\_') || '%';

  INSERT INTO public.admin_audit_log(admin_id, actor_role, action_type, details)
  VALUES (
    auth.uid(),
    public.current_admin_role(),
    'admin_user_directory_read',
    jsonb_build_object(
      'query_present', v_query <> '',
      'limit', v_limit,
      'cursor_present', p_cursor_id IS NOT NULL
    )
  );

  RETURN QUERY
  WITH page AS (
    SELECT u.id, u.email, u.created_at, u.is_banned, u.is_shadowbanned,
           u.subscription_status, p.id AS pid, p.first_name, p.last_name,
           p.country_code, p.gender, p.last_active_at, p.onboarding_step,
           p.completeness_score, p.visibility, p.verification_status,
           p.has_verification_badge, p.onboarding_completed,
           p.marriage_timeline
    FROM public.users u
    JOIN public.profiles p ON p.user_id = u.id
    WHERE (p_cursor_id IS NULL OR (u.created_at, u.id) < (p_cursor_joined_at, p_cursor_id))
      AND (
        v_query = ''
        OR u.id::text = v_query
        OR p.id::text = v_query
        OR lower(concat_ws(' ', p.first_name, p.last_name)) LIKE v_pattern
        OR lower(coalesce(u.email::text, '')) LIKE v_pattern
      )
    ORDER BY u.created_at DESC, u.id DESC
    LIMIT v_limit
  )
  SELECT
    page.id,
    page.pid,
    public.mask_admin_name(concat_ws(' ', page.first_name, page.last_name))::text,
    public.mask_admin_email(page.email::text)::text,
    page.country_code::text,
    page.gender::text,
    page.created_at::timestamptz,
    page.last_active_at::timestamptz,
    page.onboarding_step::integer,
    page.completeness_score::integer,
    page.visibility::text,
    coalesce(page.is_banned, false),
    coalesce(page.is_shadowbanned, false),
    page.subscription_status::text,
    page.verification_status::text,
    coalesce(page.has_verification_badge, false),
    (
      NOT coalesce(page.is_banned, false)
      AND coalesce(page.onboarding_completed, false)
      AND page.visibility::text NOT IN ('suspended', 'deactivated')
      AND photo.has_safe_primary
      AND page.marriage_timeline IS NOT NULL
    ),
    CASE
      WHEN coalesce(page.is_banned, false) THEN 'Banned users cannot be made visible.'
      WHEN NOT coalesce(page.onboarding_completed, false) THEN 'Onboarding must be complete.'
      WHEN page.visibility::text IN ('suspended', 'deactivated') THEN 'Restore the account first.'
      WHEN NOT photo.has_safe_primary THEN 'A safe primary photo is required.'
      WHEN page.marriage_timeline IS NULL THEN 'Marriage timeline is required.'
      ELSE NULL
    END::text
  FROM page
  CROSS JOIN LATERAL (
    SELECT EXISTS (
      SELECT 1 FROM public.photos ph
      WHERE ph.profile_id = page.pid
        AND ph.order_index = 0
        AND ph.admin_approved = true
        AND ph.nsfw_cleared = true
        AND coalesce(ph.status, 'active') = 'active'
    ) AS has_safe_primary
  ) photo
  ORDER BY page.created_at DESC, page.id DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_user_directory_keyset(text, integer, timestamptz, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_user_directory_keyset(text, integer, timestamptz, uuid) TO authenticated;

-- ---------------------------------------------------------------------------
-- Audit trail and inbox feeds with keyset pagination and filters.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_audit_feed_page(
  p_limit integer DEFAULT 50,
  p_cursor_created_at timestamptz DEFAULT NULL,
  p_cursor_id uuid DEFAULT NULL,
  p_action text DEFAULT NULL
)
RETURNS TABLE(
  audit_id uuid, admin_id uuid, admin_email text, actor_role text,
  action_type text, target_user_id uuid, details jsonb, created_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_limit integer := least(greatest(coalesce(p_limit, 50), 1), 100);
  v_action text := nullif(trim(coalesce(p_action, '')), '');
BEGIN
  IF NOT public.is_active_admin() THEN
    RAISE EXCEPTION 'staff_authorization_required' USING ERRCODE = '42501';
  END IF;
  IF (p_cursor_created_at IS NULL) <> (p_cursor_id IS NULL) THEN
    RAISE EXCEPTION 'invalid_cursor' USING ERRCODE = '22023';
  END IF;

  RETURN QUERY
  SELECT a.id, a.admin_id, account.email::text, a.actor_role, a.action_type,
         a.target_user_id, a.details, a.created_at
  FROM public.admin_audit_log a
  LEFT JOIN auth.users account ON account.id = a.admin_id
  WHERE (p_cursor_id IS NULL OR (a.created_at, a.id) < (p_cursor_created_at, p_cursor_id))
    AND (v_action IS NULL OR a.action_type = v_action)
  ORDER BY a.created_at DESC, a.id DESC
  LIMIT v_limit;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_audit_feed_page(integer, timestamptz, uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_audit_feed_page(integer, timestamptz, uuid, text) TO authenticated;

-- The composite index serves equality filters on action_type too.
CREATE INDEX IF NOT EXISTS idx_admin_audit_log_action_keyset
  ON public.admin_audit_log (action_type, created_at DESC, id DESC);
DROP INDEX IF EXISTS public.idx_audit_log_action;

CREATE OR REPLACE FUNCTION public.admin_inbox_page(
  p_unread_only boolean DEFAULT false,
  p_limit integer DEFAULT 50,
  p_cursor_created_at timestamptz DEFAULT NULL,
  p_cursor_id uuid DEFAULT NULL
)
RETURNS TABLE(
  notification_id uuid, type text, message text, related_user_id uuid,
  is_read boolean, created_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_limit integer := least(greatest(coalesce(p_limit, 50), 1), 100);
BEGIN
  IF NOT public.is_active_admin() THEN
    RAISE EXCEPTION 'staff_authorization_required' USING ERRCODE = '42501';
  END IF;
  IF (p_cursor_created_at IS NULL) <> (p_cursor_id IS NULL) THEN
    RAISE EXCEPTION 'invalid_cursor' USING ERRCODE = '22023';
  END IF;

  RETURN QUERY
  SELECT n.id, n.type, n.message, n.related_user_id, n.is_read, n.created_at
  FROM public.admin_notifications n
  WHERE (p_cursor_id IS NULL OR (n.created_at, n.id) < (p_cursor_created_at, p_cursor_id))
    AND (NOT coalesce(p_unread_only, false) OR n.is_read = false)
  ORDER BY n.created_at DESC, n.id DESC
  LIMIT v_limit;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_inbox_page(boolean, integer, timestamptz, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_inbox_page(boolean, integer, timestamptz, uuid) TO authenticated;

CREATE INDEX IF NOT EXISTS idx_admin_notifications_unread_keyset
  ON public.admin_notifications (created_at DESC, id DESC)
  WHERE is_read = false;

-- ---------------------------------------------------------------------------
-- Matches: "active matches" counted every match ever made, the list included
-- ended matches, and message stats aggregated every message before LIMIT.
-- Names are masked like the member directory.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_active_matches(p_limit integer DEFAULT 100)
RETURNS TABLE(match_id uuid, user_a_name text, user_b_name text, created_at timestamptz, message_count bigint, last_message_at timestamptz)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT m.id,
         public.mask_admin_name(concat_ws(' ', pa.first_name, pa.last_name)),
         public.mask_admin_name(concat_ws(' ', pb.first_name, pb.last_name)),
         m.created_at, stats.message_count, stats.last_message_at
  FROM (
    SELECT mt.id, mt.user_a, mt.user_b, mt.created_at
    FROM public.matches mt
    WHERE public.is_active_admin() AND mt.status = 'active'
    ORDER BY mt.created_at DESC
    LIMIT least(greatest(coalesce(p_limit, 100), 1), 100)
  ) m
  JOIN public.profiles pa ON pa.user_id = m.user_a
  JOIN public.profiles pb ON pb.user_id = m.user_b
  CROSS JOIN LATERAL (
    SELECT count(*) AS message_count, max(msg.created_at) AS last_message_at
    FROM public.messages msg
    WHERE msg.match_id = m.id
  ) stats
  ORDER BY m.created_at DESC;
$$;

CREATE OR REPLACE FUNCTION public.admin_match_metrics()
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT CASE WHEN public.is_active_admin() THEN jsonb_build_object(
    'activeMatches', (SELECT count(*) FROM public.matches WHERE status = 'active'),
    'interestsThirtyDays', (SELECT count(*) FROM public.interests WHERE created_at >= now() - interval '30 days'),
    'acceptedThirtyDays', (SELECT count(*) FROM public.interests WHERE status = 'accepted' AND created_at >= now() - interval '30 days'),
    'messagesThirtyDays', (SELECT count(*) FROM public.messages WHERE created_at >= now() - interval '30 days'),
    'discoveryProfiles', (SELECT count(*) FROM public.live_discovery_pool)
  ) ELSE NULL END;
$$;

-- ---------------------------------------------------------------------------
-- Subscriptions: the page counted at most 100 rows as "active subscribers"
-- and summed every currency as INR.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_subscription_summary()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF NOT public.is_active_admin() THEN
    RAISE EXCEPTION 'staff_authorization_required' USING ERRCODE = '42501';
  END IF;

  RETURN jsonb_build_object(
    'active', (SELECT count(*) FROM public.users WHERE subscription_status = 'active'),
    'grace', (SELECT count(*) FROM public.users WHERE subscription_status = 'grace'),
    'revenue', coalesce((
      SELECT jsonb_agg(jsonb_build_object('currency', totals.currency, 'gross', totals.gross)
        ORDER BY totals.gross DESC)
      FROM (
        SELECT coalesce(nullif(upper(se.currency), ''), 'UNKNOWN') AS currency,
               sum(se.price) AS gross
        FROM public.subscription_events se
        WHERE se.event_type IN ('INITIAL_PURCHASE', 'RENEWAL')
          AND se.price IS NOT NULL
        GROUP BY 1
      ) totals
    ), '[]'::jsonb),
    'refunds', (
      SELECT count(*) FROM public.subscription_events se
      WHERE se.event_type = 'REFUND'
    )
  );
END;
$$;

REVOKE ALL ON FUNCTION public.admin_subscription_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_subscription_summary() TO authenticated;

-- The subscriber list showed full member names, unlike every other staff
-- list. It is masked like the directory, and both per-member lookups use
-- idx_subscription_events_user_time.
CREATE OR REPLACE FUNCTION public.admin_subscribers(p_limit integer DEFAULT 100)
RETURNS TABLE(user_id uuid, name text, country_code text, subscription_status text, subscription_expires_at timestamptz, product_id text, total_paid numeric)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT u.id,
         public.mask_admin_name(concat_ws(' ', p.first_name, p.last_name)),
         p.country_code::text,
         u.subscription_status::text,
         u.subscription_expires_at,
         latest.product_id,
         coalesce(paid.total, 0)
  FROM public.users u
  JOIN public.profiles p ON p.user_id = u.id
  LEFT JOIN LATERAL (
    SELECT se.product_id FROM public.subscription_events se
    WHERE se.user_id = u.id
    ORDER BY se.event_timestamp_ms DESC, se.id DESC
    LIMIT 1
  ) latest ON true
  LEFT JOIN LATERAL (
    SELECT sum(se.price) AS total FROM public.subscription_events se
    WHERE se.user_id = u.id AND se.event_type IN ('INITIAL_PURCHASE', 'RENEWAL')
  ) paid ON true
  WHERE public.is_active_admin() AND u.subscription_status IN ('active', 'grace')
  ORDER BY u.subscription_expires_at NULLS LAST
  LIMIT least(greatest(coalesce(p_limit, 100), 1), 100);
$$;

NOTIFY pgrst, 'reload schema';
