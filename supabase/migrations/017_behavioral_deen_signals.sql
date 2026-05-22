-- ============================================================
-- MIGRATION 017: BEHAVIORAL DEEN (RELIGIOSITY) SIGNALS
--
-- Fixes Audit Finding 1.1 (High):
--   deen_level labels ('practicing','moderate','cultural') are
--   subjective. Replaces abstract labels with concrete behavioral
--   questions that reveal actual lifestyle compatibility.
--
-- Changes:
--   1. Add behavioral signal columns to profiles
--   2. Add matching preference columns to profile_preferences
--   3. Update discovery_pool MV to include new columns
-- ============================================================

-- ── 1. Behavioral signal columns on profiles ──────────────────
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS listens_to_music text
    CHECK (listens_to_music IN ('yes','no','sometimes','prefer_not_to_say')),
  ADD COLUMN IF NOT EXISTS eats_zabiha_only boolean,
  ADD COLUMN IF NOT EXISTS attends_islamic_classes boolean,
  ADD COLUMN IF NOT EXISTS reads_quran_daily boolean,
  ADD COLUMN IF NOT EXISTS celebrates_mawlid text
    CHECK (celebrates_mawlid IN ('yes','no','neutral','prefer_not_to_say')),
  ADD COLUMN IF NOT EXISTS watches_movies boolean,
  ADD COLUMN IF NOT EXISTS gender_mixing_stance text
    CHECK (gender_mixing_stance IN ('strict_separation','limited','relaxed','prefer_not_to_say'));

COMMENT ON COLUMN profiles.listens_to_music IS
  'Behavioral deen signal. Concrete question replacing subjective '
  'deen_level labels. Helps match users with compatible lifestyle views.';

COMMENT ON COLUMN profiles.eats_zabiha_only IS
  'Whether the user eats strictly Zabiha-slaughtered meat only. '
  'Key lifestyle compatibility signal for practicing Muslims.';

COMMENT ON COLUMN profiles.reads_quran_daily IS
  'Whether the user reads/recites Quran daily. Concrete behavioral '
  'signal that supplements the abstract deen_level field.';

COMMENT ON COLUMN profiles.gender_mixing_stance IS
  'User''s stance on gender interaction in social/professional settings. '
  'Important cultural compatibility signal, especially for diaspora Muslims.';

-- ── 2. Matching preference columns ────────────────────────────
ALTER TABLE profile_preferences
  ADD COLUMN IF NOT EXISTS pref_music_stance text
    CHECK (pref_music_stance IN ('same_as_mine','no_preference')),
  ADD COLUMN IF NOT EXISTS pref_zabiha_only text
    CHECK (pref_zabiha_only IN ('yes','no_preference')),
  ADD COLUMN IF NOT EXISTS pref_quran_daily text
    CHECK (pref_quran_daily IN ('yes','no_preference')),
  ADD COLUMN IF NOT EXISTS pref_gender_mixing text
    CHECK (pref_gender_mixing IN ('same_as_mine','no_preference'));

-- ── 3. Recreate discovery_pool MV with new columns ────────────
-- Must drop and recreate since ALTER on MVs is not supported.
-- ================================================================
DROP MATERIALIZED VIEW IF EXISTS discovery_pool;

CREATE MATERIALIZED VIEW discovery_pool AS
SELECT
  p.id                                               AS profile_id,
  p.user_id,
  p.gender,
  p.visibility,
  p.onboarding_step,
  p.first_name,
  LEFT(p.last_name, 1)                               AS last_name_initial,
  EXTRACT(YEAR FROM age(p.date_of_birth))::integer   AS age,
  c.name                                             AS city_name,
  p.country_code,
  c.id                                               AS city_id,
  p.sect::text,
  p.sub_sect,
  p.deen_level::text,
  p.profession,
  p.bio,
  p.static_rank_score                                AS rank_score,
  p.last_active_at,
  p.location,
  ST_Y(p.location::geometry)                         AS lat,
  ST_X(p.location::geometry)                         AS lng,
  p.photo_privacy::text,
  p.is_verified,
  p.education_rank,
  p.height_cm,
  p.date_of_birth,
  p.approved_at,
  p.is_boosted,
  p.boost_expires_at,
  -- From migration 010
  p.complexion,
  p.mother_tongue,
  p.community,
  p.residency_status,
  p.diet_type,
  p.smoking_habit,
  p.quran_memorization,
  p.religious_education,
  p.marriage_timeline,
  p.willing_to_relocate,
  p.living_expectation,
  p.is_revert,
  p.special_needs,
  p.previously_married,
  p.children_count,
  p.family_type,
  p.niqab_preference,
  p.mahr_expectation,
  p.mahr_budget,
  p.can_provide_housing,
  p.can_provide_maintenance,
  p.polygamy_status,
  -- NEW from migration 017: behavioral deen signals
  p.listens_to_music,
  p.eats_zabiha_only,
  p.attends_islamic_classes,
  p.reads_quran_daily,
  p.celebrates_mawlid,
  p.watches_movies,
  p.gender_mixing_stance,
  -- Photo data
  (
    SELECT COUNT(*)::integer
    FROM photos ph
    WHERE ph.profile_id = p.id
      AND ph.admin_approved = true
      AND ph.nsfw_cleared   = true
  )                                                  AS photo_count,
  (
    SELECT CASE WHEN p.photo_privacy = 'public' THEN ph.storage_path ELSE NULL END
    FROM photos ph
    WHERE ph.profile_id   = p.id
      AND ph.order_index  = 0
      AND ph.admin_approved = true
      AND ph.nsfw_cleared   = true
    LIMIT 1
  )                                                  AS photo_url,
  -- Preference fields
  pr.diaspora_mode,
  pr.open_to_diaspora,
  pr.preferred_countries,
  pr.preferred_age_min,
  pr.preferred_age_max,
  pr.min_education_rank,
  pr.deen_preference,
  pr.preferred_mother_tongue,
  pr.preferred_community,
  pr.preferred_height_min,
  pr.preferred_height_max,
  pr.preferred_marriage_timeline,
  pr.preferred_relocation,
  pr.preferred_living_expectation,
  pr.polygamy_acceptance  AS pref_polygamy_acceptance,
  pr.revert_acceptance,
  pr.special_needs_acceptance,
  -- NEW: behavioral deen preferences
  pr.pref_music_stance,
  pr.pref_zabiha_only,
  pr.pref_quran_daily,
  pr.pref_gender_mixing
FROM profiles p
JOIN cities c ON p.city_id = c.id
JOIN profile_preferences pr ON p.id = pr.profile_id
WHERE p.visibility    = 'visible'
  AND p.onboarding_step >= 14;

-- Recreate indexes
CREATE UNIQUE INDEX idx_discovery_pool_id       ON discovery_pool(profile_id);
CREATE INDEX         idx_discovery_pool_location ON discovery_pool USING GIST (location);
CREATE INDEX         idx_discovery_pool_rank     ON discovery_pool(rank_score DESC, profile_id DESC);
CREATE INDEX         idx_discovery_pool_gender   ON discovery_pool(gender);
CREATE INDEX         idx_discovery_pool_country  ON discovery_pool(country_code);

COMMENT ON MATERIALIZED VIEW discovery_pool IS
  'V3: Includes behavioral deen signals (music stance, zabiha, quran daily, '
  'gender mixing) from migration 017. These concrete behavioral questions '
  'supplement the subjective deen_level labels for better compatibility matching.';
