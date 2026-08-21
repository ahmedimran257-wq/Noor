-- Repair two runtime-only issues found by plpgsql_check after deployment:
-- use Supabase's built-in request role in phone completion and avoid writing a
-- users.updated_at column that is not part of this project's users contract.

CREATE OR REPLACE FUNCTION public.complete_paid_phone_verification(
  p_user_id uuid,
  p_country_code text,
  p_phone text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_country_code text := upper(trim(coalesce(p_country_code, '')));
  v_phone text := regexp_replace(coalesce(p_phone, ''), '[^0-9+]', '', 'g');
  v_consumed_user_id uuid;
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'service_role_required' USING ERRCODE = '42501';
  END IF;
  IF v_country_code <> 'IN' OR v_phone !~ '^\+91[6-9][0-9]{9}$' THEN
    RAISE EXCEPTION 'india_mobile_required' USING ERRCODE = '22023';
  END IF;

  DELETE FROM private.phone_verification_intents i
  WHERE i.user_id = p_user_id
    AND i.country_code = v_country_code
    AND i.expires_at > now()
  RETURNING i.user_id INTO v_consumed_user_id;

  IF v_consumed_user_id IS NULL THEN
    RAISE EXCEPTION 'phone_verification_intent_required'
      USING ERRCODE = 'P0001';
  END IF;

  UPDATE public.users
  SET phone = v_phone,
      phone_country_code = v_country_code,
      phone_verified_at = now()
  WHERE id = p_user_id
    AND deleted_at IS NULL;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'completed_account_required' USING ERRCODE = 'P0001';
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.complete_paid_phone_verification(
  uuid, text, text
) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.complete_paid_phone_verification(
  uuid, text, text
) TO service_role;

CREATE OR REPLACE FUNCTION public.accept_my_guardian_invitation(p_code text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_guardian_id uuid := private.assert_authenticated();
  v_profile public.profiles%ROWTYPE;
  v_phone text;
  v_verified_at timestamptz;
  v_secret text;
  v_stored_phone text;
  v_role text;
  v_hash text := private.guardian_invitation_hash(coalesce(p_code, ''));
BEGIN
  SELECT regexp_replace(coalesce(phone, ''), '[^0-9+]', '', 'g'),
         phone_verified_at
  INTO v_phone, v_verified_at
  FROM public.users
  WHERE id = v_guardian_id
  FOR UPDATE;

  IF v_verified_at IS NULL OR v_phone !~ '^\+91[6-9][0-9]{9}$' THEN
    RAISE EXCEPTION 'verified_guardian_phone_required'
      USING ERRCODE = 'P0001';
  END IF;

  SELECT * INTO v_profile
  FROM public.profiles
  WHERE guardian_invitation_token_hash = v_hash
  FOR UPDATE;

  IF NOT FOUND
    OR v_profile.user_id = v_guardian_id
    OR v_profile.guardian_mode NOT IN ('passive', 'active')
    OR v_profile.guardian_phone_encrypted IS NULL
    OR v_profile.guardian_user_id IS NOT NULL
    OR v_profile.guardian_invitation_consumed_at IS NOT NULL
    OR v_profile.guardian_invitation_expires_at <= now()
    OR v_profile.guardian_invitation_locked_until > now() THEN
    RAISE EXCEPTION 'guardian_invitation_unavailable'
      USING ERRCODE = 'P0001';
  END IF;

  SELECT decrypted_secret INTO v_secret
  FROM vault.decrypted_secrets
  WHERE name = 'guardian_key_v1';
  IF v_secret IS NULL THEN
    RAISE EXCEPTION 'guardian_phone_encryption_unavailable'
      USING ERRCODE = 'P0001';
  END IF;

  v_stored_phone := regexp_replace(
    extensions.pgp_sym_decrypt(
      v_profile.guardian_phone_encrypted,
      v_secret
    ),
    '[^0-9+]',
    '',
    'g'
  );
  IF v_stored_phone ~ '^[6-9][0-9]{9}$' THEN
    v_stored_phone := '+91' || v_stored_phone;
  ELSIF v_stored_phone ~ '^91[6-9][0-9]{9}$' THEN
    v_stored_phone := '+' || v_stored_phone;
  END IF;
  IF v_stored_phone IS DISTINCT FROM v_phone THEN
    RAISE EXCEPTION 'guardian_invitation_unavailable'
      USING ERRCODE = 'P0001';
  END IF;

  UPDATE public.profiles
  SET guardian_user_id = v_guardian_id,
      guardian_invitation_consumed_at = now(),
      guardian_invitation_token_hash = NULL,
      guardian_invitation_attempts = 0,
      guardian_invitation_locked_until = NULL
  WHERE id = v_profile.id
    AND guardian_user_id IS NULL;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'guardian_invitation_unavailable'
      USING ERRCODE = 'P0001';
  END IF;

  v_role := CASE
    WHEN EXISTS (
      SELECT 1 FROM public.profiles own_profile
      WHERE own_profile.user_id = v_guardian_id
        AND own_profile.onboarding_completed
    ) THEN 'member_guardian'
    ELSE 'guardian'
  END;

  UPDATE public.users
  SET account_role = v_role,
      onboarding_completed = CASE
        WHEN v_role = 'guardian' THEN true
        ELSE onboarding_completed
      END
  WHERE id = v_guardian_id;

  INSERT INTO public.guardian_chat_mirrors(
    match_id, guardian_id, ward_id, mode
  )
  SELECT m.id, v_guardian_id, v_profile.user_id, v_profile.guardian_mode
  FROM public.matches m
  WHERE v_profile.user_id IN (m.user_a, m.user_b)
    AND m.status = 'active'
  ON CONFLICT (match_id, guardian_id) DO UPDATE
  SET ward_id = EXCLUDED.ward_id,
      mode = EXCLUDED.mode;

  INSERT INTO public.admin_audit_log(
    admin_id, action_type, target_user_id, details
  )
  VALUES (
    v_guardian_id,
    'guardian_activated',
    v_profile.user_id,
    jsonb_build_object(
      'ward_profile_id', v_profile.id,
      'guardian_mode', v_profile.guardian_mode,
      'verified_phone_ownership', true,
      'invitation_code_consumed', true
    )
  );

  RETURN jsonb_build_object(
    'status', 'activated',
    'ward_user_id', v_profile.user_id,
    'mode', v_profile.guardian_mode,
    'account_role', v_role
  );
END;
$$;

REVOKE ALL ON FUNCTION public.accept_my_guardian_invitation(text)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.accept_my_guardian_invitation(text)
  TO authenticated;

NOTIFY pgrst, 'reload schema';
