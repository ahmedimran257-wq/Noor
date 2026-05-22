-- ============================================================
-- MIGRATION 025: ANALYTICS TRACKING — CREEP DETECTION
--
-- Fixes Audit Finding 10 (Analytics):
--   Missing time-to-first-message and female block/report ratio
--   per male. Need to flag "creeps" before they hit the
--   auto-suspend limit.
--
-- Changes:
--   1. Create user_analytics table
--   2. track_first_message() trigger
--   3. track_unmatch_block() triggers
--   4. compute_creep_scores() nightly function
--   5. Cron job
-- ============================================================

-- ── 1. User Analytics table ───────────────────────────────────
CREATE TABLE user_analytics (
  user_id                    uuid PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  -- Funnel metrics
  first_interest_sent_at     timestamptz,
  first_interest_received_at timestamptz,
  first_match_at             timestamptz,
  first_message_sent_at      timestamptz,
  first_message_received_at  timestamptz,
  time_to_first_match_hrs    double precision,
  time_to_first_message_hrs  double precision,
  -- Safety metrics
  total_unmatches_received   int NOT NULL DEFAULT 0,
  total_blocks_received      int NOT NULL DEFAULT 0,
  total_reports_received     int NOT NULL DEFAULT 0,
  -- Rolling 7-day ratios
  matches_7d                 int NOT NULL DEFAULT 0,
  unmatches_7d               int NOT NULL DEFAULT 0,
  blocks_7d                  int NOT NULL DEFAULT 0,
  messages_sent_7d           int NOT NULL DEFAULT 0,
  unmatch_ratio_7d           double precision NOT NULL DEFAULT 0.0,
  block_ratio_7d             double precision NOT NULL DEFAULT 0.0,
  -- Creep score (computed nightly)
  creep_score                double precision NOT NULL DEFAULT 0.0,
  is_shadowbanned            boolean NOT NULL DEFAULT false,
  -- Timestamps
  last_computed_at           timestamptz NOT NULL DEFAULT now(),
  created_at                 timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_user_analytics_creep ON user_analytics(creep_score DESC)
  WHERE creep_score > 0;
CREATE INDEX idx_user_analytics_shadowban ON user_analytics(is_shadowbanned)
  WHERE is_shadowbanned = true;

COMMENT ON TABLE user_analytics IS
  'Per-user analytics for funnel optimization and safety. Tracks '
  'time-to-first-message (algorithm effectiveness) and unmatch/block '
  'ratios (creep detection). Shadowbanning sets static_rank_score = 0 '
  'so the user''s profile drops to the bottom of all feeds.';

-- ── 2. Auto-initialize analytics row ─────────────────────────
CREATE OR REPLACE FUNCTION initialize_user_analytics()
RETURNS trigger AS $$
BEGIN
  INSERT INTO user_analytics (user_id)
  VALUES (NEW.user_id)
  ON CONFLICT (user_id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE TRIGGER trg_initialize_user_analytics
  AFTER INSERT ON profiles
  FOR EACH ROW
  EXECUTE FUNCTION initialize_user_analytics();

-- ── 3. Track first message ────────────────────────────────────
CREATE OR REPLACE FUNCTION track_first_message()
RETURNS trigger AS $$
DECLARE
  v_user_created_at timestamptz;
BEGIN
  -- Track sender's first message
  UPDATE user_analytics SET
    first_message_sent_at = COALESCE(first_message_sent_at, NOW()),
    time_to_first_message_hrs = CASE
      WHEN first_message_sent_at IS NULL THEN
        EXTRACT(EPOCH FROM (NOW() - (
          SELECT u.created_at FROM users u WHERE u.id = NEW.sender_id
        ))) / 3600.0
      ELSE time_to_first_message_hrs
    END
  WHERE user_id = NEW.sender_id;

  -- Track receiver's first message received
  UPDATE user_analytics SET
    first_message_received_at = COALESCE(first_message_received_at, NOW())
  WHERE user_id = NEW.receiver_id;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE TRIGGER trg_track_first_message
  AFTER INSERT ON messages
  FOR EACH ROW
  EXECUTE FUNCTION track_first_message();

-- ── 4. Track first interest ───────────────────────────────────
CREATE OR REPLACE FUNCTION track_first_interest()
RETURNS trigger AS $$
BEGIN
  -- Track sender's first interest sent
  UPDATE user_analytics SET
    first_interest_sent_at = COALESCE(first_interest_sent_at, NOW())
  WHERE user_id = NEW.sender_id;

  -- Track receiver's first interest received
  UPDATE user_analytics SET
    first_interest_received_at = COALESCE(first_interest_received_at, NOW())
  WHERE user_id = NEW.receiver_id;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE TRIGGER trg_track_first_interest
  AFTER INSERT ON interests
  FOR EACH ROW
  EXECUTE FUNCTION track_first_interest();

-- ── 5. Track first match ──────────────────────────────────────
CREATE OR REPLACE FUNCTION track_first_match()
RETURNS trigger AS $$
BEGIN
  -- Track for both users
  UPDATE user_analytics SET
    first_match_at = COALESCE(first_match_at, NOW()),
    time_to_first_match_hrs = CASE
      WHEN first_match_at IS NULL THEN
        EXTRACT(EPOCH FROM (NOW() - (
          SELECT u.created_at FROM users u WHERE u.id = NEW.user_a
        ))) / 3600.0
      ELSE time_to_first_match_hrs
    END
  WHERE user_id = NEW.user_a;

  UPDATE user_analytics SET
    first_match_at = COALESCE(first_match_at, NOW()),
    time_to_first_match_hrs = CASE
      WHEN first_match_at IS NULL THEN
        EXTRACT(EPOCH FROM (NOW() - (
          SELECT u.created_at FROM users u WHERE u.id = NEW.user_b
        ))) / 3600.0
      ELSE time_to_first_match_hrs
    END
  WHERE user_id = NEW.user_b;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE TRIGGER trg_track_first_match
  AFTER INSERT ON matches
  FOR EACH ROW
  EXECUTE FUNCTION track_first_match();

-- ── 6. Track unmatch (match closure) ──────────────────────────
CREATE OR REPLACE FUNCTION track_unmatch()
RETURNS trigger AS $$
DECLARE
  v_closed_by_gender text;
  v_other_user       uuid;
BEGIN
  -- Only track when match transitions to closed/blocked
  IF NEW.status NOT IN ('closed', 'blocked') THEN RETURN NEW; END IF;

  -- Determine who was "unmatched" (the other party)
  IF NEW.closed_by = NEW.user_a THEN
    v_other_user := NEW.user_b;
  ELSIF NEW.closed_by = NEW.user_b THEN
    v_other_user := NEW.user_a;
  ELSE
    RETURN NEW;  -- No closed_by recorded
  END IF;

  -- Increment the other user's unmatch count
  INSERT INTO user_analytics (user_id, total_unmatches_received)
  VALUES (v_other_user, 1)
  ON CONFLICT (user_id) DO UPDATE
    SET total_unmatches_received = user_analytics.total_unmatches_received + 1;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE TRIGGER trg_track_unmatch
  AFTER UPDATE OF status ON matches
  FOR EACH ROW
  WHEN (OLD.status = 'active' AND NEW.status IN ('closed', 'blocked'))
  EXECUTE FUNCTION track_unmatch();

-- ── 7. Track blocks received ──────────────────────────────────
CREATE OR REPLACE FUNCTION track_block_received()
RETURNS trigger AS $$
BEGIN
  INSERT INTO user_analytics (user_id, total_blocks_received)
  VALUES (NEW.blocked_id, 1)
  ON CONFLICT (user_id) DO UPDATE
    SET total_blocks_received = user_analytics.total_blocks_received + 1;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE TRIGGER trg_track_block_received
  AFTER INSERT ON blocks
  FOR EACH ROW
  EXECUTE FUNCTION track_block_received();

-- ── 8. Nightly creep score computation ────────────────────────
-- Computes rolling 7-day ratios and a composite creep score.
-- High creep score → shadowban (rank_score = 0)
-- Very high creep score → auto-suspend
-- ================================================================
CREATE OR REPLACE FUNCTION compute_creep_scores()
RETURNS void AS $$
BEGIN
  -- Compute 7-day rolling metrics
  UPDATE user_analytics ua SET
    matches_7d = COALESCE((
      SELECT COUNT(*) FROM matches m
      WHERE (m.user_a = ua.user_id OR m.user_b = ua.user_id)
        AND m.created_at > NOW() - INTERVAL '7 days'
    ), 0),
    unmatches_7d = COALESCE((
      SELECT COUNT(*) FROM matches m
      WHERE (m.user_a = ua.user_id OR m.user_b = ua.user_id)
        AND m.status IN ('closed', 'blocked')
        AND m.closed_by IS NOT NULL
        AND m.closed_by != ua.user_id  -- Other party closed it
        AND m.closed_at > NOW() - INTERVAL '7 days'
    ), 0),
    blocks_7d = COALESCE((
      SELECT COUNT(*) FROM blocks b
      WHERE b.blocked_id = ua.user_id
        AND b.created_at > NOW() - INTERVAL '7 days'
    ), 0),
    messages_sent_7d = COALESCE((
      SELECT COUNT(*) FROM messages msg
      WHERE msg.sender_id = ua.user_id
        AND msg.created_at > NOW() - INTERVAL '7 days'
    ), 0),
    last_computed_at = NOW();

  -- Compute ratios
  UPDATE user_analytics SET
    unmatch_ratio_7d = CASE
      WHEN matches_7d > 0 THEN unmatches_7d::double precision / matches_7d
      ELSE 0.0
    END,
    block_ratio_7d = CASE
      WHEN matches_7d > 0 THEN blocks_7d::double precision / matches_7d
      ELSE 0.0
    END;

  -- Compute composite creep score
  -- Weighted formula: blocks are 3x worse than unmatches
  UPDATE user_analytics SET
    creep_score = (unmatch_ratio_7d * 1.0) + (block_ratio_7d * 3.0);

  -- ── Shadowban threshold ──────────────────────────────────
  -- If male, unmatch_ratio > 0.8, AND total_unmatches > 5
  -- → shadowban (profile drops to bottom of feed)
  UPDATE user_analytics ua SET
    is_shadowbanned = true
  FROM users u
  WHERE u.id = ua.user_id
    AND u.gender = 'male'
    AND ua.unmatch_ratio_7d > 0.8
    AND ua.total_unmatches_received > 5
    AND ua.is_shadowbanned = false;

  -- Apply shadowban: set rank score to 0
  UPDATE profiles p SET
    static_rank_score = 0
  FROM user_analytics ua
  WHERE ua.user_id = p.user_id
    AND ua.is_shadowbanned = true;

  -- ── Auto-suspend threshold ───────────────────────────────
  -- If block_ratio > 0.5 AND blocks_7d >= 3 → auto-suspend
  UPDATE profiles p SET
    visibility = 'suspended',
    suspended_reason = 'auto_creep_detection'
  FROM user_analytics ua
  WHERE ua.user_id = p.user_id
    AND ua.block_ratio_7d > 0.5
    AND ua.blocks_7d >= 3
    AND p.visibility = 'visible';

  -- Notify admin of auto-suspended creeps
  INSERT INTO admin_notifications (type, message, related_user_id)
  SELECT
    'auto_creep_suspension',
    format('User auto-suspended by creep detection. Block ratio: %s%%, '
           'Blocks 7d: %s, Unmatch ratio: %s%%',
           ROUND(ua.block_ratio_7d * 100), ua.blocks_7d,
           ROUND(ua.unmatch_ratio_7d * 100)),
    ua.user_id
  FROM user_analytics ua
  JOIN profiles p ON p.user_id = ua.user_id
  WHERE p.suspended_reason = 'auto_creep_detection'
    AND ua.last_computed_at > NOW() - INTERVAL '1 hour';  -- Only newly suspended

  -- ── Lift shadowban for reformed users ────────────────────
  -- If previously shadowbanned but ratios have improved
  UPDATE user_analytics ua SET
    is_shadowbanned = false
  WHERE ua.is_shadowbanned = true
    AND ua.unmatch_ratio_7d <= 0.3
    AND ua.block_ratio_7d <= 0.1;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

COMMENT ON FUNCTION compute_creep_scores IS
  'Nightly computation of creep scores based on 7-day rolling ratios. '
  'Shadowbans users with >80% unmatch rate (rank drops to 0). '
  'Auto-suspends users with >50% block rate. Reformed users can '
  'have their shadowban lifted when ratios improve.';

-- ── 9. Cron job ───────────────────────────────────────────────
SELECT cron.schedule(
  'compute_creep_scores_nightly',
  '45 1 * * *',   -- 01:45 UTC, before other nightly computations
  $$SELECT compute_creep_scores();$$
);

-- ── 10. RLS ───────────────────────────────────────────────────
ALTER TABLE user_analytics ENABLE ROW LEVEL SECURITY;

-- Users cannot see their own creep scores (intentional)
-- Only admin/service role can access this table
-- No SELECT policy = no client access
