-- Complete Guardian invitation acceptance and Firebase-backed phone trust.
-- Invitation codes are short-lived, stored only as hashes, and still require
-- ownership of the exact encrypted phone configured by the ward.

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS account_role text NOT NULL DEFAULT 'member';

ALTER TABLE public.users
  DROP CONSTRAINT IF EXISTS users_account_role_check;
ALTER TABLE public.users
  ADD CONSTRAINT users_account_role_check
  CHECK (account_role IN ('member', 'guardian', 'member_guardian'));

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS guardian_invitation_token_hash text;

CREATE OR REPLACE FUNCTION private.guardian_invitation_hash(p_code text)
RETURNS text
LANGUAGE sql
IMMUTABLE
STRICT
SET search_path = ''
AS $$
  SELECT encode(
    extensions.digest(upper(trim(p_code)), 'sha256'),
    'hex'
  )
$$;

REVOKE ALL ON FUNCTION private.guardian_invitation_hash(text)
  FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION private.new_guardian_invitation_code()
RETURNS text
LANGUAGE sql
VOLATILE
SET search_path = ''
AS $$
  SELECT upper(substr(encode(extensions.gen_random_bytes(8), 'hex'), 1, 10))
$$;

REVOKE ALL ON FUNCTION private.new_guardian_invitation_code()
  FROM PUBLIC, anon, authenticated;

