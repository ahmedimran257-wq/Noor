-- ============================================================
-- MIGRATION 018: WALI (GUARDIAN) MODE — FULL INFRASTRUCTURE
--
-- Fixes Audit Finding 3.1 (Critical):
--   No structural support for Wali (guardian) to oversee chats
--   or approve profiles. Alienates the high-intent, practicing
--   segment of the market.
--
-- The profiles table already has guardian columns from migration 003:
--   guardian_phone_encrypted, guardian_name, guardian_relationship,
--   guardian_mode (none/passive/active), guardian_user_id
--
-- This migration adds:
--   1. guardian_chat_mirrors table (links guardians to match chats)
--   2. mirror_messages_to_guardian() trigger
--   3. activate_guardian() RPC
--   4. guardian_approve_match() RPC (for 'active' mode)
--   5. RLS policies for guardian access
-- ============================================================

-- ── 1. Guardian Chat Mirrors ──────────────────────────────────
-- When a guardian is in 'passive' or 'active' mode, they get
-- mirrored access to the ward's match conversations.
-- ================================================================
CREATE TABLE guardian_chat_mirrors (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  match_id     uuid NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
  guardian_id  uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  ward_id      uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  mode         text NOT NULL DEFAULT 'passive'
                 CHECK (mode IN ('passive','active')),
  created_at   timestamptz NOT NULL DEFAULT now(),
  UNIQUE (match_id, guardian_id)
);

CREATE INDEX idx_guardian_mirrors_guardian ON guardian_chat_mirrors(guardian_id);
CREATE INDEX idx_guardian_mirrors_ward     ON guardian_chat_mirrors(ward_id);
CREATE INDEX idx_guardian_mirrors_match    ON guardian_chat_mirrors(match_id);

COMMENT ON TABLE guardian_chat_mirrors IS
  'Links guardians to their ward''s match conversations. '
  'passive: guardian receives read-only copies of messages. '
  'active: guardian can also send messages on behalf of ward.';

-- ── 2. Mirror messages to guardian ────────────────────────────
-- AFTER INSERT on messages: if sender or receiver has a guardian
-- in passive/active mode, queue a notification to the guardian
-- with the message content.
-- ================================================================
CREATE OR REPLACE FUNCTION mirror_messages_to_guardian()
RETURNS trigger AS $$
DECLARE
  v_ward_id         uuid;
  v_guardian_user_id uuid;
  v_guardian_mode   text;
  v_other_name      text;
BEGIN
  -- Check if either party in this message has an active guardian
  FOR v_ward_id, v_guardian_user_id, v_guardian_mode IN
    SELECT p.user_id, p.guardian_user_id, p.guardian_mode
    FROM profiles p
    WHERE p.user_id IN (NEW.sender_id, NEW.receiver_id)
      AND p.guardian_mode IN ('passive', 'active')
      AND p.guardian_user_id IS NOT NULL
  LOOP
    -- Ensure the guardian mirror exists for this match
    INSERT INTO guardian_chat_mirrors (match_id, guardian_id, ward_id, mode)
    VALUES (NEW.match_id, v_guardian_user_id, v_ward_id, v_guardian_mode)
    ON CONFLICT (match_id, guardian_id) DO NOTHING;

    -- Get the name of the other person (not the ward)
    SELECT p.first_name INTO v_other_name
    FROM profiles p
    WHERE p.user_id = CASE
      WHEN NEW.sender_id = v_ward_id THEN NEW.receiver_id
      ELSE NEW.sender_id
    END;

    -- Queue notification to guardian
    PERFORM queue_notification(
      v_guardian_user_id,
      'guardian_message_mirror',
      CASE
        WHEN NEW.sender_id = v_ward_id
        THEN 'Your ward sent a message'
        ELSE format('New message from %s', COALESCE(v_other_name, 'someone'))
      END,
      LEFT(NEW.content, 100),  -- First 100 chars of message
      format('mithaq://chat/%s', NEW.match_id)
    );
  END LOOP;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE TRIGGER trg_mirror_messages_to_guardian
  AFTER INSERT ON messages
  FOR EACH ROW
  EXECUTE FUNCTION mirror_messages_to_guardian();

