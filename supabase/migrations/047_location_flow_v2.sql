-- Phase 1 location flow: explicit completion state and safe legacy migration.
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS onboarding_flow_version integer NOT NULL DEFAULT 1,
  ADD COLUMN IF NOT EXISTS onboarding_completed boolean NOT NULL DEFAULT false;

-- A completed legacy profile stays complete. Incomplete profiles without both
-- country and city are sent only to the new mandatory Quick Location step.
WITH legacy AS (
  SELECT
    id,
    (guardian_mode IS NOT NULL AND guardian_mode <> 'none') AS guardian_path,
    onboarding_step AS old_step,
    country_code IS NOT NULL AND city_id IS NOT NULL AS has_location,
    onboarding_step >= CASE
      WHEN guardian_mode IS NOT NULL AND guardian_mode <> 'none' THEN 12
      ELSE 11
    END AS was_complete
  FROM public.profiles
  WHERE onboarding_flow_version = 1
)
UPDATE public.profiles p
SET
  onboarding_completed = legacy.was_complete,
  onboarding_flow_version = 2,
  onboarding_step = CASE
    WHEN legacy.was_complete THEN CASE WHEN legacy.guardian_path THEN 13 ELSE 12 END
    WHEN NOT legacy.has_location THEN CASE WHEN legacy.guardian_path THEN 2 ELSE 1 END
    WHEN legacy.guardian_path AND legacy.old_step <= 1 THEN legacy.old_step
    WHEN legacy.guardian_path THEN legacy.old_step + 1
    WHEN legacy.old_step = 0 THEN 0
    ELSE legacy.old_step + 1
  END
FROM legacy
WHERE p.id = legacy.id;

ALTER TABLE public.profiles
  ALTER COLUMN onboarding_flow_version SET DEFAULT 2;

CREATE INDEX IF NOT EXISTS idx_profiles_onboarding_completed
  ON public.profiles (onboarding_completed)
  WHERE onboarding_completed = true;

-- Referral rewards fire once from the explicit completion marker, independent
-- of future onboarding step insertions.
CREATE OR REPLACE FUNCTION public.check_referral_reward()
RETURNS trigger AS $$
DECLARE
  v_referral referrals%ROWTYPE;
  v_referrer_gender text;
  v_referred_gender text;
BEGIN
  IF NOT NEW.onboarding_completed OR OLD.onboarding_completed THEN
    RETURN NEW;
  END IF;

  SELECT * INTO v_referral FROM referrals
  WHERE referred_id = NEW.user_id AND reward_granted = false;
  IF v_referral IS NULL THEN RETURN NEW; END IF;

  SELECT gender INTO v_referrer_gender FROM users WHERE id = v_referral.referrer_id;
  SELECT gender INTO v_referred_gender FROM users WHERE id = NEW.user_id;
  UPDATE referrals SET referred_gender = v_referred_gender,
    referrer_gender = v_referrer_gender WHERE id = v_referral.id;

  IF v_referrer_gender IS NOT NULL AND v_referred_gender IS NOT NULL
      AND v_referrer_gender <> v_referred_gender THEN
    UPDATE users SET subscription_status = 'active',
      subscription_expires_at = CASE
        WHEN subscription_expires_at > NOW() THEN subscription_expires_at + INTERVAL '7 days'
        ELSE NOW() + INTERVAL '7 days' END
    WHERE id = v_referral.referrer_id;
    UPDATE referrals SET reward_granted = true, reward_type = '7_days_premium'
    WHERE id = v_referral.id;
  ELSE
    UPDATE referrals SET reward_granted = true, reward_type = 'same_gender_no_reward'
    WHERE id = v_referral.id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS trg_check_referral_reward ON public.profiles;
CREATE TRIGGER trg_check_referral_reward
  AFTER UPDATE OF onboarding_completed ON public.profiles
  FOR EACH ROW
  WHEN (NEW.onboarding_completed IS TRUE AND OLD.onboarding_completed IS FALSE)
  EXECUTE FUNCTION public.check_referral_reward();

