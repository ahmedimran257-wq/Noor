-- ============================================================
-- MIGRATION 023: CHAT EXPIRATION (ANTI-GHOSTING)
--
-- Fixes Audit Finding 6 (Feature Gap):
--   Unanswered matches should unmatch after 7 days to force
--   action and reduce dead-weight in the matches table.
--
-- Changes:
--   1. Add last_message_at column to matches
--   2. Trigger to update last_message_at on new message
--   3. expire_stale_matches() function
--   4. Pre-expiration nudge notification
--   5. Cron job for daily expiration sweep
-- ============================================================

-- ── 1. Add last_message_at to matches ─────────────────────────
ALTER TABLE matches
  ADD COLUMN IF NOT EXISTS last_message_at timestamptz;

COMMENT ON COLUMN matches.last_message_at IS
  'Timestamp of the last message in this match conversation. '
  'NULL means no messages have been sent. Used by the anti-ghosting '
  'system to expire stale matches.';

-- Backfill existing matches with their last message timestamp
UPDATE matches m
SET last_message_at = (
  SELECT MAX(msg.created_at)
  FROM messages msg
  WHERE msg.match_id = m.id
)
WHERE m.status = 'active';

-- ── 2. Update last_message_at on new message ──────────────────
CREATE OR REPLACE FUNCTION update_match_last_message()
RETURNS trigger AS $$
BEGIN
  UPDATE matches
  SET last_message_at = NOW()
  WHERE id = NEW.match_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE TRIGGER trg_update_match_last_message
  AFTER INSERT ON messages
  FOR EACH ROW
  EXECUTE FUNCTION update_match_last_message();

-- ── 3. Expire stale matches ───────────────────────────────────
-- Two expiration rules:
--   a) No messages after 7 days → expired (no_response)
--   b) Last message > 14 days ago → expired (conversation_stale)
-- ================================================================
CREATE OR REPLACE FUNCTION expire_stale_matches()
RETURNS void AS $$
DECLARE
  v_expiring_count integer;
BEGIN
  -- ── Pre-expiration nudge: 24 hours before expiry ──────────
  -- Matches with no messages, created 6 days ago (expires tomorrow)
  INSERT INTO notifications (user_id, type, title, body, deep_link, scheduled_at)
  SELECT
    CASE WHEN m.user_a != msg_sender THEN m.user_a ELSE m.user_b END,
    'match_expiring',
    '⏳ Match expiring soon',
    format('Your match will expire tomorrow. Send a message to keep the conversation going!'),
    format('mithaq://chat/%s', m.id),
    NOW()
  FROM matches m
  LEFT JOIN LATERAL (
    SELECT msg.sender_id AS msg_sender
    FROM messages msg WHERE msg.match_id = m.id
    ORDER BY msg.created_at DESC LIMIT 1
  ) last_msg ON true
  WHERE m.status = 'active'
    AND m.last_message_at IS NULL
    AND m.created_at BETWEEN NOW() - INTERVAL '7 days' AND NOW() - INTERVAL '6 days'
    -- Don't re-notify (check if we already sent this notification)
    AND NOT EXISTS (
      SELECT 1 FROM notifications n
      WHERE n.type = 'match_expiring'
        AND n.deep_link = format('mithaq://chat/%s', m.id)
        AND n.created_at > NOW() - INTERVAL '2 days'
    );

  -- Nudge for stale conversations (12 days since last message)
  INSERT INTO notifications (user_id, type, title, body, deep_link, scheduled_at)
  SELECT
    CASE
      WHEN last_msg.last_sender = m.user_a THEN m.user_b  -- Nudge the non-responder
      ELSE m.user_a
    END,
    'match_expiring',
    '⏳ Conversation expiring',
    'Your conversation will expire in 2 days if there''s no response.',
    format('mithaq://chat/%s', m.id),
    NOW()
  FROM matches m
  JOIN LATERAL (
    SELECT msg.sender_id AS last_sender
    FROM messages msg WHERE msg.match_id = m.id
    ORDER BY msg.created_at DESC LIMIT 1
  ) last_msg ON true
  WHERE m.status = 'active'
    AND m.last_message_at IS NOT NULL
    AND m.last_message_at BETWEEN NOW() - INTERVAL '13 days' AND NOW() - INTERVAL '12 days'
    AND NOT EXISTS (
      SELECT 1 FROM notifications n
      WHERE n.type = 'match_expiring'
        AND n.deep_link = format('mithaq://chat/%s', m.id)
        AND n.created_at > NOW() - INTERVAL '2 days'
    );

  -- ── Expire: no messages after 7 days ─────────────────────
  UPDATE matches
  SET status = 'expired',
      closed_at = NOW(),
      closure_reason = 'no_response'
  WHERE status = 'active'
    AND last_message_at IS NULL
    AND created_at < NOW() - INTERVAL '7 days';

  GET DIAGNOSTICS v_expiring_count = ROW_COUNT;
  IF v_expiring_count > 0 THEN
    RAISE NOTICE 'Expired % matches with no messages after 7 days', v_expiring_count;
  END IF;

  -- ── Expire: conversation stale after 14 days ────────────
  UPDATE matches
  SET status = 'expired',
      closed_at = NOW(),
      closure_reason = 'conversation_stale'
  WHERE status = 'active'
    AND last_message_at IS NOT NULL
    AND last_message_at < NOW() - INTERVAL '14 days';

  GET DIAGNOSTICS v_expiring_count = ROW_COUNT;
  IF v_expiring_count > 0 THEN
    RAISE NOTICE 'Expired % matches with stale conversations (14d)', v_expiring_count;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

COMMENT ON FUNCTION expire_stale_matches IS
  'Anti-ghosting system. Expires matches that have no messages after 7 days '
  'or where the last message is older than 14 days. Sends pre-expiration '
  'nudge notifications 24 hours before expiry. Forces high-intent conversations.';

-- ── 4. Index for stale match lookups ──────────────────────────
CREATE INDEX IF NOT EXISTS idx_matches_last_message
  ON matches(last_message_at)
  WHERE status = 'active';

CREATE INDEX IF NOT EXISTS idx_matches_created_active
  ON matches(created_at)
  WHERE status = 'active' AND last_message_at IS NULL;

-- ── 5. Cron job ───────────────────────────────────────────────
SELECT cron.schedule(
  'expire_stale_matches_daily',
  '0 4 * * *',   -- 04:00 UTC daily
  $$SELECT expire_stale_matches();$$
);
