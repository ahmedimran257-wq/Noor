-- Keep the discovery RPC aligned with the integer-backed global city schema.
-- Anchoring the local variable to profiles.city_id prevents this contract from
-- silently drifting again if the reference-table key type changes later.

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
  v_viewer_visibility text;
  v_viewer_completed boolean;
  v_viewer_approved_at timestamptz;
  v_viewer_photo_count integer;
  v_viewer_location geography;
  v_viewer_country text;
  v_viewer_city_id public.profiles.city_id%TYPE;
  v_gender_pref text := nullif(lower(trim(p_filters->>'gender_pref')), '');
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
    p.visibility,
    p.onboarding_completed,
    p.approved_at,
    p.location,
    p.country_code,
    p.city_id,
    (
      SELECT count(*)::integer
      FROM public.photos ph
      WHERE ph.profile_id = p.id
        AND ph.admin_approved = true
        AND ph.nsfw_cleared = true
    )
  INTO
    v_viewer_profile_id,
    v_viewer_visibility,
    v_viewer_completed,
    v_viewer_approved_at,
    v_viewer_location,
    v_viewer_country,
    v_viewer_city_id,
    v_viewer_photo_count
  FROM public.profiles p
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

  IF NOT EXISTS (
    SELECT 1
    FROM public.recommendations rec
    WHERE rec.viewer_profile_id = v_viewer_profile_id
      AND rec.generated_at >= now() - interval '24 hours'
  ) THEN
    PERFORM public.refresh_recommendations_for_viewer(p_viewer_id, 700, 500);
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
    CASE
      WHEN v_viewer_location IS NOT NULL AND dp.location IS NOT NULL
        THEN ST_Distance(dp.location, v_viewer_location) / 1000.0
      ELSE NULL
    END AS distance_km,
    rec.score AS rank_score,
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
    ARRAY[]::text[] AS languages,
    ARRAY[]::text[] AS interests,
    dp.preferred_age_min,
    dp.preferred_age_max,
    dp.last_active_at,
    dp.blurhash
  FROM public.recommendations rec
  JOIN public.discovery_pool dp
    ON dp.profile_id = rec.candidate_profile_id
  WHERE rec.viewer_profile_id = v_viewer_profile_id
    AND rec.generated_at >= now() - interval '7 days'
    AND dp.user_id <> p_viewer_id
    AND (v_gender_pref IS NULL OR dp.gender = v_gender_pref)
    AND ((p_filters ? 'age_min') IS FALSE OR dp.age >= (p_filters->>'age_min')::integer)
    AND ((p_filters ? 'age_max') IS FALSE OR dp.age <= (p_filters->>'age_max')::integer)
    AND (coalesce((p_filters->>'active_recently')::boolean, false) IS FALSE
      OR dp.last_active_at >= now() - interval '14 days')
    AND (coalesce((p_filters->>'verified_only')::boolean, false) IS FALSE
      OR dp.is_verified = true)
    AND (nullif(p_filters->>'sect', '') IS NULL OR lower(coalesce(dp.sect, '')) = lower(p_filters->>'sect'))
    AND (nullif(p_filters->>'deen_level', '') IS NULL OR lower(coalesce(dp.deen_level, '')) = lower(p_filters->>'deen_level'))
    AND (nullif(p_filters->>'family_type', '') IS NULL OR lower(coalesce(dp.family_type, '')) = lower(p_filters->>'family_type'))
    AND (nullif(p_filters->>'marital_status', '') IS NULL OR lower(coalesce(dp.previously_married, '')) = lower(p_filters->>'marital_status'))
    AND (
      coalesce((p_filters->>'open_to_divorced')::boolean, true) = true
      OR coalesce(dp.previously_married, 'no') = 'no'
    )
    AND ((p_filters ? 'education_min') IS FALSE OR coalesce(dp.education_rank, 0) >= (p_filters->>'education_min')::integer)
    AND (nullif(p_filters->>'mother_tongue', '') IS NULL OR lower(coalesce(dp.mother_tongue, '')) = lower(p_filters->>'mother_tongue'))
    AND (nullif(p_filters->>'community', '') IS NULL OR lower(coalesce(dp.community, '')) = lower(p_filters->>'community'))
    AND (nullif(p_filters->>'living_expectation', '') IS NULL OR lower(coalesce(dp.living_expectation, '')) = lower(p_filters->>'living_expectation'))
    AND (nullif(p_filters->>'quran_memorization', '') IS NULL OR lower(coalesce(dp.quran_memorization, '')) = lower(p_filters->>'quran_memorization'))
    AND (nullif(p_filters->>'marriage_timeline', '') IS NULL OR lower(coalesce(dp.marriage_timeline, '')) = lower(p_filters->>'marriage_timeline'))
    AND (nullif(p_filters->>'willing_to_relocate', '') IS NULL OR lower(coalesce(dp.willing_to_relocate, '')) = lower(p_filters->>'willing_to_relocate'))
    AND (
      nullif(p_filters->>'has_children', '') IS NULL
      OR (p_filters->>'has_children' = 'yes' AND coalesce(dp.children_count, 0) > 0)
      OR (p_filters->>'has_children' = 'no' AND coalesce(dp.children_count, 0) = 0)
    )
    AND (
      coalesce((p_filters->>'same_country')::boolean, false) IS FALSE
      OR dp.country_code = v_viewer_country
    )
    AND (
      coalesce((p_filters->>'same_city')::boolean, false) IS FALSE
      OR dp.city_id = v_viewer_city_id
    )
    AND (
      (p_filters ? 'max_distance_km') IS FALSE
      OR v_viewer_location IS NULL
      OR dp.location IS NULL
      OR ST_DWithin(
        dp.location,
        v_viewer_location,
        ((p_filters->>'max_distance_km')::double precision * 1000.0)
      )
    )
    AND (
      p_cursor_score IS NULL
      OR rec.score < p_cursor_score
      OR (rec.score = p_cursor_score AND rec.candidate_profile_id < p_cursor_id)
    )
  ORDER BY rec.score DESC, rec.candidate_profile_id DESC
  LIMIT least(v_page_size, v_remaining);
END;
$$;

REVOKE ALL ON FUNCTION public.get_discovery_feed(
  uuid, double precision, uuid, integer, jsonb
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_discovery_feed(
  uuid, double precision, uuid, integer, jsonb
) TO authenticated;
