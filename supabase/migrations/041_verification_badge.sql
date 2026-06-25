-- ============================================================
-- MIGRATION 041: VERIFICATION BADGE COLUMNS
--
-- Phase 2.5: Adds multi-pose liveness verification badge
-- to profiles. Distinct from the basic is_verified (single
-- selfie check) — the badge requires 3 sequential poses
-- within time limits, making it significantly harder to spoof.
-- ============================================================

ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS has_verification_badge boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS badge_earned_at         timestamptz,
  ADD COLUMN IF NOT EXISTS badge_pose_sequence     text[];  -- audit trail: e.g., ['smile','turnLeft','lookUp']

COMMENT ON COLUMN profiles.has_verification_badge IS
  'True if user completed the 3-pose multi-step liveness verification.';

COMMENT ON COLUMN profiles.badge_earned_at IS
  'Timestamp when the verification badge was earned.';

COMMENT ON COLUMN profiles.badge_pose_sequence IS
  'Array of pose names used during badge verification, for audit purposes.';

-- Index for the verified-only premium filter
CREATE INDEX IF NOT EXISTS idx_profiles_badge
  ON profiles(has_verification_badge) WHERE has_verification_badge = true;
