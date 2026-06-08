-- ============================================================
-- MIGRATION 038: ADD USER_ID TO GET_DISCOVERY_FEED
-- Recreates the discovery feed search function to output the
-- user_id (UUID from users table) along with the profile_id.
-- ============================================================

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
  user_id       uuid,
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
    cp.user_id,
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
