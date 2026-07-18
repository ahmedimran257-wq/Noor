-- DigiLocker authorization is not identity verification. A strong KYC state is
-- granted only after both provider account data and HMAC-authenticated issued
-- document XML match the Silarah profile name and exact date of birth.

CREATE TABLE IF NOT EXISTS public.identity_verification_evidence (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  provider text NOT NULL DEFAULT 'digilocker'
    CHECK (provider = 'digilocker'),
  decision text NOT NULL
    CHECK (decision IN (
      'verified',
      'identity_mismatch',
      'insufficient_evidence',
      'provider_error'
    )),
  failure_code text,
  provider_subject_hmac text,
  provider_reference_hmac text,
  profile_snapshot_hmac text NOT NULL,
  document_uri_hmac text,
  document_payload_sha256 text,
  document_type text,
  issuer_id text,
  issuer_name text,
  document_source text
    CHECK (document_source IS NULL OR document_source IN ('eaadhaar', 'issued_document')),
  provider_profile_fetched boolean NOT NULL DEFAULT false,
  issued_document_fetched boolean NOT NULL DEFAULT false,
  document_integrity_verified boolean NOT NULL DEFAULT false,
  account_name_match boolean NOT NULL DEFAULT false,
  account_dob_match boolean NOT NULL DEFAULT false,
  document_name_match boolean NOT NULL DEFAULT false,
  document_dob_match boolean NOT NULL DEFAULT false,
  consent_valid_until timestamptz,
  provider_metadata jsonb NOT NULL DEFAULT '{}'::jsonb
    CHECK (jsonb_typeof(provider_metadata) = 'object'),
  created_at timestamptz NOT NULL DEFAULT now(),
  verified_at timestamptz,
  CHECK (
    decision <> 'verified' OR (
      provider_subject_hmac IS NOT NULL AND
      document_uri_hmac IS NOT NULL AND
      document_payload_sha256 IS NOT NULL AND
      provider_profile_fetched AND
      issued_document_fetched AND
      document_integrity_verified AND
      account_name_match AND
      account_dob_match AND
      document_name_match AND
      document_dob_match AND
      verified_at IS NOT NULL
    )
  )
);

COMMENT ON TABLE public.identity_verification_evidence IS
  'Service-role-only, data-minimized evidence for DigiLocker identity decisions. Raw OAuth tokens, Aadhaar numbers, names, dates of birth and document XML are never retained.';
COMMENT ON COLUMN public.identity_verification_evidence.provider_subject_hmac IS
  'Keyed, context-separated HMAC of the DigiLocker account id; not a raw provider identifier.';
COMMENT ON COLUMN public.identity_verification_evidence.document_payload_sha256 IS
  'Integrity/audit digest of the HMAC-authenticated XML payload; the payload itself is not retained.';

