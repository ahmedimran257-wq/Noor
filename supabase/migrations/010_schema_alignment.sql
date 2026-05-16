-- ============================================================
-- MIGRATION 010: SCHEMA ALIGNMENT
-- Resolves the OnboardingData ↔ Supabase contract gap.
--
-- 1. profiles: add ~30 missing columns collected by Flutter
-- 2. profile_preferences: add partner preference columns
-- 3. matches: add lifecycle columns (status, closed_by, etc.)
-- 4. users: make gender nullable (collected at onboarding step 3)
-- 5. users: enable RLS
-- ============================================================

-- ============================================================
-- 1. PROFILES — Missing columns from OnboardingData
-- ============================================================

-- ── Appearance & Cultural Identity ──────────────────────────
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS complexion text
  CHECK (complexion IN ('fair','medium','olive','dark','prefer_not_to_say'));

ALTER TABLE profiles ADD COLUMN IF NOT EXISTS mother_tongue text;

ALTER TABLE profiles ADD COLUMN IF NOT EXISTS community text;

ALTER TABLE profiles ADD COLUMN IF NOT EXISTS residency_status text
  CHECK (residency_status IN (
    'citizen','permanent_resident','work_visa','student_visa','other','prefer_not_to_say'
  ));

-- ── Habits ──────────────────────────────────────────────────
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS diet_type text
  CHECK (diet_type IN (
    'zabiha_strict','halal_only','eats_anything','vegetarian','vegan'
  ));

ALTER TABLE profiles ADD COLUMN IF NOT EXISTS smoking_habit text
  CHECK (smoking_habit IN ('never','occasionally','frequently','prefer_not'));

ALTER TABLE profiles ADD COLUMN IF NOT EXISTS vaping_habit text
  CHECK (vaping_habit IN ('never','occasionally','frequently','prefer_not'));

ALTER TABLE profiles ADD COLUMN IF NOT EXISTS hookah_habit text
  CHECK (hookah_habit IN ('never','occasionally','frequently','prefer_not'));

-- ── Education (extended) ────────────────────────────────────
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS field_of_study text;

-- ── Income (visibility) ─────────────────────────────────────
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS income_visibility text
  NOT NULL DEFAULT 'visible'
  CHECK (income_visibility IN ('visible','match_only','hidden'));

-- ── Islamic Identity (extended) ─────────────────────────────
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS quran_memorization text
  CHECK (quran_memorization IN ('none','some_surahs','partial','hafiz'));

ALTER TABLE profiles ADD COLUMN IF NOT EXISTS religious_education text
  CHECK (religious_education IN (
    'self_taught','madrasa','islamic_uni','alim_course','none'
  ));

ALTER TABLE profiles ADD COLUMN IF NOT EXISTS is_revert text
  CHECK (is_revert IN ('yes','no','prefer_not_to_say'));

ALTER TABLE profiles ADD COLUMN IF NOT EXISTS religious_leadership text
  CHECK (religious_leadership IN (
    'leads_prayer','learning','not_yet','prefer_not_to_say'
  ));

-- ── Marriage Readiness ──────────────────────────────────────
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS marriage_timeline text
  CHECK (marriage_timeline IN (
    'asap','6_months','1_year','2_plus_years','not_sure'
  ));

ALTER TABLE profiles ADD COLUMN IF NOT EXISTS willing_to_relocate text
  CHECK (willing_to_relocate IN ('yes','no','open_to_discussion'));

ALTER TABLE profiles ADD COLUMN IF NOT EXISTS living_expectation text
  CHECK (living_expectation IN (
    'with_inlaws','separate','open_to_discussion'
  ));

-- ── Female-specific fields ──────────────────────────────────
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS niqab_preference text
  CHECK (niqab_preference IN (
    'wears_niqab','open_to_niqab','no_niqab','prefer_not_to_say'
  ));

ALTER TABLE profiles ADD COLUMN IF NOT EXISTS mahr_expectation text
  CHECK (mahr_expectation IN (
    'no_preference','modest','moderate','high','to_discuss'
  ));

