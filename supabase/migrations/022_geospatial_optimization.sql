-- ============================================================
-- MIGRATION 022: GEOSPATIAL OPTIMIZATION
--
-- Fixes Audit Finding 5.2 (Medium):
--   ST_Distance on the fly for every feed request. While the
--   current architecture already uses ST_DWithin for filtering
--   (which uses GiST index), this migration adds compound
--   indexes for the most common query patterns.
--
-- Note: The existing architecture is already sound for current
-- scale. ST_DWithin filters first (indexed), then ST_Distance
-- only runs on the paginated result set (~10 rows).
-- This migration is a proactive optimization for growth.
-- ============================================================

-- ── 1. Compound index for common discovery query pattern ──────
-- Most feed queries filter by gender + country + location.
-- A partial compound index speeds up the most common path.
-- ================================================================
CREATE INDEX IF NOT EXISTS idx_discovery_pool_gender_country_rank
  ON discovery_pool(gender, country_code, rank_score DESC);

-- ── 2. Partial index for boosted profiles ─────────────────────
-- Boosted profiles are checked in every feed query but are rare.
-- A partial index makes this lookup near-instant.
CREATE INDEX IF NOT EXISTS idx_profiles_boosted_active
  ON profiles(is_boosted, boost_expires_at)
  WHERE is_boosted = true AND boost_expires_at > NOW();

-- ── 3. Covering index for blocks lookup ───────────────────────
-- The blocks exclusion subquery runs for every feed row.
-- An index covering both directions speeds it up significantly.
CREATE INDEX IF NOT EXISTS idx_blocks_both_directions
  ON blocks(blocker_id, blocked_id);
-- idx_blocks_blocked already exists from migration 005

-- ── 4. Statistics target increase for geography columns ───────
-- PostGIS geography columns benefit from higher statistics
-- targets for better query planning with ST_DWithin.
ALTER TABLE profiles ALTER COLUMN location SET STATISTICS 1000;

COMMENT ON INDEX idx_discovery_pool_gender_country_rank IS
  'Compound index for the most common discovery feed query pattern: '
  'filter by opposite gender, then country, ordered by rank. '
  'Avoids sequential scan on the MV for basic queries.';
