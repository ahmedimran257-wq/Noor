-- Precomputed discovery recommendations for 1M-user scale.
-- The app reads ranked rows from public.recommendations instead of scoring the
-- full eligible pool every time discovery opens. Refresh work is bounded.

CREATE TABLE IF NOT EXISTS public.recommendations (
  viewer_profile_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  candidate_profile_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  score double precision NOT NULL,
  reason_tags text[] NOT NULL DEFAULT ARRAY[]::text[],
  generated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (viewer_profile_id, candidate_profile_id),
  CHECK (viewer_profile_id <> candidate_profile_id)
);

CREATE INDEX IF NOT EXISTS idx_recommendations_viewer_score
  ON public.recommendations(viewer_profile_id, score DESC, candidate_profile_id DESC);

CREATE INDEX IF NOT EXISTS idx_recommendations_generated_at
  ON public.recommendations(generated_at);

ALTER TABLE public.recommendations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS recommendations_viewer_select ON public.recommendations;
CREATE POLICY recommendations_viewer_select
  ON public.recommendations FOR SELECT
  USING (
    viewer_profile_id IN (
      SELECT p.id FROM public.profiles p WHERE p.user_id = auth.uid()
    )
  );

CREATE OR REPLACE FUNCTION public.refresh_recommendations_for_viewer(
  p_viewer_user_id uuid,
  p_seed_limit integer DEFAULT 700,
  p_keep_limit integer DEFAULT 500
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_viewer_profile_id uuid;
  v_viewer_gender text;
  v_viewer_visible boolean;
  v_gender_pref text;
  v_inserted integer := 0;
  v_seed_limit integer := least(greatest(coalesce(p_seed_limit, 700), 50), 1500);
  v_keep_limit integer := least(greatest(coalesce(p_keep_limit, 500), 20), 1000);
BEGIN
  IF auth.uid() IS NOT NULL
      AND auth.uid() IS DISTINCT FROM p_viewer_user_id
      AND NOT public.is_active_admin(ARRAY['super_admin','moderator']) THEN
    RAISE EXCEPTION 'Recommendations can only be refreshed for the signed-in user';
  END IF;

  SELECT
    p.id,
    p.gender,
    p.visibility = 'visible'
      AND coalesce(p.onboarding_completed, false) = true
      AND p.approved_at IS NOT NULL
      AND EXISTS (
        SELECT 1
        FROM public.photos ph
        WHERE ph.profile_id = p.id
          AND ph.admin_approved = true
          AND ph.nsfw_cleared = true
      )
  INTO v_viewer_profile_id, v_viewer_gender, v_viewer_visible
  FROM public.profiles p
  WHERE p.user_id = p_viewer_user_id;

  IF v_viewer_profile_id IS NULL THEN
    RETURN 0;
  END IF;

  IF coalesce(v_viewer_visible, false) IS DISTINCT FROM true THEN
    DELETE FROM public.recommendations WHERE viewer_profile_id = v_viewer_profile_id;
    RETURN 0;
  END IF;

  v_gender_pref := CASE
    WHEN lower(v_viewer_gender) = 'male' THEN 'female'
    WHEN lower(v_viewer_gender) = 'female' THEN 'male'
    ELSE NULL
  END;

  DELETE FROM public.recommendations WHERE viewer_profile_id = v_viewer_profile_id;

  WITH seed AS (
    SELECT *
    FROM public.get_discovery_feed_global_pool(
      p_viewer_user_id,
      NULL,
      NULL,
      v_seed_limit,
      CASE
        WHEN v_gender_pref IS NULL THEN '{}'::jsonb
        ELSE jsonb_build_object('gender_pref', v_gender_pref)
      END
    )
  ), scored AS (
    SELECT
      seed.profile_id,
      (
        (
          public.directional_preference_score(v_viewer_profile_id, seed.profile_id)
          + public.directional_preference_score(seed.profile_id, v_viewer_profile_id)
        ) / 2.0 * 0.80
        + LEAST(100.0, GREATEST(0.0, COALESCE(seed.rank_score, 0.0))) * 0.20
      )::double precision AS score,
      ARRAY_REMOVE(ARRAY[
        CASE WHEN seed.distance_km IS NOT NULL AND seed.distance_km <= 50 THEN 'nearby' END,
        CASE WHEN seed.is_verified THEN 'verified' END,
        CASE WHEN seed.last_active_at >= now() - interval '14 days' THEN 'recently_active' END,
        CASE WHEN lower(coalesce(seed.deen_level, '')) IN ('practicing', 'very_practicing') THEN 'deen_aligned' END,
        CASE WHEN seed.country_code IS NOT NULL THEN 'country_context' END
      ], NULL)::text[] AS reason_tags
    FROM seed
    WHERE public.mutual_dealbreakers_match(v_viewer_profile_id, seed.profile_id)
  ), ranked AS (
    SELECT *
    FROM scored
    ORDER BY score DESC, profile_id DESC
    LIMIT v_keep_limit
  )
  INSERT INTO public.recommendations (
    viewer_profile_id,
    candidate_profile_id,
    score,
    reason_tags,
    generated_at
  )
  SELECT
    v_viewer_profile_id,
    ranked.profile_id,
    ranked.score,
    ranked.reason_tags,
    now()
  FROM ranked
  ON CONFLICT (viewer_profile_id, candidate_profile_id) DO UPDATE
  SET score = EXCLUDED.score,
      reason_tags = EXCLUDED.reason_tags,
      generated_at = EXCLUDED.generated_at;

  GET DIAGNOSTICS v_inserted = ROW_COUNT;
  RETURN v_inserted;
END;
$$;

CREATE OR REPLACE FUNCTION public.refresh_recommendations_for_recent_viewers(
  p_limit integer DEFAULT 500
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_count integer := 0;
BEGIN
  FOR v_user_id IN
    SELECT p.user_id
    FROM public.profiles p
    WHERE p.visibility = 'visible'
      AND coalesce(p.onboarding_completed, false) = true
      AND p.approved_at IS NOT NULL
      AND p.last_active_at >= now() - interval '30 days'
    ORDER BY p.last_active_at DESC NULLS LAST
    LIMIT least(greatest(coalesce(p_limit, 500), 1), 5000)
  LOOP
    PERFORM public.refresh_recommendations_for_viewer(v_user_id, 700, 500);
    v_count := v_count + 1;
  END LOOP;

  RETURN v_count;
END;
$$;

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
  v_viewer_city_id uuid;
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
      OR ST_DWithin(dp.location, v_viewer_location, ((p_filters->>'max_distance_km')::double precision * 1000.0))
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

DO $do$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_namespace WHERE nspname = 'cron') THEN
    IF EXISTS (
      SELECT 1
      FROM cron.job
      WHERE jobname = 'refresh_recommendations_recent_viewers_10m'
    ) THEN
      PERFORM cron.unschedule('refresh_recommendations_recent_viewers_10m');
    END IF;

    PERFORM cron.schedule(
      'refresh_recommendations_recent_viewers_10m',
      '*/10 * * * *',
      $job$SELECT public.refresh_recommendations_for_recent_viewers(300);$job$
    );
  END IF;
EXCEPTION
  WHEN undefined_function OR undefined_table OR invalid_parameter_value THEN
    NULL;
END;
$do$;

REVOKE ALL ON FUNCTION public.refresh_recommendations_for_viewer(uuid, integer, integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.refresh_recommendations_for_recent_viewers(integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_discovery_feed(uuid, double precision, uuid, integer, jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.refresh_recommendations_for_viewer(uuid, integer, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_discovery_feed(uuid, double precision, uuid, integer, jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.refresh_recommendations_for_recent_viewers(integer) TO service_role;
