-- Fix nested discovery pool ambiguity. This function returns a user_id column,
-- so all references to profile/user columns must be table-qualified.

CREATE OR REPLACE FUNCTION public.get_discovery_feed_global_pool(
  p_viewer_id uuid,
  p_cursor_score double precision DEFAULT NULL,
  p_cursor_id uuid DEFAULT NULL,
  p_page_size integer DEFAULT 10,
  p_filters jsonb DEFAULT '{}'::jsonb
)
RETURNS TABLE (
  profile_id uuid,
  user_id uuid,
  gender text,
  first_name text,
  last_name_initial text,
  age integer,
  city_name text,
  country_code text,
  sect text,
  deen_level text,
  profession text,
  bio text,
  photo_url text,
  photo_count integer,
  photo_privacy text,
  is_verified boolean,
  distance_km double precision,
  rank_score double precision,
  marriage_timeline text,
  height_cm integer,
  complexion text,
  mother_tongue text,
  smoking_habit text,
  community text,
  diet_type text,
  living_expectation text,
  quran_memorization text,
  religious_education text,
  willing_to_relocate text,
  previously_married text,
  family_type text,
  children_count integer,
  languages text[],
  interests text[],
  preferred_age_min integer,
  preferred_age_max integer,
  last_active_at timestamptz,
  blurhash text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_profile profiles%ROWTYPE;
  v_prefs profile_preferences%ROWTYPE;
  v_max_km int;
  v_active_recently boolean;
  v_age_min int;
  v_age_max int;
  v_sect text;
  v_deen_level text;
  v_verified_only boolean;
  v_family_type text;
  v_marital_status text;
  v_education_min int;
  v_mother_tongue text;
  v_community text;
  v_living_exp text;
  v_quran_mem text;
  v_marriage_tl text;
  v_relocate text;
  v_has_children text;
  v_open_divorced boolean;
BEGIN
  SELECT p.* INTO v_profile
  FROM public.profiles AS p
  WHERE p.user_id = p_viewer_id;

  IF v_profile.id IS NULL THEN
    RAISE EXCEPTION 'Viewer profile not found.';
  END IF;

  SELECT pp.* INTO v_prefs
  FROM public.profile_preferences AS pp
  WHERE pp.profile_id = v_profile.id;

  IF v_profile.visibility = 'suspended' THEN
    RAISE EXCEPTION 'Account suspended. Contact support.';
  END IF;

  v_max_km := (p_filters->>'max_distance_km')::int;
  v_active_recently := COALESCE((p_filters->>'active_recently')::boolean, false);
  v_age_min := (p_filters->>'age_min')::int;
  v_age_max := (p_filters->>'age_max')::int;
  v_sect := p_filters->>'sect';
  v_deen_level := p_filters->>'deen_level';
  v_verified_only := COALESCE((p_filters->>'verified_only')::boolean, false);
  v_family_type := p_filters->>'family_type';
  v_marital_status := p_filters->>'marital_status';
  v_education_min := (p_filters->>'education_min')::int;
  v_mother_tongue := p_filters->>'mother_tongue';
  v_community := p_filters->>'community';
  v_living_exp := p_filters->>'living_expectation';
  v_quran_mem := p_filters->>'quran_memorization';
  v_marriage_tl := p_filters->>'marriage_timeline';
  v_relocate := p_filters->>'willing_to_relocate';
  v_has_children := p_filters->>'has_children';
  v_open_divorced := COALESCE((p_filters->>'open_to_divorced')::boolean, false);

  RETURN QUERY
  WITH combined_pool AS (
    SELECT
      dp.profile_id,
      dp.user_id,
      dp.gender,
      dp.first_name,
      dp.last_name_initial,
      dp.age,
      dp.city_name,
      dp.country_code,
      dp.city_id,
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
      dp.height_cm,
      dp.complexion,
      dp.mother_tongue,
      dp.smoking_habit,
      dp.community,
      dp.diet_type,
      dp.living_expectation,
      dp.quran_memorization,
      dp.religious_education,
      dp.willing_to_relocate,
      dp.previously_married,
      dp.family_type,
      dp.children_count,
      p.open_to_diaspora,
      p.education_rank,
      p.languages,
      p.interests,
      dp.preferred_age_min,
      dp.preferred_age_max,
      dp.blurhash
    FROM public.discovery_pool AS dp
    JOIN public.profiles AS p ON p.id = dp.profile_id
    WHERE dp.user_id != p_viewer_id
      AND dp.gender != v_profile.gender

    UNION ALL

    SELECT
      na.profile_id,
      na.user_id,
      na.gender,
      na.first_name,
      na.last_name_initial,
      na.age,
      na.city_name,
      na.country_code,
      p.city_id,
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
      p.height_cm,
      p.complexion,
      na.mother_tongue,
      p.smoking_habit,
      na.community,
      p.diet_type,
      na.living_expectation,
      na.quran_memorization,
      p.religious_education,
      na.willing_to_relocate,
      na.previously_married,
      na.family_type,
      na.children_count,
      p.open_to_diaspora,
      p.education_rank,
      p.languages,
      p.interests,
      na.preferred_age_min,
      na.preferred_age_max,
      (
        SELECT ph.blurhash
        FROM public.photos AS ph
        WHERE ph.profile_id = na.profile_id
          AND ph.order_index = 0
          AND ph.admin_approved = true
          AND ph.nsfw_cleared = true
        LIMIT 1
      ) AS blurhash
    FROM public.get_new_arrivals(v_profile.gender, p_viewer_id) AS na
    JOIN public.profiles AS p ON p.id = na.profile_id
  )
  SELECT
    cp.profile_id,
    cp.user_id,
    cp.gender,
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
    CASE
      WHEN v_profile.location IS NOT NULL AND cp.location IS NOT NULL THEN
        ROUND((ST_Distance(cp.location, v_profile.location) / 1000.0)::numeric, 1)::double precision
      ELSE NULL
    END AS distance_km,
    cp.rank_score,
    cp.marriage_timeline,
    cp.height_cm,
    cp.complexion,
    cp.mother_tongue,
    cp.smoking_habit,
    cp.community,
    cp.diet_type,
    cp.living_expectation,
    cp.quran_memorization,
    cp.religious_education,
    cp.willing_to_relocate,
    cp.previously_married,
    cp.family_type,
    cp.children_count,
    cp.languages,
    cp.interests,
    cp.preferred_age_min,
    cp.preferred_age_max,
    cp.last_active_at,
    cp.blurhash
  FROM combined_pool AS cp
  WHERE
    NOT EXISTS (
      SELECT 1
      FROM public.blocks AS b
      WHERE (b.blocker_id = p_viewer_id AND b.blocked_id = cp.user_id)
         OR (b.blocker_id = cp.user_id AND b.blocked_id = p_viewer_id)
    )
    AND NOT EXISTS (
      SELECT 1
      FROM public.interests AS i
      WHERE (
          (i.sender_id = p_viewer_id AND i.receiver_id = cp.user_id)
          OR (i.sender_id = cp.user_id AND i.receiver_id = p_viewer_id)
        )
        AND i.status IN ('pending', 'accepted')
    )
    AND (
      (
        (p_filters->>'same_city')::boolean = true
        AND cp.city_id = v_profile.city_id
      )
      OR (
        (p_filters->>'same_country')::boolean = true
        AND cp.country_code = v_profile.country_code
      )
      OR (
        v_max_km IS NOT NULL
        AND (
          v_profile.location IS NULL
          OR cp.location IS NULL
          OR ST_DWithin(cp.location, v_profile.location, v_max_km * 1000)
        )
      )
      OR ((p_filters->>'anywhere')::boolean = true)
      OR (
        (p_filters->>'same_city') IS NULL
        AND (p_filters->>'same_country') IS NULL
        AND (p_filters->>'anywhere') IS NULL
        AND v_max_km IS NULL
        AND (
          (COALESCE(v_prefs.location_preference, 'openToAbroad') = 'sameCity' AND cp.city_id = v_profile.city_id)
          OR (COALESCE(v_prefs.location_preference, 'openToAbroad') = 'sameCountry' AND cp.country_code = v_profile.country_code)
          OR (
            COALESCE(v_prefs.location_preference, 'openToAbroad') = 'diaspora'
            AND (
              v_prefs.preferred_countries IS NULL
              OR cp.country_code = ANY(v_prefs.preferred_countries)
            )
            AND cp.open_to_diaspora = true
          )
          OR (COALESCE(v_prefs.location_preference, 'openToAbroad') = 'openToAbroad')
        )
      )
    )
    AND (v_active_recently = false OR cp.last_active_at > NOW() - INTERVAL '7 days')
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
    AND (
      v_has_children IS NULL
      OR CASE v_has_children
        WHEN 'yes' THEN cp.children_count > 0
        WHEN 'no' THEN COALESCE(cp.children_count, 0) = 0
        ELSE true
      END
    )
    AND (
      v_open_divorced = true
      OR cp.previously_married IS NULL
      OR cp.previously_married = 'no'
    )
    AND (
      p_cursor_score IS NULL
      OR cp.rank_score < p_cursor_score
      OR (cp.rank_score = p_cursor_score AND cp.profile_id < p_cursor_id)
    )
  ORDER BY cp.rank_score DESC, cp.profile_id DESC
  LIMIT p_page_size;
END;
$$;

REVOKE ALL ON FUNCTION public.get_discovery_feed_global_pool(
  uuid, double precision, uuid, integer, jsonb
) FROM PUBLIC, anon, authenticated;
