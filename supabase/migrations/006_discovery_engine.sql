-- ============================================================
-- MIGRATION 006: DISCOVERY ENGINE
-- materialized view (discovery_pool), ranking functions,
-- discovery feed RPC, name+city search RPC
-- ============================================================

-- ------------------------------------------------------------
-- DISCOVERY POOL — Materialized View
-- Pre-joins standard geographic + profile data so the
-- get_discovery_feed() RPC never hits the base tables.
-- Refreshed concurrently every night at 02:30.
-- ------------------------------------------------------------
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
  p.date_of_birth,
  p.approved_at,
  p.is_boosted,
  p.boost_expires_at,
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
  pr.deen_preference
FROM profiles p
JOIN cities c ON p.city_id = c.id
JOIN profile_preferences pr ON p.id = pr.profile_id
WHERE p.visibility    = 'visible'
  AND p.onboarding_step >= 14;

-- Indexes on the materialized view for fast feed queries
CREATE UNIQUE INDEX idx_discovery_pool_id       ON discovery_pool(profile_id);
CREATE INDEX         idx_discovery_pool_location ON discovery_pool USING GIST (location);
CREATE INDEX         idx_discovery_pool_rank     ON discovery_pool(rank_score DESC, profile_id DESC);
CREATE INDEX         idx_discovery_pool_gender   ON discovery_pool(gender);
CREATE INDEX         idx_discovery_pool_country  ON discovery_pool(country_code);

COMMENT ON MATERIALIZED VIEW discovery_pool IS
  'Refreshed nightly (CONCURRENTLY) at 02:30 UTC. Provides a pre-joined, indexed snapshot '
  'of all visible profiles for low-latency feed queries. Bypasses live base-table joins '
  'that would cause "Feed Crash" at scale with thousands of concurrent users.';

-- ------------------------------------------------------------
-- GLOBAL RANK SCORE COMPUTATION
-- Runs nightly via pg_cron. Writes to profiles.static_rank_score.
-- Discovery pool is then refreshed using this pre-computed value.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION compute_global_rank_scores()
RETURNS void AS $$
BEGIN
  UPDATE profiles p
  SET static_rank_score = (
    -- Completeness: max 20 pts
    COALESCE(p.completeness_score, 0)::float / 5.0
    -- Recency: max 20 pts
    + CASE
        WHEN p.last_active_at > NOW() - INTERVAL '1 day'   THEN 20
        WHEN p.last_active_at > NOW() - INTERVAL '7 days'  THEN 15
        WHEN p.last_active_at > NOW() - INTERVAL '30 days' THEN 8
        ELSE 2
      END
    -- New profile boost: +10 for first 7 days
    + CASE
        WHEN p.approved_at IS NOT NULL
          AND p.approved_at > NOW() - INTERVAL '7 days' THEN 10
        ELSE 0
      END
    -- Weekly subscriber boost: +5
    + CASE
        WHEN p.is_boosted = true AND p.boost_expires_at > NOW() THEN 5
        ELSE 0
      END
  )
  WHERE p.visibility = 'visible';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- ------------------------------------------------------------
-- INACTIVE PROFILE MANAGEMENT
-- Profiles inactive for 30+ days are paused automatically.
-- Users receive a push nudge before this happens (7-day warning).
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION hide_inactive_profiles()
RETURNS void AS $$
BEGIN
  UPDATE profiles
  SET visibility = 'paused'
  WHERE visibility = 'visible'
    AND (last_active_at IS NULL OR last_active_at < NOW() - INTERVAL '30 days');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- ------------------------------------------------------------
-- DISCOVERY FEED RPC
-- Called by Flutter with cursor-based pagination.
-- Queries the materialized view, never base tables.
-- ------------------------------------------------------------
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
  rank_score    double precision
)
AS $$
DECLARE
  v_sub_status     text;
  v_profile        profiles%ROWTYPE;
  v_prefs          profile_preferences%ROWTYPE;
  v_max_km         int;
  v_active_recently boolean;
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

  -- Parse optional filter params
  v_max_km         := LEAST(COALESCE((p_filters->>'max_distance_km')::int, 20000), 20000);
  v_active_recently := COALESCE((p_filters->>'active_recently')::boolean, false);

  RETURN QUERY
  SELECT
    dp.profile_id,
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
    -- Distance in km (null if location unavailable)
    CASE
      WHEN v_profile.location IS NOT NULL AND dp.location IS NOT NULL THEN
        ROUND((ST_Distance(dp.location, v_profile.location) / 1000.0)::numeric, 1)::double precision
      ELSE NULL
    END AS distance_km,
    dp.rank_score
  FROM discovery_pool dp
  WHERE
    -- Exclude the viewer themselves
    dp.user_id != p_viewer_id

    -- Opposite gender only (matrimony context)
    AND dp.gender != v_profile.gender

    -- Exclude blocks in both directions
    AND NOT EXISTS (
      SELECT 1 FROM blocks b
      WHERE (b.blocker_id = p_viewer_id AND b.blocked_id = dp.user_id)
         OR (b.blocker_id = dp.user_id  AND b.blocked_id = p_viewer_id)
    )

    -- Location / diaspora filter
    AND (
      -- Diaspora mode: match by preferred country, not distance
      (
        v_prefs.diaspora_mode = true
        AND (
          v_prefs.preferred_countries IS NULL
          OR dp.country_code = ANY(v_prefs.preferred_countries)
        )
        AND dp.open_to_diaspora = true
      )
      OR
      -- Normal mode: geospatial distance
      (
        v_prefs.diaspora_mode = false
        AND (
          v_max_km IS NULL
          OR v_profile.location IS NULL
          OR dp.location IS NULL
          OR ST_DWithin(dp.location, v_profile.location, v_max_km * 1000)
        )
      )
    )

    -- Recency filter (subscriber-only feature)
    AND (
      v_active_recently = false
      OR dp.last_active_at > NOW() - INTERVAL '7 days'
    )

    -- Cursor-based pagination (no offset drift)
    AND (
      p_cursor_score IS NULL
      OR (dp.rank_score < p_cursor_score)
      OR (dp.rank_score = p_cursor_score AND dp.profile_id < p_cursor_id)
    )

  ORDER BY dp.rank_score DESC, dp.profile_id DESC
  LIMIT p_page_size;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- ------------------------------------------------------------
-- NAME + CITY SEARCH RPC
-- Used by the search bar. First name + city only — never last name.
-- Returns visible, onboarded profiles excluding blocked pairs.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION search_profiles_by_name_city(
  p_viewer_id  uuid,
  p_first_name text,
  p_city_id    uuid DEFAULT NULL
)
RETURNS TABLE(
  profile_id        uuid,
  first_name        text,
  last_name_initial text,
  city_name         text
)
AS $$
BEGIN
  RETURN QUERY
  SELECT
    p.id,
    p.first_name,
    LEFT(p.last_name, 1),
    c.name
  FROM profiles p
  JOIN cities c ON p.city_id = c.id
  WHERE
    p.visibility    = 'visible'
    AND p.onboarding_step >= 14
    AND p.user_id  != p_viewer_id
    AND p.first_name ILIKE p_first_name || '%'
    AND (p_city_id IS NULL OR p.city_id = p_city_id)
    AND NOT EXISTS (
      SELECT 1 FROM blocks b
      WHERE (b.blocker_id = p_viewer_id AND b.blocked_id = p.user_id)
         OR (b.blocker_id = p.user_id  AND b.blocked_id = p_viewer_id)
    )
  ORDER BY p.first_name, p.id
  LIMIT 20;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;
