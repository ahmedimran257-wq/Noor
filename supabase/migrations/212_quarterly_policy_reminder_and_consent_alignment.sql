-- Keep the verified signup transaction aligned with the 2.2.0 policy bundle
-- and provide a cheap, server-authoritative quarterly rules reminder.

CREATE TABLE IF NOT EXISTS private.policy_reminder_acknowledgements (
  user_id uuid PRIMARY KEY
    REFERENCES public.users(id) ON DELETE CASCADE,
  policy_version text NOT NULL,
  acknowledged_at timestamptz NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now()
);
REVOKE ALL ON private.policy_reminder_acknowledgements
  FROM PUBLIC, anon, authenticated;

-- Existing members start a fresh 90-day interval at deployment instead of
-- receiving an unexpected blocking prompt immediately after an app update.
INSERT INTO private.policy_reminder_acknowledgements(
  user_id, policy_version, acknowledged_at, updated_at
)
SELECT id, '2.2.0', now(), now()
FROM public.users
ON CONFLICT (user_id) DO NOTHING;

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
        'silarah-launch-policy:2.2.0:terms|privacy|community|age|religious',
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
    OR v_tx.policy_version <> '2.2.0'
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
    '2.2.0',
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

  INSERT INTO private.policy_reminder_acknowledgements(
    user_id, policy_version, acknowledged_at, updated_at
  ) VALUES (
    v_user_id, '2.2.0', v_tx.accepted_at, now()
  )
  ON CONFLICT (user_id) DO UPDATE
  SET policy_version = EXCLUDED.policy_version,
      acknowledged_at = EXCLUDED.acknowledged_at,
      updated_at = now();

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

CREATE OR REPLACE FUNCTION public.get_my_policy_reminder_state()
RETURNS TABLE(
  policy_version text,
  acknowledged_at timestamptz,
  next_reminder_at timestamptz,
  reminder_due boolean
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT
    '2.2.0'::text,
    reminder.acknowledged_at,
    reminder.acknowledged_at + interval '3 months',
    (
      reminder.user_id IS NULL
      OR reminder.policy_version <> '2.2.0'
      OR reminder.acknowledged_at <= now() - interval '3 months'
    )::boolean
  FROM (SELECT private.assert_authenticated() AS user_id) me
  LEFT JOIN private.policy_reminder_acknowledgements reminder
    ON reminder.user_id = me.user_id;
$$;
REVOKE ALL ON FUNCTION public.get_my_policy_reminder_state()
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_policy_reminder_state()
  TO authenticated;

CREATE OR REPLACE FUNCTION public.acknowledge_policy_reminder(
  p_policy_version text
)
RETURNS timestamptz
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid := private.assert_authenticated();
  v_now timestamptz := now();
BEGIN
  IF trim(coalesce(p_policy_version, '')) <> '2.2.0' THEN
    RAISE EXCEPTION 'policy_version_mismatch' USING ERRCODE = '22023';
  END IF;

  INSERT INTO private.policy_reminder_acknowledgements(
    user_id, policy_version, acknowledged_at, updated_at
  ) VALUES (
    v_user_id, '2.2.0', v_now, v_now
  )
  ON CONFLICT (user_id) DO UPDATE
  SET policy_version = EXCLUDED.policy_version,
      acknowledged_at = EXCLUDED.acknowledged_at,
      updated_at = EXCLUDED.updated_at;

  RETURN v_now;
END;
$$;
REVOKE ALL ON FUNCTION public.acknowledge_policy_reminder(text)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.acknowledge_policy_reminder(text)
  TO authenticated;

COMMENT ON TABLE private.policy_reminder_acknowledgements IS
  'Minimal quarterly intermediary-rules reminder evidence. No push delivery or per-session reads are required.';
