-- ============================================================
-- MITHAQ — Server-side profile view limits
-- ============================================================

CREATE TABLE IF NOT EXISTS public.profile_view_daily_seen (
  viewer_user_id    uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  viewed_profile_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  viewed_on         date NOT NULL DEFAULT current_date,
  first_viewed_at   timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (viewer_user_id, viewed_profile_id, viewed_on)
);

CREATE INDEX IF NOT EXISTS idx_profile_view_daily_seen_user_day
  ON public.profile_view_daily_seen(viewer_user_id, viewed_on);

ALTER TABLE public.profile_view_daily_seen ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS profile_view_daily_seen_self_select ON public.profile_view_daily_seen;
CREATE POLICY profile_view_daily_seen_self_select
  ON public.profile_view_daily_seen FOR SELECT
  USING (viewer_user_id = auth.uid());

CREATE OR REPLACE FUNCTION public.profile_view_daily_limit(p_user_id uuid)
RETURNS integer
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT CASE
    WHEN u.subscription_status IN ('active', 'grace')
      AND (u.subscription_expires_at IS NULL OR u.subscription_expires_at > now())
      THEN 2147483647
    ELSE 15
  END
  FROM public.users u
  WHERE u.id = p_user_id;
$$;

CREATE OR REPLACE FUNCTION public.get_profile_view_quota()
RETURNS TABLE (
  views_today integer,
  daily_limit integer,
  remaining integer,
  is_limited boolean
)
LANGUAGE plpgsql
SECURITY INVOKER
AS $$
DECLARE
  v_me uuid := auth.uid();
  v_limit integer;
  v_count integer;
BEGIN
  IF v_me IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = 'P0001';
  END IF;

  v_limit := coalesce(public.profile_view_daily_limit(v_me), 15);

  SELECT count(*)::integer INTO v_count
  FROM public.profile_view_daily_seen
  WHERE viewer_user_id = v_me
    AND viewed_on = current_date;

  RETURN QUERY SELECT
    v_count,
    v_limit,
    greatest(v_limit - v_count, 0),
    v_count >= v_limit;
END;
$$;

CREATE OR REPLACE FUNCTION public.record_profile_view(p_viewed_user_id uuid)
RETURNS TABLE (
  allowed boolean,
  views_today integer,
  daily_limit integer,
  remaining integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_me uuid := auth.uid();
  v_viewer_profile_id uuid;
  v_viewed_profile_id uuid;
  v_limit integer;
  v_count integer;
  v_inserted boolean := false;
BEGIN
  IF v_me IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = 'P0001';
  END IF;

  IF p_viewed_user_id IS NULL OR p_viewed_user_id = v_me THEN
    v_limit := coalesce(public.profile_view_daily_limit(v_me), 15);
    SELECT count(*)::integer INTO v_count
    FROM public.profile_view_daily_seen
    WHERE viewer_user_id = v_me
      AND viewed_on = current_date;
    RETURN QUERY SELECT true, v_count, v_limit, greatest(v_limit - v_count, 0);
    RETURN;
  END IF;

  SELECT id INTO v_viewer_profile_id
  FROM public.profiles
  WHERE user_id = v_me
  LIMIT 1;

  SELECT id INTO v_viewed_profile_id
  FROM public.profiles
  WHERE user_id = p_viewed_user_id
  LIMIT 1;

  IF v_viewer_profile_id IS NULL OR v_viewed_profile_id IS NULL THEN
    RAISE EXCEPTION 'Profile not found' USING ERRCODE = 'P0001';
  END IF;

  v_limit := coalesce(public.profile_view_daily_limit(v_me), 15);

  SELECT count(*)::integer INTO v_count
  FROM public.profile_view_daily_seen
  WHERE viewer_user_id = v_me
    AND viewed_on = current_date;

  IF v_count >= v_limit AND NOT EXISTS (
    SELECT 1 FROM public.profile_view_daily_seen
    WHERE viewer_user_id = v_me
      AND viewed_profile_id = v_viewed_profile_id
      AND viewed_on = current_date
  ) THEN
    RETURN QUERY SELECT false, v_count, v_limit, 0;
    RETURN;
  END IF;

  INSERT INTO public.profile_view_daily_seen(viewer_user_id, viewed_profile_id, viewed_on)
  VALUES (v_me, v_viewed_profile_id, current_date)
  ON CONFLICT DO NOTHING;

  GET DIAGNOSTICS v_count = ROW_COUNT;
  v_inserted := v_count > 0;

  IF v_inserted THEN
    INSERT INTO public.profile_views(viewer_profile_id, viewed_profile_id)
    VALUES (v_viewer_profile_id, v_viewed_profile_id);
  END IF;

  SELECT count(*)::integer INTO v_count
  FROM public.profile_view_daily_seen
  WHERE viewer_user_id = v_me
    AND viewed_on = current_date;

  RETURN QUERY SELECT true, v_count, v_limit, greatest(v_limit - v_count, 0);
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

  SELECT id INTO v_viewer_profile_id
  FROM public.profiles
  WHERE user_id = p_viewer_id;

  v_limit := coalesce(public.profile_view_daily_limit(p_viewer_id), 15);

  SELECT count(*)::integer INTO v_count
  FROM public.profile_view_daily_seen
  WHERE viewer_user_id = p_viewer_id
    AND viewed_on = current_date;

  v_remaining := greatest(v_limit - v_count, 0);
  IF v_remaining <= 0 THEN
    RETURN;
  END IF;

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
  LIMIT LEAST(GREATEST(p_page_size, 1), 15, v_remaining);
END;
$$;

REVOKE ALL ON FUNCTION public.profile_view_daily_limit(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_profile_view_quota() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.record_profile_view(uuid) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.get_profile_view_quota() TO authenticated;
GRANT EXECUTE ON FUNCTION public.record_profile_view(uuid) TO authenticated;
