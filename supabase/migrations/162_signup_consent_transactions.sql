-- Second audit: bind pre-auth legal choices to one expiring signup transaction
-- and the verified email account that ultimately consumes it.

CREATE TABLE private.signup_consent_transactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  policy_version text NOT NULL,
  acceptances jsonb NOT NULL,
  accepted_at timestamptz NOT NULL DEFAULT now(),
  bound_email_hash text,
  bound_at timestamptz,
  expires_at timestamptz NOT NULL DEFAULT (now() + interval '30 minutes'),
  consumed_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  consumed_at timestamptz,
  CHECK (jsonb_typeof(acceptances) = 'object')
);
CREATE INDEX idx_signup_consent_expiry
  ON private.signup_consent_transactions(expires_at)
  WHERE consumed_at IS NULL;
REVOKE ALL ON private.signup_consent_transactions
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
  IF trim(coalesce(p_policy_version, '')) <> '2.0.0'
    OR jsonb_typeof(p_acceptances) <> 'object'
    OR (SELECT count(*) FROM jsonb_object_keys(p_acceptances)) <> 5 THEN
    RAISE EXCEPTION 'invalid_consent_transaction' USING ERRCODE = 'P0001';
  END IF;
  FOREACH v_key IN ARRAY v_required LOOP
    IF p_acceptances ->> v_key <> 'true' THEN
      RAISE EXCEPTION 'required_consent_missing' USING ERRCODE = 'P0001';
    END IF;
  END LOOP;

  INSERT INTO private.signup_consent_transactions(
    policy_version, acceptances
  )
  VALUES ('2.0.0', p_acceptances)
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;
REVOKE ALL ON FUNCTION public.begin_signup_consent_transaction(text, jsonb)
  FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.begin_signup_consent_transaction(text, jsonb)
  TO anon, authenticated;

CREATE OR REPLACE FUNCTION public.bind_signup_consent_transaction(
  p_transaction_id uuid,
  p_email text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_hash text := encode(
    extensions.digest(
      convert_to(lower(trim(coalesce(p_email, ''))), 'UTF8'),
      'sha256'
    ),
    'hex'
  );
BEGIN
  IF lower(trim(coalesce(p_email, '')))
      !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' THEN
    RETURN false;
  END IF;

  UPDATE private.signup_consent_transactions
  SET bound_email_hash = v_hash,
      bound_at = now()
  WHERE id = p_transaction_id
    AND consumed_at IS NULL
    AND expires_at > now()
    AND (
      bound_email_hash IS NULL
      OR bound_email_hash = v_hash
    );
  RETURN FOUND;
END;
$$;
REVOKE ALL ON FUNCTION public.bind_signup_consent_transaction(uuid, text)
  FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.bind_signup_consent_transaction(uuid, text)
  TO anon, authenticated;

CREATE OR REPLACE FUNCTION public.finalize_signup_consents(
  p_transaction_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid := private.assert_authenticated();
  v_email text;
  v_email_confirmed_at timestamptz;
  v_tx private.signup_consent_transactions%ROWTYPE;
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
  SELECT lower(trim(email)), email_confirmed_at
  INTO v_email, v_email_confirmed_at
  FROM auth.users
  WHERE id = v_user_id;
  IF v_email_confirmed_at IS NULL OR nullif(v_email, '') IS NULL THEN
    RAISE EXCEPTION 'verified_signup_identity_required'
      USING ERRCODE = 'P0001';
  END IF;

  SELECT * INTO v_tx
  FROM private.signup_consent_transactions
  WHERE id = p_transaction_id
  FOR UPDATE;
  IF NOT FOUND
    OR v_tx.consumed_at IS NOT NULL
    OR v_tx.expires_at <= now()
    OR v_tx.policy_version <> '2.0.0'
    OR v_tx.bound_email_hash IS DISTINCT FROM encode(
      extensions.digest(convert_to(v_email, 'UTF8'), 'sha256'),
      'hex'
    ) THEN
    RAISE EXCEPTION 'signup_consent_transaction_unavailable'
      USING ERRCODE = 'P0001';
  END IF;

  INSERT INTO public.user_consents(
    user_id, consent_type, version, granted_at, revoked_at,
    evidence_source, policy_digest
  )
  SELECT
    v_user_id,
    required.consent_type,
    '2.0.0',
    v_tx.accepted_at,
    NULL,
    'verified_signup_transaction:' || v_tx.id::text,
    v_digest
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
      granted_at = EXCLUDED.granted_at,
      evidence_source = EXCLUDED.evidence_source,
      policy_digest = EXCLUDED.policy_digest;

  UPDATE private.signup_consent_transactions
  SET consumed_by = v_user_id,
      consumed_at = now()
  WHERE id = v_tx.id;
END;
$$;
REVOKE ALL ON FUNCTION public.finalize_signup_consents(uuid)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.finalize_signup_consents(uuid)
  TO authenticated;

-- The legacy authenticated-only bundle writer had no proof that a legal-gate
-- action belonged to the current signup. Keep it unavailable to API roles.
REVOKE ALL ON FUNCTION public.record_onboarding_consents(text)
  FROM PUBLIC, anon, authenticated;
