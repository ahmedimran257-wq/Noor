-- ============================================================
-- MIGRATION 043: EMAIL OTP AUTH IDENTIFIER
-- Supabase email OTP replaces Firebase/SMS phone OTP for signup/signin.
-- Phone is optional and collected later for premium trust verification.
-- ============================================================

ALTER TABLE users
  ADD COLUMN IF NOT EXISTS email text;

ALTER TABLE users
  ALTER COLUMN phone DROP NOT NULL,
  ALTER COLUMN country_code DROP NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS idx_users_email_lower
  ON users (lower(email))
  WHERE email IS NOT NULL;

DROP INDEX IF EXISTS idx_users_phone;
CREATE UNIQUE INDEX IF NOT EXISTS idx_users_phone
  ON users(phone)
  WHERE phone IS NOT NULL;

COMMENT ON COLUMN users.email IS
  'Supabase email OTP auth identifier. Replaces phone as the signup/signin identifier.';

COMMENT ON COLUMN users.phone IS
  'Optional phone verification contact, collected later for premium trust verification. Not used for signup SMS OTP.';

DROP POLICY IF EXISTS users_insert_own ON users;
CREATE POLICY users_insert_own ON users
  FOR INSERT
  WITH CHECK (id = auth.uid());
