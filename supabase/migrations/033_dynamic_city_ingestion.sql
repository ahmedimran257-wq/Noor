-- ============================================================
-- MIGRATION 033: DYNAMIC CITY INGESTION
--
-- Enables dynamic ingestion of global cities searched by name
-- and coordinates, automatically indexing them in cities table
-- for RLS and PostGIS geometry calculations.
-- ============================================================

-- Attach search vector index trigger to cities table for dynamic search indexing
DROP TRIGGER IF EXISTS trg_cities_search ON cities;
CREATE TRIGGER trg_cities_search
  BEFORE INSERT OR UPDATE ON cities
  FOR EACH ROW
  EXECUTE FUNCTION cities_searchvector_trigger();

-- SECURITY DEFINER function to get or dynamically create a city row
CREATE OR REPLACE FUNCTION get_or_create_city(
  p_name         text,
  p_country_code text,
  p_latitude     double precision,
  p_longitude    double precision,
  p_timezone     text DEFAULT 'UTC',
  p_name_local   text DEFAULT NULL
)
RETURNS uuid
AS $$
DECLARE
  v_city_id uuid;
BEGIN
  -- Search for existing city by name, country code, and coordinate proximity (within ~5km)
  SELECT id INTO v_city_id
  FROM cities
  WHERE country_code = p_country_code
    AND name = p_name
    AND ABS(latitude - p_latitude) < 0.05
    AND ABS(longitude - p_longitude) < 0.05
  LIMIT 1;

  -- Dynamic ingestion if it does not exist
  IF v_city_id IS NULL THEN
    INSERT INTO cities (name, name_local, country_code, latitude, longitude, timezone)
    VALUES (p_name, p_name_local, p_country_code, p_latitude, p_longitude, p_timezone)
    RETURNING id INTO v_city_id;
  END IF;

  RETURN v_city_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;
