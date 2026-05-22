-- ============================================================
-- MIGRATION 016: MARRIAGE TIMELINE REQUIRED GATE
--
-- Fixes Audit Finding 1.2 (High):
--   No "seriousness" verification. Women encounter time-wasters.
--   Make marriage_timeline a required field before a profile
--   can go visible, and surface it in the discovery feed.
--
-- Changes:
--   1. Trigger to enforce marriage_timeline before visibility
--   2. Add marriage_timeline to discovery feed return columns
--      (already handled in migration 013's get_discovery_feed)
--   3. Backfill: set existing NULL values to 'not_sure'
-- ============================================================

-- ── 1. Backfill existing profiles ─────────────────────────────
-- Profiles created before this migration may have NULL
-- marriage_timeline. Set them to 'not_sure' to avoid breaking
-- existing visible profiles.
-- ================================================================
UPDATE profiles
SET marriage_timeline = 'not_sure'
WHERE marriage_timeline IS NULL
  AND visibility = 'visible'
  AND onboarding_step >= 14;

COMMENT ON COLUMN profiles.marriage_timeline IS
  'Required for profile visibility. Set during onboarding. '
  'Options: asap, 6_months, 1_year, 2_plus_years, not_sure. '
  'Surfaced on discovery feed cards. Existing profiles backfilled '
  'to ''not_sure'' by migration 016.';

-- ── 2. Enforcement trigger ─────────────────────────────────────
-- Prevents a profile from being set to 'visible' without a
-- marriage_timeline. Uses a BEFORE UPDATE trigger so the
-- transition is blocked, not rolled back.
-- ================================================================
CREATE OR REPLACE FUNCTION enforce_marriage_timeline()
RETURNS trigger AS $$
BEGIN
  -- Only enforce when transitioning TO visible
  IF NEW.visibility = 'visible' AND NEW.marriage_timeline IS NULL THEN
    RAISE EXCEPTION
      'Marriage timeline is required before your profile can go live. '
      'Please set your marriage readiness timeline in your profile settings.';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Fire on both INSERT and UPDATE of visibility
CREATE TRIGGER trg_enforce_marriage_timeline
  BEFORE INSERT OR UPDATE OF visibility ON profiles
  FOR EACH ROW
  WHEN (NEW.visibility = 'visible')
  EXECUTE FUNCTION enforce_marriage_timeline();

COMMENT ON FUNCTION enforce_marriage_timeline IS
  'Prevents profile visibility without a marriage_timeline. '
  'Addresses audit finding 1.2: users without a declared timeline '
  'are more likely to be casual daters who churn female users.';

-- ── 3. Casual swiping detection ────────────────────────────────
-- Track a "seriousness penalty" for users who exhibit casual
-- swiping behavior: high volume of interests sent but very
-- low acceptance rate + no messages sent after match.
--
-- This is a lightweight check run by compute_global_rank_scores().
-- Users with casual_swiping_penalty > 0 get ranked lower.
-- ================================================================
ALTER TABLE user_glicko_ratings
  ADD COLUMN IF NOT EXISTS casual_penalty double precision NOT NULL DEFAULT 0.0;

COMMENT ON COLUMN user_glicko_ratings.casual_penalty IS
  'Penalty applied to users who exhibit casual swiping behavior: '
  'high interest volume with low follow-through (no messages after match). '
  'Computed nightly. Subtracted from static_rank_score.';

-- Function to detect and penalize casual swipers
CREATE OR REPLACE FUNCTION compute_casual_penalties()
RETURNS void AS $$
BEGIN
  UPDATE user_glicko_ratings g
  SET casual_penalty = CASE
    -- If sent > 10 interests in last 7 days AND response rate < 20%
    -- AND sent 0 messages in last 7 days → heavy penalty
    WHEN (
      SELECT COUNT(*) FROM interests i
      WHERE i.sender_id = g.user_id
        AND i.created_at > NOW() - INTERVAL '7 days'
    ) > 10
    AND (
      SELECT COUNT(*) FROM messages m
      WHERE m.sender_id = g.user_id
        AND m.created_at > NOW() - INTERVAL '7 days'
    ) = 0
    THEN 10.0

    -- If sent > 10 interests but only replied to < 30% of matches
    WHEN (
      SELECT COUNT(*) FROM interests i
      WHERE i.sender_id = g.user_id
        AND i.created_at > NOW() - INTERVAL '7 days'
    ) > 10
    AND (
      SELECT COUNT(*)::float /
             NULLIF((SELECT COUNT(*) FROM matches m
                     WHERE (m.user_a = g.user_id OR m.user_b = g.user_id)
                       AND m.created_at > NOW() - INTERVAL '7 days'), 0)
      FROM messages msg
      WHERE msg.sender_id = g.user_id
        AND msg.created_at > NOW() - INTERVAL '7 days'
    ) < 0.3
    THEN 5.0

    ELSE 0.0
  END
  WHERE g.interactions_count >= 5;  -- Only penalize after enough data
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Add casual penalty to the rank score computation
-- (Integrated into compute_global_rank_scores via a subtraction)
-- The penalty is applied after the base score is computed.

-- Update compute_global_rank_scores to subtract casual_penalty
CREATE OR REPLACE FUNCTION compute_global_rank_scores()
RETURNS void AS $$
BEGIN
  -- First compute casual penalties
  PERFORM compute_casual_penalties();

  UPDATE profiles p
  SET static_rank_score = GREATEST(0, (
    -- Completeness: max 10 pts
    LEAST(COALESCE(p.completeness_score, 0)::float / 10.0, 10.0)

    -- Glicko tier: 10-25 pts
    + COALESCE(
        (SELECT CASE g.tier
           WHEN 'platinum' THEN 25
           WHEN 'gold'     THEN 20
           WHEN 'silver'   THEN 15
           WHEN 'bronze'   THEN 10
           ELSE 12
         END
         FROM user_glicko_ratings g WHERE g.user_id = p.user_id),
        12
      )

    -- RD confidence bonus: 0-3 pts
    + COALESCE(
        (SELECT CASE
           WHEN g.rating_deviation < 100 THEN 3
           WHEN g.rating_deviation < 200 THEN 1
           ELSE 0
         END
         FROM user_glicko_ratings g WHERE g.user_id = p.user_id),
        0
      )

    -- Recency: max 20 pts
    + CASE
        WHEN p.last_active_at > NOW() - INTERVAL '1 day'   THEN 20
        WHEN p.last_active_at > NOW() - INTERVAL '7 days'  THEN 15
        WHEN p.last_active_at > NOW() - INTERVAL '30 days' THEN 8
        ELSE 2
      END

    -- New profile boost: +10 for first 7 days
    + CASE
        WHEN p.approved_at IS NOT NULL
          AND p.approved_at > NOW() - INTERVAL '7 days' THEN 10
        ELSE 0
      END

    -- Subscriber boost: +5
    + CASE
        WHEN p.is_boosted = true AND p.boost_expires_at > NOW() THEN 5
        ELSE 0
      END

    -- Verified boost: +8
    + CASE
        WHEN p.is_verified = true THEN 8
        ELSE 0
      END

    -- Casual swiping penalty (subtracted)
    - COALESCE(
        (SELECT g.casual_penalty FROM user_glicko_ratings g WHERE g.user_id = p.user_id),
        0.0
      )
  )::integer)
  WHERE p.visibility = 'visible';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

COMMENT ON FUNCTION compute_global_rank_scores IS
  'V3: Blends Glicko-2 + completeness + recency + verification. '
  'Includes RD confidence bonus (0-3 pts for stable ratings). '
  'Subtracts casual_penalty for users who swipe heavily '
  'but never follow through with messages (time-waster detection).';

-- ── 4. Cron job for casual penalties ──────────────────────────
-- Runs at 01:50 UTC, before rank scores and Elo tiers
SELECT cron.schedule(
  'compute_casual_penalties_nightly',
  '50 1 * * *',
  $$SELECT compute_casual_penalties();$$
);
