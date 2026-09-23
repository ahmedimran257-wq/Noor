-- Backend-first rollout. Keep installed 2.4.0 clients working; never relabel
-- their evidence as 2.5.0. Retire 2.4.0 only in a later, explicit migration
-- after an app upgrade gate and all 30-minute transactions have drained.
-- Migration 263 owns request retention/holds. This migration performs no
-- consent backfill and does not treat a reminder acknowledgement as consent.

CREATE OR REPLACE FUNCTION public.begin_signup_consent_transaction(
  p_policy_version text, p_acceptances jsonb
)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_id uuid; v_version text := trim(coalesce(p_policy_version, ''));
BEGIN
  PERFORM private.enforce_pre_auth_rate_limit('signup_consent', 20, 900);
  IF v_version NOT IN ('2.4.0', '2.5.0') THEN
    RAISE EXCEPTION 'invalid_consent_transaction' USING ERRCODE = 'P0001';
  END IF;
  -- Exact JSON boolean equality rejects missing keys, JSON null, strings,
  -- extra keys and SQL NULL. <> alone is not safe with SQL three-valued logic.
  IF p_acceptances IS DISTINCT FROM '{"terms_of_service":true,"privacy_policy":true,"community_guidelines":true,"age_verification":true,"special_category_religious":true}'::jsonb THEN
    RAISE EXCEPTION 'required_consent_missing' USING ERRCODE = 'P0001';
  END IF;
  INSERT INTO private.signup_consent_transactions(policy_version, acceptances)
  VALUES (v_version, p_acceptances) RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.finalize_signup_consents(p_transaction_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_user_id uuid := private.assert_authenticated();
  v_email text; v_verified timestamptz;
  v_tx private.signup_consent_transactions%ROWTYPE;
  v_digest text;
BEGIN
  SELECT lower(trim(email)), email_confirmed_at INTO v_email, v_verified
  FROM auth.users WHERE id = v_user_id;
  IF v_verified IS NULL OR nullif(v_email, '') IS NULL THEN
    RAISE EXCEPTION 'verified_signup_identity_required' USING ERRCODE = 'P0001';
  END IF;
  SELECT * INTO v_tx FROM private.signup_consent_transactions
  WHERE id = p_transaction_id FOR UPDATE;
  IF NOT FOUND OR v_tx.policy_version NOT IN ('2.4.0', '2.5.0')
    OR v_tx.bound_email_hash IS DISTINCT FROM encode(
      extensions.digest(convert_to(v_email, 'UTF8'), 'sha256'), 'hex') THEN
    RAISE EXCEPTION 'signup_consent_transaction_unavailable' USING ERRCODE = 'P0001';
  END IF;
  -- Validate even pre-rollout transactions: the previous intake accepted
  -- incomplete objects when a missing key made its comparison SQL NULL.
  IF v_tx.acceptances IS DISTINCT FROM '{"terms_of_service":true,"privacy_policy":true,"community_guidelines":true,"age_verification":true,"special_category_religious":true}'::jsonb THEN
    RAISE EXCEPTION 'required_consent_missing' USING ERRCODE = 'P0001';
  END IF;
  IF v_tx.consumed_at IS NOT NULL THEN
    IF v_tx.consumed_by = v_user_id THEN RETURN; END IF;
    RAISE EXCEPTION 'signup_consent_transaction_unavailable' USING ERRCODE = 'P0001';
  END IF;
  IF v_tx.expires_at <= now() THEN
    RAISE EXCEPTION 'signup_consent_transaction_unavailable' USING ERRCODE = 'P0001';
  END IF;
  -- This preserves the established version-identifier digest convention;
  -- it is NOT a hash of the notice text or evidence of consent to a new version.
  v_digest := encode(extensions.digest(convert_to(
    'silarah-launch-policy:' || v_tx.policy_version || ':terms|privacy|community|age|religious',
    'UTF8'), 'sha256'), 'hex');
  INSERT INTO public.user_consents(user_id, consent_type, version, granted_at,
    revoked_at, evidence_source, policy_digest)
  SELECT v_user_id, required.consent_type, v_tx.policy_version, v_tx.accepted_at,
    NULL, 'verified_signup_transaction:' || v_tx.id::text, v_digest
  FROM (VALUES ('terms_of_service'), ('privacy_policy'), ('community_guidelines'),
    ('age_verification'), ('special_category_religious')) AS required(consent_type)
  -- Retries must not overwrite original evidence or undo a later withdrawal.
  ON CONFLICT (user_id, consent_type, version) DO NOTHING;

  INSERT INTO private.policy_reminder_acknowledgements AS existing
    (user_id, policy_version, acknowledged_at, updated_at)
  VALUES (v_user_id, v_tx.policy_version, v_tx.accepted_at, now())
  ON CONFLICT (user_id) DO UPDATE SET policy_version = EXCLUDED.policy_version,
    acknowledged_at = EXCLUDED.acknowledged_at, updated_at = EXCLUDED.updated_at
  WHERE (existing.policy_version = EXCLUDED.policy_version
      AND existing.acknowledged_at < EXCLUDED.acknowledged_at)
    OR (existing.policy_version <> '2.5.0' AND EXCLUDED.policy_version = '2.5.0');
  UPDATE private.signup_consent_transactions
  SET consumed_by = v_user_id, consumed_at = now() WHERE id = v_tx.id;
END;
$$;

-- Preserve the complete existing provisioning/write boundary, replacing only
-- its consent predicate. A bundle must have all five consents at ONE version;
-- accepting a mixture of versions would manufacture a complete agreement.
DO $migration$
DECLARE v_original text; v_updated text;
BEGIN
  SELECT replace(pg_get_functiondef('public.sync_my_user(text,text)'::regprocedure), E'\r\n', E'\n') INTO v_original;
  v_updated := replace(v_original,
    'SELECT count(DISTINCT consent.consent_type)',
    'SELECT coalesce(max(bundle.consent_count), 0) FROM (SELECT count(DISTINCT consent.consent_type) AS consent_count');
  v_updated := replace(v_updated, E'    INTO v_required_consents\n', '');
  v_updated := replace(v_updated, 'consent.version = ''2.4.0''', 'consent.version IN (''2.4.0'', ''2.5.0'')');
  v_updated := replace(v_updated, E'      );\n    IF v_required_consents <> 5 THEN',
    E'      )\n    GROUP BY consent.version) bundle INTO v_required_consents;\n    IF v_required_consents <> 5 THEN');
  IF v_updated = v_original OR position('GROUP BY consent.version) bundle INTO v_required_consents;' IN v_updated) = 0
    OR position('consent.version IN (''2.4.0'', ''2.5.0'')' IN v_updated) = 0 THEN
    RAISE EXCEPTION 'policy_250_provisioning_anchor_missing';
  END IF;
  EXECUTE v_updated;
END;
$migration$;

CREATE OR REPLACE FUNCTION public.get_my_policy_reminder_state()
RETURNS TABLE(policy_version text, acknowledged_at timestamptz,
  next_reminder_at timestamptz, reminder_due boolean)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT '2.5.0'::text, reminder.acknowledged_at,
    reminder.acknowledged_at + interval '3 months',
    (reminder.user_id IS NULL OR reminder.policy_version <> '2.5.0'
      OR reminder.acknowledged_at <= now() - interval '3 months')::boolean
  FROM (SELECT private.assert_authenticated() AS user_id) me
  LEFT JOIN private.policy_reminder_acknowledgements reminder ON reminder.user_id = me.user_id;
$$;

CREATE OR REPLACE FUNCTION public.acknowledge_policy_reminder(p_policy_version text)
RETURNS timestamptz LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_user_id uuid := private.assert_authenticated();
  v_version text := trim(coalesce(p_policy_version, '')); v_now timestamptz := now();
BEGIN
  -- Old clients display bundled 2.4.0 and send 2.4.0. Let their blocking sheet
  -- close, but leave 2.5.0 due and never fabricate consent or downgrade a newer
  -- acknowledgement. The old client caches this reminder for its normal interval.
  IF v_version NOT IN ('2.4.0', '2.5.0') THEN
    RAISE EXCEPTION 'policy_version_mismatch' USING ERRCODE = '22023';
  END IF;
  INSERT INTO private.policy_reminder_acknowledgements AS existing
    (user_id, policy_version, acknowledged_at, updated_at)
  VALUES (v_user_id, v_version, v_now, v_now)
  ON CONFLICT (user_id) DO UPDATE SET policy_version = EXCLUDED.policy_version,
    acknowledged_at = EXCLUDED.acknowledged_at, updated_at = EXCLUDED.updated_at
  WHERE existing.policy_version <> '2.5.0' OR EXCLUDED.policy_version = '2.5.0';
  RETURN v_now;
END;
$$;

CREATE OR REPLACE FUNCTION public.download_my_data(p_client_version text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  -- Current notice metadata is not a claim about the member's consent version.
  -- The nested consent records remain unchanged in the authenticated export.
  RETURN jsonb_set(private.build_personal_data_export(p_client_version),
    '{policy_version}', to_jsonb('2.5.0'::text), true);
END;
$$;

REVOKE ALL ON FUNCTION public.begin_signup_consent_transaction(text,jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.begin_signup_consent_transaction(text,jsonb) TO anon, authenticated;
REVOKE ALL ON FUNCTION public.finalize_signup_consents(uuid), public.get_my_policy_reminder_state(),
  public.acknowledge_policy_reminder(text), public.download_my_data(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.finalize_signup_consents(uuid), public.get_my_policy_reminder_state(),
  public.acknowledge_policy_reminder(text), public.download_my_data(text) TO authenticated;
COMMENT ON FUNCTION public.begin_signup_consent_transaction(text,jsonb) IS
  'Rate-limited explicit consent intake: 2.4.0 compatibility and current 2.5.0; actual displayed version is preserved.';
NOTIFY pgrst, 'reload schema';
