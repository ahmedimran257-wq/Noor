-- ============================================================
-- MIGRATION 035: GLOBAL LOCATION SCHEMA & INGESSION
-- Restructures location tracking: Country -> Region -> City
-- ============================================================

-- Step 1: Drop dependent objects temporarily so we can alter countries and cities
DROP MATERIALIZED VIEW IF EXISTS discovery_pool;
DROP FUNCTION IF EXISTS get_discovery_feed(uuid, double precision, uuid, integer, jsonb);
DROP FUNCTION IF EXISTS get_new_arrivals(text, uuid);
DROP FUNCTION IF EXISTS search_profiles_by_name_city(uuid, text, uuid);
DROP FUNCTION IF EXISTS search_cities(text, text);
DROP FUNCTION IF EXISTS get_or_create_city(text, text, double precision, double precision, text, text);

-- Step 2: Drop foreign keys referencing countries and cities
ALTER TABLE profiles DROP CONSTRAINT IF EXISTS profiles_city_id_fkey;
ALTER TABLE profiles DROP CONSTRAINT IF EXISTS profiles_country_code_fkey;
ALTER TABLE users DROP CONSTRAINT IF EXISTS users_country_code_fkey;
ALTER TABLE income_brackets DROP CONSTRAINT IF EXISTS income_brackets_country_code_fkey;

-- Step 3: Modify countries table
ALTER TABLE countries DROP CONSTRAINT IF EXISTS countries_pkey CASCADE;
ALTER TABLE countries RENAME COLUMN code TO iso_code;
ALTER TABLE countries ALTER COLUMN iso_code TYPE VARCHAR(2);
ALTER TABLE countries ADD CONSTRAINT countries_pkey PRIMARY KEY (iso_code);

-- Step 4: Drop old cities table and recreate regions and cities
DROP TABLE IF EXISTS cities CASCADE;

CREATE TABLE public.regions (
    id SERIAL PRIMARY KEY,
    country_code VARCHAR(2) REFERENCES public.countries(iso_code) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL, -- States (India/US), Provinces (Canada), Counties (UK)
    UNIQUE (country_code, name)
);

