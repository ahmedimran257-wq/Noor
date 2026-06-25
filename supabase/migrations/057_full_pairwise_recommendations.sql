-- Apply non-negotiable preferences as eligibility rules before ranking. The
-- existing score still ranks softer preferences, but neither user is shown a
-- profile that violates their stated age, sect, deen, education, marital, or
-- children deal-breaker.
CREATE OR REPLACE FUNCTION public.mutual_dealbreakers_match(
  p_viewer_profile_id uuid,
  p_candidate_profile_id uuid
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  WITH pair AS (
    SELECT
      viewer.date_of_birth AS viewer_dob,
      viewer.sect AS viewer_sect,
      viewer.deen_level AS viewer_deen,
      viewer.education_rank AS viewer_education,
      viewer.previously_married AS viewer_marital,
      COALESCE(viewer.children_count, 0) AS viewer_children,
      candidate.date_of_birth AS candidate_dob,
      candidate.sect AS candidate_sect,
      candidate.deen_level AS candidate_deen,
      candidate.education_rank AS candidate_education,
      candidate.previously_married AS candidate_marital,
      COALESCE(candidate.children_count, 0) AS candidate_children,
      vp.preferred_age_min AS viewer_age_min,
      vp.preferred_age_max AS viewer_age_max,
      vp.sect_preference AS viewer_sect_pref,
      vp.deen_preference AS viewer_deen_pref,
      vp.min_education_rank AS viewer_education_min,
      vp.open_to_divorced AS viewer_open_divorced,
      vp.open_to_widowed AS viewer_open_widowed,
      vp.open_to_has_children AS viewer_open_children,
      cp.preferred_age_min AS candidate_age_min,
      cp.preferred_age_max AS candidate_age_max,
      cp.sect_preference AS candidate_sect_pref,
      cp.deen_preference AS candidate_deen_pref,
      cp.min_education_rank AS candidate_education_min,
      cp.open_to_divorced AS candidate_open_divorced,
      cp.open_to_widowed AS candidate_open_widowed,
      cp.open_to_has_children AS candidate_open_children
    FROM public.profiles viewer
    JOIN public.profiles candidate ON candidate.id = p_candidate_profile_id
    LEFT JOIN public.profile_preferences vp ON vp.profile_id = viewer.id
    LEFT JOIN public.profile_preferences cp ON cp.profile_id = candidate.id
    WHERE viewer.id = p_viewer_profile_id
  )
  SELECT COALESCE(bool_and(rule), false)
  FROM (
    SELECT viewer_age_min IS NULL OR viewer_age_max IS NULL OR
      EXTRACT(YEAR FROM age(candidate_dob)) BETWEEN viewer_age_min AND viewer_age_max AS rule FROM pair
    UNION ALL SELECT candidate_age_min IS NULL OR candidate_age_max IS NULL OR
      EXTRACT(YEAR FROM age(viewer_dob)) BETWEEN candidate_age_min AND candidate_age_max FROM pair
    UNION ALL SELECT lower(COALESCE(viewer_sect_pref, 'any')) IN ('any', 'no preference') OR
      (lower(viewer_sect_pref) = 'same as mine' AND lower(COALESCE(candidate_sect, '')) = lower(COALESCE(viewer_sect, ''))) OR
      lower(COALESCE(candidate_sect, '')) = lower(viewer_sect_pref) FROM pair
    UNION ALL SELECT lower(COALESCE(candidate_sect_pref, 'any')) IN ('any', 'no preference') OR
      (lower(candidate_sect_pref) = 'same as mine' AND lower(COALESCE(viewer_sect, '')) = lower(COALESCE(candidate_sect, ''))) OR
      lower(COALESCE(viewer_sect, '')) = lower(candidate_sect_pref) FROM pair
    UNION ALL SELECT lower(COALESCE(viewer_deen_pref, 'any')) IN ('any', 'no preference') OR
      lower(COALESCE(candidate_deen, '')) = lower(viewer_deen_pref) FROM pair
    UNION ALL SELECT lower(COALESCE(candidate_deen_pref, 'any')) IN ('any', 'no preference') OR
      lower(COALESCE(viewer_deen, '')) = lower(candidate_deen_pref) FROM pair
    UNION ALL SELECT viewer_education_min IS NULL OR viewer_education_min <= 1 OR
      COALESCE(candidate_education, 0) >= viewer_education_min FROM pair
    UNION ALL SELECT candidate_education_min IS NULL OR candidate_education_min <= 1 OR
      COALESCE(viewer_education, 0) >= candidate_education_min FROM pair
    UNION ALL SELECT candidate_marital <> 'divorced' OR COALESCE(viewer_open_divorced, false) FROM pair
    UNION ALL SELECT candidate_marital <> 'widowed' OR COALESCE(viewer_open_widowed, false) FROM pair
    UNION ALL SELECT candidate_children = 0 OR COALESCE(viewer_open_children, false) FROM pair
    UNION ALL SELECT viewer_marital <> 'divorced' OR COALESCE(candidate_open_divorced, false) FROM pair
    UNION ALL SELECT viewer_marital <> 'widowed' OR COALESCE(candidate_open_widowed, false) FROM pair
    UNION ALL SELECT viewer_children = 0 OR COALESCE(candidate_open_children, false) FROM pair
  ) checks;
$$;

-- The former wrapper scored an arbitrary first 250 candidates. Remove that
-- ceiling so mutual ranking is applied to the complete eligible result set.
DO $$
DECLARE
  definition text;
BEGIN
  SELECT pg_get_functiondef(
    'public.get_discovery_feed_global_pool(uuid,double precision,uuid,integer,jsonb)'::regprocedure
  ) INTO definition;
  definition := replace(definition, 'p_page_size > 250', 'false');
  EXECUTE definition;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_discovery_feed(
  p_viewer_id uuid,
  p_cursor_score double precision DEFAULT NULL,
  p_cursor_id uuid DEFAULT NULL,
  p_page_size integer DEFAULT 10,
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
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_viewer_profile_id uuid;
BEGIN
  IF auth.uid() IS DISTINCT FROM p_viewer_id THEN
    RAISE EXCEPTION 'Discovery can only be requested for the signed-in user.';
  END IF;
  SELECT id INTO v_viewer_profile_id FROM public.profiles WHERE user_id = p_viewer_id;

  RETURN QUERY
  WITH eligible AS (
    SELECT * FROM public.get_discovery_feed_global_pool(
      p_viewer_id, NULL, NULL, 2147483647, p_filters
    )
  ), mutually_scored AS (
    SELECT eligible.*, (
      public.directional_preference_score(v_viewer_profile_id, eligible.profile_id) +
      public.directional_preference_score(eligible.profile_id, v_viewer_profile_id)
    ) / 2.0 AS mutual_preference_score
    FROM eligible
    WHERE public.mutual_dealbreakers_match(v_viewer_profile_id, eligible.profile_id)
  ), ranked AS (
    SELECT mutually_scored.*, (
      mutual_preference_score * 0.80 +
      LEAST(100.0, GREATEST(0.0, COALESCE(rank_score, 0.0))) * 0.20
    )::double precision AS recommendation_score
    FROM mutually_scored
  )
  SELECT profile_id, user_id, gender, first_name, last_name_initial, age,
    city_name, country_code, sect, deen_level, profession, bio, photo_url,
    photo_count, photo_privacy, is_verified, distance_km,
    recommendation_score AS rank_score, marriage_timeline, height_cm,
    complexion, mother_tongue, smoking_habit, community, diet_type,
    living_expectation, quran_memorization, religious_education,
    willing_to_relocate, previously_married, family_type, children_count,
    languages, interests, preferred_age_min, preferred_age_max,
    last_active_at, blurhash
  FROM ranked
  WHERE p_cursor_score IS NULL OR recommendation_score < p_cursor_score
    OR (recommendation_score = p_cursor_score AND profile_id < p_cursor_id)
  ORDER BY recommendation_score DESC, profile_id DESC
  LIMIT LEAST(GREATEST(p_page_size, 1), 15);
END;
$$;

REVOKE ALL ON FUNCTION public.mutual_dealbreakers_match(uuid, uuid) FROM PUBLIC;
COMMENT ON FUNCTION public.get_discovery_feed(uuid, double precision, uuid, integer, jsonb) IS
  'Ranks the complete eligible pool by reciprocal preferences after applying both users non-negotiable deal-breakers.';
