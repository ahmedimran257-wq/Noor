-- The legacy discovery_pool is refreshed daily and is suitable for background
-- recommendation jobs, but not for an interactive geographic filter. Build an
-- indexed, live source from canonical profile/location rows and switch only the
-- public feed RPC to it. Location, visibility, privacy and photo changes are
-- therefore visible on the next request rather than after a cron refresh.

CREATE INDEX IF NOT EXISTS idx_profiles_live_discovery_geo
  ON public.profiles(
    gender,
    country_code,
    city_id,
    static_rank_score DESC,
    id DESC
  )
  WHERE visibility = 'visible'
    AND onboarding_completed = true
    AND approved_at IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_profiles_live_discovery_location
  ON public.profiles USING GIST(location)
  WHERE visibility = 'visible'
    AND onboarding_completed = true
    AND approved_at IS NOT NULL;

CREATE OR REPLACE VIEW public.live_discovery_pool
WITH (security_invoker = true)
AS
SELECT
  p.id AS profile_id,
  p.user_id,
  p.gender,
  p.first_name,
  left(p.last_name, 1) AS last_name_initial,
  extract(year FROM age(p.date_of_birth))::integer AS age,
  c.name AS city_name,
  p.country_code,
  p.city_id,
  p.sect::text AS sect,
  p.deen_level::text AS deen_level,
  p.profession,
  p.bio,
  CASE WHEN p.photo_privacy = 'public' THEN primary_photo.storage_path END
    AS photo_url,
  photo_totals.photo_count,
  p.photo_privacy::text AS photo_privacy,
  p.is_verified,
  p.location,
  p.static_rank_score AS rank_score,
  p.marriage_timeline,
  p.height_cm,
  p.complexion,
  p.mother_tongue,
  p.smoking_habit,
  p.community,
  p.diet_type,
  p.living_expectation,
  p.quran_memorization,
  p.religious_education,
  p.willing_to_relocate,
  p.previously_married,
  p.family_type,
  p.children_count,
  p.education_rank,
  prefs.preferred_age_min,
  prefs.preferred_age_max,
  p.last_active_at,
  CASE WHEN p.photo_privacy = 'public' THEN primary_photo.blurhash END
    AS blurhash
FROM public.profiles p
LEFT JOIN public.cities c ON c.id = p.city_id
JOIN public.profile_preferences prefs ON prefs.profile_id = p.id
JOIN LATERAL (
  SELECT count(*)::integer AS photo_count
  FROM public.photos ph
  WHERE ph.profile_id = p.id
    AND ph.admin_approved = true
    AND ph.nsfw_cleared = true
) photo_totals ON photo_totals.photo_count > 0
LEFT JOIN LATERAL (
  SELECT ph.storage_path, ph.blurhash
  FROM public.photos ph
  WHERE ph.profile_id = p.id
    AND ph.order_index = 0
    AND ph.admin_approved = true
    AND ph.nsfw_cleared = true
  ORDER BY ph.created_at DESC
  LIMIT 1
) primary_photo ON true
WHERE p.visibility = 'visible'
  AND p.onboarding_completed = true
  AND p.approved_at IS NOT NULL;

REVOKE ALL ON public.live_discovery_pool FROM PUBLIC, anon, authenticated;

DO $migration$
DECLARE
  v_signature regprocedure :=
    'public.get_discovery_feed(uuid,double precision,uuid,integer,jsonb)'::regprocedure;
  v_definition text;
  v_updated text;
BEGIN
  SELECT pg_get_functiondef(v_signature) INTO v_definition;
  v_updated := replace(
    v_definition,
    'FROM public.discovery_pool dp',
    'FROM public.live_discovery_pool dp'
  );

  IF v_updated = v_definition THEN
    RAISE EXCEPTION
      'get_discovery_feed source contract changed; live pool was not installed';
  END IF;

  EXECUTE v_updated;
END;
$migration$;

COMMENT ON VIEW public.live_discovery_pool IS
  'Canonical, immediately consistent source for interactive discovery. The materialized discovery_pool remains available to background recommendation jobs.';
