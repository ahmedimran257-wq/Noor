-- Mutual recommendation ranking. A candidate is evaluated against the
-- viewer's stated preferences and the viewer is evaluated against the
-- candidate's stated preferences. Global quality remains a small, capped
-- tie-breaker, so a paid boost cannot dominate recommendation order.

CREATE OR REPLACE FUNCTION public.directional_preference_score(
  p_seeker_profile_id uuid,
  p_candidate_profile_id uuid
)
RETURNS double precision
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  WITH data AS (
    SELECT
      seeker.date_of_birth AS seeker_dob,
      seeker.sect AS seeker_sect,
      seeker.deen_level AS seeker_deen,
      seeker.education_rank AS seeker_education,
      candidate.date_of_birth AS candidate_dob,
      candidate.sect AS candidate_sect,
      candidate.deen_level AS candidate_deen,
      candidate.education_rank AS candidate_education,
      candidate.mother_tongue AS candidate_mother_tongue,
      candidate.community AS candidate_community,
      candidate.height_cm AS candidate_height,
      candidate.marriage_timeline AS candidate_timeline,
      candidate.willing_to_relocate AS candidate_relocation,
      candidate.living_expectation AS candidate_living,
      candidate.previously_married AS candidate_marital_status,
      candidate.children_count AS candidate_children,
      prefs.*
    FROM public.profiles seeker
    JOIN public.profile_preferences prefs ON prefs.profile_id = seeker.id
    JOIN public.profiles candidate ON candidate.id = p_candidate_profile_id
    WHERE seeker.id = p_seeker_profile_id
  ), criteria AS (
    SELECT 22::double precision AS weight,
      preferred_age_min IS NOT NULL AND preferred_age_max IS NOT NULL AS specified,
      EXTRACT(YEAR FROM age(candidate_dob)) BETWEEN preferred_age_min AND preferred_age_max AS matched
    FROM data
    UNION ALL SELECT 14,
      COALESCE(NULLIF(lower(sect_preference), ''), 'any') NOT IN ('any', 'no preference'),
      CASE WHEN lower(sect_preference) = 'same as mine'
        THEN lower(COALESCE(candidate_sect, '')) = lower(COALESCE(seeker_sect, ''))
        ELSE lower(COALESCE(candidate_sect, '')) = lower(COALESCE(sect_preference, '')) END
    FROM data
    UNION ALL SELECT 14,
      COALESCE(NULLIF(lower(deen_preference), ''), 'any') NOT IN ('any', 'no preference'),
      CASE WHEN lower(deen_preference) = 'same as mine'
        THEN lower(COALESCE(candidate_deen, '')) = lower(COALESCE(seeker_deen, ''))
        ELSE lower(COALESCE(candidate_deen, '')) = lower(COALESCE(deen_preference, '')) END
    FROM data
    UNION ALL SELECT 10,
      min_education_rank IS NOT NULL AND min_education_rank > 1,
      COALESCE(candidate_education, 0) >= min_education_rank
    FROM data
    UNION ALL SELECT 7,
      COALESCE(cardinality(preferred_mother_tongue), 0) > 0,
      candidate_mother_tongue = ANY(preferred_mother_tongue)
    FROM data
    UNION ALL SELECT 6,
      COALESCE(cardinality(preferred_community), 0) > 0,
      candidate_community = ANY(preferred_community)
    FROM data
    UNION ALL SELECT 6,
      preferred_height_min IS NOT NULL OR preferred_height_max IS NOT NULL,
      (preferred_height_min IS NULL OR COALESCE(candidate_height, 0) >= preferred_height_min)
      AND (preferred_height_max IS NULL OR COALESCE(candidate_height, 999) <= preferred_height_max)
    FROM data
    UNION ALL SELECT 5,
      COALESCE(preferred_marriage_timeline, 'no_preference') <> 'no_preference',
      candidate_timeline = preferred_marriage_timeline
    FROM data
    UNION ALL SELECT 5,
      COALESCE(preferred_relocation, 'no_preference') <> 'no_preference',
      candidate_relocation = preferred_relocation
    FROM data
    UNION ALL SELECT 5,
      COALESCE(preferred_living_expectation, 'no_preference') <> 'no_preference',
      candidate_living = preferred_living_expectation
    FROM data
    UNION ALL SELECT 3,
      candidate_marital_status = 'divorced',
      COALESCE(open_to_divorced, false)
    FROM data
    UNION ALL SELECT 2,
      candidate_marital_status = 'widowed',
      COALESCE(open_to_widowed, false)
    FROM data
    UNION ALL SELECT 1,
      COALESCE(candidate_children, 0) > 0,
      COALESCE(open_to_has_children, false)
    FROM data
  )
  SELECT COALESCE(
    ROUND((100.0 * SUM(CASE WHEN specified AND matched THEN weight ELSE 0 END)
      / NULLIF(SUM(CASE WHEN specified THEN weight ELSE 0 END), 0))::numeric, 1),
    50.0
  )::double precision
  FROM criteria;
