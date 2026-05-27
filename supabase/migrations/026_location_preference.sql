-- ============================================================
-- MIGRATION 026: LOCATION PREFERENCE SUPPORT
-- Adds full enum persistence for LocationPreference
-- ============================================================

ALTER TABLE profile_preferences
  ADD COLUMN IF NOT EXISTS location_preference text
    CHECK (location_preference IN ('sameCity', 'sameCountry', 'openToAbroad', 'diaspora'));

COMMENT ON COLUMN profile_preferences.location_preference IS
  'Raw LocationPreference enum name value: sameCity, sameCountry, openToAbroad, diaspora.';
