-- ============================================================
-- MIGRATION 024: REMOVE NAME SEARCH (STALKING VECTOR)
--
-- Fixes Audit Finding 6 (Feature Gap / Safety):
--   search_profiles_by_name_city() turns the app into Facebook
--   and creates a stalking vulnerability. Matrimony apps should
--   be double-blind discovery only.
--
-- This migration drops the function entirely.
-- ============================================================

-- Drop the function
DROP FUNCTION IF EXISTS search_profiles_by_name_city(uuid, text, uuid);

-- Log the removal
COMMENT ON SCHEMA public IS
  'search_profiles_by_name_city() removed in migration 024. '
  'Name-based search was a stalking vector incompatible with '
  'double-blind matrimony discovery. Replaced by filter-only discovery.';
