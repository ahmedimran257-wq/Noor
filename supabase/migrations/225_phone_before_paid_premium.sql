-- Verify phone ownership before a paid Premium checkout begins.
--
-- Email remains the account identifier. Phone verification is requested only
-- after a member deliberately taps a paid plan (or changes an already verified
-- number), keeping SMS spend bounded while ensuring paid Premium accounts carry
-- a verified India phone. Promotional referral Premium does not consume an SMS
-- and remains usable by both genders.

CREATE TABLE IF NOT EXISTS private.phone_verification_intents (
  user_id uuid PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
  country_code text NOT NULL,
  is_change boolean NOT NULL DEFAULT false,
  window_started_at timestamptz NOT NULL DEFAULT now(),
  request_count integer NOT NULL DEFAULT 0
    CHECK (request_count BETWEEN 0 AND 3),
  expires_at timestamptz NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now()
);

REVOKE ALL ON TABLE private.phone_verification_intents
  FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.begin_my_paid_phone_verification(
  p_country_code text,
  p_is_change boolean DEFAULT false
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid := private.assert_authenticated();
  v_country_code text := upper(trim(coalesce(p_country_code, '')));
  v_user public.users%ROWTYPE;
  v_intent private.phone_verification_intents%ROWTYPE;
  v_paid_active boolean := false;
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM public.launch_countries lc
    WHERE lc.country_code = v_country_code
      AND lc.enabled
  ) THEN
    RAISE EXCEPTION 'launch_country_unavailable' USING ERRCODE = 'P0001';
  END IF;

  SELECT * INTO v_user
  FROM public.users u
  WHERE u.id = v_user_id
  FOR UPDATE;

  IF NOT FOUND
    OR v_user.deleted_at IS NOT NULL
    OR coalesce(v_user.is_banned, false)
    OR NOT EXISTS (
      SELECT 1
      FROM public.profiles p
      WHERE p.user_id = v_user_id
        AND p.onboarding_completed = true
    ) THEN
    RAISE EXCEPTION 'completed_account_required' USING ERRCODE = 'P0001';
  END IF;

  v_paid_active :=
    (
      v_user.subscription_status = 'active'
      AND (
        v_user.subscription_expires_at IS NULL
        OR v_user.subscription_expires_at > now()
      )
    )
    OR (
      v_user.subscription_status = 'grace'
      AND v_user.subscription_expires_at IS NOT NULL
      AND v_user.subscription_expires_at > now() - interval '24 hours'
    );

  IF p_is_change THEN
    IF v_user.phone_verified_at IS NULL OR nullif(v_user.phone, '') IS NULL THEN
      RAISE EXCEPTION 'verified_phone_required' USING ERRCODE = 'P0001';
    END IF;
    IF NOT v_paid_active THEN
      RAISE EXCEPTION 'paid_subscription_required' USING ERRCODE = 'P0001';
    END IF;
  ELSIF v_user.phone_verified_at IS NOT NULL
        AND nullif(v_user.phone, '') IS NOT NULL THEN
    -- A previously verified number survives renewals and does not need another
    -- SMS before checkout.
    RETURN;
  END IF;

  PERFORM pg_advisory_xact_lock(hashtextextended(v_user_id::text, 225));

  INSERT INTO private.phone_verification_intents(
    user_id,
    country_code,
    is_change,
    window_started_at,
    request_count,
    expires_at,
    updated_at
  ) VALUES (
    v_user_id,
    v_country_code,
    p_is_change,
    now(),
    0,
    now(),
    now()
  )
  ON CONFLICT (user_id) DO NOTHING;

  SELECT * INTO v_intent
  FROM private.phone_verification_intents i
  WHERE i.user_id = v_user_id
  FOR UPDATE;

  IF v_intent.window_started_at <= now() - interval '24 hours' THEN
    v_intent.window_started_at := now();
    v_intent.request_count := 0;
  END IF;

  IF v_intent.request_count >= 3 THEN
    RAISE EXCEPTION 'phone_verification_rate_limited'
      USING ERRCODE = 'P0001';
  END IF;

  UPDATE private.phone_verification_intents
  SET country_code = v_country_code,
      is_change = p_is_change,
      window_started_at = v_intent.window_started_at,
      request_count = v_intent.request_count + 1,
      expires_at = now() + interval '15 minutes',
      updated_at = now()
  WHERE user_id = v_user_id;
