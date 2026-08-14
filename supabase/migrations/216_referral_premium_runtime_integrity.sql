-- Keep promotional Premium honest and consistent across every entitlement
-- consumer. A member may claim one referral reward in their lifetime; further
-- successful invitations do not create an indefinitely renewable free plan.

CREATE UNIQUE INDEX IF NOT EXISTS
  promotional_premium_grants_one_lifetime_reward_per_user
  ON public.promotional_premium_grants(user_id);

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
  v_starts_at timestamptz := now();
  v_expires_at timestamptz;
BEGIN
  IF p_beneficiary_role NOT IN ('referrer', 'referred') THEN
    RAISE EXCEPTION 'invalid_referral_beneficiary_role'
      USING ERRCODE = '22023';
  END IF;

  -- Serialize by beneficiary and check all historical grants, including
  -- expired ones. Referral Premium is a one-time acquisition reward, not a
  -- repeatable substitute for a paid membership.
  PERFORM pg_advisory_xact_lock(hashtextextended(p_user_id::text, 0));

  IF EXISTS (
    SELECT 1
    FROM public.promotional_premium_grants g
    WHERE g.user_id = p_user_id
  ) THEN
    RETURN NULL;
  END IF;

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
  v_referrer_expiry timestamptz;
  v_referred_expiry timestamptz;
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
      'Your referral completed their profile. Invite an opposite-gender member for the one-time Premium reward.',
      'silarah://profile'
    );
    RETURN true;
  END IF;

  v_referrer_expiry := private.grant_referral_premium(
    v_referral.id,
    v_referral.referrer_id,
    'referrer'
  );
  v_referred_expiry := private.grant_referral_premium(
    v_referral.id,
    p_referred_id,
    'referred'
  );

  UPDATE public.referrals
  SET reward_granted = true,
      reward_type = CASE
        WHEN v_referrer_expiry IS NOT NULL AND v_referred_expiry IS NOT NULL
          THEN '3_days_premium_both'
        WHEN v_referred_expiry IS NOT NULL
          THEN '3_days_premium_referred_only'
        WHEN v_referrer_expiry IS NOT NULL
          THEN '3_days_premium_referrer_only'
        ELSE 'referral_reward_cap_reached'
      END
  WHERE id = v_referral.id;

  IF v_referrer_expiry IS NOT NULL THEN
    PERFORM public.queue_notification(
      v_referral.referrer_id,
      'referral_reward',
      '3 days of Premium unlocked',
      'Your referral completed their profile. Your one-time 3-day Premium reward is active.',
      'silarah://profile'
    );
  ELSE
    PERFORM public.queue_notification(
      v_referral.referrer_id,
      'referral_completed',
      'Your referral joined',
      'You already claimed your one-time referral Premium. Your eligible friend can still receive their reward.',
      'silarah://profile'
    );
  END IF;

  IF v_referred_expiry IS NOT NULL THEN
    PERFORM public.queue_notification(
      p_referred_id,
      'referral_reward',
      '3 days of Premium unlocked',
      'Your one-time 3-day referral Premium is active.',
      'silarah://profile'
    );
  END IF;

  RETURN true;
END;
$$;

REVOKE ALL ON FUNCTION private.process_referral_reward(uuid)
  FROM PUBLIC, anon, authenticated;

-- Daily Discovery quotas must consume the canonical combined entitlement,
-- not just RevenueCat-owned columns on public.users.
CREATE OR REPLACE FUNCTION public.profile_view_daily_limit(p_user_id uuid)
RETURNS integer
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT CASE
    WHEN public.has_active_premium(p_user_id) THEN 2147483647
    ELSE 15
  END;
$$;

REVOKE ALL ON FUNCTION public.profile_view_daily_limit(uuid)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.profile_view_daily_limit(uuid)
  TO authenticated;

-- Referral rewards are an account status, not a sales notification. Existing
-- undismissed rows are repaired so old pushes and the in-app inbox agree.
UPDATE public.notifications
SET deep_link = 'silarah://profile'
WHERE type = 'referral_reward'
  AND deep_link IS DISTINCT FROM 'silarah://profile';

COMMENT ON INDEX
  public.promotional_premium_grants_one_lifetime_reward_per_user IS
  'Prevents referral rewards from becoming an unlimited, stackable substitute for paid Premium.';
COMMENT ON TABLE public.promotional_premium_grants IS
  'Auditable one-time referral Premium grants, independent from paid-store subscription state.';
COMMENT ON FUNCTION private.process_referral_reward(uuid) IS
  'Grants each eligible account at most one lifetime three-day referral Premium reward.';
COMMENT ON FUNCTION public.profile_view_daily_limit(uuid) IS
  'Returns unlimited Discovery for any active paid, grace, or referral Premium entitlement.';

NOTIFY pgrst, 'reload schema';
