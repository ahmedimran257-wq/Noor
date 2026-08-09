-- Restore the internal reciprocal-preference scorer used by
-- get_discovery_feed. Migration 199 retired it as if it belonged only to the
-- old recommendation pipeline, but the live feed still resolves this helper
-- at execution time. PostgreSQL does not record dependencies inside PL/pgSQL
-- function bodies, so DROP ... RESTRICT could not protect the feed.

CREATE OR REPLACE FUNCTION public.directional_preference_score(
  p_seeker_profile_id uuid,
  p_candidate_profile_id uuid
)
RETURNS double precision
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
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
    SELECT
      22::double precision AS weight,
      preferred_age_min IS NOT NULL AND preferred_age_max IS NOT NULL AS specified,
      extract(year FROM age(candidate_dob))
        BETWEEN preferred_age_min AND preferred_age_max AS matched
    FROM data
    UNION ALL
    SELECT
      14,
      coalesce(nullif(lower(sect_preference), ''), 'any')
        NOT IN ('any', 'no preference'),
      CASE
        WHEN lower(sect_preference) = 'same as mine' THEN
          lower(coalesce(candidate_sect, '')) = lower(coalesce(seeker_sect, ''))
        ELSE
          lower(coalesce(candidate_sect, '')) = lower(coalesce(sect_preference, ''))
      END
    FROM data
    UNION ALL
    SELECT
      14,
      coalesce(nullif(lower(deen_preference), ''), 'any')
        NOT IN ('any', 'no preference'),
      CASE
        WHEN lower(deen_preference) = 'same as mine' THEN
          lower(coalesce(candidate_deen, '')) = lower(coalesce(seeker_deen, ''))
        ELSE
          lower(coalesce(candidate_deen, '')) = lower(coalesce(deen_preference, ''))
      END
    FROM data
    UNION ALL
    SELECT
      10,
      min_education_rank IS NOT NULL AND min_education_rank > 1,
      coalesce(candidate_education, 0) >= min_education_rank
    FROM data
    UNION ALL
    SELECT
      7,
      coalesce(cardinality(preferred_mother_tongue), 0) > 0,
      candidate_mother_tongue = ANY(preferred_mother_tongue)
    FROM data
    UNION ALL
    SELECT
      6,
      coalesce(cardinality(preferred_community), 0) > 0,
      candidate_community = ANY(preferred_community)
    FROM data
    UNION ALL
    SELECT
      6,
      preferred_height_min IS NOT NULL OR preferred_height_max IS NOT NULL,
      (preferred_height_min IS NULL
        OR coalesce(candidate_height, 0) >= preferred_height_min)
      AND (preferred_height_max IS NULL
        OR coalesce(candidate_height, 999) <= preferred_height_max)
    FROM data
    UNION ALL
    SELECT
      5,
      coalesce(preferred_marriage_timeline, 'no_preference') <> 'no_preference',
      candidate_timeline = preferred_marriage_timeline
    FROM data
    UNION ALL
    SELECT
      5,
      coalesce(preferred_relocation, 'no_preference') <> 'no_preference',
      candidate_relocation = preferred_relocation
    FROM data
    UNION ALL
    SELECT
      5,
      coalesce(preferred_living_expectation, 'no_preference') <> 'no_preference',
      candidate_living = preferred_living_expectation
    FROM data
    UNION ALL
    SELECT
      3,
      candidate_marital_status = 'divorced',
      coalesce(open_to_divorced, false)
    FROM data
    UNION ALL
    SELECT
      2,
      candidate_marital_status = 'widowed',
      coalesce(open_to_widowed, false)
    FROM data
    UNION ALL
    SELECT
      1,
      coalesce(candidate_children, 0) > 0,
      coalesce(open_to_has_children, false)
    FROM data
  )
  SELECT coalesce(
    round(
      (
        100.0
        * sum(CASE WHEN specified AND matched THEN weight ELSE 0 END)
        / nullif(sum(CASE WHEN specified THEN weight ELSE 0 END), 0)
      )::numeric,
      1
    ),
    50.0
  )::double precision
  FROM criteria;
$$;

-- This helper is an implementation detail of the SECURITY DEFINER feed. It
-- must not become an independently callable member API.
REVOKE ALL ON FUNCTION public.directional_preference_score(uuid, uuid)
  FROM PUBLIC, anon, authenticated;

DO $migration$
DECLARE
  v_feed regprocedure :=
    'public.get_discovery_feed(uuid,double precision,uuid,integer,jsonb)'::regprocedure;
  v_definition text;
BEGIN
  SELECT pg_get_functiondef(v_feed) INTO v_definition;

  IF position('public.directional_preference_score(' IN v_definition) = 0 THEN
    RAISE EXCEPTION 'discovery_preference_dependency_contract_changed'
      USING ERRCODE = 'P0001';
  END IF;

  IF to_regprocedure('public.directional_preference_score(uuid,uuid)') IS NULL THEN
    RAISE EXCEPTION 'discovery_preference_dependency_missing'
      USING ERRCODE = 'P0001';
  END IF;
END;
$migration$;

COMMENT ON FUNCTION public.directional_preference_score(uuid, uuid) IS
  'Internal reciprocal-preference scorer required by get_discovery_feed; not exposed to API roles.';

-- Make the repaired contract visible immediately even when PostgREST retained
-- a schema snapshot across the previous migration deployment.
NOTIFY pgrst, 'reload schema';
