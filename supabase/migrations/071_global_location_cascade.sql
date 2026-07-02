-- 071_global_location_cascade.sql
-- Async global location cascade support.
--
-- The Flutter app searches only the selected country/region instead of ever
-- loading large city lists into memory. Regions are optional because some
-- countries have sparse cached data; verified city coordinates remain required.

CREATE INDEX IF NOT EXISTS idx_regions_country_name_lower
  ON public.regions (country_code, lower(name));

CREATE INDEX IF NOT EXISTS idx_cities_region_name_lower
  ON public.cities (region_id, lower(name));

CREATE INDEX IF NOT EXISTS idx_cities_coordinates_present
  ON public.cities (region_id, latitude, longitude)
  WHERE latitude IS NOT NULL AND longitude IS NOT NULL;

ALTER TABLE public.regions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cities ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS regions_select ON public.regions;
CREATE POLICY regions_select ON public.regions
  FOR SELECT USING (true);

DROP POLICY IF EXISTS cities_select ON public.cities;
CREATE POLICY cities_select ON public.cities
  FOR SELECT USING (true);

DROP FUNCTION IF EXISTS public.search_regions(text, text);
CREATE OR REPLACE FUNCTION public.search_regions(
  search_term text,
  country_filter text
)
RETURNS TABLE(
  id int,
  name text,
  country_code text,
  country text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    r.id,
    r.name::text,
    r.country_code::text,
    co.name::text AS country
  FROM public.regions r
  JOIN public.countries co ON co.iso_code = r.country_code
  WHERE r.country_code = upper(country_filter)
    AND r.name ILIKE '%' || trim(search_term) || '%'
  ORDER BY r.name
  LIMIT 30;
END;
$$;

DROP FUNCTION IF EXISTS public.search_cities(text, text);
DROP FUNCTION IF EXISTS public.search_cities(text, text, text);
CREATE OR REPLACE FUNCTION public.search_cities(
  search_term text,
  country_filter text DEFAULT NULL,
  region_filter text DEFAULT NULL
)
RETURNS TABLE(
  id int,
  name text,
  state text,
  country text,
  country_code text,
  lat numeric,
  lng numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    c.id,
    c.name::text,
    r.name::text AS state,
    co.name::text AS country,
    r.country_code::text,
    c.latitude AS lat,
    c.longitude AS lng
  FROM public.cities c
  JOIN public.regions r ON c.region_id = r.id
  JOIN public.countries co ON r.country_code = co.iso_code
  WHERE c.latitude IS NOT NULL
    AND c.longitude IS NOT NULL
    AND (country_filter IS NULL OR r.country_code = upper(country_filter))
    AND (
      region_filter IS NULL
      OR trim(region_filter) = ''
      OR lower(r.name) = lower(trim(region_filter))
    )
    AND c.name ILIKE '%' || trim(search_term) || '%'
  ORDER BY c.name
  LIMIT 30;
END;
$$;

GRANT EXECUTE ON FUNCTION public.search_regions(text, text)
  TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.search_cities(text, text, text)
  TO anon, authenticated;
