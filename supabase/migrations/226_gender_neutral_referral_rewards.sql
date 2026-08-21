-- Referral rewards are based on a completed, eligible account—not gender.
-- Both participants may receive one lifetime three-day grant. The unique
-- user grant index introduced in migration 216 prevents stacking.

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
    JOIN public.users u ON u.id = p.user_id
    WHERE p.user_id = p_referred_id
      AND p.onboarding_completed = true
      AND u.deleted_at IS NULL
  ) THEN
    RETURN false;
  END IF;

  -- Retain gender snapshots for aggregate referral analytics only. Gender is
  -- deliberately not an eligibility condition.
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
      'You already claimed your one-time referral Premium. Your friend can still receive their own reward.',
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

-- Earlier same-gender completions were recorded as ineligible. Apply the new
-- rule once, without bypassing the lifetime cap or onboarding requirement.
DO $$
DECLARE
  v_referral public.referrals%ROWTYPE;
  v_referrer_expiry timestamptz;
  v_referred_expiry timestamptz;
BEGIN
  FOR v_referral IN
    SELECT r.*
    FROM public.referrals r
    JOIN public.profiles p ON p.user_id = r.referred_id
    JOIN public.users u ON u.id = r.referred_id
    WHERE r.reward_granted = true
      AND r.reward_type = 'same_gender_no_reward'
      AND p.onboarding_completed = true
      AND u.deleted_at IS NULL
    ORDER BY r.created_at, r.id
    FOR UPDATE OF r
  LOOP
    v_referrer_expiry := private.grant_referral_premium(
      v_referral.id,
      v_referral.referrer_id,
      'referrer'
    );
    v_referred_expiry := private.grant_referral_premium(
      v_referral.id,
      v_referral.referred_id,
      'referred'
    );

    UPDATE public.referrals
    SET reward_type = CASE
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
        'Your one-time 3-day referral Premium is active.',
        'silarah://profile'
      );
    END IF;

    IF v_referred_expiry IS NOT NULL THEN
      PERFORM public.queue_notification(
        v_referral.referred_id,
        'referral_reward',
        '3 days of Premium unlocked',
        'Your one-time 3-day referral Premium is active.',
        'silarah://profile'
      );
    END IF;
  END LOOP;
END;
$$;

COMMENT ON FUNCTION private.process_referral_reward(uuid) IS
  'Grants each eligible referral participant one lifetime three-day Premium reward regardless of gender.';

NOTIFY pgrst, 'reload schema';
