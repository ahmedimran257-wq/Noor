-- Audit 1: close remaining runtime integrity gaps.

-- Finalizing an upload must consume its reservation, create the photo row and
-- create its moderation work item in one database transaction.
CREATE OR REPLACE FUNCTION public.finalize_profile_photo_upload(
  p_user_id uuid,
  p_storage_path text,
  p_observed_mime text,
  p_observed_bytes integer,
  p_blurhash text,
  p_client_nsfw_score numeric DEFAULT 0
)
RETURNS TABLE(photo_id uuid, action text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_reservation private.upload_reservations%ROWTYPE;
  v_photo_id uuid;
  v_score numeric := least(greatest(coalesce(p_client_nsfw_score, 0), 0), 1);
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'service_role_required' USING ERRCODE = 'P0001';
  END IF;

  SELECT ph.id INTO v_photo_id
  FROM public.photos ph
  JOIN public.profiles pr ON pr.id = ph.profile_id
  WHERE ph.storage_path = p_storage_path
    AND pr.user_id = p_user_id;
  IF v_photo_id IS NOT NULL THEN
    INSERT INTO public.photo_moderation_queue(
      photo_id, user_id, confidence, category, status
    )
    SELECT
      ph.id, p_user_id, coalesce(ph.nsfw_score, 0),
      'unreviewed_upload', 'pending_review'
    FROM public.photos ph
    WHERE ph.id = v_photo_id
      AND ph.status = 'pending_review'
    ON CONFLICT (photo_id) DO NOTHING;
    RETURN QUERY SELECT v_photo_id, 'pending_review'::text;
    RETURN;
  END IF;

  SELECT * INTO v_reservation
  FROM private.upload_reservations r
  WHERE r.user_id = p_user_id
    AND r.storage_path = p_storage_path
    AND r.purpose = 'profile_photo'
    AND r.status = 'reserved'
  FOR UPDATE;

  IF NOT FOUND
    OR v_reservation.expires_at <= now()
    OR v_reservation.expected_mime <> p_observed_mime
    OR p_observed_bytes < 32
    OR p_observed_bytes > v_reservation.max_bytes
    OR nullif(trim(coalesce(p_blurhash, '')), '') IS NULL THEN
    RAISE EXCEPTION 'upload_reservation_invalid_or_expired'
      USING ERRCODE = 'P0001';
  END IF;

  INSERT INTO public.photos(
    profile_id, storage_path, status, order_index, admin_approved,
    nsfw_cleared, nsfw_score, nsfw_category, nsfw_scanned_at,
    moderation_source, moderation_status, blurhash
  )
  VALUES (
    v_reservation.profile_id, v_reservation.storage_path, 'pending_review',
    v_reservation.order_index, false, false, v_score, 'unreviewed_upload',
    now(), 'client_signal_untrusted', 'pending', p_blurhash
  )
  RETURNING id INTO v_photo_id;

  INSERT INTO public.photo_moderation_queue(
    photo_id, user_id, confidence, category, status
  )
  VALUES (
    v_photo_id, p_user_id, v_score, 'unreviewed_upload', 'pending_review'
  );

  UPDATE private.upload_reservations
  SET status = 'consumed', consumed_at = now()
  WHERE id = v_reservation.id;

  RETURN QUERY SELECT v_photo_id, 'pending_review'::text;
END;
$$;
REVOKE ALL ON FUNCTION public.finalize_profile_photo_upload(
  uuid, text, text, integer, text, numeric
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.finalize_profile_photo_upload(
  uuid, text, text, integer, text, numeric
) TO service_role;

-- Token-level delivery uses the same vocabulary at the function and storage
-- boundaries. Existing "invalid" rows remain valid for migration safety.
ALTER TABLE private.notification_deliveries
  DROP CONSTRAINT IF EXISTS notification_deliveries_status_check;
ALTER TABLE private.notification_deliveries
  ADD CONSTRAINT notification_deliveries_status_check
  CHECK (status IN (
    'pending', 'sent', 'retry', 'invalid', 'invalid_token', 'failed'
  ));

-- Consent provenance is assigned at the trusted database boundary. A modified
-- client cannot invent an old/new policy bundle, timestamp or evidence source.
ALTER TABLE public.user_consents
  ADD COLUMN IF NOT EXISTS revoked_at timestamptz,
  ADD COLUMN IF NOT EXISTS evidence_source text,
  ADD COLUMN IF NOT EXISTS policy_digest text;

CREATE OR REPLACE FUNCTION public.record_onboarding_consents(
  p_policy_version text DEFAULT '2.0.0'
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_current_version constant text := '2.0.0';
  v_digest text := encode(
    extensions.digest(
      convert_to(
        'silarah-launch-policy:2.0.0:terms|privacy|community|age|religious',
        'UTF8'
      ),
      'sha256'
    ),
    'hex'
  );
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'authentication_required' USING ERRCODE = 'P0001';
  END IF;
  IF trim(coalesce(p_policy_version, '')) <> v_current_version THEN
    RAISE EXCEPTION 'policy_version_outdated' USING ERRCODE = 'P0001';
  END IF;

  INSERT INTO public.user_consents(
    user_id, consent_type, version, granted_at, revoked_at,
    evidence_source, policy_digest
  )
  SELECT
    v_user_id, required.consent_type, v_current_version, now(), NULL,
    'authenticated_onboarding_gate', v_digest
  FROM (
    VALUES
      ('terms_of_service'),
      ('privacy_policy'),
      ('community_guidelines'),
      ('age_verification'),
      ('special_category_religious')
  ) AS required(consent_type)
  ON CONFLICT (user_id, consent_type, version) DO UPDATE
  SET revoked_at = NULL,
      evidence_source = EXCLUDED.evidence_source,
      policy_digest = EXCLUDED.policy_digest;
END;
$$;
REVOKE ALL ON FUNCTION public.record_onboarding_consents(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.record_onboarding_consents(text)
  TO authenticated;

-- One indexed presence row is updated per heartbeat. Profile activity is
-- coalesced to at most once per hour rather than paid on every heartbeat.
CREATE OR REPLACE FUNCTION public.record_user_presence(
  p_app_state text DEFAULT 'foreground',
  p_platform text DEFAULT NULL
)
RETURNS timestamptz
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_now timestamptz := now();
  v_state text := coalesce(nullif(trim(p_app_state), ''), 'foreground');
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'authentication_required' USING ERRCODE = 'P0001';
  END IF;
  IF v_state NOT IN ('foreground', 'background', 'inactive') THEN
    v_state := 'foreground';
  END IF;

  INSERT INTO public.user_presence(
    user_id, last_seen_at, app_state, platform, updated_at
  )
  VALUES (
    v_user_id, v_now, v_state,
    nullif(left(trim(coalesce(p_platform, '')), 24), ''), v_now
  )
  ON CONFLICT (user_id) DO UPDATE
  SET last_seen_at = EXCLUDED.last_seen_at,
      app_state = EXCLUDED.app_state,
      platform = coalesce(EXCLUDED.platform, public.user_presence.platform),
      updated_at = EXCLUDED.updated_at;

  UPDATE public.profiles
  SET last_active_at = v_now
  WHERE user_id = v_user_id
    AND (
      last_active_at IS NULL
      OR last_active_at < v_now - interval '1 hour'
    );
  RETURN v_now;
END;
$$;
REVOKE ALL ON FUNCTION public.record_user_presence(text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.record_user_presence(text, text)
  TO authenticated;

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
SET search_path = ''
AS $$
BEGIN
  IF NOT public.is_active_admin() THEN
    RAISE EXCEPTION 'aal2_staff_required' USING ERRCODE = 'P0001';
  END IF;
  RETURN QUERY
  SELECT
    up.user_id,
    p.id,
    public.mask_admin_name(concat_ws(' ', p.first_name, p.last_name)),
    public.mask_admin_email(u.email),
    coalesce(p.country_code, u.country_code)::text,
    coalesce(p.gender, u.gender)::text,
    up.last_seen_at,
    up.app_state,
    up.platform,
    coalesce(p.visibility, 'profile_pending')::text,
    coalesce(p.verification_status, 'unverified')::text,
    coalesce(u.subscription_status, 'none')::text
  FROM public.user_presence up
  JOIN public.users u ON u.id = up.user_id
  LEFT JOIN public.profiles p ON p.user_id = up.user_id
  WHERE up.last_seen_at >= now() - interval '12 minutes'
  ORDER BY up.last_seen_at DESC
  LIMIT least(greatest(coalesce(p_limit, 25), 1), 100);
END;
$$;
REVOKE ALL ON FUNCTION public.admin_online_users(integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_online_users(integer) TO authenticated;

-- These server-owned datasets are reachable only through their bounded RPCs.
REVOKE SELECT ON public.discovery_pool FROM anon, authenticated;
REVOKE SELECT, INSERT, UPDATE, DELETE ON public.recommendations
  FROM anon, authenticated;
REVOKE INSERT, UPDATE, DELETE ON public.profile_view_daily_seen
  FROM anon, authenticated;

CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA extensions;
CREATE INDEX IF NOT EXISTS idx_profiles_admin_first_name_trgm
  ON public.profiles USING gin (
    (lower(first_name)) extensions.gin_trgm_ops
  );
CREATE INDEX IF NOT EXISTS idx_profiles_admin_last_name_trgm
  ON public.profiles USING gin (
    (lower(last_name)) extensions.gin_trgm_ops
  );
CREATE INDEX IF NOT EXISTS idx_users_admin_email_trgm
  ON public.users USING gin (
    (lower(email)) extensions.gin_trgm_ops
  );

-- The legacy selfie bucket is no longer a member-accessible storage surface.
-- Passive liveness runs on device and authoritative identity evidence uses the
-- reserved KYC workflow. Queue any legacy objects for durable removal.
DROP POLICY IF EXISTS "Allow authenticated uploads" ON storage.objects;
DROP POLICY IF EXISTS "Allow user read" ON storage.objects;
INSERT INTO private.storage_deletion_jobs(
  bucket_id, storage_path, reason
)
SELECT 'selfie-verifications', object.name, 'legacy_selfie_retention'
FROM storage.objects object
WHERE object.bucket_id = 'selfie-verifications'
ON CONFLICT (bucket_id, storage_path) DO NOTHING;