-- ── 3. Activate Guardian RPC ──────────────────────────────────
-- Called when a guardian creates their own account and links
-- to a ward. Validates matching phone, sets guardian_user_id,
-- and creates mirrors for existing matches.
-- ================================================================
CREATE OR REPLACE FUNCTION activate_guardian(
  p_ward_profile_id uuid,
  p_guardian_phone   text
)
RETURNS jsonb AS $$
DECLARE
  v_guardian_id      uuid;
  v_stored_phone     text;
  v_vault_key        text;
  v_ward_user_id     uuid;
  v_guardian_mode     text;
  v_match            record;
BEGIN
  v_guardian_id := auth.uid();

  IF v_guardian_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required.';
  END IF;

  -- Decrypt the stored guardian phone to verify
  SELECT decrypted_secret INTO v_vault_key
  FROM vault.decrypted_secrets
  WHERE name = 'guardian_key_v1';

  IF v_vault_key IS NULL THEN
    RAISE EXCEPTION 'System configuration error. Contact support.';
  END IF;

  SELECT
    pgp_sym_decrypt(p.guardian_phone_encrypted, v_vault_key),
    p.user_id,
    p.guardian_mode
  INTO v_stored_phone, v_ward_user_id, v_guardian_mode
  FROM profiles p
  WHERE p.id = p_ward_profile_id
    AND p.guardian_mode IN ('passive', 'active');

  IF v_stored_phone IS NULL THEN
    RAISE EXCEPTION 'No guardian phone registered for this profile.';
  END IF;

  -- Verify the caller's phone matches the stored guardian phone
  IF v_stored_phone != p_guardian_phone THEN
    RAISE EXCEPTION 'Phone number does not match the registered guardian phone.';
  END IF;

  -- Prevent self-guardianship
  IF v_guardian_id = v_ward_user_id THEN
    RAISE EXCEPTION 'You cannot be your own guardian.';
  END IF;

  -- Link the guardian
  UPDATE profiles
  SET guardian_user_id = v_guardian_id
  WHERE id = p_ward_profile_id;

  -- Create mirrors for all existing active matches
  FOR v_match IN
    SELECT m.id AS match_id
    FROM matches m
    WHERE (m.user_a = v_ward_user_id OR m.user_b = v_ward_user_id)
      AND m.status = 'active'
  LOOP
    INSERT INTO guardian_chat_mirrors (match_id, guardian_id, ward_id, mode)
    VALUES (v_match.match_id, v_guardian_id, v_ward_user_id, v_guardian_mode)
    ON CONFLICT (match_id, guardian_id) DO NOTHING;
  END LOOP;

  -- Log the activation
  INSERT INTO admin_audit_log (admin_id, action_type, target_user_id, details)
  VALUES (
    v_guardian_id,
    'guardian_activated',
    v_ward_user_id,
    jsonb_build_object(
      'ward_profile_id', p_ward_profile_id,
      'guardian_mode', v_guardian_mode
    )
  );

  RETURN jsonb_build_object(
    'status', 'activated',
    'ward_user_id', v_ward_user_id,
    'mode', v_guardian_mode
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

COMMENT ON FUNCTION activate_guardian IS
  'Links a guardian''s account to their ward''s profile. Verifies phone '
  'match against the encrypted guardian phone. Creates chat mirrors for '
  'all existing active matches. Guardian can then view/participate in chats.';

-- ── 4. Guardian approve match RPC (active mode only) ──────────
-- In 'active' mode, the guardian must approve a match before
-- messaging can begin. This adds a gate to the match flow.
-- ================================================================
ALTER TABLE matches
  ADD COLUMN IF NOT EXISTS guardian_approved boolean,
  ADD COLUMN IF NOT EXISTS guardian_approved_at timestamptz,
  ADD COLUMN IF NOT EXISTS guardian_approved_by uuid REFERENCES users(id);

CREATE OR REPLACE FUNCTION guardian_approve_match(p_match_id uuid)
RETURNS void AS $$
DECLARE
  v_guardian_id uuid;
BEGIN
  v_guardian_id := auth.uid();

  -- Verify this guardian is linked to this match
  IF NOT EXISTS (
    SELECT 1 FROM guardian_chat_mirrors gcm
    WHERE gcm.match_id = p_match_id
      AND gcm.guardian_id = v_guardian_id
      AND gcm.mode = 'active'
  ) THEN
    RAISE EXCEPTION 'You do not have active guardian access to this match.';
  END IF;

  UPDATE matches
  SET guardian_approved = true,
      guardian_approved_at = NOW(),
      guardian_approved_by = v_guardian_id
  WHERE id = p_match_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- ── 5. RLS policies for guardian access ───────────────────────
ALTER TABLE guardian_chat_mirrors ENABLE ROW LEVEL SECURITY;

-- Guardian can see their own mirror entries
CREATE POLICY guardian_mirrors_select ON guardian_chat_mirrors
  FOR SELECT USING (
    guardian_id = auth.uid()
    OR ward_id = auth.uid()
  );

-- Guardians can read messages in mirrored matches
-- (This extends the existing messages_select policy)
DROP POLICY IF EXISTS messages_select ON messages;
CREATE POLICY messages_select ON messages
  FOR SELECT USING (
    sender_id = auth.uid()
    OR receiver_id = auth.uid()
    -- Guardian access: can read messages in mirrored matches
    OR EXISTS (
      SELECT 1 FROM guardian_chat_mirrors gcm
      WHERE gcm.match_id = messages.match_id
        AND gcm.guardian_id = auth.uid()
    )
  );

-- Active guardians can send messages in mirrored matches
-- (The existing messages_insert policy only allows sender_id = auth.uid())
-- We add a separate policy for guardian message sending
CREATE POLICY messages_guardian_insert ON messages
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM guardian_chat_mirrors gcm
      WHERE gcm.match_id = messages.match_id
        AND gcm.guardian_id = auth.uid()
        AND gcm.mode = 'active'
    )
    AND sender_id = (
      -- Guardian sends as the ward
      SELECT gcm.ward_id FROM guardian_chat_mirrors gcm
      WHERE gcm.match_id = messages.match_id
        AND gcm.guardian_id = auth.uid()
        AND gcm.mode = 'active'
      LIMIT 1
    )
  );