CREATE TABLE public.cities (
    id SERIAL PRIMARY KEY,
    region_id INT REFERENCES public.regions(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL, -- City, District, or Town name
    latitude NUMERIC(9,6),      -- Essential for geospatial radius filtering
    longitude NUMERIC(9,6),     -- Essential for geospatial radius filtering
    UNIQUE (region_id, name)
);

-- Step 5: Update profiles and profile_preferences referencing cities and countries
-- Convert country_code columns in users, profiles, and income_brackets to VARCHAR(2)
ALTER TABLE profiles ALTER COLUMN country_code TYPE VARCHAR(2);
ALTER TABLE users ALTER COLUMN country_code TYPE VARCHAR(2);
ALTER TABLE income_brackets ALTER COLUMN country_code TYPE VARCHAR(2);

-- Convert city_id type in profiles from uuid to integer
ALTER TABLE profiles ALTER COLUMN city_id TYPE INT USING NULL;
ALTER TABLE profiles ADD CONSTRAINT profiles_city_id_fkey FOREIGN KEY (city_id) REFERENCES cities(id) ON DELETE SET NULL;
ALTER TABLE profiles ADD CONSTRAINT profiles_country_code_fkey FOREIGN KEY (country_code) REFERENCES countries(iso_code);

-- Re-establish users and income_brackets foreign keys
ALTER TABLE users ADD CONSTRAINT users_country_code_fkey FOREIGN KEY (country_code) REFERENCES countries(iso_code);
ALTER TABLE income_brackets ADD CONSTRAINT income_brackets_country_code_fkey FOREIGN KEY (country_code) REFERENCES countries(iso_code);

-- Convert preferred_city_ids in profile_preferences from uuid[] to int[]
ALTER TABLE profile_preferences ALTER COLUMN preferred_city_ids TYPE INT[] USING NULL;

-- Step 6: Trigger to automatically update geography profiles.location from city_id coordinates
CREATE OR REPLACE FUNCTION sync_profile_location()
RETURNS trigger AS $$
DECLARE
  v_lat NUMERIC(9,6);
  v_lng NUMERIC(9,6);
BEGIN
  IF NEW.city_id IS DISTINCT FROM OLD.city_id OR (NEW.city_id IS NOT NULL AND NEW.location IS NULL) THEN
    -- Fetch latitude and longitude from cities table
    SELECT latitude, longitude INTO v_lat, v_lng
    FROM cities
    WHERE id = NEW.city_id;

    IF v_lat IS NOT NULL AND v_lng IS NOT NULL THEN
      NEW.location := ST_MakePoint(v_lng, v_lat)::geography;
    ELSE
      NEW.location := NULL;
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS trg_sync_profile_location ON profiles;
CREATE TRIGGER trg_sync_profile_location
  BEFORE INSERT OR UPDATE OF city_id ON profiles
  FOR EACH ROW
  EXECUTE FUNCTION sync_profile_location();

-- Step 7: Recreate location engine search and ingestion functions
CREATE OR REPLACE FUNCTION get_or_create_city(
  p_city_name    VARCHAR(100),
  p_region_name  VARCHAR(100),
  p_country_name VARCHAR(100),
  p_country_code VARCHAR(2),
  p_latitude     NUMERIC(9,6),
  p_longitude    NUMERIC(9,6)
)
RETURNS INT
AS $$
DECLARE
  v_country_exists BOOLEAN;
  v_region_id INT;
  v_city_id INT;
BEGIN
  -- 1. Look up if the country exists. If not, insert it.
  SELECT EXISTS(SELECT 1 FROM countries WHERE iso_code = p_country_code) INTO v_country_exists;
  IF NOT v_country_exists THEN
    INSERT INTO countries (iso_code, name, dialing_code, currency, default_lang, rtl, show_sect, show_sub_sect, wali_requirement, pricing_tier)
    VALUES (p_country_code, p_country_name, '', '', 'en', false, true, false, 'optional', 'tier_3');
  END IF;

  -- 2. Look up if the region exists for that country. If not, insert it.
  SELECT id INTO v_region_id
  FROM regions
  WHERE country_code = p_country_code
    AND name = p_region_name;

  IF v_region_id IS NULL THEN
    INSERT INTO regions (country_code, name)
    VALUES (p_country_code, p_region_name)
    RETURNING id INTO v_region_id;
  END IF;

  -- 3. Look up if the city/district exists under that region_id. If not, insert it.
  SELECT id INTO v_city_id
  FROM cities
  WHERE region_id = v_region_id
    AND name = p_city_name;

  IF v_city_id IS NULL THEN
    INSERT INTO cities (region_id, name, latitude, longitude)
    VALUES (v_region_id, p_city_name, p_latitude, p_longitude)
    RETURNING id INTO v_city_id;
  END IF;

  RETURN v_city_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION search_cities(
  search_term    text,
  country_filter text DEFAULT NULL
)
RETURNS TABLE(
  id           INT,
  name         text,
  state        text,
  country      text,
  country_code text,
  lat          numeric,
  lng          numeric
)
AS $$
BEGIN
  RETURN QUERY
  SELECT
    c.id,
    c.name,
    r.name AS state,
    co.name AS country,
    r.country_code,
    c.latitude AS lat,
    c.longitude AS lng
  FROM cities c
  JOIN regions r ON c.region_id = r.id
  JOIN countries co ON r.country_code = co.iso_code
  WHERE
    (c.name ILIKE '%' || search_term || '%' OR r.name ILIKE '%' || search_term || '%')
    AND (country_filter IS NULL OR r.country_code = country_filter)
  LIMIT 20;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION search_profiles_by_name_city(
  p_viewer_id  uuid,
  p_first_name text,
  p_city_id    INT DEFAULT NULL
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
  LEFT JOIN cities c ON p.city_id = c.id
  WHERE
    p.visibility    = 'visible'
    AND p.onboarding_step >= 14
    AND p.user_id  != p_viewer_id
    AND p.first_name ILIKE p_first_name || '%'
    AND (p_city_id IS NULL OR p.city_id = p_city_id)
    AND NOT EXISTS (
      SELECT 1 FROM blocks b
      WHERE (b.blocker_id = p_viewer_id AND b.blocked_id = p.user_id)
         OR (b.blocker_id = dp.user_id  AND b.blocked_id = p_viewer_id) -- dp check here was a bug in old function, let's make sure it refers to p.user_id
    )
  ORDER BY p.first_name, p.id
  LIMIT 20;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Standardized search_profiles_by_name_city block check fix
CREATE OR REPLACE FUNCTION search_profiles_by_name_city(
  p_viewer_id  uuid,
  p_first_name text,
  p_city_id    INT DEFAULT NULL
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
  LEFT JOIN cities c ON p.city_id = c.id
  WHERE
    p.visibility    = 'visible'
    AND p.onboarding_step >= 14
    AND p.user_id  != p_viewer_id
    AND p.first_name ILIKE p_first_name || '%'
    AND (p_city_id IS NULL OR p.city_id = p_city_id)
    AND NOT EXISTS (
      SELECT 1 FROM blocks b
      WHERE (b.blocker_id = p_viewer_id AND b.blocked_id = p.user_id)
         OR (b.blocker_id = p.user_id   AND b.blocked_id = p_viewer_id)
    )
  ORDER BY p.first_name, p.id
  LIMIT 20;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

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
    (COALESCE(p.static_rank_score, 0) + 15)::double precision AS rank_score,
    p.last_active_at,
    p.location,
    p.marriage_timeline,
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
  LEFT JOIN cities c ON p.city_id = c.id
  LEFT JOIN profile_preferences pr ON p.id = pr.profile_id
  WHERE p.visibility      = 'visible'
    AND p.onboarding_step >= 14
    AND p.approved_at     IS NOT NULL
    AND p.approved_at     > NOW() - INTERVAL '48 hours'
    AND p.gender         != p_viewer_gender
    AND p.user_id        != p_viewer_id
    AND NOT EXISTS (
      SELECT 1 FROM discovery_pool dp WHERE dp.profile_id = p.id
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Step 8: Recreate proximity match function (get_nearby_matches)
CREATE OR REPLACE FUNCTION get_nearby_matches(user_lat NUMERIC, user_lng NUMERIC, radius_km NUMERIC)
RETURNS SETOF profiles AS $$
BEGIN
    RETURN QUERY
    SELECT p.* 
    FROM profiles p
    JOIN cities c ON p.city_id = c.id
    WHERE ST_DWithin(
        ST_MakePoint(c.longitude, c.latitude)::geography,
        ST_MakePoint(user_lng, user_lat)::geography,
        radius_km * 1000
    );
END;
$$ LANGUAGE plpgsql;

-- Step 9: Recreate discovery_pool materialized view
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
  p.listens_to_music,
  p.eats_zabiha_only,
  p.attends_islamic_classes,
  p.reads_quran_daily,
  p.celebrates_mawlid,
  p.watches_movies,
  p.gender_mixing_stance,
  -- Photo count
  (
    SELECT COUNT(*)::integer
    FROM photos ph
    WHERE ph.profile_id = p.id
      AND ph.admin_approved = true
      AND ph.nsfw_cleared   = true
  )                                                  AS photo_count,
  -- photo_url (first photo storage path)
  (
    SELECT CASE WHEN p.photo_privacy = 'public' THEN ph.storage_path ELSE NULL END
    FROM photos ph
    WHERE ph.profile_id   = p.id
      AND ph.order_index  = 0
      AND ph.admin_approved = true
      AND ph.nsfw_cleared   = true
    LIMIT 1
  )                                                  AS photo_url,
  -- photo_blurhash (first photo blurhash)
  (
    SELECT CASE WHEN p.photo_privacy = 'public' THEN ph.blurhash ELSE NULL END
    FROM photos ph
    WHERE ph.profile_id   = p.id
      AND ph.order_index  = 0
      AND ph.admin_approved = true
      AND ph.nsfw_cleared   = true
    LIMIT 1
  )                                                  AS blurhash,
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
  pr.pref_music_stance,
  pr.pref_zabiha_only,
  pr.pref_quran_daily,
  pr.pref_gender_mixing
FROM profiles p
LEFT JOIN cities c ON p.city_id = c.id
JOIN profile_preferences pr ON p.id = pr.profile_id
WHERE p.visibility    = 'visible'
  AND p.onboarding_step >= 14;

-- Recreate indexes on discovery_pool
CREATE UNIQUE INDEX idx_discovery_pool_id       ON discovery_pool(profile_id);
CREATE INDEX         idx_discovery_pool_location ON discovery_pool USING GIST (location);
CREATE INDEX         idx_discovery_pool_rank     ON discovery_pool(rank_score DESC, profile_id DESC);
CREATE INDEX         idx_discovery_pool_gender   ON discovery_pool(gender);
CREATE INDEX         idx_discovery_pool_country  ON discovery_pool(country_code);
CREATE INDEX IF NOT EXISTS idx_discovery_pool_gender_country_rank
  ON discovery_pool(gender, country_code, rank_score DESC);

-- Step 10: Recreate get_discovery_feed function
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
