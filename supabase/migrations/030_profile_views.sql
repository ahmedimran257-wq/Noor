-- ============================================================
-- MIGRATION 030: PROFILE VIEWS TABLE
--
-- Fixes Audit Finding MEDIUM-5:
--   Create table profile_views to track who viewed whose profile.
--   Includes RLS policies to allow insertion of views and selection
--   of views for the viewed user.
-- ============================================================

CREATE TABLE IF NOT EXISTS profile_views (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  viewer_profile_id  uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  viewed_profile_id  uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  viewed_at          timestamptz NOT NULL DEFAULT now()
);

-- Indices for quick lookup
CREATE INDEX IF NOT EXISTS idx_profile_views_viewed_profile ON profile_views(viewed_profile_id, viewed_at DESC);
CREATE INDEX IF NOT EXISTS idx_profile_views_viewer_profile ON profile_views(viewer_profile_id, viewed_at DESC);

-- Enable RLS
ALTER TABLE profile_views ENABLE ROW LEVEL SECURITY;

-- Policy: Anyone authenticated can insert a profile view (representing them viewing another profile)
CREATE POLICY profile_views_insert ON profile_views
  FOR INSERT WITH CHECK (
    -- The viewer_profile_id must belong to the authenticated user
    viewer_profile_id = (SELECT id FROM profiles WHERE user_id = auth.uid() LIMIT 1)
  );

-- Policy: A user can see who viewed their profile
CREATE POLICY profile_views_select ON profile_views
  FOR SELECT USING (
    viewed_profile_id = (SELECT id FROM profiles WHERE user_id = auth.uid() LIMIT 1)
  );
