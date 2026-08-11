-- Authenticated, rate-limited personal data export for privacy access and
-- portability requests. The export deliberately excludes credentials, raw
-- push tokens, other members' reports, staff identities, private moderation
-- methods and temporary verification captures.

-- Keep new signup consent in lockstep with the 2.2.0 policy bundle. Existing
-- consent rows remain immutable; material changes are presented by the app.
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
  IF trim(coalesce(p_policy_version, '')) <> '2.2.0'
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
  VALUES ('2.2.0', p_acceptances)
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

REVOKE ALL ON FUNCTION public.begin_signup_consent_transaction(text, jsonb)
  FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.begin_signup_consent_transaction(text, jsonb)
  TO anon, authenticated;

CREATE TABLE IF NOT EXISTS public.data_export_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  requested_at timestamptz NOT NULL DEFAULT now(),
  completed_at timestamptz,
  client_version text,
  format text NOT NULL DEFAULT 'json' CHECK (format IN ('json')),
  status text NOT NULL DEFAULT 'processing'
    CHECK (status IN ('processing', 'completed', 'failed')),
  exported_row_count integer,
  error_code text
);

CREATE INDEX IF NOT EXISTS idx_data_export_requests_user_time
  ON public.data_export_requests(user_id, requested_at DESC);

ALTER TABLE public.data_export_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS data_export_requests_select_own
  ON public.data_export_requests;
CREATE POLICY data_export_requests_select_own
  ON public.data_export_requests
  FOR SELECT TO authenticated
  USING (user_id = auth.uid());

REVOKE ALL ON public.data_export_requests FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.data_export_requests TO authenticated;

