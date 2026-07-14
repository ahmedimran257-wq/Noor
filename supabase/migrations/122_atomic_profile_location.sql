-- Canonical profile location changes must keep the user resume fields, profile
-- foreign keys, and PostGIS discovery origin in one transaction.

CREATE OR REPLACE FUNCTION public.guard_profile_location_mutation()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  IF (NEW.city_id, NEW.country_code, NEW.location,
      NEW.location_source, NEW.location_updated_at)
       IS DISTINCT FROM
     (OLD.city_id, OLD.country_code, OLD.location,
      OLD.location_source, OLD.location_updated_at)
     AND current_user NOT IN ('postgres', 'service_role', 'supabase_admin')
     AND current_setting('silarah.allow_location_mutation', true)
         IS DISTINCT FROM 'yes'
  THEN
    RAISE EXCEPTION 'Use update_profile_location() to change profile location.';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS guard_profile_location_mutation ON public.profiles;
CREATE TRIGGER guard_profile_location_mutation
BEFORE UPDATE OF city_id, country_code, location,
                 location_source, location_updated_at
ON public.profiles
FOR EACH ROW EXECUTE FUNCTION public.guard_profile_location_mutation();

CREATE OR REPLACE FUNCTION public.update_profile_location(
  p_city_id int,
  p_country_code text,
  p_postal_code text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_country_code text := upper(trim(coalesce(p_country_code, '')));
  v_city_name text;
  v_state_name text;
  v_city_country text;
  v_lat numeric(9,6);
  v_lng numeric(9,6);
  v_postal_code text := nullif(left(trim(coalesce(p_postal_code, '')), 32), '');
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required.';
  END IF;
  IF p_city_id IS NULL OR length(v_country_code) <> 2 THEN
    RAISE EXCEPTION 'A verified city and country are required.';
  END IF;

  SELECT c.name, r.name, upper(r.country_code), c.latitude, c.longitude
  INTO v_city_name, v_state_name, v_city_country, v_lat, v_lng
  FROM public.cities c
  JOIN public.regions r ON r.id = c.region_id
  WHERE c.id = p_city_id;

  IF NOT FOUND OR v_lat IS NULL OR v_lng IS NULL THEN
    RAISE EXCEPTION 'The selected city is unavailable. Please select it again.';
  END IF;
  IF v_city_country IS DISTINCT FROM v_country_code THEN
    RAISE EXCEPTION 'The selected city does not belong to that country.';
  END IF;

  -- Lock both owned rows and fail closed instead of producing half a location.
  PERFORM 1 FROM public.users WHERE id = v_user_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'User row missing.';
  END IF;
  PERFORM 1 FROM public.profiles WHERE user_id = v_user_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Profile row missing.';
  END IF;

  UPDATE public.users
  SET country_code = v_country_code,
      onboarding_city_id = p_city_id,
      onboarding_city_name = v_city_name,
      onboarding_state_name = v_state_name,
      onboarding_postal_code = v_postal_code,
      onboarding_lat = v_lat,
      onboarding_lng = v_lng
  WHERE id = v_user_id;

  PERFORM set_config('silarah.allow_location_mutation', 'yes', true);
  UPDATE public.profiles
  SET city_id = p_city_id,
      country_code = v_country_code,
      location = ST_SetSRID(ST_MakePoint(v_lng, v_lat), 4326)::geography,
      location_source = 'city',
      location_updated_at = now(),
      updated_at = now()
  WHERE user_id = v_user_id;

  RETURN jsonb_build_object(
    'city_id', p_city_id,
    'city_name', v_city_name,
    'state_name', v_state_name,
    'country_code', v_country_code,
    'postal_code', coalesce(v_postal_code, ''),
    'lat', v_lat,
    'lng', v_lng
  );
END;
$$;

REVOKE ALL ON FUNCTION public.update_profile_location(int, text, text)
  FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.update_profile_location(int, text, text)
  TO authenticated;

COMMENT ON FUNCTION public.update_profile_location(int, text, text) IS
  'Atomically changes the authenticated profile city and resets discovery to the canonical city coordinates.';