ALTER TABLE profiles ADD COLUMN IF NOT EXISTS willing_to_work_after_marriage boolean;

ALTER TABLE profiles ADD COLUMN IF NOT EXISTS polygamy_acceptance text
  CHECK (polygamy_acceptance IN (
    'yes','no','open_to_discussion','prefer_not_to_say'
  ));

-- ── Male-specific fields ────────────────────────────────────
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS mahr_budget text
  CHECK (mahr_budget IN ('modest','moderate','generous','to_discuss'));

ALTER TABLE profiles ADD COLUMN IF NOT EXISTS can_provide_housing boolean;

ALTER TABLE profiles ADD COLUMN IF NOT EXISTS can_provide_maintenance boolean;

ALTER TABLE profiles ADD COLUMN IF NOT EXISTS debt_status text
  CHECK (debt_status IN (
    'no_debt','manageable','significant','prefer_not_to_say'
  ));

ALTER TABLE profiles ADD COLUMN IF NOT EXISTS polygamy_status text
  CHECK (polygamy_status IN (
    'first_marriage','currently_married','prefer_not_to_say'
  ));

-- ── Special Needs ───────────────────────────────────────────
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS special_needs text
  CHECK (special_needs IN (
    'none','physical','hearing','visual','other','prefer_not_to_say'
  ));

-- ── Guardian (extended) ─────────────────────────────────────
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS guardian_email text;

ALTER TABLE profiles ADD COLUMN IF NOT EXISTS guardian_authority_scope text
  CHECK (guardian_authority_scope IN ('full','advisory','limited'));

ALTER TABLE profiles ADD COLUMN IF NOT EXISTS profile_creator_relation text
  CHECK (profile_creator_relation IN ('self','parent','sibling','guardian'));

ALTER TABLE profiles ADD COLUMN IF NOT EXISTS guardian_phone_country_code text;

-- ============================================================
-- 2. PROFILE PREFERENCES — Extended partner filtering
-- ============================================================

ALTER TABLE profile_preferences
  ADD COLUMN IF NOT EXISTS preferred_mother_tongue text[],
  ADD COLUMN IF NOT EXISTS preferred_community text[],
  ADD COLUMN IF NOT EXISTS preferred_height_min int,
  ADD COLUMN IF NOT EXISTS preferred_height_max int,
  ADD COLUMN IF NOT EXISTS preferred_marriage_timeline text
    CHECK (preferred_marriage_timeline IN (
      'asap','6_months','1_year','2_plus_years','not_sure','no_preference'
    )),
  ADD COLUMN IF NOT EXISTS preferred_relocation text
    CHECK (preferred_relocation IN ('yes','no','open_to_discussion','no_preference')),
  ADD COLUMN IF NOT EXISTS preferred_living_expectation text
    CHECK (preferred_living_expectation IN (
      'with_inlaws','separate','open_to_discussion','no_preference'
    )),
  ADD COLUMN IF NOT EXISTS polygamy_acceptance text
    CHECK (polygamy_acceptance IN (
      'yes','no','open_to_discussion','no_preference'
    )),
  ADD COLUMN IF NOT EXISTS revert_acceptance text
    CHECK (revert_acceptance IN ('yes','no','no_preference')),
  ADD COLUMN IF NOT EXISTS special_needs_acceptance text
    CHECK (special_needs_acceptance IN ('yes','no','no_preference'));

-- Sensible height range constraint
ALTER TABLE profile_preferences
  ADD CONSTRAINT sensible_height_range
    CHECK (
      preferred_height_min IS NULL OR preferred_height_max IS NULL
      OR preferred_height_min <= preferred_height_max
    );

-- ============================================================
-- 3. MATCHES — Lifecycle columns
-- ============================================================

ALTER TABLE matches
  ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'active'
    CHECK (status IN ('active','closed','blocked','expired','reported')),
  ADD COLUMN IF NOT EXISTS closed_by uuid REFERENCES users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS closed_at timestamptz,
  ADD COLUMN IF NOT EXISTS closure_reason text;

