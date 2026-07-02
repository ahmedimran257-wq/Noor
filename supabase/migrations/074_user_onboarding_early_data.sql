-- Persist mandatory early onboarding data before profiles can be inserted.
-- profiles requires identity fields, so profile type and location live on
-- public.users until Basic Identity writes the full profile row.

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS onboarding_profile_for text,
  ADD COLUMN IF NOT EXISTS onboarding_profile_creator_relation text,
  ADD COLUMN IF NOT EXISTS onboarding_city_id int REFERENCES public.cities(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS onboarding_city_name text,
  ADD COLUMN IF NOT EXISTS onboarding_state_name text,
  ADD COLUMN IF NOT EXISTS onboarding_postal_code text,
  ADD COLUMN IF NOT EXISTS onboarding_lat numeric(9,6),
  ADD COLUMN IF NOT EXISTS onboarding_lng numeric(9,6);

ALTER TABLE public.users
  DROP CONSTRAINT IF EXISTS users_onboarding_profile_for_check;

ALTER TABLE public.users
  ADD CONSTRAINT users_onboarding_profile_for_check
  CHECK (
    onboarding_profile_for IS NULL
    OR onboarding_profile_for IN ('myself', 'guardian')
  );

CREATE OR REPLACE FUNCTION public.save_onboarding_profile_type(
  p_profile_for text,
  p_profile_creator_relation text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_profile_for text := lower(trim(coalesce(p_profile_for, '')));
  v_relation text := lower(trim(coalesce(p_profile_creator_relation, '')));
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required.';
  END IF;

  IF v_profile_for NOT IN ('myself', 'guardian') THEN
    RAISE EXCEPTION 'Invalid profile type.';
  END IF;

  IF v_profile_for = 'myself' THEN
    v_relation := 'self';
  ELSIF v_relation = '' THEN
    RAISE EXCEPTION 'Guardian relationship is required.';
  END IF;

  UPDATE public.users
  SET
    onboarding_profile_for = v_profile_for,
    onboarding_profile_creator_relation = v_relation,
    is_guardian_path = (v_profile_for = 'guardian')
  WHERE id = v_user_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'User row missing.';
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.save_onboarding_location(
  p_country_code text,
  p_city_id int,
  p_city_name text,
  p_state_name text,
  p_postal_code text,
  p_lat numeric,
  p_lng numeric
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_country_code text := upper(trim(coalesce(p_country_code, '')));
  v_city_name text := trim(coalesce(p_city_name, ''));
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required.';
  END IF;

  IF v_country_code = '' OR length(v_country_code) <> 2 THEN
    RAISE EXCEPTION 'Valid country code is required.';
  END IF;

  IF p_city_id IS NULL OR v_city_name = '' OR p_lat IS NULL OR p_lng IS NULL THEN
    RAISE EXCEPTION 'Resolved city, latitude, and longitude are required.';
  END IF;

  UPDATE public.users
  SET
    country_code = v_country_code,
    onboarding_city_id = p_city_id,
    onboarding_city_name = v_city_name,
    onboarding_state_name = nullif(trim(coalesce(p_state_name, '')), ''),
    onboarding_postal_code = nullif(trim(coalesce(p_postal_code, '')), ''),
    onboarding_lat = p_lat,
    onboarding_lng = p_lng
  WHERE id = v_user_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'User row missing.';
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.save_onboarding_profile_type(text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.save_onboarding_location(text, int, text, text, text, numeric, numeric) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.save_onboarding_profile_type(text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.save_onboarding_location(text, int, text, text, text, numeric, numeric) TO authenticated;

COMMENT ON FUNCTION public.save_onboarding_profile_type(text, text) IS
  'Persists mandatory early profile type before profiles can be inserted.';

COMMENT ON FUNCTION public.save_onboarding_location(text, int, text, text, text, numeric, numeric) IS
  'Persists mandatory Quick Location before profiles can be inserted.';
