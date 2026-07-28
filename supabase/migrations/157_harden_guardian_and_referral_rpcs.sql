-- Repair legacy RPCs surfaced by linked-schema lint and close their default
-- PUBLIC execution grants.

CREATE OR REPLACE FUNCTION public.set_guardian_phone(
  p_profile_id uuid,
  p_phone text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid := private.assert_authenticated();
  v_secret text;
  v_phone text := regexp_replace(coalesce(p_phone, ''), '[^0-9+]', '', 'g');
BEGIN
  IF char_length(v_phone) < 8 OR char_length(v_phone) > 18 THEN
    RAISE EXCEPTION 'invalid_guardian_phone' USING ERRCODE = 'P0001';
  END IF;

  SELECT decrypted_secret INTO v_secret
  FROM vault.decrypted_secrets
  WHERE name = 'guardian_key_v1';
  IF v_secret IS NULL THEN
    RAISE EXCEPTION 'guardian_phone_encryption_unavailable'
      USING ERRCODE = 'P0001';
  END IF;

  UPDATE public.profiles
  SET guardian_phone_encrypted = extensions.pgp_sym_encrypt(v_phone, v_secret),
      guardian_key_version = 'v1'
  WHERE id = p_profile_id
    AND user_id = v_user_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'profile_not_found' USING ERRCODE = 'P0001';
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.activate_guardian(
  p_ward_profile_id uuid,
  p_guardian_phone text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_guardian_id uuid := private.assert_authenticated();
  v_stored_phone text;
  v_supplied_phone text := regexp_replace(
    coalesce(p_guardian_phone, ''),
    '[^0-9+]',
    '',
    'g'
  );
  v_vault_key text;
  v_ward_user_id uuid;
  v_guardian_mode text;
  v_existing_guardian uuid;
  v_match record;
BEGIN
  IF char_length(v_supplied_phone) < 8
    OR char_length(v_supplied_phone) > 18 THEN
    RAISE EXCEPTION 'invalid_guardian_phone' USING ERRCODE = 'P0001';
  END IF;

  SELECT decrypted_secret INTO v_vault_key
  FROM vault.decrypted_secrets
  WHERE name = 'guardian_key_v1';
  IF v_vault_key IS NULL THEN
    RAISE EXCEPTION 'guardian_phone_encryption_unavailable'
      USING ERRCODE = 'P0001';
  END IF;

  SELECT
    extensions.pgp_sym_decrypt(
      p.guardian_phone_encrypted,
      v_vault_key
    ),
    p.user_id,
    p.guardian_mode,
    p.guardian_user_id
  INTO
    v_stored_phone,
    v_ward_user_id,
    v_guardian_mode,
    v_existing_guardian
  FROM public.profiles p
  WHERE p.id = p_ward_profile_id
    AND p.guardian_mode IN ('passive', 'active')
    AND p.guardian_phone_encrypted IS NOT NULL
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'guardian_invitation_unavailable'
      USING ERRCODE = 'P0001';
  END IF;
  IF v_stored_phone IS DISTINCT FROM v_supplied_phone THEN
    RAISE EXCEPTION 'guardian_invitation_mismatch'
      USING ERRCODE = 'P0001';
  END IF;
  IF v_guardian_id = v_ward_user_id THEN
    RAISE EXCEPTION 'guardian_self_link_forbidden'
      USING ERRCODE = 'P0001';
  END IF;
  IF v_existing_guardian IS NOT NULL
    AND v_existing_guardian <> v_guardian_id THEN
    RAISE EXCEPTION 'guardian_already_linked'
      USING ERRCODE = 'P0001';
  END IF;

  UPDATE public.profiles
  SET guardian_user_id = v_guardian_id
  WHERE id = p_ward_profile_id
    AND (
      guardian_user_id IS NULL
      OR guardian_user_id = v_guardian_id
    );

  FOR v_match IN
    SELECT m.id AS match_id
    FROM public.matches m
    WHERE (
      m.user_a = v_ward_user_id
      OR m.user_b = v_ward_user_id
    )
      AND m.status = 'active'
  LOOP
    INSERT INTO public.guardian_chat_mirrors(
      match_id,
      guardian_id,
      ward_id,
      mode
    )
    VALUES (
      v_match.match_id,
      v_guardian_id,
      v_ward_user_id,
      v_guardian_mode
    )
    ON CONFLICT (match_id, guardian_id) DO NOTHING;
  END LOOP;

  RETURN jsonb_build_object(
    'status', 'activated',
    'ward_user_id', v_ward_user_id,
    'mode', v_guardian_mode
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.generate_referral_code()
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid := private.assert_authenticated();
  v_code text;
  v_attempt integer;
BEGIN
  SELECT code INTO v_code
  FROM public.referral_codes
  WHERE owner_id = v_user_id;
  IF v_code IS NOT NULL THEN
    RETURN v_code;
  END IF;

  FOR v_attempt IN 1..32 LOOP
    v_code := upper(
      substr(
        md5(gen_random_uuid()::text || clock_timestamp()::text),
        1,
        6
      )
    );
    INSERT INTO public.referral_codes(code, owner_id)
    VALUES (v_code, v_user_id)
    ON CONFLICT DO NOTHING;

    SELECT code INTO v_code
    FROM public.referral_codes
    WHERE owner_id = v_user_id;
    IF v_code IS NOT NULL THEN
      RETURN v_code;
    END IF;
  END LOOP;

  RAISE EXCEPTION 'referral_code_generation_failed' USING ERRCODE = 'P0001';
END;
$$;

REVOKE ALL ON FUNCTION public.set_guardian_phone(uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.activate_guardian(uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.generate_referral_code() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.set_guardian_phone(
  uuid, text
) TO authenticated;
GRANT EXECUTE ON FUNCTION public.activate_guardian(
  uuid, text
) TO authenticated;
GRANT EXECUTE ON FUNCTION public.generate_referral_code() TO authenticated;
