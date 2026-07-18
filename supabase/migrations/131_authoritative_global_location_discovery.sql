-- Authoritative geographic discovery.
--
-- Geographic filters are applied to the full eligible discovery pool before
-- ranking. They are never applied to a small, unrelated recommendation cache.
-- Premium geographic scopes are also enforced in Postgres so a modified
-- client cannot unlock them.

CREATE INDEX IF NOT EXISTS idx_discovery_pool_city
  ON public.discovery_pool(city_id);
CREATE INDEX IF NOT EXISTS idx_cities_region_id
  ON public.cities(region_id);

CREATE OR REPLACE FUNCTION public.get_discovery_feed(
  p_viewer_id uuid,
  p_cursor_score double precision DEFAULT NULL,
  p_cursor_id uuid DEFAULT NULL,
  p_page_size integer DEFAULT 20,
  p_filters jsonb DEFAULT '{}'::jsonb
)
RETURNS TABLE (
  profile_id uuid, user_id uuid, gender text, first_name text,
  last_name_initial text, age integer, city_name text, country_code text,
  sect text, deen_level text, profession text, bio text, photo_url text,
  photo_count integer, photo_privacy text, is_verified boolean,
  distance_km double precision, rank_score double precision,
  marriage_timeline text, height_cm integer, complexion text,
  mother_tongue text, smoking_habit text, community text, diet_type text,
  living_expectation text, quran_memorization text, religious_education text,
  willing_to_relocate text, previously_married text, family_type text,
  children_count integer, languages text[], interests text[],
  preferred_age_min integer, preferred_age_max integer,
  last_active_at timestamptz, blurhash text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_viewer_profile_id uuid;
  v_viewer_gender text;
  v_viewer_visibility text;
  v_viewer_completed boolean;
  v_viewer_approved_at timestamptz;
  v_viewer_photo_count integer;
  v_viewer_location geography;
  v_viewer_country text;
  v_viewer_city_id public.profiles.city_id%TYPE;
  v_viewer_region_id integer;
  v_gender_pref text := nullif(lower(trim(p_filters->>'gender_pref')), '');
  v_location_scope text := nullif(lower(trim(p_filters->>'location_scope')), '');
  v_max_distance_km integer;
  v_country_codes text[] := ARRAY[]::text[];
  v_diaspora_countries text[] := ARRAY[]::text[];
  v_limit integer;
  v_count integer;
  v_remaining integer;
  v_page_size integer := least(greatest(coalesce(p_page_size, 20), 1), 20);
BEGIN
  IF auth.uid() IS DISTINCT FROM p_viewer_id THEN
    RAISE EXCEPTION 'Discovery can only be requested for the signed-in user.';
  END IF;

  SELECT
    p.id,
    p.gender::text,
    p.visibility,
    p.onboarding_completed,
    p.approved_at,
    p.location,
    upper(p.country_code::text),
    p.city_id,
    c.region_id,
    (
      SELECT count(*)::integer
      FROM public.photos ph
      WHERE ph.profile_id = p.id
        AND ph.admin_approved = true
        AND ph.nsfw_cleared = true
    )
  INTO
    v_viewer_profile_id,
    v_viewer_gender,
    v_viewer_visibility,
    v_viewer_completed,
    v_viewer_approved_at,
    v_viewer_location,
    v_viewer_country,
    v_viewer_city_id,
    v_viewer_region_id,
    v_viewer_photo_count
  FROM public.profiles p
  LEFT JOIN public.cities c ON c.id = p.city_id
  WHERE p.user_id = p_viewer_id;

  IF v_viewer_profile_id IS NULL THEN
    RETURN;
  END IF;

  IF v_viewer_visibility IS DISTINCT FROM 'visible'
      OR coalesce(v_viewer_completed, false) IS DISTINCT FROM true
      OR v_viewer_approved_at IS NULL
      OR coalesce(v_viewer_photo_count, 0) <= 0 THEN
    RETURN;
  END IF;

  -- Accept old clients while making the new location_scope contract canonical.
  IF coalesce((p_filters->>'diaspora_mode')::boolean, false) THEN
    v_location_scope := 'diaspora';
  ELSIF v_location_scope IS NULL THEN
    v_location_scope := CASE
      WHEN coalesce((p_filters->>'same_city')::boolean, false)
        THEN 'same_city'
      WHEN coalesce((p_filters->>'same_region')::boolean, false)
        THEN 'same_region'
      WHEN coalesce((p_filters->>'same_country')::boolean, false)
        THEN 'same_country'
      WHEN p_filters ? 'max_distance_km'
        THEN 'radius'
      WHEN p_filters ? 'country_codes'
        THEN 'countries'
      ELSE 'global'
    END;
  END IF;

  IF v_location_scope = 'same_state' THEN
    v_location_scope := 'same_region';
  ELSIF v_location_scope = 'anywhere' THEN
    v_location_scope := 'global';
  END IF;

  IF v_location_scope NOT IN (
    'global', 'same_city', 'same_region', 'same_country',
    'radius', 'countries', 'diaspora'
  ) THEN
    RAISE EXCEPTION 'invalid_location_scope' USING ERRCODE = '22023';
  END IF;

  IF p_filters ? 'country_codes' THEN
    IF jsonb_typeof(p_filters->'country_codes') <> 'array' THEN
      RAISE EXCEPTION 'country_codes_must_be_an_array' USING ERRCODE = '22023';
    END IF;
    IF jsonb_array_length(p_filters->'country_codes') > 20 THEN
      RAISE EXCEPTION 'too_many_country_codes' USING ERRCODE = '22023';
    END IF;
    IF EXISTS (
      SELECT 1
      FROM jsonb_array_elements_text(p_filters->'country_codes') item(value)
      WHERE upper(trim(item.value)) !~ '^[A-Z]{2}$'
    ) THEN
      RAISE EXCEPTION 'invalid_country_code' USING ERRCODE = '22023';
    END IF;
    SELECT coalesce(array_agg(code ORDER BY code), ARRAY[]::text[])
    INTO v_country_codes
    FROM (
      SELECT DISTINCT upper(trim(item.value)) AS code
      FROM jsonb_array_elements_text(p_filters->'country_codes') item(value)
    ) normalized;
  END IF;

  IF p_filters ? 'diaspora_countries' THEN
    IF jsonb_typeof(p_filters->'diaspora_countries') <> 'array' THEN
      RAISE EXCEPTION 'diaspora_countries_must_be_an_array'
        USING ERRCODE = '22023';
    END IF;
    IF jsonb_array_length(p_filters->'diaspora_countries') > 20 THEN
      RAISE EXCEPTION 'too_many_diaspora_countries' USING ERRCODE = '22023';
    END IF;
    IF EXISTS (
      SELECT 1
      FROM jsonb_array_elements_text(p_filters->'diaspora_countries') item(value)
      WHERE upper(trim(item.value)) !~ '^[A-Z]{2}$'
    ) THEN
      RAISE EXCEPTION 'invalid_diaspora_country_code' USING ERRCODE = '22023';
    END IF;
    SELECT coalesce(array_agg(code ORDER BY code), ARRAY[]::text[])
    INTO v_diaspora_countries
    FROM (
      SELECT DISTINCT upper(trim(item.value)) AS code
      FROM jsonb_array_elements_text(p_filters->'diaspora_countries') item(value)
    ) normalized;
  END IF;

  IF cardinality(v_country_codes) > 0 AND EXISTS (
    SELECT 1
    FROM unnest(v_country_codes) requested(code)
    WHERE NOT EXISTS (
      SELECT 1 FROM public.countries c
      WHERE upper(c.iso_code::text) = requested.code
    )
  ) THEN
    RAISE EXCEPTION 'unknown_country_code' USING ERRCODE = '22023';
  END IF;

  IF cardinality(v_diaspora_countries) = 0
      AND v_location_scope = 'diaspora' THEN
    SELECT coalesce(
      array_agg(DISTINCT upper(code)) FILTER (WHERE code IS NOT NULL),
      ARRAY[]::text[]
    )
    INTO v_diaspora_countries
    FROM public.profile_preferences pp,
      unnest(coalesce(pp.preferred_countries, ARRAY[]::text[])) code
    WHERE pp.profile_id = v_viewer_profile_id;
  END IF;

  IF cardinality(v_diaspora_countries) > 0 AND EXISTS (
    SELECT 1
    FROM unnest(v_diaspora_countries) requested(code)
    WHERE NOT EXISTS (
      SELECT 1 FROM public.countries c
      WHERE upper(c.iso_code::text) = requested.code
    )
  ) THEN
    RAISE EXCEPTION 'unknown_diaspora_country_code' USING ERRCODE = '22023';
  END IF;

  IF v_location_scope = 'countries' AND cardinality(v_country_codes) = 0 THEN
    RAISE EXCEPTION 'country_selection_required' USING ERRCODE = '22023';
  END IF;

  IF v_location_scope = 'radius' THEN
    v_max_distance_km := (p_filters->>'max_distance_km')::integer;
    IF v_max_distance_km IS NULL
        OR v_max_distance_km < 1
        OR v_max_distance_km > 20000 THEN
      RAISE EXCEPTION 'invalid_distance_radius' USING ERRCODE = '22023';
    END IF;
  END IF;

  IF v_location_scope <> 'global'
      AND NOT public.has_active_premium(p_viewer_id) THEN
    RAISE EXCEPTION 'premium_filter_required'
      USING ERRCODE = 'P0001',
            DETAIL = json_build_object(
              'feature', 'location_filters',
              'location_scope', v_location_scope
            )::text;
  END IF;

  v_limit := coalesce(public.profile_view_daily_limit(p_viewer_id), 15);
  SELECT count(*)::integer INTO v_count
  FROM public.profile_view_daily_seen seen
  WHERE seen.viewer_user_id = p_viewer_id
    AND seen.viewed_on = current_date;

  v_remaining := greatest(v_limit - v_count, 0);
  IF v_remaining <= 0 THEN
    RETURN;
  END IF;

  RETURN QUERY
  WITH eligible AS MATERIALIZED (
    SELECT
      dp.profile_id,
      dp.user_id,
      dp.gender::text AS gender,
      dp.first_name::text AS first_name,
      dp.last_name_initial::text AS last_name_initial,
      dp.age,
      dp.city_name::text AS city_name,
      upper(dp.country_code::text) AS country_code,
      dp.city_id,
      candidate_city.region_id,
      dp.sect::text AS sect,
      dp.deen_level::text AS deen_level,
      dp.profession::text AS profession,
      dp.bio::text AS bio,
      dp.photo_url::text AS photo_url,
      dp.photo_count,
      dp.photo_privacy::text AS photo_privacy,
      dp.is_verified,
      CASE
        WHEN v_viewer_location IS NOT NULL AND dp.location IS NOT NULL
          THEN ST_Distance(dp.location, v_viewer_location) / 1000.0
        ELSE NULL
      END AS distance_km,
      least(100.0, greatest(0.0, coalesce(dp.rank_score, 0.0)))
        ::double precision AS quality_score,
      dp.marriage_timeline::text AS marriage_timeline,
      dp.height_cm,
      dp.complexion::text AS complexion,
      dp.mother_tongue::text AS mother_tongue,
      dp.smoking_habit::text AS smoking_habit,
      dp.community::text AS community,
      dp.diet_type::text AS diet_type,
      dp.living_expectation::text AS living_expectation,
      dp.quran_memorization::text AS quran_memorization,
      dp.religious_education::text AS religious_education,
      dp.willing_to_relocate::text AS willing_to_relocate,
      dp.previously_married::text AS previously_married,
      dp.family_type::text AS family_type,
      dp.children_count,
      coalesce(candidate_profile.languages, ARRAY[]::text[]) AS languages,
      coalesce(candidate_profile.interests, ARRAY[]::text[]) AS interests,
      dp.preferred_age_min,
      dp.preferred_age_max,
      dp.last_active_at,
      dp.blurhash::text AS blurhash,
      coalesce(candidate_prefs.open_to_diaspora, false) AS open_to_diaspora
    FROM public.discovery_pool dp
    JOIN public.profiles candidate_profile
      ON candidate_profile.id = dp.profile_id
    LEFT JOIN public.cities candidate_city
      ON candidate_city.id = dp.city_id
    LEFT JOIN public.profile_preferences candidate_prefs
      ON candidate_prefs.profile_id = dp.profile_id
    WHERE dp.user_id <> p_viewer_id
      AND candidate_profile.visibility = 'visible'
      AND coalesce(candidate_profile.onboarding_completed, false) = true
      AND dp.photo_count > 0
      AND (
        (v_gender_pref IS NULL AND lower(dp.gender::text) <> lower(v_viewer_gender))
        OR lower(dp.gender::text) = v_gender_pref
      )
      AND NOT EXISTS (
        SELECT 1 FROM public.blocks b
        WHERE (b.blocker_id = p_viewer_id AND b.blocked_id = dp.user_id)
           OR (b.blocker_id = dp.user_id AND b.blocked_id = p_viewer_id)
      )
      AND NOT EXISTS (
        SELECT 1 FROM public.interests i
        WHERE (
          (i.sender_id = p_viewer_id AND i.receiver_id = dp.user_id)
          OR (i.sender_id = dp.user_id AND i.receiver_id = p_viewer_id)
        )
        AND i.status IN ('pending', 'accepted')
      )
      AND ((p_filters ? 'age_min') IS FALSE
        OR dp.age >= (p_filters->>'age_min')::integer)
      AND ((p_filters ? 'age_max') IS FALSE
        OR dp.age <= (p_filters->>'age_max')::integer)
      AND (coalesce((p_filters->>'active_recently')::boolean, false) IS FALSE
        OR dp.last_active_at >= now() - interval '14 days')
      AND (coalesce((p_filters->>'verified_only')::boolean, false) IS FALSE
        OR dp.is_verified = true)
      AND (nullif(p_filters->>'sect', '') IS NULL
        OR lower(coalesce(dp.sect::text, '')) = lower(p_filters->>'sect'))
      AND (nullif(p_filters->>'deen_level', '') IS NULL
        OR lower(coalesce(dp.deen_level::text, '')) = lower(p_filters->>'deen_level'))
      AND (nullif(p_filters->>'family_type', '') IS NULL
        OR lower(coalesce(dp.family_type::text, '')) = lower(p_filters->>'family_type'))
      AND (nullif(p_filters->>'marital_status', '') IS NULL
        OR lower(coalesce(dp.previously_married::text, '')) = lower(p_filters->>'marital_status'))
      AND (
        coalesce((p_filters->>'open_to_divorced')::boolean, true) = true
        OR coalesce(dp.previously_married::text, 'no') = 'no'
      )
      AND ((p_filters ? 'education_min') IS FALSE
        OR coalesce(dp.education_rank, 0) >= (p_filters->>'education_min')::integer)
      AND (nullif(p_filters->>'mother_tongue', '') IS NULL
        OR lower(coalesce(dp.mother_tongue::text, '')) = lower(p_filters->>'mother_tongue'))
      AND (nullif(p_filters->>'community', '') IS NULL
        OR lower(coalesce(dp.community::text, '')) = lower(p_filters->>'community'))
      AND (nullif(p_filters->>'living_expectation', '') IS NULL
        OR lower(coalesce(dp.living_expectation::text, '')) = lower(p_filters->>'living_expectation'))
      AND (nullif(p_filters->>'quran_memorization', '') IS NULL
        OR lower(coalesce(dp.quran_memorization::text, '')) = lower(p_filters->>'quran_memorization'))
      AND (nullif(p_filters->>'marriage_timeline', '') IS NULL
        OR lower(coalesce(dp.marriage_timeline::text, '')) = lower(p_filters->>'marriage_timeline'))
      AND (nullif(p_filters->>'willing_to_relocate', '') IS NULL
        OR lower(coalesce(dp.willing_to_relocate::text, '')) = lower(p_filters->>'willing_to_relocate'))
      AND (
        nullif(p_filters->>'has_children', '') IS NULL
        OR (p_filters->>'has_children' = 'yes' AND coalesce(dp.children_count, 0) > 0)
        OR (p_filters->>'has_children' = 'no' AND coalesce(dp.children_count, 0) = 0)
      )
      AND CASE v_location_scope
        WHEN 'same_city' THEN
          v_viewer_city_id IS NOT NULL AND dp.city_id = v_viewer_city_id
        WHEN 'same_region' THEN
          v_viewer_region_id IS NOT NULL
          AND candidate_city.region_id = v_viewer_region_id
        WHEN 'same_country' THEN
          v_viewer_country IS NOT NULL
          AND upper(dp.country_code::text) = v_viewer_country
        WHEN 'radius' THEN
          v_viewer_location IS NOT NULL
          AND dp.location IS NOT NULL
          AND ST_DWithin(
            dp.location,
            v_viewer_location,
            v_max_distance_km::double precision * 1000.0
          )
        WHEN 'countries' THEN
          upper(dp.country_code::text) = ANY(v_country_codes)
        WHEN 'diaspora' THEN
          coalesce(candidate_prefs.open_to_diaspora, false) = true
          AND (
            cardinality(v_diaspora_countries) = 0
            OR upper(dp.country_code::text) = ANY(v_diaspora_countries)
          )
        ELSE true
      END
    ORDER BY coalesce(dp.rank_score, 0.0) DESC, dp.profile_id DESC
    LIMIT 1500
  ), scored AS (
    SELECT
      e.*,
      (
        public.directional_preference_score(v_viewer_profile_id, e.profile_id)
        + public.directional_preference_score(e.profile_id, v_viewer_profile_id)
      ) / 2.0 AS mutual_preference_score,
      CASE
        WHEN v_viewer_city_id IS NOT NULL AND e.city_id = v_viewer_city_id
          THEN 100.0
        WHEN v_viewer_region_id IS NOT NULL AND e.region_id = v_viewer_region_id
          THEN 75.0
        WHEN v_viewer_country IS NOT NULL AND e.country_code = v_viewer_country
          THEN 55.0
        WHEN e.distance_km IS NOT NULL AND e.distance_km <= 250.0
          THEN greatest(20.0, 50.0 - (e.distance_km / 10.0))
        ELSE 10.0
      END AS location_score
    FROM eligible e
  ), ranked AS (
    SELECT
      s.*,
      (
        s.mutual_preference_score * 0.72
        + s.quality_score * 0.18
        + s.location_score * 0.10
      )::double precision AS recommendation_score
    FROM scored s
  )
  SELECT
    r.profile_id, r.user_id, r.gender, r.first_name, r.last_name_initial,
    r.age, r.city_name, r.country_code, r.sect, r.deen_level,
    r.profession, r.bio, r.photo_url, r.photo_count, r.photo_privacy,
    r.is_verified, r.distance_km, r.recommendation_score,
    r.marriage_timeline, r.height_cm, r.complexion, r.mother_tongue,
    r.smoking_habit, r.community, r.diet_type, r.living_expectation,
    r.quran_memorization, r.religious_education, r.willing_to_relocate,
    r.previously_married, r.family_type, r.children_count, r.languages,
    r.interests, r.preferred_age_min, r.preferred_age_max,
    r.last_active_at, r.blurhash
  FROM ranked r
  WHERE p_cursor_score IS NULL
    OR r.recommendation_score < p_cursor_score
    OR (
      r.recommendation_score = p_cursor_score
      AND r.profile_id < p_cursor_id
    )
  ORDER BY r.recommendation_score DESC, r.profile_id DESC
  LIMIT least(v_page_size, v_remaining);
END;
$$;

REVOKE ALL ON FUNCTION public.get_discovery_feed(
  uuid, double precision, uuid, integer, jsonb
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_discovery_feed(
  uuid, double precision, uuid, integer, jsonb
) TO authenticated;

COMMENT ON FUNCTION public.get_discovery_feed(
  uuid, double precision, uuid, integer, jsonb
) IS
  'Full-pool discovery with authoritative city, region, country, radius, selected-country and diaspora scopes; Premium is enforced server-side.';
