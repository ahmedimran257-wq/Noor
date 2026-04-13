-- ============================================================
-- MIGRATION 007: ROW LEVEL SECURITY (RLS)
-- All policies follow defense-in-depth: even if a bug exists
-- in application logic, the database enforces access control.
-- ============================================================

-- ============================================================
-- PROFILES
-- ============================================================
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- Anyone can read visible profiles; users always see their own
CREATE POLICY profiles_select ON profiles
  FOR SELECT USING (
    user_id = auth.uid()
    OR visibility = 'visible'
  );

-- Users insert only their own profile
CREATE POLICY profiles_insert ON profiles
  FOR INSERT WITH CHECK (user_id = auth.uid());

-- Users update only their own profile
CREATE POLICY profiles_update ON profiles
  FOR UPDATE
  USING    (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- Users delete only their own profile (soft-delete via users.deleted_at preferred)
CREATE POLICY profiles_delete ON profiles
  FOR DELETE USING (user_id = auth.uid());

-- ============================================================
-- PROFILE PREFERENCES
-- ============================================================
ALTER TABLE profile_preferences ENABLE ROW LEVEL SECURITY;

CREATE POLICY prefs_select ON profile_preferences
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM profiles p WHERE p.id = profile_id AND p.user_id = auth.uid())
  );

CREATE POLICY prefs_insert ON profile_preferences
  FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM profiles p WHERE p.id = profile_id AND p.user_id = auth.uid())
  );

CREATE POLICY prefs_update ON profile_preferences
  FOR UPDATE
  USING (
    EXISTS (SELECT 1 FROM profiles p WHERE p.id = profile_id AND p.user_id = auth.uid())
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM profiles p WHERE p.id = profile_id AND p.user_id = auth.uid())
  );

-- ============================================================
-- PHOTOS
-- ============================================================
ALTER TABLE photos ENABLE ROW LEVEL SECURITY;

-- Uses the can_view_photo() STABLE function (respects photo_privacy + match state)
CREATE POLICY photos_select ON photos
  FOR SELECT USING (
    admin_approved = true
    AND nsfw_cleared = true
    AND can_view_photo(auth.uid(), profile_id)
  );

-- Insert handled by Edge Function (pre-signed URL flow), but RLS must permit it
CREATE POLICY photos_insert ON photos
  FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM profiles p WHERE p.id = profile_id AND p.user_id = auth.uid())
  );

CREATE POLICY photos_update ON photos
  FOR UPDATE
  USING (
    EXISTS (SELECT 1 FROM profiles p WHERE p.id = profile_id AND p.user_id = auth.uid())
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM profiles p WHERE p.id = profile_id AND p.user_id = auth.uid())
  );

CREATE POLICY photos_delete ON photos
  FOR DELETE USING (
    EXISTS (SELECT 1 FROM profiles p WHERE p.id = profile_id AND p.user_id = auth.uid())
  );

-- ============================================================
-- INTERESTS
-- ============================================================
ALTER TABLE interests ENABLE ROW LEVEL SECURITY;

-- Participants (sender + receiver) can read their own interests
CREATE POLICY interests_select ON interests
  FOR SELECT USING (
    sender_id = auth.uid() OR receiver_id = auth.uid()
  );

-- Only the sender can insert an interest
CREATE POLICY interests_insert ON interests
  FOR INSERT WITH CHECK (sender_id = auth.uid());

-- Sender can withdraw; receiver can accept/decline
-- Both are participants, but the trigger enforces business logic
CREATE POLICY interests_update ON interests
  FOR UPDATE
  USING (sender_id = auth.uid() OR receiver_id = auth.uid())
  WITH CHECK (sender_id = auth.uid() OR receiver_id = auth.uid());

-- ============================================================
-- MATCHES
-- ============================================================
ALTER TABLE matches ENABLE ROW LEVEL SECURITY;

-- Participants + their guardians (Phase 2 guardian_user_id) can see matches
CREATE POLICY matches_select ON matches
  FOR SELECT USING (
    user_a = auth.uid()
    OR user_b = auth.uid()
    OR EXISTS (
      SELECT 1 FROM profiles p
      WHERE (p.user_id = matches.user_a OR p.user_id = matches.user_b)
        AND p.guardian_user_id = auth.uid()
    )
  );

-- Matches are created only by triggers (create_match_on_accept)
-- No direct INSERT from clients

-- ============================================================
-- MESSAGES
-- ============================================================
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;

