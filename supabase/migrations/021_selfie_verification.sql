-- ============================================================
-- MIGRATION 021: SELFIE VERIFICATION (ML Kit Challenge-Response)
--
-- Replaces the third-party KYC approach (Persona/Sumsub/Ballerine)
-- with an automated on-device selfie verification system.
--
-- Google ML Kit Face Detection runs entirely on-device (free).
-- A random challenge (smile, turn left/right, look up/down) is
-- presented; the app validates the Euler angles / classification
-- before marking the profile as verified.
--
-- No manual admin review. No external APIs. No cost.
--
-- Changes:
--   1. Drop identity_verifications table + triggers (old approach)
--   2. Add verification columns to profiles table
--   3. Create submit_selfie_verification() RPC
--   4. Update discovery_pool MV to include verification_status
-- ============================================================

-- ── 1. Drop old identity verification infrastructure ─────────
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'identity_verifications') THEN
    DROP TRIGGER IF EXISTS trg_sync_verification_status_insert ON identity_verifications;
    DROP TRIGGER IF EXISTS trg_sync_verification_status ON identity_verifications;
  END IF;
END $$;
DROP FUNCTION IF EXISTS sync_verification_status();
DROP FUNCTION IF EXISTS request_verification(text);
DROP FUNCTION IF EXISTS expire_old_verifications();

-- Remove the cron job for expiring verifications
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    PERFORM cron.unschedule('expire_old_verifications_monthly');
  END IF;
EXCEPTION
  WHEN OTHERS THEN NULL;
END $$;

DROP TABLE IF EXISTS identity_verifications CASCADE;


-- ── 2. Add verification columns to profiles ──────────────────
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS verification_status text NOT NULL DEFAULT 'unverified'
    CHECK (verification_status IN ('unverified', 'verified')),
  ADD COLUMN IF NOT EXISTS verification_attempts integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS verification_photo_url text,
  ADD COLUMN IF NOT EXISTS verification_challenge text,
  ADD COLUMN IF NOT EXISTS verified_at timestamptz;

COMMENT ON COLUMN profiles.verification_status IS
  'Selfie verification status. Set to ''verified'' after the user '
  'completes an ML Kit challenge-response selfie (smile, turn head, etc). '
  'Not true identity/KYC verification — proves a real person, not legal identity.';

COMMENT ON COLUMN profiles.verification_attempts IS
  'Number of verification attempts today. Resets daily. Max 5 per day.';

COMMENT ON COLUMN profiles.verification_photo_url IS
  'Supabase Storage path of the challenge selfie that passed verification.';

COMMENT ON COLUMN profiles.verification_challenge IS
  'The challenge that was completed: smile, turn_left, turn_right, look_up, look_down.';

COMMENT ON COLUMN profiles.verified_at IS
  'Timestamp when the profile was successfully verified via selfie challenge.';

-- Index for filtering verified profiles in discovery
CREATE INDEX IF NOT EXISTS idx_profiles_verification_status
  ON profiles(verification_status)
  WHERE verification_status = 'verified';


-- ── 3. Submit selfie verification RPC ────────────────────────
-- Called by Flutter after ML Kit validates the challenge on-device.
-- The server trusts the client validation (ML Kit runs on-device)
-- but enforces rate limits and state transitions.
-- ================================================================
CREATE OR REPLACE FUNCTION submit_selfie_verification(
  p_challenge  text,
  p_photo_path text
)
RETURNS jsonb AS $$
DECLARE
  v_user_id   uuid;
  v_profile   profiles%ROWTYPE;
  v_today     date := CURRENT_DATE;
BEGIN
  v_user_id := auth.uid();

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required.';
  END IF;

  -- Fetch profile
  SELECT * INTO v_profile
  FROM profiles WHERE user_id = v_user_id;

  IF v_profile IS NULL THEN
    RAISE EXCEPTION 'Profile not found.';
  END IF;

  -- Already verified
  IF v_profile.verification_status = 'verified' THEN
    RETURN jsonb_build_object(
      'status', 'already_verified',
      'verified_at', v_profile.verified_at
    );
  END IF;

  -- Rate limit: max 5 attempts per day
  -- Reset counter if last attempt was a different day
  IF v_profile.verified_at IS NULL AND v_profile.verification_attempts >= 5 THEN
    -- Check if attempts are from today by looking at updated_at
    IF v_profile.updated_at::date = v_today THEN
      RETURN jsonb_build_object(
        'status', 'max_attempts_reached',
        'message', 'Maximum 5 verification attempts per day. Please try again tomorrow.'
      );
    ELSE
      -- New day: reset counter
      UPDATE profiles
      SET verification_attempts = 0
      WHERE user_id = v_user_id;
    END IF;
  END IF;

  -- Mark as verified
  UPDATE profiles
  SET verification_status   = 'verified',
      verification_attempts = verification_attempts + 1,
      verification_photo_url = p_photo_path,
      verification_challenge = p_challenge,
      verified_at            = NOW(),
      is_verified            = true
  WHERE user_id = v_user_id;

  -- Send notification
  PERFORM queue_notification(
    v_user_id,
    'verification_approved',
    '✅ Profile Verified!',
    'Your identity has been verified. Verified profiles receive more interest and rank higher in search.',
    'mithaq://profile'
  );

  RETURN jsonb_build_object(
    'status', 'verified',
    'verified_at', NOW()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

COMMENT ON FUNCTION submit_selfie_verification IS
  'Marks a profile as verified after the client completes an ML Kit '
  'challenge-response selfie. Enforces max 5 attempts/day. The ML Kit '
  'validation runs on-device (free); the server trusts the client result '
  'but enforces rate limits and state transitions.';


-- ── 4. Record failed attempt RPC ─────────────────────────────
-- Called when the selfie fails ML Kit validation on-device.
-- Increments the attempt counter for rate limiting.
-- ================================================================
CREATE OR REPLACE FUNCTION record_failed_verification_attempt()
RETURNS jsonb AS $$
DECLARE
  v_user_id    uuid;
  v_profile    profiles%ROWTYPE;
  v_today      date := CURRENT_DATE;
  v_new_count  integer;
BEGIN
  v_user_id := auth.uid();

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required.';
  END IF;

  SELECT * INTO v_profile
  FROM profiles WHERE user_id = v_user_id;

  IF v_profile IS NULL THEN
    RAISE EXCEPTION 'Profile not found.';
  END IF;

  IF v_profile.verification_status = 'verified' THEN
    RETURN jsonb_build_object('status', 'already_verified');
  END IF;

  -- Reset counter if new day
  IF v_profile.updated_at::date < v_today THEN
    v_new_count := 1;
  ELSE
    v_new_count := v_profile.verification_attempts + 1;
  END IF;

  UPDATE profiles
  SET verification_attempts = v_new_count
  WHERE user_id = v_user_id;

  RETURN jsonb_build_object(
    'status', 'attempt_recorded',
    'attempts_today', v_new_count,
    'remaining', GREATEST(0, 5 - v_new_count)
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;


-- ── 5. Refresh discovery pool to pick up new columns ─────────
-- The discovery_pool MV already exposes is_verified (bool).
-- verification_status is redundant in the MV since is_verified
-- already serves the filter. No MV rebuild needed.
-- Just refresh to pick up any profile changes.
REFRESH MATERIALIZED VIEW CONCURRENTLY discovery_pool;