COMMENT ON POLICY messages_guardian_insert ON messages IS
  'Active guardians can send messages in their ward''s matches. '
  'The sender_id is set to the ward''s user_id, not the guardian''s. '
  'This ensures the other party sees messages as coming from the ward.';

-- Notify ward when guardian sends a message on their behalf
CREATE OR REPLACE FUNCTION notify_ward_of_guardian_message()
RETURNS trigger AS $$
DECLARE
  v_guardian_id uuid;
  v_ward_id     uuid;
BEGIN
  -- Check if this message was sent by a guardian
  SELECT gcm.guardian_id, gcm.ward_id INTO v_guardian_id, v_ward_id
  FROM guardian_chat_mirrors gcm
  WHERE gcm.match_id = NEW.match_id
    AND gcm.ward_id = NEW.sender_id
    AND gcm.mode = 'active'
  LIMIT 1;

  -- If the actual session user is the guardian (not the ward), notify the ward
  IF v_guardian_id IS NOT NULL AND auth.uid() = v_guardian_id THEN
    PERFORM queue_notification(
      v_ward_id,
      'guardian_sent_message',
      'Your guardian sent a message',
      'Your guardian responded on your behalf in a conversation.',
      format('mithaq://chat/%s', NEW.match_id)
    );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE TRIGGER trg_notify_ward_of_guardian_message
  AFTER INSERT ON messages
  FOR EACH ROW
  EXECUTE FUNCTION notify_ward_of_guardian_message();

-- ── 6. Guardian Sessions ─────────────────────────────────────
-- Tracks guardian login sessions for unread message counting
-- and last-seen tracking on the guardian dashboard.
-- ================================================================
CREATE TABLE guardian_sessions (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  guardian_id   uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  ward_id       uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  is_active     boolean NOT NULL DEFAULT true,
  last_seen_at  timestamptz NOT NULL DEFAULT now(),
  created_at    timestamptz NOT NULL DEFAULT now(),
  UNIQUE (guardian_id, ward_id)
);

CREATE INDEX idx_guardian_sessions_guardian ON guardian_sessions(guardian_id)
  WHERE is_active = true;

ALTER TABLE guardian_sessions ENABLE ROW LEVEL SECURITY;

CREATE POLICY guardian_sessions_own ON guardian_sessions
  FOR ALL USING (guardian_id = auth.uid());

