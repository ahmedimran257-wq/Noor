-- Optional device-assisted radius discovery. Coordinates are rounded to three
-- decimal places (roughly 110 m) before storage to avoid retaining exact GPS.
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS location_source text NOT NULL DEFAULT 'city',
  ADD COLUMN IF NOT EXISTS location_updated_at timestamptz;

ALTER TABLE public.profiles
  DROP CONSTRAINT IF EXISTS profiles_location_source_check;
ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_location_source_check
  CHECK (location_source IN ('city', 'device_coarse'));

-- A later city change must replace any previous device point and restore the
-- city source marker. Direct location-only updates do not fire this trigger.
CREATE OR REPLACE FUNCTION public.sync_profile_location()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_lat numeric(9,6);
  v_lng numeric(9,6);
BEGIN
  IF TG_OP = 'INSERT'
      OR NEW.city_id IS DISTINCT FROM OLD.city_id
      OR (NEW.city_id IS NOT NULL AND NEW.location IS NULL) THEN
    SELECT latitude, longitude INTO v_lat, v_lng
    FROM public.cities
    WHERE id = NEW.city_id;

    IF v_lat IS NOT NULL AND v_lng IS NOT NULL THEN
      NEW.location := ST_SetSRID(ST_MakePoint(v_lng, v_lat), 4326)::geography;
    ELSE
      NEW.location := NULL;
    END IF;
    NEW.location_source := 'city';
    NEW.location_updated_at := now();
  END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.update_discovery_location(
  p_latitude double precision,
  p_longitude double precision
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_lat numeric;
  v_lng numeric;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required.';
  END IF;
  IF p_latitude NOT BETWEEN -90 AND 90
      OR p_longitude NOT BETWEEN -180 AND 180 THEN
    RAISE EXCEPTION 'Invalid coordinates.';
  END IF;

  v_lat := round(p_latitude::numeric, 3);
  v_lng := round(p_longitude::numeric, 3);
  UPDATE public.profiles
  SET location = ST_SetSRID(ST_MakePoint(v_lng, v_lat), 4326)::geography,
      location_source = 'device_coarse',
      location_updated_at = now()
  WHERE user_id = auth.uid();

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Profile not found.';
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.update_discovery_location(double precision, double precision)
  FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.update_discovery_location(double precision, double precision)
  TO authenticated;

COMMENT ON COLUMN public.profiles.location IS
  'Discovery origin. City coordinates by default; coarse device coordinates when the user enables a radius filter.';
