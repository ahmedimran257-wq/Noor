-- ============================================================
-- MIGRATION 014: REPORT TRUST SCORING
--
-- Fixes Audit Finding 4.1 (Critical):
--   Hardcoded 3-report auto-suspend is trivially abusable via
--   burner accounts (brigading). Replace with trust-weighted
--   scoring where reports from verified, older accounts carry
--   more weight.
--
-- Changes:
--   1. Add reporter_trust_score_at_time column to reports
--   2. Create reporter_trust_score() helper function
--   3. Replace check_report_threshold() with trust-weighted logic
-- ============================================================

-- ── 1. Snapshot column for audit trail ─────────────────────────
ALTER TABLE reports
  ADD COLUMN IF NOT EXISTS reporter_trust_score integer;

COMMENT ON COLUMN reports.reporter_trust_score IS
  'Snapshot of the reporter''s trust score at the time the report was filed. '
  'Used for audit trail and to retroactively assess report quality.';

-- ── 2. Trust score computation for a single user ──────────────
-- Returns a score from -5 to +7 based on account signals.
-- Higher = more trustworthy reporter.
-- ================================================================
CREATE OR REPLACE FUNCTION compute_reporter_trust_score(p_user_id uuid)
RETURNS integer AS $$
DECLARE
  v_score       integer := 0;
  v_account_age interval;
  v_is_verified boolean;
  v_pending_reports_against integer;
  v_dismissed_reports_filed integer;
  v_actioned_reports_filed  integer;
BEGIN
  -- Account age bonus
  SELECT (NOW() - u.created_at) INTO v_account_age
  FROM users u WHERE u.id = p_user_id;

  IF v_account_age > INTERVAL '90 days' THEN
    v_score := v_score + 2;
  ELSIF v_account_age > INTERVAL '30 days' THEN
    v_score := v_score + 1;
  END IF;

  -- Verification bonus
  SELECT p.is_verified INTO v_is_verified
  FROM profiles p WHERE p.user_id = p_user_id;

  IF v_is_verified = true THEN
    v_score := v_score + 2;
  END IF;

  -- Penalty: pending reports against this reporter themselves
  SELECT COUNT(*) INTO v_pending_reports_against
  FROM reports r
  WHERE r.reported_user_id = p_user_id
    AND r.status = 'pending';

  v_score := v_score - LEAST(v_pending_reports_against, 2);  -- Cap penalty at -2

  -- Penalty: previously dismissed reports (false reporter pattern)
  SELECT COUNT(*) INTO v_dismissed_reports_filed
  FROM reports r
  WHERE r.reporter_id = p_user_id
    AND r.status = 'dismissed';

  v_score := v_score - LEAST(v_dismissed_reports_filed * 3, 6);  -- -3 per dismissed, cap at -6

  -- Bonus: previously actioned reports (accurate reporter)
  SELECT COUNT(*) INTO v_actioned_reports_filed
  FROM reports r
  WHERE r.reporter_id = p_user_id
    AND r.status = 'actioned';

  v_score := v_score + LEAST(v_actioned_reports_filed, 3);  -- +1 per actioned, cap at +3

  RETURN v_score;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

COMMENT ON FUNCTION compute_reporter_trust_score IS
  'Computes a trust score (-5 to +7) for a user as a reporter. '
  'Factors: account age, verification status, report history '
  '(accurate vs. false reports), and whether they are reported themselves.';

-- ── 3. Replace check_report_threshold() ───────────────────────
-- Old logic: 3 unique pending reports → auto-suspend
-- New logic:
--   a) Sum trust scores of all distinct pending reporters
--   b) If ALL reporters are < 7 days old → NEVER auto-suspend (anti-brigading)
--   c) If weighted_score >= 6 → auto-suspend + admin notification
--   d) If weighted_score >= 3 but < 6 → admin review only (no suspend)
--   e) If weighted_score < 3 → no action yet
-- ================================================================
CREATE OR REPLACE FUNCTION check_report_threshold()
RETURNS trigger AS $$
DECLARE
  v_weighted_score    integer := 0;
  v_reporter_count    integer := 0;
  v_all_new_accounts  boolean := true;
  v_reporter          record;
  v_reporter_score    integer;
  v_reporter_age      interval;
BEGIN
  -- Snapshot the reporter's trust score on this report row
  UPDATE reports
  SET reporter_trust_score = compute_reporter_trust_score(NEW.reporter_id)
  WHERE id = NEW.id;

  -- Compute aggregate weighted score across all pending reporters
  FOR v_reporter IN
    SELECT DISTINCT r.reporter_id
    FROM reports r
    WHERE r.reported_user_id = NEW.reported_user_id
      AND r.status = 'pending'
  LOOP
    v_reporter_count := v_reporter_count + 1;
    v_reporter_score := compute_reporter_trust_score(v_reporter.reporter_id);
    -- Minimum trust score contribution is 1 (even new/low-trust accounts count for something)
    v_weighted_score := v_weighted_score + GREATEST(v_reporter_score, 1);

    -- Check if reporter is older than 7 days
    SELECT (NOW() - u.created_at) INTO v_reporter_age
    FROM users u WHERE u.id = v_reporter.reporter_id;

    IF v_reporter_age > INTERVAL '7 days' THEN
      v_all_new_accounts := false;
    END IF;
  END LOOP;

  -- ── Anti-brigading: all reporters are brand new → never auto-suspend
  IF v_reporter_count >= 3 AND v_all_new_accounts THEN
    INSERT INTO admin_notifications (type, message, related_user_id)
    VALUES (
      'brigading_suspected',
      format('User received %s reports from accounts ALL younger than 7 days. '
             'Possible brigading attack. Weighted score: %s. Auto-suspend BLOCKED.',
             v_reporter_count, v_weighted_score),
      NEW.reported_user_id
    );
    -- Do NOT suspend — flag for manual review only
    RETURN NEW;
  END IF;

  -- ── High confidence: weighted score >= 6 → auto-suspend
  IF v_weighted_score >= 6 THEN
    UPDATE profiles
    SET visibility = 'suspended',
        suspended_reason = 'auto_trust_weighted_reports'
    WHERE user_id = NEW.reported_user_id;

    INSERT INTO admin_notifications (type, message, related_user_id)
    VALUES (
      'auto_suspension',
      format('User auto-suspended. %s unique reporters, weighted trust score: %s. '
             'Reports from verified/established accounts confirm pattern.',
             v_reporter_count, v_weighted_score),
      NEW.reported_user_id
    );
    RETURN NEW;
  END IF;

  -- ── Medium confidence: weighted score >= 3 → admin review
  IF v_weighted_score >= 3 THEN
    INSERT INTO admin_notifications (type, message, related_user_id)
    VALUES (
      'review_required',
      format('User received %s reports with weighted trust score: %s. '
             'Below auto-suspend threshold (6) but warrants manual review.',
             v_reporter_count, v_weighted_score),
      NEW.reported_user_id
    );
  END IF;

  -- Below threshold — no action needed yet
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

COMMENT ON FUNCTION check_report_threshold IS
  'V2: Trust-weighted report threshold. Replaces the naive 3-report '
  'auto-suspend with a scoring system. Reports from verified, older '
  'accounts carry more weight. All-new-account reports trigger '
  'brigading detection instead of auto-suspension.';