END;
$$;

REVOKE ALL ON FUNCTION public.begin_my_paid_phone_verification(text, boolean)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.begin_my_paid_phone_verification(text, boolean)
  TO authenticated;

CREATE OR REPLACE FUNCTION public.assert_my_phone_verification_intent(
  p_country_code text
)
RETURNS void
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid := private.assert_authenticated();
  v_country_code text := upper(trim(coalesce(p_country_code, '')));
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM private.phone_verification_intents i
    JOIN public.launch_countries lc
      ON lc.country_code = i.country_code
     AND lc.enabled
    WHERE i.user_id = v_user_id
      AND i.country_code = v_country_code
      AND i.expires_at > now()
  ) THEN
    RAISE EXCEPTION 'phone_verification_intent_required'
      USING ERRCODE = 'P0001';
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.assert_my_phone_verification_intent(text)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.assert_my_phone_verification_intent(text)
  TO authenticated;

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
  IF NOT private.is_service_role() THEN
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

-- Keep the installed Edge Function and any briefly overlapping app version
-- safe during rollout. The old function name now validates a short-lived paid
-- checkout/change intent instead of requiring Premium to already be active.
CREATE OR REPLACE FUNCTION public.assert_my_phone_country_enabled(
  p_country_code text
)
RETURNS void
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT public.assert_my_phone_verification_intent(p_country_code)
$$;

REVOKE ALL ON FUNCTION public.assert_my_phone_country_enabled(text)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.assert_my_phone_country_enabled(text)
  TO authenticated;

-- Women continue to message free. Men need Premium; a paid entitlement also
-- requires the phone verified before checkout, while a referral-only grant is
-- usable without spending an SMS on a promotional account.
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
  v_subscription_status text;
  v_subscription_expires_at timestamptz;
  v_paid_active boolean := false;
  v_referral_active boolean := false;
BEGIN
  SELECT lower(trim(u.gender::text)),
         u.phone_verified_at,
         u.subscription_status,
         u.subscription_expires_at
  INTO v_gender,
       v_phone_verified_at,
       v_subscription_status,
       v_subscription_expires_at
  FROM public.users u
  WHERE u.id = p_user_id;

  IF NOT FOUND OR v_gender IS NULL OR v_gender NOT IN ('male', 'female') THEN
    RAISE EXCEPTION 'profile_gender_required' USING ERRCODE = 'P0001';
  END IF;

  IF v_gender = 'female' THEN
    RETURN;
  END IF;

  v_paid_active :=
    (
      v_subscription_status = 'active'
      AND (
        v_subscription_expires_at IS NULL
        OR v_subscription_expires_at > now()
      )
    )
    OR (
      v_subscription_status = 'grace'
      AND v_subscription_expires_at IS NOT NULL
      AND v_subscription_expires_at > now() - interval '24 hours'
    );

  SELECT EXISTS (
    SELECT 1
    FROM public.promotional_premium_grants g
    WHERE g.user_id = p_user_id
      AND g.starts_at <= now()
      AND g.expires_at > now()
  ) INTO v_referral_active;

  IF NOT v_paid_active AND NOT v_referral_active THEN
    RAISE EXCEPTION 'subscription_required' USING ERRCODE = 'P0001';
  END IF;

  IF v_paid_active AND v_phone_verified_at IS NULL THEN
    RAISE EXCEPTION 'phone_verification_required' USING ERRCODE = 'P0001';
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION private.assert_outgoing_chat_entitlement(uuid)
  FROM PUBLIC, anon, authenticated;

COMMENT ON FUNCTION public.begin_my_paid_phone_verification(text, boolean) IS
  'Creates a 15-minute, rate-limited India SMS intent after a member deliberately starts paid checkout or an eligible phone change.';
COMMENT ON FUNCTION public.assert_my_phone_verification_intent(text) IS
  'Validates the short-lived server-side intent before a Firebase phone proof may update the member phone.';
COMMENT ON FUNCTION public.complete_paid_phone_verification(uuid, text, text) IS
  'Atomically consumes one short-lived paid phone intent and stores the Firebase-verified India number; callable only by service role.';
COMMENT ON FUNCTION private.assert_outgoing_chat_entitlement(uuid) IS
  'Women message free; men need paid or referral Premium, with phone trust required for paid entitlements and not promotional referral-only access.';

NOTIFY pgrst, 'reload schema';