$$;

-- Preserve the established eligibility/filtering query as an internal pool.
-- The public function below is the only discovery entry point for clients.
DO $$
DECLARE
  definition text;
BEGIN
  SELECT pg_get_functiondef(
    'public.get_discovery_feed(uuid,double precision,uuid,integer,jsonb)'::regprocedure
  ) INTO definition;
  definition := replace(definition, 'p_page_size > 15', 'p_page_size > 250');
  EXECUTE definition;
END;
$$;

ALTER FUNCTION public.get_discovery_feed(uuid, double precision, uuid, integer, jsonb)
  RENAME TO get_discovery_feed_global_pool;
REVOKE ALL ON FUNCTION public.get_discovery_feed_global_pool(
  uuid, double precision, uuid, integer, jsonb
) FROM PUBLIC, anon, authenticated;

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
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS DISTINCT FROM p_viewer_id THEN
    RAISE EXCEPTION 'Discovery can only be requested for the signed-in user.';
  END IF;

  RETURN QUERY
  WITH eligible AS (
    SELECT *
    FROM public.get_discovery_feed_global_pool(
      p_viewer_id, NULL, NULL, 250, p_filters
    )
  ), mutually_scored AS (
    SELECT
      eligible.*,
      (
        public.directional_preference_score((
          SELECT id FROM public.profiles WHERE user_id = p_viewer_id
        ), eligible.profile_id)
        + public.directional_preference_score(eligible.profile_id, (
          SELECT id FROM public.profiles WHERE user_id = p_viewer_id
        ))
      ) / 2.0 AS mutual_preference_score
    FROM eligible
  ), ranked AS (
    SELECT
      mutually_scored.*,
      (
        mutual_preference_score * 0.80
        + LEAST(100.0, GREATEST(0.0, COALESCE(rank_score, 0.0))) * 0.20
      )::double precision AS recommendation_score
    FROM mutually_scored
  )
  SELECT
    profile_id, user_id, gender, first_name, last_name_initial, age,
    city_name, country_code, sect, deen_level, profession, bio, photo_url,
    photo_count, photo_privacy, is_verified, distance_km,
    recommendation_score AS rank_score,
    marriage_timeline, height_cm, complexion, mother_tongue, smoking_habit,
    community, diet_type, living_expectation, quran_memorization,
    religious_education, willing_to_relocate, previously_married, family_type,
    children_count, languages, interests, preferred_age_min, preferred_age_max,
    last_active_at, blurhash
  FROM ranked
  WHERE p_cursor_score IS NULL
    OR recommendation_score < p_cursor_score
    OR (recommendation_score = p_cursor_score AND profile_id < p_cursor_id)
  ORDER BY recommendation_score DESC, profile_id DESC
  LIMIT LEAST(GREATEST(p_page_size, 1), 15);
END;
$$;

REVOKE ALL ON FUNCTION public.directional_preference_score(uuid, uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_discovery_feed(uuid, double precision, uuid, integer, jsonb)
  FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_discovery_feed(
  uuid, double precision, uuid, integer, jsonb
) TO authenticated;

COMMENT ON FUNCTION public.get_discovery_feed(uuid, double precision, uuid, integer, jsonb) IS
  'Ranks eligible candidates by an 80% reciprocal preference score and a 20% capped quality score.';