CREATE INDEX IF NOT EXISTS idx_identity_verification_evidence_user_created
  ON public.identity_verification_evidence (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_identity_verification_evidence_verified
  ON public.identity_verification_evidence (user_id, verified_at DESC)
  WHERE decision = 'verified';

ALTER TABLE public.identity_verification_evidence ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.identity_verification_evidence FROM PUBLIC, anon, authenticated;

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS kyc_assurance_level text NOT NULL DEFAULT 'none'
    CHECK (kyc_assurance_level IN (
      'none',
      'authorization_only',
      'government_document_match',
      'manual_document_review'
    )),
  ADD COLUMN IF NOT EXISTS kyc_evidence_id uuid
    REFERENCES public.identity_verification_evidence(id) ON DELETE SET NULL;

COMMENT ON COLUMN public.profiles.kyc_assurance_level IS
  'Identity assurance, kept separate from the passive face/liveness badge. OAuth authorization alone is never a verified level.';
COMMENT ON COLUMN public.profiles.kyc_evidence_id IS
  'Evidence record supporting the current KYC decision. Null means no auditable DigiLocker evidence exists.';

CREATE OR REPLACE FUNCTION public.record_digilocker_verification_result(
  p_user_id uuid,
  p_decision text,
  p_failure_code text,
  p_provider_subject_hmac text,
  p_provider_reference_hmac text,
  p_profile_snapshot_hmac text,
  p_document_uri_hmac text,
  p_document_payload_sha256 text,
  p_document_type text,
  p_issuer_id text,
  p_issuer_name text,
  p_document_source text,
  p_provider_profile_fetched boolean,
  p_issued_document_fetched boolean,
  p_document_integrity_verified boolean,
  p_account_name_match boolean,
  p_account_dob_match boolean,
  p_document_name_match boolean,
  p_document_dob_match boolean,
  p_consent_valid_until timestamptz,
  p_provider_metadata jsonb
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_evidence_id uuid;
  v_previous_verified boolean := false;
BEGIN
  IF coalesce(auth.role(), '') <> 'service_role' THEN
    RAISE EXCEPTION 'Service role required.';
  END IF;
  IF p_user_id IS NULL OR p_profile_snapshot_hmac IS NULL THEN
    RAISE EXCEPTION 'Incomplete verification evidence.';
  END IF;
  IF p_decision NOT IN (
    'verified',
    'identity_mismatch',
    'insufficient_evidence',
    'provider_error'
  ) THEN
    RAISE EXCEPTION 'Invalid DigiLocker decision.';
  END IF;
  IF p_decision = 'verified' AND NOT (
    p_provider_subject_hmac IS NOT NULL AND
    p_document_uri_hmac IS NOT NULL AND
    p_document_payload_sha256 IS NOT NULL AND
    p_document_source IN ('eaadhaar', 'issued_document') AND
    p_provider_profile_fetched AND
    p_issued_document_fetched AND
    p_document_integrity_verified AND
    p_account_name_match AND
    p_account_dob_match AND
    p_document_name_match AND
    p_document_dob_match
  ) THEN
    RAISE EXCEPTION 'A verified decision requires complete matching evidence.';
  END IF;

  SELECT coalesce(kyc_verified, false)
  INTO v_previous_verified
  FROM public.profiles
  WHERE user_id = p_user_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Profile not found.';
  END IF;

  INSERT INTO public.identity_verification_evidence (
    user_id,
    decision,
    failure_code,
    provider_subject_hmac,
    provider_reference_hmac,
    profile_snapshot_hmac,
    document_uri_hmac,
    document_payload_sha256,
    document_type,
    issuer_id,
    issuer_name,
    document_source,
    provider_profile_fetched,
    issued_document_fetched,
    document_integrity_verified,
    account_name_match,
    account_dob_match,
    document_name_match,
    document_dob_match,
    consent_valid_until,
    provider_metadata,
    verified_at
  ) VALUES (
    p_user_id,
    p_decision,
    nullif(trim(coalesce(p_failure_code, '')), ''),
    nullif(trim(coalesce(p_provider_subject_hmac, '')), ''),
    nullif(trim(coalesce(p_provider_reference_hmac, '')), ''),
    p_profile_snapshot_hmac,
    nullif(trim(coalesce(p_document_uri_hmac, '')), ''),
    nullif(trim(coalesce(p_document_payload_sha256, '')), ''),
    nullif(trim(coalesce(p_document_type, '')), ''),
    nullif(trim(coalesce(p_issuer_id, '')), ''),
    nullif(trim(coalesce(p_issuer_name, '')), ''),
    p_document_source,
    p_provider_profile_fetched,
    p_issued_document_fetched,
    p_document_integrity_verified,
    p_account_name_match,
    p_account_dob_match,
    p_document_name_match,
    p_document_dob_match,
    p_consent_valid_until,
    coalesce(p_provider_metadata, '{}'::jsonb),
    CASE WHEN p_decision = 'verified' THEN now() ELSE NULL END
  )
  RETURNING id INTO v_evidence_id;

  IF p_decision = 'verified' THEN
    UPDATE public.profiles
    SET kyc_verified = true,
        kyc_method = 'digilocker_evidence_v2',
        kyc_assurance_level = 'government_document_match',
        kyc_evidence_id = v_evidence_id,
        verified_at = now(),
        verification_status = 'verified',
        is_verified = true
    WHERE user_id = p_user_id
      AND country_code = 'IN';

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Eligible Indian profile not found.';
    END IF;

    IF NOT v_previous_verified THEN
      PERFORM public.queue_notification(
        p_user_id,
        'identity_verified',
        'Identity verification complete',
        'Your DigiLocker identity and issued document match your Silarah profile.',
        'silarah://profile'
      );
    END IF;
  ELSE
    -- A failed DigiLocker attempt must not overwrite a valid verification from
    -- another provider. It does revoke legacy token-only DigiLocker decisions.
    UPDATE public.profiles
    SET kyc_verified = false,
        kyc_method = 'digilocker_evidence_v2',
        kyc_assurance_level = CASE
          WHEN p_provider_profile_fetched THEN 'authorization_only'
          ELSE 'none'
        END,
        kyc_evidence_id = v_evidence_id,
        verification_status = CASE
          WHEN coalesce(has_verification_badge, false) THEN 'verified'
          ELSE 'unverified'
        END,
        is_verified = coalesce(has_verification_badge, false),
        verified_at = CASE
          WHEN coalesce(has_verification_badge, false) THEN verified_at
          ELSE NULL
        END
    WHERE user_id = p_user_id
      AND coalesce(kyc_method, '') IN (
        '',
        'digilocker_optional',
        'digilocker_legacy_unverified',
        'digilocker_evidence_v2'
      );
  END IF;

  INSERT INTO public.admin_audit_log (
    admin_id,
    action_type,
    target_user_id,
    details
  ) VALUES (
    p_user_id,
    'digilocker_identity_decision',
    p_user_id,
    jsonb_build_object(
      'decision', p_decision,
      'failure_code', p_failure_code,
      'evidence_id', v_evidence_id,
      'document_type', p_document_type,
      'issuer_id', p_issuer_id,
      'document_integrity_verified', p_document_integrity_verified
    )
  );

  RETURN v_evidence_id;
END;
$$;

REVOKE ALL ON FUNCTION public.record_digilocker_verification_result(
  uuid, text, text, text, text, text, text, text, text, text, text, text,
  boolean, boolean, boolean, boolean, boolean, boolean, boolean, timestamptz, jsonb
) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.record_digilocker_verification_result(
  uuid, text, text, text, text, text, text, text, text, text, text, text,
  boolean, boolean, boolean, boolean, boolean, boolean, boolean, timestamptz, jsonb
) TO service_role;

-- The previous implementation granted a strong KYC state after token exchange
-- only. Revoke those unsupported decisions while preserving an independently
-- earned passive face/liveness badge.
UPDATE public.profiles
SET kyc_verified = false,
    kyc_method = 'digilocker_legacy_unverified',
    kyc_assurance_level = 'none',
    kyc_evidence_id = NULL,
    verification_status = CASE
      WHEN coalesce(has_verification_badge, false) THEN 'verified'
      ELSE 'unverified'
    END,
    is_verified = coalesce(has_verification_badge, false),
    verified_at = CASE
      WHEN coalesce(has_verification_badge, false) THEN verified_at
      ELSE NULL
    END
WHERE kyc_method = 'digilocker_optional';
