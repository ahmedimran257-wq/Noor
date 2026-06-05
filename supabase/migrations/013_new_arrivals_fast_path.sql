-- ============================================================
-- MIGRATION 013: NEW ARRIVALS FAST-PATH
--
-- Fixes Audit Finding 2.1 (Critical):
--   New users waiting 24h to appear in the discovery feed
--   kills Day-1 retention. This migration decouples new users
--   from the nightly batch MV refresh by adding a real-time
--   "new arrivals" query UNIONed into the discovery feed.
--
-- Strategy:
--   1. Add an index for fast new-arrival lookups
--   2. Create get_new_arrivals() — queries base tables directly
--   3. Replace get_discovery_feed() with a version that UNIONs
--      the materialized view WITH new arrivals
-- ============================================================

-- ── 1. Index for fast new-arrival lookups ─────────────────────
CREATE INDEX IF NOT EXISTS idx_profiles_approved_recent
  ON profiles(approved_at DESC)
  WHERE visibility = 'visible'
    AND onboarding_step >= 14
    AND approved_at IS NOT NULL;

COMMENT ON INDEX idx_profiles_approved_recent IS
  'Supports the get_new_arrivals() fast-path query. Covers profiles '
  'approved in the last 48 hours that are not yet in the nightly '
  'discovery_pool materialized view.';

