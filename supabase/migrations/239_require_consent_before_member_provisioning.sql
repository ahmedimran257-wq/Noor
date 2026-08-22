-- Prevent a custom/malicious client from provisioning a first-time member row
-- before the current signup consent bundle has been finalized.

CREATE OR REPLACE FUNCTION public.sync_my_user(
  p_country_code text DEFAULT NULL,
  p_gender text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid := private.assert_authenticated();
  v_auth auth.users%ROWTYPE;
  v_row public.users%ROWTYPE;
  v_gender text := lower(nullif(trim(p_gender), ''));
  v_country text := upper(nullif(trim(p_country_code), ''));
  v_required_consents integer;
BEGIN
  IF v_gender IS NOT NULL AND v_gender NOT IN ('male', 'female') THEN
    RAISE EXCEPTION 'invalid_gender' USING ERRCODE = 'P0001';
  END IF;

  SELECT * INTO v_auth FROM auth.users WHERE id = v_user_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'authentication_required' USING ERRCODE = 'P0001';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.users u WHERE u.id = v_user_id) THEN
    SELECT count(DISTINCT consent.consent_type)
    INTO v_required_consents
    FROM public.user_consents consent
    WHERE consent.user_id = v_user_id
      AND consent.version = '2.3.0'
      AND consent.revoked_at IS NULL
      AND consent.consent_type IN (
        'terms_of_service',
        'privacy_policy',
        'community_guidelines',
        'age_verification',
        'special_category_religious'
      );
    IF v_required_consents <> 5 THEN
      RAISE EXCEPTION 'required_signup_consents_missing'
        USING ERRCODE = 'P0001';
    END IF;
  END IF;

  INSERT INTO public.users (id, email, phone, country_code, gender)
  VALUES (
    v_user_id,
    v_auth.email,
    nullif(v_auth.phone, ''),
    v_country,
    v_gender
  )
  ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    phone = coalesce(nullif(EXCLUDED.phone, ''), public.users.phone),
    country_code = coalesce(EXCLUDED.country_code, public.users.country_code),
    gender = CASE
      WHEN public.users.onboarding_completed IS TRUE
        AND public.users.gender IS DISTINCT FROM EXCLUDED.gender
        AND EXCLUDED.gender IS NOT NULL
        THEN public.users.gender
      ELSE coalesce(EXCLUDED.gender, public.users.gender)
    END
  RETURNING * INTO v_row;

  RETURN to_jsonb(v_row)
    - ARRAY[
      'last_billing_event_ts', 'ban_reason', 'moderation_reason',
      'shadow_banned_at', 'moderated_by'
    ];
END;
$$;

REVOKE ALL ON FUNCTION public.sync_my_user(text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.sync_my_user(text, text) TO authenticated;

CREATE OR REPLACE FUNCTION public.finalize_signup_and_provision_my_user(
  p_transaction_id uuid,
  p_country_code text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid := private.assert_authenticated();
  v_auth auth.users%ROWTYPE;
  v_row public.users%ROWTYPE;
  v_country text := upper(nullif(trim(p_country_code), ''));
BEGIN
  SELECT * INTO v_auth FROM auth.users WHERE id = v_user_id;
  IF NOT FOUND OR v_auth.email_confirmed_at IS NULL THEN
    RAISE EXCEPTION 'verified_signup_identity_required'
      USING ERRCODE = 'P0001';
  END IF;

  -- The FK requires the member row before consent evidence can be inserted.
  -- Both operations share this transaction: any invalid/expired consent rolls
  -- the provisional member row back completely.
  INSERT INTO public.users (id, email, phone, country_code)
  VALUES (v_user_id, v_auth.email, nullif(v_auth.phone, ''), v_country)
  ON CONFLICT (id) DO NOTHING;

  PERFORM public.finalize_signup_consents(p_transaction_id);

  SELECT * INTO v_row FROM public.users WHERE id = v_user_id;
  RETURN to_jsonb(v_row)
    - ARRAY[
      'last_billing_event_ts', 'ban_reason', 'moderation_reason',
      'shadow_banned_at', 'moderated_by'
    ];
END;
$$;

REVOKE ALL ON FUNCTION public.finalize_signup_and_provision_my_user(uuid, text)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.finalize_signup_and_provision_my_user(uuid, text)
  TO authenticated;

NOTIFY pgrst, 'reload schema';
