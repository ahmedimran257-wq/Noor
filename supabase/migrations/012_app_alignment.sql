-- ============================================================
-- MIGRATION 012: APP ALIGNMENT
-- Resolves remaining Flutter ↔ Supabase schema gaps.
--
-- 1. profiles: add employment_status (exists in OnboardingData)
-- 2. interests: add note column (D1 interest note feature)
-- 3. profiles: extend visibility CHECK to include 'pending_review'
-- ============================================================

-- ============================================================
-- 1. PROFILES — employment_status
-- OnboardingData.employmentStatus enum exists in Flutter but
-- has no corresponding DB column. Maps to:
--   employed | self_employed | student | not_working
-- ============================================================

ALTER TABLE profiles ADD COLUMN IF NOT EXISTS employment_status text
  CHECK (employment_status IN ('employed','self_employed','student','not_working'));

COMMENT ON COLUMN profiles.employment_status IS
  'Employment status collected during onboarding Step 6 (Background). '
  'Maps to Flutter EmploymentStatus enum values.';

-- ============================================================
-- 2. INTERESTS — note (D1: Interest Note feature)
-- Optional 150-char personal message attached to an interest.
-- Dramatically improves response rates over cold pings.
-- ============================================================

ALTER TABLE interests ADD COLUMN IF NOT EXISTS note text
  CHECK (char_length(note) <= 150);

COMMENT ON COLUMN interests.note IS
  'Optional personal note (max 150 chars) sent with an interest request. '
  'Displayed on the received interest card. Content-filtered client-side '
  'before insertion.';

-- ============================================================
-- 3. PROFILES — Extend visibility CHECK for pending_review + deactivated
-- After onboarding completion, profiles enter 'pending_review'
-- state until NSFW scan clears photos. Realtime listener in
-- Flutter routes to home when visibility flips to 'visible'.
-- 'deactivated' = user voluntarily left via "I Found My Match" (D4).
-- ============================================================

ALTER TABLE profiles DROP CONSTRAINT IF EXISTS profiles_visibility_check;
ALTER TABLE profiles ADD CONSTRAINT profiles_visibility_check
  CHECK (visibility IN ('visible','paused','suspended','pending_review','deactivated'));

-- Update the default to remain 'visible' (pending_review is set
-- explicitly by the onboarding completion flow, not as default).

COMMENT ON CONSTRAINT profiles_visibility_check ON profiles IS
  'Extended to include pending_review (T4 moderation queue) and '
  'deactivated (D4 voluntary "I Found My Match"). '
  'Profiles in pending_review/deactivated are excluded from discovery_pool.';

-- ============================================================
-- 4. PROFILES — deactivation_reason (D4: "I Found My Match")
-- Distinguishes voluntary deactivation from admin suspension.
-- Used for analytics and potential re-activation flows.
-- ============================================================

ALTER TABLE profiles ADD COLUMN IF NOT EXISTS deactivation_reason text
  CHECK (deactivation_reason IN ('found_match','personal','other'));

COMMENT ON COLUMN profiles.deactivation_reason IS
  'Set when user voluntarily deactivates via D4 "I Found My Match" button. '
  'NULL when profile is active. Analytics: track conversion to found_match.';

-- ============================================================
-- 5. Note: Language Selection → users.preferred_language
-- The LanguageSelectionScreen persists locale to SharedPreferences
-- locally. On backend wiring, the setLocale() flow should ALSO
-- upsert `users.preferred_language = <code>` so the server can
-- use it for push notification localization.
--
-- No schema change needed — users.preferred_language already
-- exists (migration 003, line 16).
-- ============================================================

-- ============================================================
-- 6. Note: profiles.completeness_score
-- The D5 profile completeness gate (G11) uses client-side
-- calculation. On backend wiring, the onboarding completion
-- flow should SET profiles.completeness_score so the server
-- can use it for feed ranking.
--
-- No schema change needed — profiles.completeness_score already
-- exists (migration 003, line 147).
-- ============================================================

-- NOTE: discovery_pool already filters `WHERE p.visibility = 'visible'`
-- so pending_review and deactivated profiles are automatically excluded
-- from the feed. No MV recreation needed for this migration.