-- ── 2. get_new_arrivals() — Real-time query for fresh profiles ─
-- Returns the same column shape as discovery_pool so it can be
-- UNIONed seamlessly. Only queries profiles approved in the
-- last 48 hours — after that, the nightly MV takes over.
-- ================================================================
CREATE OR REPLACE FUNCTION get_new_arrivals(
  p_viewer_gender text,
  p_viewer_id     uuid
)
RETURNS TABLE(
  profile_id          uuid,
  user_id             uuid,
  gender              text,
  first_name          text,
  last_name_initial   text,
  age                 integer,
  city_name           text,
  country_code        text,
  sect                text,
  deen_level          text,
  profession          text,
  bio                 text,
  photo_url           text,
  photo_count         integer,
  photo_privacy       text,
  is_verified         boolean,
  rank_score          double precision,
  last_active_at      timestamptz,
  location            geography,
  marriage_timeline   text,
  -- Preference fields for feed filtering
  diaspora_mode       boolean,
  open_to_diaspora    boolean,
  preferred_countries text[],
  preferred_age_min   int,
  preferred_age_max   int,
  education_rank      int,
  date_of_birth       date,
  previously_married  text,
  children_count      int,
  family_type         text,
  mother_tongue       text,
  community           text,
  living_expectation  text,
  quran_memorization  text,
  willing_to_relocate text,
  is_boosted          boolean,
  boost_expires_at    timestamptz
)
AS $$
BEGIN
  RETURN QUERY
  SELECT
    p.id                                               AS profile_id,
    p.user_id,
    p.gender,
    p.first_name,
    LEFT(p.last_name, 1)                               AS last_name_initial,
    EXTRACT(YEAR FROM age(p.date_of_birth))::integer   AS age,
    c.name                                             AS city_name,
    p.country_code,
    p.sect::text,
    p.deen_level::text,
    p.profession,
    p.bio,
    (
      SELECT CASE WHEN p.photo_privacy = 'public' THEN ph.storage_path ELSE NULL END
      FROM photos ph
      WHERE ph.profile_id   = p.id
        AND ph.order_index  = 0
        AND ph.admin_approved = true
        AND ph.nsfw_cleared   = true
      LIMIT 1
    )                                                  AS photo_url,
    (
      SELECT COUNT(*)::integer
      FROM photos ph
      WHERE ph.profile_id = p.id
        AND ph.admin_approved = true
        AND ph.nsfw_cleared   = true
    )                                                  AS photo_count,
    p.photo_privacy::text,
    p.is_verified,
    -- New arrivals get a +15 rank bonus so they appear near the top
    (COALESCE(p.static_rank_score, 0) + 15)::double precision AS rank_score,
    p.last_active_at,
    p.location,
    p.marriage_timeline,
    -- Preference fields
    pr.diaspora_mode,
    pr.open_to_diaspora,
    pr.preferred_countries,
    pr.preferred_age_min,
    pr.preferred_age_max,
    p.education_rank,
    p.date_of_birth,
    p.previously_married,
    p.children_count,
    p.family_type,
    p.mother_tongue,
    p.community,
    p.living_expectation,
    p.quran_memorization,
    p.willing_to_relocate,
    p.is_boosted,
    p.boost_expires_at
  FROM profiles p
  JOIN cities c ON p.city_id = c.id
  LEFT JOIN profile_preferences pr ON p.id = pr.profile_id
  WHERE p.visibility      = 'visible'
    AND p.onboarding_step >= 14
    AND p.approved_at     IS NOT NULL
    AND p.approved_at     > NOW() - INTERVAL '48 hours'
    AND p.gender         != p_viewer_gender
    AND p.user_id        != p_viewer_id
    -- Exclude profiles already in the MV (avoid duplicates)
    AND NOT EXISTS (
      SELECT 1 FROM discovery_pool dp WHERE dp.profile_id = p.id
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

COMMENT ON FUNCTION get_new_arrivals IS
  'Real-time fast-path for profiles approved in the last 48 hours. '
  'Bypasses the nightly discovery_pool MV refresh to ensure new users '
  'appear in the feed within minutes of onboarding completion. '
  'Returns the same column shape as discovery_pool for seamless UNION.';

-- ── 3. Replace get_discovery_feed() — UNION with new arrivals ──
-- This replaces the version from migration 011.
-- The ONLY change is: we UNION the MV with get_new_arrivals()
-- before applying filters, so fresh profiles appear immediately.
-- ================================================================
DROP FUNCTION IF EXISTS get_discovery_feed(uuid, double precision, uuid, integer, jsonb);

CREATE OR REPLACE FUNCTION get_discovery_feed(
  p_viewer_id    uuid,
  p_cursor_score double precision DEFAULT NULL,
  p_cursor_id    uuid DEFAULT NULL,
  p_page_size    integer DEFAULT 10,
  p_filters      jsonb DEFAULT '{}'::jsonb
)
RETURNS TABLE(
  profile_id    uuid,
  first_name    text,
  last_name_initial text,
  age           integer,
  city_name     text,
  country_code  text,
  sect          text,
  deen_level    text,
  profession    text,
  bio           text,
  photo_url     text,
  photo_count   integer,
  photo_privacy text,
  is_verified   boolean,
  distance_km   double precision,
  rank_score    double precision,
  marriage_timeline text
)
AS $$
DECLARE
  v_sub_status      text;
  v_profile         profiles%ROWTYPE;
  v_prefs           profile_preferences%ROWTYPE;
  -- Parsed filter params
  v_max_km          int;
  v_active_recently boolean;
  v_age_min         int;
  v_age_max         int;
  v_sect            text;
  v_deen_level      text;
  v_verified_only   boolean;
  v_family_type     text;
  v_marital_status  text;
  v_education_min   int;
  v_mother_tongue   text;
  v_community       text;
  v_living_exp      text;
  v_quran_mem       text;
  v_marriage_tl     text;
  v_relocate        text;
  v_has_children    text;
  v_open_divorced   boolean;
BEGIN
  -- Subscription check: free tier page size capped at 15
  SELECT subscription_status INTO v_sub_status FROM users WHERE id = p_viewer_id;

  IF v_sub_status != 'active' AND p_page_size > 15 THEN
    RAISE EXCEPTION 'Page size exceeds free-tier limit of 15.';
  END IF;

  -- Load viewer's profile + preferences
  SELECT * INTO v_profile FROM profiles WHERE user_id = p_viewer_id;
  SELECT * INTO v_prefs   FROM profile_preferences WHERE profile_id = v_profile.id;

  IF v_profile.visibility = 'suspended' THEN
    RAISE EXCEPTION 'Account suspended. Contact support.';
  END IF;

  -- Parse filter params from jsonb
  v_max_km          := LEAST(COALESCE((p_filters->>'max_distance_km')::int, 20000), 20000);
  v_active_recently := COALESCE((p_filters->>'active_recently')::boolean, false);
  v_age_min         := (p_filters->>'age_min')::int;
  v_age_max         := (p_filters->>'age_max')::int;
  v_sect            := p_filters->>'sect';
  v_deen_level      := p_filters->>'deen_level';
  v_verified_only   := COALESCE((p_filters->>'verified_only')::boolean, false);
  v_family_type     := p_filters->>'family_type';
  v_marital_status  := p_filters->>'marital_status';
  v_education_min   := (p_filters->>'education_min')::int;
  v_mother_tongue   := p_filters->>'mother_tongue';
  v_community       := p_filters->>'community';
  v_living_exp      := p_filters->>'living_expectation';
  v_quran_mem       := p_filters->>'quran_memorization';
  v_marriage_tl     := p_filters->>'marriage_timeline';
  v_relocate        := p_filters->>'willing_to_relocate';
  v_has_children    := p_filters->>'has_children';
  v_open_divorced   := COALESCE((p_filters->>'open_to_divorced')::boolean, false);

  RETURN QUERY
  -- ── CTE: Merge materialized view with real-time new arrivals ──
  WITH combined_pool AS (
    -- Existing materialized view (bulk of profiles)
    SELECT
      dp.profile_id,
      dp.user_id,
      dp.gender,
      dp.first_name,
      dp.last_name_initial,
      dp.age,
      dp.city_name,
      dp.country_code,
      dp.sect,
      dp.deen_level,
      dp.profession,
      dp.bio,
      dp.photo_url,
      dp.photo_count,
      dp.photo_privacy,
      dp.is_verified,
      dp.rank_score,
      dp.last_active_at,
      dp.location,
      dp.marriage_timeline,
      dp.diaspora_mode,
      dp.open_to_diaspora,
      dp.preferred_countries,
      dp.previously_married,
      dp.education_rank,
      dp.children_count,
      dp.family_type,
      dp.mother_tongue,
      dp.community,
      dp.living_expectation,
      dp.quran_memorization,
      dp.willing_to_relocate
    FROM discovery_pool dp
    WHERE dp.user_id != p_viewer_id
      AND dp.gender != v_profile.gender

    UNION ALL

    -- Real-time new arrivals (profiles from last 48h not yet in MV)
    SELECT
      na.profile_id,
      na.user_id,
      na.gender,
      na.first_name,
      na.last_name_initial,
      na.age,
      na.city_name,
      na.country_code,
      na.sect,
      na.deen_level,
      na.profession,
      na.bio,
      na.photo_url,
      na.photo_count,
      na.photo_privacy,
      na.is_verified,
      na.rank_score,
      na.last_active_at,
      na.location,
      na.marriage_timeline,
      na.diaspora_mode,
      na.open_to_diaspora,
      na.preferred_countries,
      na.previously_married,
      na.education_rank,
      na.children_count,
      na.family_type,
      na.mother_tongue,
      na.community,
      na.living_expectation,
      na.quran_memorization,
      na.willing_to_relocate
    FROM get_new_arrivals(v_profile.gender, p_viewer_id) na
  )
  SELECT
    cp.profile_id,
    cp.first_name,
    cp.last_name_initial,
    cp.age,
    cp.city_name,
    cp.country_code,
    cp.sect,
    cp.deen_level,
    cp.profession,
    cp.bio,
    cp.photo_url,
    cp.photo_count,
    cp.photo_privacy,
    cp.is_verified,
    -- Distance in km (null if location unavailable)
    CASE
      WHEN v_profile.location IS NOT NULL AND cp.location IS NOT NULL THEN
        ROUND((ST_Distance(cp.location, v_profile.location) / 1000.0)::numeric, 1)::double precision
      ELSE NULL
    END AS distance_km,
    cp.rank_score,
    cp.marriage_timeline
  FROM combined_pool cp
  WHERE
    -- Exclude blocks in both directions
    NOT EXISTS (
      SELECT 1 FROM blocks b
      WHERE (b.blocker_id = p_viewer_id AND b.blocked_id = cp.user_id)
         OR (b.blocker_id = cp.user_id  AND b.blocked_id = p_viewer_id)
    )

    -- Location / diaspora filter
    AND (
      (
        v_prefs.diaspora_mode = true
        AND (
          v_prefs.preferred_countries IS NULL
          OR cp.country_code = ANY(v_prefs.preferred_countries)
        )
        AND cp.open_to_diaspora = true
      )
      OR
      (
        v_prefs.diaspora_mode = false
        AND (
          v_max_km IS NULL
          OR v_profile.location IS NULL
          OR cp.location IS NULL
          OR ST_DWithin(cp.location, v_profile.location, v_max_km * 1000)
        )
      )
    )

    -- Recency filter
    AND (
      v_active_recently = false
      OR cp.last_active_at > NOW() - INTERVAL '7 days'
    )

    -- ── Extended filters ─────────────────────────────────
    AND (v_age_min IS NULL OR cp.age >= v_age_min)
    AND (v_age_max IS NULL OR cp.age <= v_age_max)
    AND (v_sect IS NULL OR cp.sect = v_sect)
    AND (v_deen_level IS NULL OR cp.deen_level = v_deen_level)
    AND (v_verified_only = false OR cp.is_verified = true)
    AND (v_family_type IS NULL OR cp.family_type = v_family_type)
    AND (v_marital_status IS NULL OR cp.previously_married = v_marital_status)
    AND (v_education_min IS NULL OR cp.education_rank >= v_education_min)
    AND (v_mother_tongue IS NULL OR cp.mother_tongue = v_mother_tongue)
    AND (v_community IS NULL OR cp.community = v_community)
    AND (v_living_exp IS NULL OR cp.living_expectation = v_living_exp)
    AND (v_quran_mem IS NULL OR cp.quran_memorization = v_quran_mem)
    AND (v_marriage_tl IS NULL OR cp.marriage_timeline = v_marriage_tl)
    AND (v_relocate IS NULL OR cp.willing_to_relocate = v_relocate)
    AND (v_has_children IS NULL OR
      CASE v_has_children
        WHEN 'yes' THEN cp.children_count > 0
        WHEN 'no'  THEN COALESCE(cp.children_count, 0) = 0
        ELSE true
      END
    )
    AND (
      v_open_divorced = true
      OR cp.previously_married IS NULL
      OR cp.previously_married = 'no'
    )

    -- Cursor-based pagination
    AND (
      p_cursor_score IS NULL
      OR (cp.rank_score < p_cursor_score)
      OR (cp.rank_score = p_cursor_score AND cp.profile_id < p_cursor_id)
    )

  ORDER BY cp.rank_score DESC, cp.profile_id DESC
  LIMIT p_page_size;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

COMMENT ON FUNCTION get_discovery_feed IS
  'V3: UNIONs the nightly discovery_pool MV with real-time new arrivals '
  '(profiles approved in the last 48 hours). New arrivals get a +15 rank '
  'bonus to ensure immediate Day-1 visibility. Now also returns '
  'marriage_timeline for feed card display.';
