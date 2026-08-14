-- Referral Premium is a promotional entitlement, independent from the
-- RevenueCat-owned paid-subscription columns on public.users. Keeping the two
-- sources separate prevents a billing webhook from erasing a referral reward.

CREATE TABLE IF NOT EXISTS public.promotional_premium_grants (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  referral_id uuid NOT NULL REFERENCES public.referrals(id) ON DELETE CASCADE,
  beneficiary_role text NOT NULL
    CHECK (beneficiary_role IN ('referrer', 'referred')),
  starts_at timestamptz NOT NULL,
  expires_at timestamptz NOT NULL,
  granted_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT promotional_premium_grants_positive_window
    CHECK (expires_at > starts_at),
  CONSTRAINT promotional_premium_grants_referral_user_unique
    UNIQUE (referral_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_promotional_premium_grants_active_user
  ON public.promotional_premium_grants(user_id, expires_at DESC);

ALTER TABLE public.promotional_premium_grants ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS promotional_premium_grants_select_own
  ON public.promotional_premium_grants;
CREATE POLICY promotional_premium_grants_select_own
  ON public.promotional_premium_grants
  FOR SELECT TO authenticated
  USING (user_id = (SELECT auth.uid()));

REVOKE ALL ON TABLE public.promotional_premium_grants
  FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.promotional_premium_grants TO authenticated;

CREATE OR REPLACE FUNCTION private.grant_referral_premium(
  p_referral_id uuid,
  p_user_id uuid,
  p_beneficiary_role text
)
RETURNS timestamptz
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_existing_expiry timestamptz;
  v_starts_at timestamptz;
  v_expires_at timestamptz;
BEGIN
  IF p_beneficiary_role NOT IN ('referrer', 'referred') THEN
    RAISE EXCEPTION 'invalid_referral_beneficiary_role'
      USING ERRCODE = '22023';
  END IF;

  -- Serialize grants per member so multiple successful referrals stack rather
  -- than overlap and silently lose promotional days.
  PERFORM pg_advisory_xact_lock(hashtextextended(p_user_id::text, 0));

  SELECT g.expires_at
  INTO v_existing_expiry
  FROM public.promotional_premium_grants g
  WHERE g.referral_id = p_referral_id
    AND g.user_id = p_user_id;

  IF v_existing_expiry IS NOT NULL THEN
    RETURN v_existing_expiry;
  END IF;

  SELECT greatest(now(), coalesce(max(g.expires_at), now()))
  INTO v_starts_at
  FROM public.promotional_premium_grants g
  WHERE g.user_id = p_user_id
    AND g.expires_at > now();

  v_expires_at := v_starts_at + interval '3 days';

  INSERT INTO public.promotional_premium_grants(
    user_id,
    referral_id,
    beneficiary_role,
    starts_at,
    expires_at
  ) VALUES (
    p_user_id,
    p_referral_id,
    p_beneficiary_role,
    v_starts_at,
    v_expires_at
  );

  RETURN v_expires_at;
END;
$$;

REVOKE ALL ON FUNCTION private.grant_referral_premium(uuid, uuid, text)
  FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.has_active_premium(p_user_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT
    coalesce((
      SELECT
        (
          u.subscription_status = 'active'
          AND (
            u.subscription_expires_at IS NULL
            OR u.subscription_expires_at > now()
          )
        )
        OR (
          u.subscription_status = 'grace'
          AND u.subscription_expires_at IS NOT NULL
          AND u.subscription_expires_at > now() - interval '24 hours'
        )
      FROM public.users u
      WHERE u.id = p_user_id
    ), false)
    OR EXISTS (
      SELECT 1
      FROM public.promotional_premium_grants g
      WHERE g.user_id = p_user_id
        AND g.starts_at <= now()
        AND g.expires_at > now()
    );
$$;

REVOKE ALL ON FUNCTION public.has_active_premium(uuid)
  FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.get_my_premium_entitlement()
RETURNS TABLE (
  is_active boolean,
  source text,
  expires_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid := private.assert_authenticated();
  v_subscription_status text;
  v_subscription_expires_at timestamptz;
  v_paid_active boolean := false;
  v_paid_expires_at timestamptz;
  v_referral_expires_at timestamptz;
BEGIN
  SELECT u.subscription_status, u.subscription_expires_at
  INTO v_subscription_status, v_subscription_expires_at
  FROM public.users u
  WHERE u.id = v_user_id;

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

  IF v_paid_active THEN
    v_paid_expires_at := CASE
      WHEN v_subscription_status = 'grace'
        THEN v_subscription_expires_at + interval '24 hours'
      ELSE v_subscription_expires_at
    END;
  END IF;

  SELECT max(g.expires_at)
  INTO v_referral_expires_at
  FROM public.promotional_premium_grants g
  WHERE g.user_id = v_user_id
    AND g.starts_at <= now()
    AND g.expires_at > now();

  is_active := v_paid_active OR v_referral_expires_at IS NOT NULL;
  source := CASE
    WHEN v_paid_active AND v_referral_expires_at IS NOT NULL
      THEN 'paid_and_referral'
    WHEN v_paid_active THEN 'paid'
    WHEN v_referral_expires_at IS NOT NULL THEN 'referral'
    ELSE 'none'
  END;
  expires_at := CASE
    WHEN v_paid_active AND v_paid_expires_at IS NULL THEN NULL
    WHEN v_paid_expires_at IS NULL THEN v_referral_expires_at
    WHEN v_referral_expires_at IS NULL THEN v_paid_expires_at
    ELSE greatest(v_paid_expires_at, v_referral_expires_at)
  END;

  RETURN NEXT;
END;
$$;

REVOKE ALL ON FUNCTION public.get_my_premium_entitlement()
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_premium_entitlement()
  TO authenticated;

CREATE OR REPLACE FUNCTION private.process_referral_reward(p_referred_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_referral public.referrals%ROWTYPE;
  v_referrer_gender text;
  v_referred_gender text;
BEGIN
  SELECT r.*
  INTO v_referral
  FROM public.referrals r
  WHERE r.referred_id = p_referred_id
    AND r.reward_granted = false
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN false;
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.profiles p
    WHERE p.user_id = p_referred_id
      AND p.onboarding_completed = true
  ) THEN
    RETURN false;
  END IF;

  SELECT lower(trim(u.gender::text))
  INTO v_referrer_gender
  FROM public.users u
  WHERE u.id = v_referral.referrer_id;

  SELECT lower(trim(u.gender::text))
  INTO v_referred_gender
  FROM public.users u
  WHERE u.id = p_referred_id;

  UPDATE public.referrals
  SET referred_gender = v_referred_gender,
      referrer_gender = v_referrer_gender
  WHERE id = v_referral.id;

  IF v_referrer_gender IS NULL OR v_referred_gender IS NULL THEN
    RETURN false;
  END IF;

  IF v_referrer_gender = v_referred_gender THEN
    UPDATE public.referrals
    SET reward_granted = true,
        reward_type = 'same_gender_no_reward'
    WHERE id = v_referral.id;

    PERFORM public.queue_notification(
      v_referral.referrer_id,
      'referral_completed',
      'Referral joined',
      'Your referral completed their profile. Invite an opposite-gender member so both of you can earn Premium.',
      'silarah://referral'
    );
    RETURN true;
  END IF;

  PERFORM private.grant_referral_premium(
    v_referral.id,
    v_referral.referrer_id,
    'referrer'
  );
  PERFORM private.grant_referral_premium(
    v_referral.id,
    p_referred_id,
    'referred'
  );

  UPDATE public.referrals
  SET reward_granted = true,
      reward_type = '3_days_premium_both'
  WHERE id = v_referral.id;

  PERFORM public.queue_notification(
    v_referral.referrer_id,
    'referral_reward',
    '3 days of Premium unlocked',
    'Your referral completed their profile. You both received 3 days of Premium.',
    'silarah://subscription'
  );
  PERFORM public.queue_notification(
    p_referred_id,
    'referral_reward',
    '3 days of Premium unlocked',
    'You completed signup with a referral code. You both received 3 days of Premium.',
    'silarah://subscription'
  );

  RETURN true;
END;
$$;

REVOKE ALL ON FUNCTION private.process_referral_reward(uuid)
  FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.check_referral_reward()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  PERFORM private.process_referral_reward(NEW.user_id);
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_check_referral_reward ON public.profiles;
CREATE TRIGGER trg_check_referral_reward
  AFTER UPDATE OF onboarding_completed ON public.profiles
  FOR EACH ROW
  WHEN (
    NEW.onboarding_completed IS TRUE
    AND OLD.onboarding_completed IS FALSE
  )
  EXECUTE FUNCTION public.check_referral_reward();

CREATE OR REPLACE FUNCTION public.apply_referral_code(p_code text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_referred_id uuid := private.assert_authenticated();
  v_referrer_id uuid;
  v_inserted boolean := false;
BEGIN
  -- Referral codes are a signup incentive. Existing completed accounts cannot
  -- attach a code after the fact and farm promotional access.
  IF EXISTS (
    SELECT 1
    FROM public.profiles p
    WHERE p.user_id = v_referred_id
      AND p.onboarding_completed = true
  ) THEN
    RETURN jsonb_build_object('status', 'ineligible_existing_account');
  END IF;

  SELECT rc.owner_id
  INTO v_referrer_id
  FROM public.referral_codes rc
  WHERE rc.code = upper(trim(coalesce(p_code, '')));

  IF v_referrer_id IS NULL THEN
    RETURN jsonb_build_object('status', 'invalid_code');
  END IF;
  IF v_referrer_id = v_referred_id THEN
    RETURN jsonb_build_object('status', 'self_referral');
  END IF;

  WITH inserted AS (
    INSERT INTO public.referrals(referrer_id, referred_id)
    VALUES (v_referrer_id, v_referred_id)
    ON CONFLICT (referred_id) DO NOTHING
    RETURNING 1
  )
  SELECT EXISTS (SELECT 1 FROM inserted) INTO v_inserted;

  IF NOT v_inserted THEN
    RETURN jsonb_build_object('status', 'already_referred');
  END IF;

  UPDATE public.referral_codes
  SET uses_count = uses_count + 1
  WHERE owner_id = v_referrer_id;

  RETURN jsonb_build_object(
    'status', 'applied',
    'referrer_id', v_referrer_id
  );
END;
$$;

REVOKE ALL ON FUNCTION public.apply_referral_code(text)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.apply_referral_code(text)
  TO authenticated;

COMMENT ON TABLE public.promotional_premium_grants IS
  'Auditable, stackable Premium grants that are independent from paid-store subscription state.';
COMMENT ON FUNCTION public.get_my_premium_entitlement() IS
  'Canonical merged paid and promotional Premium state for the authenticated member.';
COMMENT ON FUNCTION private.process_referral_reward(uuid) IS
  'Grants exactly three stackable Premium days to both opposite-gender referral participants after onboarding completion.';

NOTIFY pgrst, 'reload schema';
