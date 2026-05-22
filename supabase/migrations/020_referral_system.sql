-- ============================================================
-- MIGRATION 020: REFERRAL SYSTEM
--
-- Fixes Audit Finding 7.1 (High):
--   No viral or ambassador mechanics. Matrimony is highly
--   word-of-mouth. Give users 1 week of free premium for
--   referring a friend of the opposite gender (balances ratios).
--
-- Changes:
--   1. Create referral_codes table (one code per user)
--   2. Create referrals table (tracks who referred whom)
--   3. generate_referral_code() RPC
--   4. apply_referral_code() RPC (called during onboarding)
--   5. grant_referral_reward() trigger
-- ============================================================

-- ── 1. Referral Codes ─────────────────────────────────────────
CREATE TABLE referral_codes (
  code       text PRIMARY KEY,  -- 6-char alphanumeric uppercase
  owner_id   uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  uses_count int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (owner_id)  -- One code per user
);

CREATE INDEX idx_referral_codes_owner ON referral_codes(owner_id);

COMMENT ON TABLE referral_codes IS
  'One referral code per user. 6-character alphanumeric uppercase. '
  'Shareable via deep link: noor.app/r/{CODE}';

-- ── 2. Referrals tracking ─────────────────────────────────────
CREATE TABLE referrals (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  referrer_id     uuid NOT NULL REFERENCES users(id),
  referred_id     uuid NOT NULL REFERENCES users(id),
  referred_gender text,
  referrer_gender text,
  reward_granted  boolean NOT NULL DEFAULT false,
  reward_type     text,  -- e.g. '7_days_premium'
  created_at      timestamptz NOT NULL DEFAULT now(),
  UNIQUE (referred_id)  -- A user can only be referred once
);

CREATE INDEX idx_referrals_referrer ON referrals(referrer_id);

COMMENT ON TABLE referrals IS
  'Tracks referral relationships. Reward is granted when the referred '
  'user completes onboarding AND is of the opposite gender to the referrer. '
  'This incentivizes gender-balanced growth.';

-- ── 3. Generate referral code ─────────────────────────────────
-- Creates a unique 6-char alphanumeric code for the caller.
-- Idempotent: returns existing code if one already exists.
-- ================================================================
CREATE OR REPLACE FUNCTION generate_referral_code()
RETURNS text AS $$
DECLARE
  v_user_id uuid;
  v_code    text;
  v_exists  boolean;
BEGIN
  v_user_id := auth.uid();

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required.';
  END IF;

  -- Return existing code if already generated
  SELECT code INTO v_code FROM referral_codes WHERE owner_id = v_user_id;
  IF v_code IS NOT NULL THEN
    RETURN v_code;
  END IF;

  -- Generate unique 6-char code
  LOOP
    -- Generate random 6-char alphanumeric uppercase
    v_code := upper(substr(md5(random()::text || clock_timestamp()::text), 1, 6));

    -- Ensure uniqueness
    SELECT EXISTS(SELECT 1 FROM referral_codes WHERE code = v_code) INTO v_exists;
    EXIT WHEN NOT v_exists;
  END LOOP;

  INSERT INTO referral_codes (code, owner_id) VALUES (v_code, v_user_id);

  RETURN v_code;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- ── 4. Apply referral code (called during onboarding) ─────────
-- Records the referral relationship. Reward is granted later
-- when the referred user completes onboarding (has gender set).
-- ================================================================
CREATE OR REPLACE FUNCTION apply_referral_code(p_code text)
RETURNS jsonb AS $$
DECLARE
  v_referred_id  uuid;
  v_referrer_id  uuid;