-- Sender and receiver can read their own messages
CREATE POLICY messages_select ON messages
  FOR SELECT USING (
    sender_id = auth.uid() OR receiver_id = auth.uid()
  );

-- Only sender can write; business logic enforced by triggers
CREATE POLICY messages_insert ON messages
  FOR INSERT WITH CHECK (sender_id = auth.uid());

-- Soft-delete: only participants can mark deleted_by_* flags
CREATE POLICY messages_update ON messages
  FOR UPDATE
  USING (sender_id = auth.uid() OR receiver_id = auth.uid())
  WITH CHECK (sender_id = auth.uid() OR receiver_id = auth.uid());

-- ============================================================
-- BLOCKS
-- ============================================================
ALTER TABLE blocks ENABLE ROW LEVEL SECURITY;

CREATE POLICY blocks_select ON blocks
  FOR SELECT USING (blocker_id = auth.uid() OR blocked_id = auth.uid());

CREATE POLICY blocks_insert ON blocks
  FOR INSERT WITH CHECK (blocker_id = auth.uid());

CREATE POLICY blocks_delete ON blocks
  FOR DELETE USING (blocker_id = auth.uid());

-- ============================================================
-- REPORTS
-- ============================================================
ALTER TABLE reports ENABLE ROW LEVEL SECURITY;

CREATE POLICY reports_select ON reports
  FOR SELECT USING (reporter_id = auth.uid());

CREATE POLICY reports_insert ON reports
  FOR INSERT WITH CHECK (reporter_id = auth.uid());

-- ============================================================
-- CONTENT VIOLATIONS (read-only for users)
-- ============================================================
ALTER TABLE content_violations ENABLE ROW LEVEL SECURITY;

CREATE POLICY violations_select ON content_violations
  FOR SELECT USING (user_id = auth.uid());

-- Inserts only from SECURITY DEFINER functions (Edge Functions via service role)

-- ============================================================
-- USER CONSENTS
-- ============================================================
ALTER TABLE user_consents ENABLE ROW LEVEL SECURITY;

CREATE POLICY consents_select ON user_consents
  FOR SELECT USING (user_id = auth.uid());

CREATE POLICY consents_insert ON user_consents
  FOR INSERT WITH CHECK (user_id = auth.uid());

-- ============================================================
-- NOTIFICATION PREFS
-- ============================================================
ALTER TABLE notification_prefs ENABLE ROW LEVEL SECURITY;

CREATE POLICY notif_prefs_select ON notification_prefs
  FOR SELECT USING (user_id = auth.uid());

CREATE POLICY notif_prefs_insert ON notification_prefs
  FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY notif_prefs_update ON notification_prefs
  FOR UPDATE
  USING    (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- ============================================================
-- NOTIFICATIONS (read + mark-read only)
-- ============================================================
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY notifs_select ON notifications
  FOR SELECT USING (user_id = auth.uid());

CREATE POLICY notifs_update ON notifications
  FOR UPDATE
  USING    (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- ============================================================
-- INCOME BRACKETS (public read, no write from clients)
-- ============================================================
ALTER TABLE income_brackets ENABLE ROW LEVEL SECURITY;

CREATE POLICY income_brackets_select ON income_brackets
  FOR SELECT USING (true);              -- Public reference data

-- ============================================================
-- COUNTRIES (public read)
-- ============================================================
ALTER TABLE countries ENABLE ROW LEVEL SECURITY;

CREATE POLICY countries_select ON countries
  FOR SELECT USING (true);

-- ============================================================
-- CITIES (public read)
-- ============================================================
ALTER TABLE cities ENABLE ROW LEVEL SECURITY;

CREATE POLICY cities_select ON cities
  FOR SELECT USING (true);

-- ============================================================
-- STORAGE: profile-photos bucket
-- Direct client uploads DISABLED. All uploads go through
-- the get-signed-url Edge Function which:
--   1. Checks quota (max 4)
--   2. Inserts 'pending_upload' placeholder in photos table
--   3. Returns a short-lived pre-signed upload URL
-- ============================================================
-- NOTE: Bucket creation must be done via Supabase Dashboard or CLI:
--   supabase storage create profile-photos --public=false
--
-- Storage SELECT RLS is DISABLED on the bucket level.
-- All photo reads are served via short-lived signed URLs
-- generated by Edge Functions. This prevents RLS subquery
-- overhead from exhausting the connection pool at scale.
-- ============================================================