-- Keep the real-time arrival path aligned with the materialized discovery pool.
CREATE OR REPLACE FUNCTION public.get_new_arrivals(
  p_viewer_gender text,
  p_viewer_id uuid
)
RETURNS TABLE(
  profile_id uuid, user_id uuid, gender text, first_name text,
  last_name_initial text, age integer, city_name text, country_code text,
  sect text, deen_level text, profession text, bio text, photo_url text,
  photo_count integer, photo_privacy text, is_verified boolean,
  rank_score double precision, last_active_at timestamptz, location geography,
  marriage_timeline text, diaspora_mode boolean, open_to_diaspora boolean,
  preferred_countries text[], preferred_age_min int, preferred_age_max int,
  education_rank int, date_of_birth date, previously_married text,
  children_count int, family_type text, mother_tongue text, community text,
  living_expectation text, quran_memorization text, willing_to_relocate text,
  is_boosted boolean, boost_expires_at timestamptz
)
AS $$
BEGIN
  RETURN QUERY
  SELECT p.id, p.user_id, p.gender, p.first_name, LEFT(p.last_name, 1),
    EXTRACT(YEAR FROM age(p.date_of_birth))::integer, c.name, p.country_code,
    p.sect::text, p.deen_level::text, p.profession, p.bio,
    (SELECT CASE WHEN p.photo_privacy = 'public' THEN ph.storage_path END
      FROM photos ph WHERE ph.profile_id = p.id AND ph.order_index = 0
      AND ph.admin_approved AND ph.nsfw_cleared LIMIT 1),
    (SELECT COUNT(*)::integer FROM photos ph WHERE ph.profile_id = p.id
      AND ph.admin_approved AND ph.nsfw_cleared),
    p.photo_privacy::text, p.is_verified,
    (COALESCE(p.static_rank_score, 0) + 15)::double precision,
    p.last_active_at, p.location, p.marriage_timeline, pr.diaspora_mode,
    pr.open_to_diaspora, pr.preferred_countries, pr.preferred_age_min,
    pr.preferred_age_max, p.education_rank, p.date_of_birth,
    p.previously_married, p.children_count, p.family_type, p.mother_tongue,
    p.community, p.living_expectation, p.quran_memorization,
    p.willing_to_relocate, p.is_boosted, p.boost_expires_at
  FROM profiles p
  LEFT JOIN cities c ON p.city_id = c.id
  LEFT JOIN profile_preferences pr ON p.id = pr.profile_id
  WHERE p.visibility = 'visible'
    AND p.onboarding_completed = true
    AND p.approved_at IS NOT NULL
    AND p.approved_at > NOW() - INTERVAL '48 hours'
    AND p.gender <> p_viewer_gender
    AND p.user_id <> p_viewer_id
    AND NOT EXISTS (SELECT 1 FROM discovery_pool dp WHERE dp.profile_id = p.id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- The pool must use the same marker as the real-time path. Preserve the
-- current column contract so the existing feed RPC remains compatible.
DROP MATERIALIZED VIEW IF EXISTS public.discovery_pool;
CREATE MATERIALIZED VIEW public.discovery_pool AS
SELECT
  p.id AS profile_id, p.user_id, p.gender, p.visibility, p.onboarding_step,
  p.first_name, LEFT(p.last_name, 1) AS last_name_initial,
  EXTRACT(YEAR FROM age(p.date_of_birth))::integer AS age,
  c.name AS city_name, p.country_code, c.id AS city_id, p.sect::text,
  p.sub_sect, p.deen_level::text, p.profession, p.bio,
  p.static_rank_score AS rank_score, p.last_active_at, p.location,
  ST_Y(p.location::geometry) AS lat, ST_X(p.location::geometry) AS lng,
  p.photo_privacy::text, p.is_verified, p.education_rank, p.height_cm,
  p.date_of_birth, p.approved_at, p.is_boosted, p.boost_expires_at,
  p.complexion, p.mother_tongue, p.community, p.residency_status,
  p.diet_type, p.smoking_habit, p.quran_memorization, p.religious_education,
  p.marriage_timeline, p.willing_to_relocate, p.living_expectation,
  p.is_revert, p.special_needs, p.previously_married, p.children_count,
  p.family_type, p.niqab_preference, p.mahr_expectation, p.mahr_budget,
  p.can_provide_housing, p.can_provide_maintenance, p.polygamy_status,
  p.listens_to_music, p.eats_zabiha_only, p.attends_islamic_classes,
  p.reads_quran_daily, p.celebrates_mawlid, p.watches_movies,
  p.gender_mixing_stance,
  (SELECT COUNT(*)::integer FROM photos ph WHERE ph.profile_id = p.id
    AND ph.admin_approved AND ph.nsfw_cleared) AS photo_count,
  (SELECT CASE WHEN p.photo_privacy = 'public' THEN ph.storage_path END
    FROM photos ph WHERE ph.profile_id = p.id AND ph.order_index = 0
    AND ph.admin_approved AND ph.nsfw_cleared LIMIT 1) AS photo_url,
  (SELECT CASE WHEN p.photo_privacy = 'public' THEN ph.blurhash END
    FROM photos ph WHERE ph.profile_id = p.id AND ph.order_index = 0
    AND ph.admin_approved AND ph.nsfw_cleared LIMIT 1) AS blurhash,
  pr.diaspora_mode, pr.open_to_diaspora, pr.preferred_countries,
  pr.preferred_age_min, pr.preferred_age_max, pr.min_education_rank,
  pr.deen_preference, pr.preferred_mother_tongue, pr.preferred_community,
  pr.preferred_height_min, pr.preferred_height_max,
  pr.preferred_marriage_timeline, pr.preferred_relocation,
  pr.preferred_living_expectation,
  pr.polygamy_acceptance AS pref_polygamy_acceptance, pr.revert_acceptance,
  pr.special_needs_acceptance, pr.pref_music_stance, pr.pref_zabiha_only,
  pr.pref_quran_daily, pr.pref_gender_mixing
FROM profiles p
LEFT JOIN cities c ON p.city_id = c.id
JOIN profile_preferences pr ON p.id = pr.profile_id
WHERE p.visibility = 'visible' AND p.onboarding_completed = true;

CREATE UNIQUE INDEX idx_discovery_pool_id ON public.discovery_pool(profile_id);
CREATE INDEX idx_discovery_pool_location ON public.discovery_pool USING GIST(location);
CREATE INDEX idx_discovery_pool_rank ON public.discovery_pool(rank_score DESC, profile_id DESC);
CREATE INDEX idx_discovery_pool_gender ON public.discovery_pool(gender);
CREATE INDEX idx_discovery_pool_country ON public.discovery_pool(country_code);
CREATE INDEX idx_discovery_pool_gender_country_rank
  ON public.discovery_pool(gender, country_code, rank_score DESC);
