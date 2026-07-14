-- Fix PL/pgSQL output-column ambiguity in get_discovery_feed.
-- RETURNS TABLE columns such as user_id/profile_id are visible as variables
-- inside the function body, so every table/CTE reference must be qualified.

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
DECLARE
  v_viewer_profile_id uuid;
  v_limit integer;
  v_count integer;
  v_remaining integer;
BEGIN
  IF auth.uid() IS DISTINCT FROM p_viewer_id THEN
    RAISE EXCEPTION 'Discovery can only be requested for the signed-in user.';
  END IF;

  SELECT p.id INTO v_viewer_profile_id
  FROM public.profiles AS p
  WHERE p.user_id = p_viewer_id;

  IF v_viewer_profile_id IS NULL THEN
    RETURN;
  END IF;

  v_limit := coalesce(public.profile_view_daily_limit(p_viewer_id), 15);

  SELECT count(*)::integer INTO v_count
  FROM public.profile_view_daily_seen AS seen
  WHERE seen.viewer_user_id = p_viewer_id
    AND seen.viewed_on = current_date;

  v_remaining := greatest(v_limit - v_count, 0);
  IF v_remaining <= 0 THEN
    RETURN;
  END IF;

  RETURN QUERY
  WITH eligible AS (
    SELECT *
    FROM public.get_discovery_feed_global_pool(
      p_viewer_id, NULL, NULL, 2147483647, p_filters
    )
  ), mutually_scored AS (
    SELECT
      e.*,
      (
        public.directional_preference_score(v_viewer_profile_id, e.profile_id)
        + public.directional_preference_score(e.profile_id, v_viewer_profile_id)
      ) / 2.0 AS mutual_preference_score
    FROM eligible AS e
    WHERE public.mutual_dealbreakers_match(v_viewer_profile_id, e.profile_id)
  ), ranked AS (
    SELECT
      ms.*,
      (
        ms.mutual_preference_score * 0.80
        + LEAST(100.0, GREATEST(0.0, COALESCE(ms.rank_score, 0.0))) * 0.20
      )::double precision AS recommendation_score
    FROM mutually_scored AS ms
  )
  SELECT
    r.profile_id,
    r.user_id,
    r.gender,
    r.first_name,
    r.last_name_initial,
    r.age,
    r.city_name,
    r.country_code,
    r.sect,
    r.deen_level,
    r.profession,
    r.bio,
    r.photo_url,
    r.photo_count,
    r.photo_privacy,
    r.is_verified,
    r.distance_km,
    r.recommendation_score AS rank_score,
    r.marriage_timeline,
    r.height_cm,
    r.complexion,
    r.mother_tongue,
    r.smoking_habit,
    r.community,
    r.diet_type,
    r.living_expectation,
    r.quran_memorization,
    r.religious_education,
    r.willing_to_relocate,
    r.previously_married,
    r.family_type,
    r.children_count,
    r.languages,
    r.interests,
    r.preferred_age_min,
    r.preferred_age_max,
    r.last_active_at,
    r.blurhash
  FROM ranked AS r
  WHERE p_cursor_score IS NULL
    OR r.recommendation_score < p_cursor_score
    OR (r.recommendation_score = p_cursor_score AND r.profile_id < p_cursor_id)
  ORDER BY r.recommendation_score DESC, r.profile_id DESC
  LIMIT LEAST(GREATEST(p_page_size, 1), 15, v_remaining);
END;
$$;

REVOKE ALL ON FUNCTION public.get_discovery_feed(
  uuid, double precision, uuid, integer, jsonb
) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.get_discovery_feed(
  uuid, double precision, uuid, integer, jsonb
) TO authenticated;