BEGIN
  v_referred_id := auth.uid();

  IF v_referred_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required.';
  END IF;

  -- Check if already referred
  IF EXISTS (SELECT 1 FROM referrals WHERE referred_id = v_referred_id) THEN
    RETURN jsonb_build_object('status', 'already_referred');
  END IF;

  -- Look up the referral code
  SELECT owner_id INTO v_referrer_id
  FROM referral_codes WHERE code = upper(p_code);

  IF v_referrer_id IS NULL THEN
    RETURN jsonb_build_object('status', 'invalid_code');
  END IF;

  -- Can't refer yourself
  IF v_referrer_id = v_referred_id THEN
    RETURN jsonb_build_object('status', 'self_referral');
  END IF;

  -- Record the referral (reward granted later by trigger)
  INSERT INTO referrals (referrer_id, referred_id)
  VALUES (v_referrer_id, v_referred_id);

  -- Increment uses count
  UPDATE referral_codes SET uses_count = uses_count + 1
  WHERE code = upper(p_code);

  RETURN jsonb_build_object('status', 'applied', 'referrer_id', v_referrer_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- ── 5. Grant referral reward when referred user completes onboarding
-- Fires when a profile reaches onboarding_step >= 14 (completed).
-- Checks if the referred user is opposite gender to referrer.
-- If yes: grants 7 days premium to the referrer.
-- ================================================================
CREATE OR REPLACE FUNCTION check_referral_reward()
RETURNS trigger AS $$
DECLARE
  v_referral     referrals%ROWTYPE;
  v_referrer_gender text;
  v_referred_gender text;
BEGIN
  -- Only trigger when onboarding completes
  IF NEW.onboarding_step < 14 OR OLD.onboarding_step >= 14 THEN
    RETURN NEW;
  END IF;

  -- Check if this user was referred
  SELECT * INTO v_referral FROM referrals
  WHERE referred_id = NEW.user_id AND reward_granted = false;

  IF v_referral IS NULL THEN
    RETURN NEW;
  END IF;

  -- Get genders
  SELECT gender INTO v_referrer_gender FROM users WHERE id = v_referral.referrer_id;
  SELECT gender INTO v_referred_gender FROM users WHERE id = NEW.user_id;

  -- Update referral with gender info
  UPDATE referrals SET
    referred_gender = v_referred_gender,
    referrer_gender = v_referrer_gender
  WHERE id = v_referral.id;

  -- Grant reward if opposite gender
  IF v_referrer_gender IS NOT NULL AND v_referred_gender IS NOT NULL
     AND v_referrer_gender != v_referred_gender THEN

    -- Grant 7 days premium to referrer
    UPDATE users SET
      subscription_status = CASE
        WHEN subscription_status = 'active' THEN 'active'  -- Don't downgrade
        ELSE 'active'
      END,
      subscription_expires_at = CASE
        WHEN subscription_expires_at IS NOT NULL AND subscription_expires_at > NOW()
        THEN subscription_expires_at + INTERVAL '7 days'  -- Extend existing
        ELSE NOW() + INTERVAL '7 days'  -- New premium period
      END
    WHERE id = v_referral.referrer_id;

    -- Mark reward as granted
    UPDATE referrals SET
      reward_granted = true,
      reward_type = '7_days_premium'
    WHERE id = v_referral.id;

    -- Notify the referrer
    PERFORM queue_notification(
      v_referral.referrer_id,
      'referral_reward',
      '🎉 Referral reward!',
      'Your referral completed their profile! You''ve earned 7 days of free premium.',
      'noor://settings/subscription'
    );
  ELSE
    -- Same gender referral: mark as completed but no reward
    UPDATE referrals SET
      reward_granted = true,
      reward_type = 'same_gender_no_reward'
    WHERE id = v_referral.id;

    -- Still thank them
    PERFORM queue_notification(
      v_referral.referrer_id,
      'referral_completed',
      'Referral joined!',
      'Your referral completed their profile. Refer someone of the opposite gender to earn premium!',
      'noor://settings/referral'
    );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE TRIGGER trg_check_referral_reward
  AFTER UPDATE OF onboarding_step ON profiles
  FOR EACH ROW
  WHEN (NEW.onboarding_step >= 14 AND OLD.onboarding_step < 14)
  EXECUTE FUNCTION check_referral_reward();

-- ── 6. RLS policies ──────────────────────────────────────────
ALTER TABLE referral_codes ENABLE ROW LEVEL SECURITY;
ALTER TABLE referrals ENABLE ROW LEVEL SECURITY;

CREATE POLICY referral_codes_select ON referral_codes
  FOR SELECT USING (owner_id = auth.uid());

CREATE POLICY referrals_select ON referrals
  FOR SELECT USING (
    referrer_id = auth.uid() OR referred_id = auth.uid()
  );