-- Index for active-match queries (chat list)
CREATE INDEX IF NOT EXISTS idx_matches_status ON matches(status)
  WHERE status = 'active';

COMMENT ON COLUMN matches.status IS
  'Match lifecycle: active (chat open), closed (respectful closure by either party), '
  'blocked (via block action), expired (30-day inactivity), reported (under review). '
  'Messages become read-only when status != active.';

-- ============================================================
-- 4. USERS — Make gender nullable for auth-before-onboarding
-- ============================================================

-- Gender is collected at onboarding Step 3 (ProfileForWhom screen),
-- but the user row is created during firebase-auth-exchange which
-- only knows the phone number. Making this nullable prevents the
-- auth exchange from having to guess.
ALTER TABLE users
  ALTER COLUMN gender DROP NOT NULL;

-- Update the CHECK to allow NULL
ALTER TABLE users DROP CONSTRAINT IF EXISTS users_gender_check;
ALTER TABLE users ADD CONSTRAINT users_gender_check
  CHECK (gender IS NULL OR gender IN ('male','female'));

-- ============================================================
-- 5. USERS — Row Level Security
-- ============================================================

ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- Users can read their own row
CREATE POLICY users_select_own ON users
  FOR SELECT USING (id = auth.uid());

-- Users can update their own row (for language, timezone prefs)
CREATE POLICY users_update_own ON users
  FOR UPDATE
  USING    (id = auth.uid())
  WITH CHECK (id = auth.uid());

-- Insert is handled by the firebase-auth-exchange Edge Function
-- via service role — no direct client INSERT needed.

-- Service role (Edge Functions) bypass RLS automatically.
-- No explicit policy needed for admin operations.

-- Discovery feed and other RPCs run as SECURITY DEFINER,
-- so they can read users rows internally without RLS interference.

-- ============================================================
-- 6. UPDATE discovery_pool materialized view to include new fields
-- ============================================================

-- Drop and recreate to add new columns.
-- This is safe because the view is refreshed nightly anyway.
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
  -- New fields from migration 010
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
  -- Female-specific
  p.niqab_preference,
  p.mahr_expectation,
  -- Male-specific
  p.mahr_budget,
  p.can_provide_housing,
  p.can_provide_maintenance,
  p.polygamy_status,
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
  pr.diaspora_mode,
  pr.open_to_diaspora,
  pr.preferred_countries,
  pr.preferred_age_min,
  pr.preferred_age_max,
  pr.min_education_rank,
  pr.deen_preference,
  -- New preference fields
  pr.preferred_mother_tongue,
  pr.preferred_community,
  pr.preferred_height_min,
  pr.preferred_height_max,
  pr.preferred_marriage_timeline,
  pr.preferred_relocation,
  pr.preferred_living_expectation,
  pr.polygamy_acceptance  AS pref_polygamy_acceptance,
  pr.revert_acceptance,
  pr.special_needs_acceptance
FROM profiles p
JOIN cities c ON p.city_id = c.id
JOIN profile_preferences pr ON p.id = pr.profile_id
WHERE p.visibility    = 'visible'
  AND p.onboarding_step >= 14;

-- Recreate indexes on the new materialized view
CREATE UNIQUE INDEX idx_discovery_pool_id       ON discovery_pool(profile_id);
CREATE INDEX         idx_discovery_pool_location ON discovery_pool USING GIST (location);
CREATE INDEX         idx_discovery_pool_rank     ON discovery_pool(rank_score DESC, profile_id DESC);
CREATE INDEX         idx_discovery_pool_gender   ON discovery_pool(gender);
CREATE INDEX         idx_discovery_pool_country  ON discovery_pool(country_code);

COMMENT ON MATERIALIZED VIEW discovery_pool IS
  'Refreshed nightly (CONCURRENTLY) at 02:30 UTC. V2: includes extended profile '
  'fields (complexion, mother_tongue, community, marriage details, habits) and '
  'extended preference fields for richer server-side filtering.';