-- Saving a new phone or refreshing a pending invitation returns the raw code
-- exactly once. Only its SHA-256 hash remains in the database.
CREATE OR REPLACE FUNCTION public.save_my_guardian_configuration(
  p_enabled boolean,
  p_can_reply boolean DEFAULT false,
  p_name text DEFAULT NULL,
  p_relationship text DEFAULT NULL,
  p_phone text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid := private.assert_authenticated();
  v_profile public.profiles%ROWTYPE;
  v_code text;
  v_guardian_phone text;
BEGIN
  PERFORM public.set_my_guardian_settings(
    p_enabled,
    p_can_reply,
    p_name,
    p_relationship,
    NULL::text,
    NULL::text,
    NULL::text
  );

  SELECT * INTO v_profile
  FROM public.profiles
  WHERE user_id = v_user_id
  FOR UPDATE;

  IF NOT p_enabled THEN
    UPDATE public.profiles
    SET guardian_invitation_token_hash = NULL
    WHERE id = v_profile.id;
  ELSIF v_profile.guardian_user_id IS NULL THEN
    IF nullif(trim(p_phone), '') IS NOT NULL THEN
      v_guardian_phone := regexp_replace(p_phone, '[^0-9+]', '', 'g');
      IF v_guardian_phone ~ '^[6-9][0-9]{9}$' THEN
        v_guardian_phone := '+91' || v_guardian_phone;
      ELSIF v_guardian_phone ~ '^91[6-9][0-9]{9}$' THEN
        v_guardian_phone := '+' || v_guardian_phone;
      END IF;
      IF v_guardian_phone !~ '^\+91[6-9][0-9]{9}$' THEN
        RAISE EXCEPTION 'invalid_guardian_phone' USING ERRCODE = '22023';
      END IF;
      PERFORM public.set_guardian_phone(v_profile.id, v_guardian_phone);
    ELSIF v_profile.guardian_phone_encrypted IS NULL THEN
      RAISE EXCEPTION 'guardian_phone_required' USING ERRCODE = 'P0001';
    END IF;

    v_code := private.new_guardian_invitation_code();
    UPDATE public.profiles
    SET guardian_invitation_token_hash =
          private.guardian_invitation_hash(v_code),
        guardian_invitation_expires_at = now() + interval '7 days',
        guardian_invitation_consumed_at = NULL,
        guardian_invitation_attempts = 0,
        guardian_invitation_locked_until = NULL
    WHERE id = v_profile.id;
  END IF;

  SELECT * INTO v_profile
  FROM public.profiles
  WHERE id = v_profile.id;

  RETURN jsonb_build_object(
    'enabled', p_enabled,
    'mode', v_profile.guardian_mode,
    'linked', v_profile.guardian_user_id IS NOT NULL,
    'phone_configured', v_profile.guardian_phone_encrypted IS NOT NULL,
    'invitation_code', v_code,
    'invitation_expires_at', v_profile.guardian_invitation_expires_at
  );
END;
$$;

REVOKE ALL ON FUNCTION public.save_my_guardian_configuration(
  boolean, boolean, text, text, text
) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.save_my_guardian_configuration(
  boolean, boolean, text, text, text
) TO authenticated;

CREATE OR REPLACE FUNCTION public.renew_my_guardian_invitation()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid := private.assert_authenticated();
  v_profile public.profiles%ROWTYPE;
  v_code text := private.new_guardian_invitation_code();
BEGIN
  SELECT * INTO v_profile
  FROM public.profiles
  WHERE user_id = v_user_id
  FOR UPDATE;

  IF NOT FOUND
    OR v_profile.guardian_mode NOT IN ('passive', 'active')
    OR v_profile.guardian_phone_encrypted IS NULL
    OR v_profile.guardian_user_id IS NOT NULL THEN
    RAISE EXCEPTION 'guardian_invitation_unavailable'
      USING ERRCODE = 'P0001';
  END IF;

  UPDATE public.profiles
  SET guardian_invitation_token_hash =
        private.guardian_invitation_hash(v_code),
      guardian_invitation_expires_at = now() + interval '7 days',
      guardian_invitation_consumed_at = NULL,
      guardian_invitation_attempts = 0,
      guardian_invitation_locked_until = NULL
  WHERE id = v_profile.id;

  RETURN jsonb_build_object(
    'invitation_code', v_code,
    'invitation_expires_at', now() + interval '7 days'
  );
END;
$$;

REVOKE ALL ON FUNCTION public.renew_my_guardian_invitation()
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.renew_my_guardian_invitation()
  TO authenticated;

-- Called before Firebase sends an SMS. It prevents the free Guardian route
-- from becoming a general-purpose SMS relay and never reveals whether a code
-- or phone was the mismatched value.
CREATE OR REPLACE FUNCTION public.assert_guardian_invitation_phone(
  p_code text,
  p_phone text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid := private.assert_authenticated();
  v_profile public.profiles%ROWTYPE;
  v_secret text;
  v_stored_phone text;
  v_phone text := regexp_replace(coalesce(p_phone, ''), '[^0-9+]', '', 'g');
  v_hash text := private.guardian_invitation_hash(coalesce(p_code, ''));
BEGIN
  IF upper(trim(coalesce(p_code, ''))) !~ '^[A-F0-9]{10}$'
    OR v_phone !~ '^\+91[6-9][0-9]{9}$' THEN
    RAISE EXCEPTION 'guardian_invitation_unavailable'
      USING ERRCODE = 'P0001';
  END IF;

  SELECT * INTO v_profile
  FROM public.profiles
  WHERE guardian_invitation_token_hash = v_hash
  FOR UPDATE;

  IF NOT FOUND
    OR v_profile.user_id = v_user_id
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
    UPDATE public.profiles
    SET guardian_invitation_attempts = guardian_invitation_attempts + 1,
        guardian_invitation_locked_until = CASE
          WHEN guardian_invitation_attempts + 1 >= 5
            THEN now() + interval '24 hours'
          ELSE guardian_invitation_locked_until
        END
    WHERE id = v_profile.id;
    RAISE EXCEPTION 'guardian_invitation_unavailable'
      USING ERRCODE = 'P0001';
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.assert_guardian_invitation_phone(text, text)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.assert_guardian_invitation_phone(text, text)
  TO authenticated;

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
      END,
      updated_at = now()
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

-- Legacy clients can still activate by profile id, but authorization now uses
-- the Firebase-verified public phone rather than an unconfigured Supabase SMS
-- provider. New clients use the invitation-code RPC above.
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
  v_phone text;
  v_verified_at timestamptz;
  v_code_hash text;
BEGIN
  PERFORM p_guardian_phone;
  SELECT phone, phone_verified_at INTO v_phone, v_verified_at
  FROM public.users WHERE id = v_guardian_id;
  IF v_verified_at IS NULL OR nullif(v_phone, '') IS NULL THEN
    RAISE EXCEPTION 'verified_guardian_phone_required'
      USING ERRCODE = 'P0001';
  END IF;

  SELECT guardian_invitation_token_hash INTO v_code_hash
  FROM public.profiles
  WHERE id = p_ward_profile_id;
  IF v_code_hash IS NULL THEN
    RAISE EXCEPTION 'guardian_invitation_unavailable'
      USING ERRCODE = 'P0001';
  END IF;

  RAISE EXCEPTION 'guardian_client_upgrade_required'
    USING ERRCODE = 'P0001';
END;
$$;

REVOKE ALL ON FUNCTION public.activate_guardian(uuid, text)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.activate_guardian(uuid, text)
  TO authenticated;

CREATE OR REPLACE FUNCTION public.audit_guardian_invitation_wiring()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF NOT private.is_service_role() THEN
    RAISE EXCEPTION 'service_role_required' USING ERRCODE = '42501';
  END IF;
  RETURN jsonb_build_object(
    'hashed_codes', true,
    'firebase_phone_column', EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'users'
        AND column_name = 'phone_verified_at'
    ),
    'guardian_account_roles', EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'users'
        AND column_name = 'account_role'
    ),
    'pending_invitations', (
      SELECT count(*) FROM public.profiles p
      WHERE p.guardian_invitation_token_hash IS NOT NULL
        AND p.guardian_user_id IS NULL
        AND p.guardian_invitation_expires_at > now()
    )
  );
END;
$$;

REVOKE ALL ON FUNCTION public.audit_guardian_invitation_wiring()
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.audit_guardian_invitation_wiring()
  TO service_role;

NOTIFY pgrst, 'reload schema';
