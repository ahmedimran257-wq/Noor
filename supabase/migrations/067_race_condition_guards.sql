-- Race-condition hardening for onboarding, referrals, and RevenueCat.

CREATE OR REPLACE FUNCTION public.advance_onboarding_step_monotonic(p_step integer)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required.';
  END IF;

  -- Monotonic forward-only update: stale async saves cannot regress the step.
  UPDATE public.profiles
  SET onboarding_step = greatest(coalesce(onboarding_step, 0), p_step)
  WHERE user_id = v_user_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.generate_referral_code()
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_code text;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required.';
  END IF;

  -- Fast path for existing callers.
  SELECT code INTO v_code
  FROM public.referral_codes
  WHERE owner_id = v_user_id;
  IF v_code IS NOT NULL THEN
    RETURN v_code;
  END IF;

  -- Idempotent insert-on-conflict: concurrent requests either create one row
  -- or reselect the row created by the competing transaction.
  LOOP
    v_code := upper(substr(md5(gen_random_uuid()::text || clock_timestamp()::text), 1, 6));

    INSERT INTO public.referral_codes (code, owner_id)
    VALUES (v_code, v_user_id)
    ON CONFLICT DO NOTHING;

    SELECT code INTO v_code
    FROM public.referral_codes
    WHERE owner_id = v_user_id;
    IF v_code IS NOT NULL THEN
      RETURN v_code;
    END IF;
  END LOOP;
END;
$$;

CREATE OR REPLACE FUNCTION public.apply_revenuecat_subscription_event(
  p_user_id uuid,
  p_event_type text,
  p_event_timestamp_ms bigint,
  p_subscription_status text,
  p_subscription_expires_at timestamptz,
  p_product_id text DEFAULT NULL,
  p_currency text DEFAULT NULL,
  p_price numeric DEFAULT NULL,
  p_event_expires_at timestamptz DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_last_ts bigint;
BEGIN
  IF p_subscription_status NOT IN ('none', 'active', 'grace') THEN
    RAISE EXCEPTION 'Invalid subscription status: %', p_subscription_status;
  END IF;

  -- Row lock makes compare-and-set atomic across concurrent webhooks.
  SELECT last_billing_event_ts
  INTO v_last_ts
  FROM public.users
  WHERE id = p_user_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('applied', false, 'reason', 'user_not_found');
  END IF;

  IF p_event_timestamp_ms <= coalesce(v_last_ts, 0) THEN
    INSERT INTO public.subscription_events (
      user_id, event_type, event_timestamp_ms, product_id, currency, price, expires_at
    )
    VALUES (
      p_user_id, p_event_type, p_event_timestamp_ms, p_product_id, p_currency,
      p_price, p_event_expires_at
    )
    ON CONFLICT (user_id, event_type, event_timestamp_ms) DO NOTHING;

    RETURN jsonb_build_object('applied', false, 'reason', 'stale_event');
  END IF;

  UPDATE public.users
  SET subscription_status = p_subscription_status,
      subscription_expires_at = p_subscription_expires_at,
      last_billing_event_ts = p_event_timestamp_ms
  WHERE id = p_user_id;

  INSERT INTO public.subscription_events (
    user_id, event_type, event_timestamp_ms, product_id, currency, price, expires_at
  )
  VALUES (
    p_user_id, p_event_type, p_event_timestamp_ms, p_product_id, p_currency,
    p_price, p_event_expires_at
  )
  ON CONFLICT (user_id, event_type, event_timestamp_ms) DO NOTHING;

  RETURN jsonb_build_object('applied', true, 'reason', 'applied');
END;
$$;