COMMENT ON TABLE guardian_sessions IS
  'Tracks guardian login sessions. last_seen_at is used to compute '
  'unread message counts on the guardian dashboard. One session per '
  'guardian-ward pair.';

-- ── 7. Guardian Dashboard RPC ─────────────────────────────────
-- Returns the full dashboard data for a guardian: all their wards'
-- active conversations with last message, unread count, and
-- match approval status.
-- ================================================================
CREATE OR REPLACE FUNCTION get_guardian_dashboard()
RETURNS TABLE(
  ward_name          text,
  ward_profile_id    uuid,
  ward_user_id       uuid,
  match_id           uuid,
  other_party_name   text,
  other_party_photo  text,
  last_message       text,
  last_message_at    timestamptz,
  unread_count       bigint,
  guardian_mode       text,
  match_status       text,
  guardian_approved   boolean,
  match_created_at   timestamptz
)
AS $$
DECLARE
  v_guardian_id uuid;
BEGIN
  v_guardian_id := auth.uid();

  IF v_guardian_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required.';
  END IF;

  RETURN QUERY
  SELECT
    ward_p.first_name              AS ward_name,
    ward_p.id                      AS ward_profile_id,
    gcm.ward_id                    AS ward_user_id,
    gcm.match_id,
    other_p.first_name             AS other_party_name,
    -- Only show photo if public
    CASE
      WHEN other_p.photo_privacy = 'public' THEN (
        SELECT ph.storage_path FROM photos ph
        WHERE ph.profile_id = other_p.id
          AND ph.order_index = 0
          AND ph.admin_approved = true
          AND ph.nsfw_cleared = true
        LIMIT 1
      )
      ELSE NULL
    END                            AS other_party_photo,
    -- Last message in this match
    (
      SELECT LEFT(msg.content, 120) FROM messages msg
      WHERE msg.match_id = gcm.match_id
      ORDER BY msg.created_at DESC
      LIMIT 1
    )                              AS last_message,
    m.last_message_at,
    -- Unread count (messages since guardian last saw this chat)
    (
      SELECT COUNT(*) FROM messages msg
      WHERE msg.match_id = gcm.match_id
        AND msg.created_at > COALESCE(
          (SELECT gs.last_seen_at FROM guardian_sessions gs
           WHERE gs.guardian_id = v_guardian_id
             AND gs.ward_id = gcm.ward_id),
          '1970-01-01'::timestamptz
        )
    )                              AS unread_count,
    gcm.mode                       AS guardian_mode,
    m.status                       AS match_status,
    m.guardian_approved,
    m.created_at                   AS match_created_at
  FROM guardian_chat_mirrors gcm
  JOIN matches m ON m.id = gcm.match_id
  JOIN profiles ward_p ON ward_p.user_id = gcm.ward_id
  JOIN profiles other_p ON other_p.user_id = CASE
    WHEN m.user_a = gcm.ward_id THEN m.user_b
    ELSE m.user_a
  END
  WHERE gcm.guardian_id = v_guardian_id
    AND m.status IN ('active', 'pending')
  ORDER BY m.last_message_at DESC NULLS LAST, m.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

COMMENT ON FUNCTION get_guardian_dashboard IS
  'Returns all active chat mirrors for the authenticated guardian. '
  'Includes ward name, other party details, last message preview, '
  'unread count (based on guardian_sessions.last_seen_at), and '
  'match approval status. Used by the Flutter GuardianDashboardScreen.';

-- ── 8. Update guardian last-seen timestamp ────────────────────
CREATE OR REPLACE FUNCTION update_guardian_last_seen(
  p_ward_id uuid
)
RETURNS void AS $$
BEGIN
  INSERT INTO guardian_sessions (guardian_id, ward_id, last_seen_at)
  VALUES (auth.uid(), p_ward_id, NOW())
  ON CONFLICT (guardian_id, ward_id)
    DO UPDATE SET last_seen_at = NOW();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- ── 9. Enable Supabase Realtime on messages ───────────────────
-- Guardians subscribe to message changes via Supabase Realtime.
-- RLS policies (messages_select) ensure they only receive messages
-- for matches they're mirrored on.
-- ================================================================
ALTER PUBLICATION supabase_realtime ADD TABLE messages;

