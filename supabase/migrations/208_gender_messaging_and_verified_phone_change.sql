-- Keep Silarah's gender-based messaging contract authoritative and make phone
-- changes independent from RevenueCat subscription ownership.
--
-- Product policy:
--   * women can read and send messages in valid matches without Premium or SMS;
--   * men need active Premium to open chat and a verified phone to send;
--   * unknown gender fails closed;
--   * changing a phone requires a successful Supabase phone-change OTP;
--   * a phone change never modifies subscription status or expiry.

CREATE OR REPLACE FUNCTION private.assert_outgoing_chat_entitlement(
  p_user_id uuid
)
RETURNS void
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_gender text;
  v_phone_verified_at timestamptz;
BEGIN
  SELECT lower(trim(u.gender::text)), u.phone_verified_at
  INTO v_gender, v_phone_verified_at
  FROM public.users u
  WHERE u.id = p_user_id;

  IF NOT FOUND OR v_gender IS NULL OR v_gender NOT IN ('male', 'female') THEN
    RAISE EXCEPTION 'profile_gender_required' USING ERRCODE = 'P0001';
  END IF;

  -- Women have free messaging and no phone prerequisite.
  IF v_gender = 'female' THEN
    RETURN;
  END IF;

  IF NOT public.has_active_premium(p_user_id) THEN
    RAISE EXCEPTION 'subscription_required' USING ERRCODE = 'P0001';
  END IF;

  IF v_phone_verified_at IS NULL THEN
    RAISE EXCEPTION 'phone_verification_required' USING ERRCODE = 'P0001';
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION private.assert_outgoing_chat_entitlement(uuid)
  FROM PUBLIC, anon, authenticated;

-- Replace the universal SMS guard introduced by migration 206 with the
-- canonical gender-aware policy while preserving the mature delivery RPC.
DO $migration$
DECLARE
  v_signature regprocedure :=
    'public.send_chat_message(uuid,text)'::regprocedure;
  v_definition text;
  v_updated text;
  v_old text := $old$  IF NOT EXISTS (
    SELECT 1 FROM public.users verified_sender
    WHERE verified_sender.id = v_me
      AND verified_sender.phone_verified_at IS NOT NULL
  ) THEN
    RAISE EXCEPTION 'phone_verification_required'
      USING ERRCODE = 'P0001';
  END IF;$old$;
  v_new text := $new$  PERFORM private.assert_outgoing_chat_entitlement(v_me);$new$;
BEGIN
  SELECT replace(pg_get_functiondef(v_signature), E'\r\n', E'\n')
  INTO v_definition;

  IF position('private.assert_outgoing_chat_entitlement(v_me)' IN v_definition) = 0 THEN
    IF position(v_old IN v_definition) = 0 THEN
      RAISE EXCEPTION 'gender_chat_policy_anchor_not_found';
    END IF;
    v_updated := replace(v_definition, v_old, v_new);
    EXECUTE v_updated;
  END IF;
END;
$migration$;

-- Preserve trigger-level defence for every current or future trusted write
-- path, even though members cannot insert messages directly.
CREATE OR REPLACE FUNCTION public.assert_messaging_allowed()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_suspended_until timestamptz;
BEGIN
  IF auth.uid() IS NOT NULL AND NEW.sender_id <> auth.uid() THEN
    RAISE EXCEPTION 'You cannot send a message for another member.'
      USING ERRCODE = '42501';
  END IF;

  SELECT u.messaging_suspended_until
  INTO v_suspended_until
  FROM public.users u
  WHERE u.id = NEW.sender_id;

  IF v_suspended_until IS NOT NULL AND v_suspended_until > now() THEN
    RAISE EXCEPTION 'messaging_suspended'
      USING ERRCODE = 'P0001',
            DETAIL = json_build_object('until', v_suspended_until)::text;
  END IF;

  PERFORM private.assert_outgoing_chat_entitlement(NEW.sender_id);
  RETURN NEW;
END;
$$;

-- New clients submit the selected country so the public trust record stays in
-- sync with the OTP-confirmed auth phone. The original no-argument overload is
-- retained temporarily for already-installed clients.
CREATE OR REPLACE FUNCTION public.confirm_my_verified_phone(
  p_country_code text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid := private.assert_authenticated();
  v_phone text;
  v_phone_confirmed_at timestamptz;
  v_country_code text := upper(trim(coalesce(p_country_code, '')));
  v_dialing_code text;
BEGIN
  IF v_country_code !~ '^[A-Z]{2}$' THEN
    RAISE EXCEPTION 'invalid_phone_country' USING ERRCODE = '22023';
  END IF;

  SELECT c.dialing_code
  INTO v_dialing_code
  FROM public.countries c
  WHERE c.iso_code = v_country_code;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'invalid_phone_country' USING ERRCODE = '22023';
  END IF;

  SELECT au.phone, au.phone_confirmed_at
  INTO v_phone, v_phone_confirmed_at
  FROM auth.users au
  WHERE au.id = v_user_id;

  IF nullif(v_phone, '') IS NULL OR v_phone_confirmed_at IS NULL THEN
    RAISE EXCEPTION 'phone_not_verified' USING ERRCODE = 'P0001';
  END IF;
  IF v_phone NOT LIKE v_dialing_code || '%' THEN
    RAISE EXCEPTION 'phone_country_mismatch' USING ERRCODE = 'P0001';
  END IF;

  -- Deliberately update only phone trust fields. RevenueCat ownership and the
  -- database subscription expiry remain keyed to the immutable user UUID.
  UPDATE public.users
  SET phone = v_phone,
      phone_country_code = v_country_code,
      phone_verified_at = now()
  WHERE id = v_user_id;
END;
$$;

REVOKE ALL ON FUNCTION public.confirm_my_verified_phone(text)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.confirm_my_verified_phone(text)
  TO authenticated;

COMMENT ON FUNCTION private.assert_outgoing_chat_entitlement(uuid) IS
  'Women message free without SMS; men require active Premium and an SMS-verified phone; unknown gender fails closed.';
COMMENT ON FUNCTION public.confirm_my_verified_phone(text) IS
  'Copies an OTP-confirmed Supabase Auth phone into member trust fields without changing subscription state or expiry.';

NOTIFY pgrst, 'reload schema';
