-- ============================================================
-- MIGRATION 002: REFERENCE TABLES
-- countries, cities, income_brackets
-- ============================================================

-- ------------------------------------------------------------
-- COUNTRIES
-- Controls all cultural adaptation per market.
-- Seeded in seed/001_countries.sql
-- ------------------------------------------------------------
CREATE TABLE countries (
  code            text PRIMARY KEY,                     -- ISO 3166-1 alpha-2 (e.g. 'IN', 'PK')
  name            text NOT NULL,
  dialing_code    text NOT NULL,                        -- e.g. '+91'
  currency        text NOT NULL,                        -- ISO 4217 (e.g. 'INR')
  default_lang    text NOT NULL DEFAULT 'en',           -- BCP-47 language tag
  rtl             boolean NOT NULL DEFAULT false,
  show_sect       boolean NOT NULL DEFAULT true,        -- Cultural config: hide sect in Gulf
  show_sub_sect   boolean NOT NULL DEFAULT false,
  wali_requirement text NOT NULL DEFAULT 'optional'     -- optional | recommended | mandatory
                      CHECK (wali_requirement IN ('optional','recommended','mandatory')),
  pricing_tier    text NOT NULL
                      CHECK (pricing_tier IN ('tier_3','tier_2','tier_1','premium'))
);

COMMENT ON TABLE countries IS
  'One row per supported market. Controls cultural feature flags, language defaults, '
  'pricing tiers, and RTL layout. Read-only during runtime — mutated by admin only.';

-- ------------------------------------------------------------
-- CITIES
-- City list with geospatial coordinates and full-text search.
-- search_vector is populated at seed time only (static data).
-- ------------------------------------------------------------
CREATE TABLE cities (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name         text NOT NULL,
  name_local   text,                                    -- Native language name (e.g. 'ممبئی')
  country_code text NOT NULL REFERENCES countries(code) ON DELETE CASCADE,
  latitude     double precision NOT NULL,
  longitude    double precision NOT NULL,
  timezone     text NOT NULL,                           -- IANA timezone (e.g. 'Asia/Kolkata')
  search_vector tsvector                                -- Pre-built at seed time, NOT via trigger
);

CREATE INDEX idx_cities_country ON cities(country_code);
CREATE INDEX idx_cities_search  ON cities USING GIN (search_vector);

COMMENT ON COLUMN cities.search_vector IS
  'Pre-computed at seed time. Do NOT use a trigger on this column — cities are static '
  'data and rebuilding GIN vectors on every update causes heavy lock contention.';

-- Trigger kept here for reference but NOT attached in production.
-- Use: UPDATE cities SET search_vector = to_tsvector(''simple'', name || '' '' || coalesce(name_local, ''''));
CREATE OR REPLACE FUNCTION cities_searchvector_trigger()
RETURNS trigger AS $$
BEGIN
  NEW.search_vector :=
    to_tsvector('simple',
      coalesce(NEW.name, '') || ' ' || coalesce(NEW.name_local, '')
    );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
-- NOT attached: CREATE TRIGGER trg_cities_search BEFORE INSERT OR UPDATE ON cities
--   FOR EACH ROW EXECUTE FUNCTION cities_searchvector_trigger();

-- ------------------------------------------------------------
-- INCOME BRACKETS
-- Per-country income ranges displayed in the user's local
-- currency. income_bracket int on profiles is a FK to this.
-- ------------------------------------------------------------
CREATE TABLE income_brackets (
  id           serial PRIMARY KEY,
  country_code text NOT NULL REFERENCES countries(code) ON DELETE CASCADE,
  rank         int  NOT NULL,                           -- 1 = lowest; higher = richer
  label_en     text NOT NULL,                           -- English label shown in app
  label_local  text,                                    -- Native language label (optional)
  UNIQUE (country_code, rank)
);

CREATE INDEX idx_income_brackets_country ON income_brackets(country_code);

-- City search RPC — called by Flutter with 300ms debounce
CREATE OR REPLACE FUNCTION search_cities(
  search_term    text,
  country_filter text DEFAULT NULL
)
RETURNS TABLE(
  id           uuid,
  name         text,
  name_local   text,
  country_code text,
  lat          double precision,
  lng          double precision,
  timezone     text
)
AS $$
BEGIN
  RETURN QUERY
  SELECT
    c.id,
    c.name,
    c.name_local,
    c.country_code,
    c.latitude,
    c.longitude,
    c.timezone
  FROM cities c
  WHERE
    c.search_vector @@ to_tsquery('simple', trim(search_term) || ':*')
    AND (country_filter IS NULL OR c.country_code = country_filter)
  ORDER BY
    ts_rank(c.search_vector, to_tsquery('simple', trim(search_term) || ':*')) DESC
  LIMIT 20;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;
