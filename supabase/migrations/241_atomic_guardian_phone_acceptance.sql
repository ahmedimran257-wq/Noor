-- Guardian phone ownership and invitation acceptance are one transaction.
-- The pre-SMS check returns false (rather than raising) so mismatch counters
-- commit and abuse throttling cannot be rolled back by an exception.
CREATE OR REPLACE FUNCTION public.check_guardian_invitation_phone(
  p_code text,
  p_phone text
)
RETURNS boolean
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
  v_hash text;
BEGIN
  IF upper(trim(coalesce(p_code, ''))) !~ '^[A-F0-9]{10}$'
    OR v_phone !~ '^\+91[6-9][0-9]{9}$' THEN
    RETURN false;
  END IF;
  v_hash := private.guardian_invitation_hash(p_code);

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
    RETURN false;
  END IF;

  SELECT decrypted_secret INTO v_secret
  FROM vault.decrypted_secrets
  WHERE name = 'guardian_key_v1';
  IF v_secret IS NULL THEN
    RAISE EXCEPTION 'guardian_phone_encryption_unavailable'
      USING ERRCODE = 'P0001';
  END IF;

  v_stored_phone := regexp_replace(
    extensions.pgp_sym_decrypt(v_profile.guardian_phone_encrypted, v_secret),
    '[^0-9+]', '', 'g'
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
    RETURN false;
  END IF;
  RETURN true;
END;
$$;

REVOKE ALL ON FUNCTION public.check_guardian_invitation_phone(text, text)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.check_guardian_invitation_phone(text, text)
  TO authenticated;

CREATE OR REPLACE FUNCTION public.complete_guardian_phone_and_accept(
  p_guardian_id uuid,
  p_code text,
  p_phone text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_profile public.profiles%ROWTYPE;
  v_secret text;
  v_stored_phone text;
  v_phone text := regexp_replace(coalesce(p_phone, ''), '[^0-9+]', '', 'g');
  v_role text;
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'service_role_required' USING ERRCODE = '42501';
  END IF;
  IF p_guardian_id IS NULL
    OR upper(trim(coalesce(p_code, ''))) !~ '^[A-F0-9]{10}$'
    OR v_phone !~ '^\+91[6-9][0-9]{9}$' THEN
    RAISE EXCEPTION 'guardian_invitation_unavailable' USING ERRCODE = 'P0001';
  END IF;

  PERFORM pg_advisory_xact_lock(hashtextextended(p_guardian_id::text, 241));

  IF NOT EXISTS (
    SELECT 1 FROM public.users
    WHERE id = p_guardian_id
      AND deleted_at IS NULL
      AND coalesce(is_banned, false) = false
  ) THEN
    RAISE EXCEPTION 'guardian_account_unavailable' USING ERRCODE = 'P0001';
  END IF;

  SELECT * INTO v_profile
  FROM public.profiles
  WHERE guardian_invitation_token_hash =
    private.guardian_invitation_hash(p_code)
  FOR UPDATE;

  IF NOT FOUND
    OR v_profile.user_id = p_guardian_id
    OR v_profile.guardian_mode NOT IN ('passive', 'active')
    OR v_profile.guardian_phone_encrypted IS NULL
    OR v_profile.guardian_user_id IS NOT NULL
    OR v_profile.guardian_invitation_consumed_at IS NOT NULL
    OR v_profile.guardian_invitation_expires_at <= now()
    OR v_profile.guardian_invitation_locked_until > now() THEN
    RAISE EXCEPTION 'guardian_invitation_unavailable' USING ERRCODE = 'P0001';
  END IF;

  SELECT decrypted_secret INTO v_secret
  FROM vault.decrypted_secrets
  WHERE name = 'guardian_key_v1';
  IF v_secret IS NULL THEN
    RAISE EXCEPTION 'guardian_phone_encryption_unavailable'
      USING ERRCODE = 'P0001';
  END IF;
  v_stored_phone := regexp_replace(
    extensions.pgp_sym_decrypt(v_profile.guardian_phone_encrypted, v_secret),
    '[^0-9+]', '', 'g'
  );
  IF v_stored_phone ~ '^[6-9][0-9]{9}$' THEN
    v_stored_phone := '+91' || v_stored_phone;
  ELSIF v_stored_phone ~ '^91[6-9][0-9]{9}$' THEN
    v_stored_phone := '+' || v_stored_phone;
  END IF;
  IF v_stored_phone IS DISTINCT FROM v_phone THEN
    RAISE EXCEPTION 'guardian_invitation_unavailable' USING ERRCODE = 'P0001';
  END IF;

  UPDATE public.users
  SET phone = v_phone,
      phone_country_code = 'IN',
      phone_verified_at = now()
  WHERE id = p_guardian_id;

  UPDATE public.profiles
  SET guardian_user_id = p_guardian_id,
      guardian_invitation_consumed_at = now(),
      guardian_invitation_token_hash = NULL,
      guardian_invitation_attempts = 0,
      guardian_invitation_locked_until = NULL
  WHERE id = v_profile.id
    AND guardian_user_id IS NULL;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'guardian_invitation_unavailable' USING ERRCODE = 'P0001';
  END IF;

  v_role := CASE WHEN EXISTS (
    SELECT 1 FROM public.profiles own_profile
    WHERE own_profile.user_id = p_guardian_id
      AND own_profile.onboarding_completed
  ) THEN 'member_guardian' ELSE 'guardian' END;

  UPDATE public.users
  SET account_role = v_role,
      onboarding_completed = CASE
        WHEN v_role = 'guardian' THEN true ELSE onboarding_completed END
  WHERE id = p_guardian_id;

  INSERT INTO public.guardian_chat_mirrors(match_id, guardian_id, ward_id, mode)
  SELECT m.id, p_guardian_id, v_profile.user_id, v_profile.guardian_mode
  FROM public.matches m
  WHERE v_profile.user_id IN (m.user_a, m.user_b)
    AND m.status = 'active'
  ON CONFLICT (match_id, guardian_id) DO UPDATE
  SET ward_id = EXCLUDED.ward_id, mode = EXCLUDED.mode;

  INSERT INTO public.admin_audit_log(
    admin_id, action_type, target_user_id, details
  ) VALUES (
    p_guardian_id, 'guardian_activated', v_profile.user_id,
    jsonb_build_object(
      'ward_profile_id', v_profile.id,
      'guardian_mode', v_profile.guardian_mode,
      'verified_phone_ownership', true,
      'invitation_code_consumed', true,
      'atomic_activation', true
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

REVOKE ALL ON FUNCTION public.complete_guardian_phone_and_accept(
  uuid, text, text
) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.complete_guardian_phone_and_accept(
  uuid, text, text
) TO service_role;

-- A member who stops guarding their final ward should no longer retain the
-- combined member_guardian role. Dedicated Guardian accounts remain Guardian
-- accounts so they can accept a replacement invitation without onboarding a
-- public matrimonial profile.
CREATE OR REPLACE FUNCTION private.sync_detached_guardian_role()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF OLD.guardian_user_id IS NOT NULL
    AND OLD.guardian_user_id IS DISTINCT FROM NEW.guardian_user_id
    AND NOT EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.guardian_user_id = OLD.guardian_user_id
    ) THEN
    UPDATE public.users
    SET account_role = 'member'
    WHERE id = OLD.guardian_user_id
      AND account_role = 'member_guardian';
  END IF;
  RETURN NULL;
END;
$$;

REVOKE ALL ON FUNCTION private.sync_detached_guardian_role()
  FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_sync_detached_guardian_role ON public.profiles;
CREATE TRIGGER trg_sync_detached_guardian_role
AFTER UPDATE OF guardian_user_id ON public.profiles
FOR EACH ROW EXECUTE FUNCTION private.sync_detached_guardian_role();

NOTIFY pgrst, 'reload schema';