CREATE OR REPLACE FUNCTION public.download_my_data(
  p_client_version text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
SET statement_timeout = '60s'
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_profile_id uuid;
  v_request_id uuid;
  v_export jsonb;
  v_row_count integer := 0;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'authentication_required' USING ERRCODE = 'P0001';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.id = v_user_id AND u.deletion_status <> 'purged'
  ) THEN
    RAISE EXCEPTION 'account_not_available' USING ERRCODE = 'P0001';
  END IF;

  -- Keep repeated taps and automated scraping from generating expensive full
  -- account snapshots. A failed request can be retried immediately.
  IF EXISTS (
    SELECT 1
    FROM public.data_export_requests der
    WHERE der.user_id = v_user_id
      AND der.status = 'completed'
      AND der.requested_at > now() - interval '10 minutes'
  ) THEN
    RAISE EXCEPTION 'export_rate_limited_10_minutes' USING ERRCODE = 'P0001';
  END IF;

  INSERT INTO public.data_export_requests(user_id, client_version)
  VALUES (v_user_id, nullif(left(trim(coalesce(p_client_version, '')), 80), ''))
  RETURNING id INTO v_request_id;

  SELECT p.id INTO v_profile_id
  FROM public.profiles p
  WHERE p.user_id = v_user_id;

  SELECT jsonb_build_object(
    'schema_version', '1.0',
    'policy_version', '2.2.0',
    'generated_at', now(),
    'request_id', v_request_id,
    'service', 'Silarah',
    'format_notice',
      'Machine-readable JSON. Dates are ISO-8601. IDs preserve relationships between sections.',
    'scope_notice',
      'This self-service archive contains account data available for direct export. It excludes passwords and OTPs, raw push tokens, temporary verification captures, other members'' confidential reports, staff identities, privileged legal material and anti-abuse methods. Contact privacy@silarah.com for a verified request concerning an omitted category.',
    'account', coalesce((
      SELECT jsonb_build_object(
        'auth_user_id', au.id,
        'email', au.email,
        'phone', coalesce(au.phone, u.phone),
        'email_confirmed_at', au.email_confirmed_at,
        'phone_confirmed_at', au.phone_confirmed_at,
        'last_sign_in_at', au.last_sign_in_at,
        'auth_created_at', au.created_at,
        'service_account', to_jsonb(u) - 'last_billing_event_ts'
      )
      FROM public.users u
      LEFT JOIN auth.users au ON au.id = u.id
      WHERE u.id = v_user_id
    ), '{}'::jsonb),
    'profile', coalesce((
      SELECT to_jsonb(p) - 'guardian_phone_encrypted'
      FROM public.profiles p WHERE p.user_id = v_user_id
    ), '{}'::jsonb),
    'partner_preferences', coalesce((
      SELECT to_jsonb(pp)
      FROM public.profile_preferences pp
      WHERE pp.profile_id = v_profile_id
    ), '{}'::jsonb),
    'profile_photos', coalesce((
      SELECT jsonb_agg(to_jsonb(ph) ORDER BY ph.order_index, ph.created_at)
      FROM public.photos ph WHERE ph.profile_id = v_profile_id
    ), '[]'::jsonb),
    'interests', coalesce((
      SELECT jsonb_agg(to_jsonb(i) ORDER BY i.created_at)
      FROM public.interests i
      WHERE i.sender_id = v_user_id OR i.receiver_id = v_user_id
    ), '[]'::jsonb),
    'matches', coalesce((
      SELECT jsonb_agg(to_jsonb(m) ORDER BY m.created_at)
      FROM public.matches m
      WHERE m.user_a = v_user_id OR m.user_b = v_user_id
    ), '[]'::jsonb),
    'messages', coalesce((
      SELECT jsonb_agg(to_jsonb(msg) ORDER BY msg.created_at, msg.id)
      FROM public.messages msg
      JOIN public.matches m ON m.id = msg.match_id
      WHERE m.user_a = v_user_id OR m.user_b = v_user_id
    ), '[]'::jsonb),
    'notifications', coalesce((
      SELECT jsonb_agg(to_jsonb(n) ORDER BY n.created_at)
      FROM public.notifications n WHERE n.user_id = v_user_id
    ), '[]'::jsonb),
    'notification_preferences', coalesce((
      SELECT to_jsonb(np)
      FROM public.notification_prefs np WHERE np.user_id = v_user_id
    ), '{}'::jsonb),
    'consents', coalesce((
      SELECT jsonb_agg(to_jsonb(uc) ORDER BY uc.granted_at)
      FROM public.user_consents uc WHERE uc.user_id = v_user_id
    ), '[]'::jsonb),
    'subscription_events', coalesce((
      SELECT jsonb_agg(to_jsonb(se) ORDER BY se.created_at)
      FROM public.subscription_events se WHERE se.user_id = v_user_id
    ), '[]'::jsonb),
    'devices', coalesce((
      SELECT jsonb_agg(to_jsonb(ud) ORDER BY ud.created_at)
      FROM public.user_devices ud WHERE ud.user_id = v_user_id
    ), '[]'::jsonb),
    'push_registrations', coalesce((
      SELECT jsonb_agg(jsonb_build_object(
        'id', ft.id,
        'device_id', ft.device_id,
        'platform', ft.platform,
        'created_at', ft.created_at,
        'updated_at', ft.updated_at,
        'token', '[redacted credential]'
      ) ORDER BY ft.created_at)
      FROM public.user_fcm_tokens ft WHERE ft.user_id = v_user_id
    ), '[]'::jsonb),
    'profile_views', coalesce((
      SELECT jsonb_agg(to_jsonb(pv) ORDER BY pv.viewed_at)
      FROM public.profile_views pv
      WHERE pv.viewer_profile_id = v_profile_id
         OR pv.viewed_profile_id = v_profile_id
    ), '[]'::jsonb),
    'bookmarks', coalesce((
      SELECT jsonb_agg(to_jsonb(pb) ORDER BY pb.created_at)
      FROM public.profile_bookmarks pb WHERE pb.user_id = v_user_id
    ), '[]'::jsonb),
    'blocks_created', coalesce((
      SELECT jsonb_agg(to_jsonb(b) ORDER BY b.created_at)
      FROM public.blocks b WHERE b.blocker_id = v_user_id
    ), '[]'::jsonb),
    'reports_created', coalesce((
      SELECT jsonb_agg(to_jsonb(r) ORDER BY r.created_at)
      FROM public.reports r WHERE r.reporter_id = v_user_id
    ), '[]'::jsonb),
    'message_reports_created', coalesce((
      SELECT jsonb_agg(to_jsonb(mr) ORDER BY mr.created_at)
      FROM public.message_reports mr WHERE mr.reporter_id = v_user_id
    ), '[]'::jsonb),
    'photo_access_requests', coalesce((
      SELECT jsonb_agg(to_jsonb(par) ORDER BY par.created_at)
      FROM public.photo_access_requests par
      WHERE par.requester_id = v_user_id OR par.owner_id = v_user_id
    ), '[]'::jsonb),
    'guardian_sessions', coalesce((
      SELECT jsonb_agg(to_jsonb(gs) ORDER BY gs.created_at)
      FROM public.guardian_sessions gs
      WHERE gs.guardian_id = v_user_id OR gs.ward_id = v_user_id
    ), '[]'::jsonb),
    'guardian_chat_links', coalesce((
      SELECT jsonb_agg(to_jsonb(gcm) ORDER BY gcm.created_at)
      FROM public.guardian_chat_mirrors gcm
      WHERE gcm.guardian_id = v_user_id OR gcm.ward_id = v_user_id
    ), '[]'::jsonb),
    'referrals', coalesce((
      SELECT jsonb_agg(to_jsonb(ref) ORDER BY ref.created_at)
      FROM public.referrals ref
      WHERE ref.referrer_id = v_user_id OR ref.referred_id = v_user_id
    ), '[]'::jsonb),
    'referral_code', coalesce((
      SELECT to_jsonb(rc)
      FROM public.referral_codes rc WHERE rc.owner_id = v_user_id
    ), '{}'::jsonb),
    'photo_verification_history', coalesce((
      SELECT jsonb_agg(
        to_jsonb(pvs)
          - 'neutral_storage_path'
          - 'smile_storage_path'
          - 'blink_storage_path'
          - 'reviewed_by'
          - 'review_checklist'
          - 'purge_last_error'
        ORDER BY pvs.created_at
      )
      FROM public.photo_verification_submissions pvs
      WHERE pvs.user_id = v_user_id
    ), '[]'::jsonb),
    'content_filter_events', coalesce((
      SELECT jsonb_agg(to_jsonb(cv) ORDER BY cv.created_at)
      FROM public.content_violations cv WHERE cv.user_id = v_user_id
    ), '[]'::jsonb)
  ) INTO v_export;

  SELECT coalesce(sum(jsonb_array_length(value)), 0)::integer
  INTO v_row_count
  FROM jsonb_each(v_export)
  WHERE jsonb_typeof(value) = 'array';

  UPDATE public.data_export_requests
  SET status = 'completed',
      completed_at = now(),
      exported_row_count = v_row_count
  WHERE id = v_request_id;

  RETURN v_export;
EXCEPTION
  WHEN OTHERS THEN
    IF v_request_id IS NOT NULL THEN
      UPDATE public.data_export_requests
      SET status = 'failed',
          completed_at = now(),
          error_code = left(SQLSTATE || ':' || SQLERRM, 180)
      WHERE id = v_request_id;
    END IF;
    RAISE;
END;
$$;

REVOKE ALL ON FUNCTION public.download_my_data(text)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.download_my_data(text) TO authenticated;

COMMENT ON FUNCTION public.download_my_data(text) IS
  'Returns the authenticated member''s rate-limited machine-readable privacy archive without exposing credentials, confidential third-party reports or internal moderation methods.';

NOTIFY pgrst, 'reload schema';
