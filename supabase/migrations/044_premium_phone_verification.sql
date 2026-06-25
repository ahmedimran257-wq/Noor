-- ============================================================
-- MIGRATION 044: PREMIUM PHONE VERIFICATION
-- Phone is collected only for paid trust verification, not signup.
-- ============================================================

ALTER TABLE users
  ADD COLUMN IF NOT EXISTS phone_country_code text,
  ADD COLUMN IF NOT EXISTS phone_verified_at timestamptz;

COMMENT ON COLUMN users.phone_country_code IS
  'ISO country code for the optional premium phone verification number.';

COMMENT ON COLUMN users.phone_verified_at IS
  'Set after Supabase phone-change OTP succeeds before premium purchase.';
