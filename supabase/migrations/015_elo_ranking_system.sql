-- ============================================================
-- MIGRATION 015: GLICKO-2 ASYNC BATCH RATING SYSTEM
--
-- Replaces the original Elo-based system (Audit Finding 5.1).
--
-- Why Glicko-2 over Elo:
--   Elo doesn't track Rating Deviation (RD) — the algorithm's
--   confidence in a score. A new user with 0 interactions has
--   the same certainty as a user with 500. Glicko-2 solves the
--   cold-start problem mathematically by tracking:
--     μ  (rating)           — the user's desirability score
--     φ  (rating deviation) — how confident we are in μ
--     σ  (volatility)       — how erratic the user's outcomes are
--
-- Architecture:
--   1. Lightweight trigger logs swipe outcomes to glicko_interactions
--   2. pg_cron batch job every 5 minutes processes unprocessed
--      interactions and recalculates Glicko-2 ratings in bulk
--   3. Zero UI latency — no synchronous computation on swipe
--
-- Changes:
--   1. Create user_glicko_ratings table (replaces user_elo_scores)
--   2. Create glicko_interactions table (swipe log)
--   3. Create log_glicko_interaction() lightweight trigger
--   4. Create initialize_glicko_rating() trigger for new profiles
--   5. Create compute_glicko2_batch() batch function
--   6. Create compute_glicko_tiers() nightly function
--   7. Update compute_global_rank_scores() for Glicko
--   8. Add 5-minute cron job
-- ============================================================

-- ── 1. Glicko-2 ratings table ────────────────────────────────
CREATE TABLE user_glicko_ratings (
  user_id            uuid PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  rating             double precision NOT NULL DEFAULT 1500.0,   -- μ (Glicko-2 default)
  rating_deviation   double precision NOT NULL DEFAULT 350.0,    -- φ (high = uncertain/new)
  volatility         double precision NOT NULL DEFAULT 0.06,     -- σ (system constant)
  tier               text NOT NULL DEFAULT 'unranked'
                       CHECK (tier IN ('unranked','bronze','silver','gold','platinum')),
  interactions_count int NOT NULL DEFAULT 0,
  last_computed_at   timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_glicko_ratings_tier ON user_glicko_ratings(tier);
CREATE INDEX idx_glicko_ratings_score ON user_glicko_ratings(rating DESC);

COMMENT ON TABLE user_glicko_ratings IS
  'Glicko-2 desirability ratings. rating=μ (1500 default), '
  'rating_deviation=φ (350=max uncertainty, decreases with data), '
  'volatility=σ (measures erratic outcomes). Computed asynchronously '
  'every 5 minutes from glicko_interactions. Tiers assigned nightly.';

-- ── 2. Interaction log table (swipe outcomes) ─────────────────
-- Lightweight insert-only table. The 5-minute batch job reads
-- unprocessed rows, computes ratings, then marks them processed.
-- ================================================================
CREATE TABLE glicko_interactions (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_id     uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  target_id    uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  outcome      text NOT NULL CHECK (outcome IN ('accepted','declined')),
  created_at   timestamptz NOT NULL DEFAULT now(),
  processed    boolean NOT NULL DEFAULT false
);

CREATE INDEX idx_glicko_unprocessed ON glicko_interactions(created_at)
  WHERE processed = false;
CREATE INDEX idx_glicko_actor ON glicko_interactions(actor_id, created_at DESC);
CREATE INDEX idx_glicko_target ON glicko_interactions(target_id, created_at DESC);

COMMENT ON TABLE glicko_interactions IS
  'Append-only log of interest outcomes for Glicko-2 batch processing. '
  'Each row represents one interest accept/decline event. Processed by '
  'compute_glicko2_batch() every 5 minutes. Old processed rows can be '
  'archived/purged after 90 days.';

-- ── 3. Auto-initialize Glicko rating when profile is created ──
CREATE OR REPLACE FUNCTION initialize_glicko_rating()
RETURNS trigger AS $$
BEGIN
  INSERT INTO user_glicko_ratings (user_id)
  VALUES (NEW.user_id)
  ON CONFLICT (user_id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE TRIGGER trg_initialize_glicko_rating
  AFTER INSERT ON profiles
  FOR EACH ROW
  EXECUTE FUNCTION initialize_glicko_rating();

-- ── 4. Lightweight trigger: log interaction on interest response ──
-- This does NO computation — just an O(1) INSERT into the log table.
-- The batch job handles all the math asynchronously.
-- ================================================================
CREATE OR REPLACE FUNCTION log_glicko_interaction()
RETURNS trigger AS $$
BEGIN
  -- Only log accepted/declined transitions
  IF NEW.status IN ('accepted', 'declined') THEN
    INSERT INTO glicko_interactions (actor_id, target_id, outcome)
    VALUES (NEW.sender_id, NEW.receiver_id, NEW.status);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE TRIGGER trg_log_glicko_interaction
  AFTER UPDATE OF status ON interests
  FOR EACH ROW
  WHEN (OLD.status IS DISTINCT FROM NEW.status
        AND NEW.status IN ('accepted', 'declined'))
  EXECUTE FUNCTION log_glicko_interaction();

COMMENT ON FUNCTION log_glicko_interaction IS
  'Lightweight trigger that logs interest outcomes for async Glicko-2 '
  'processing. No computation happens here — just an O(1) INSERT. '
  'This is the key architectural difference from the original Elo system '
  'which computed ratings synchronously on every swipe.';

-- ── 5. Glicko-2 batch computation ─────────────────────────────
-- Runs every 5 minutes via pg_cron. Processes all unprocessed
-- interactions, groups by user, and applies the full Glicko-2
-- algorithm.
--
-- Glicko-2 Algorithm Steps (per user per rating period):
--   Step 1: Convert μ, φ to Glicko-2 scale
--   Step 2: For each opponent, compute g(φj) and E(μ, μj, φj)
--   Step 3: Compute estimated variance v
--   Step 4: Compute estimated improvement Δ
--   Step 5: Update volatility σ' via iterative algorithm
--   Step 6: Pre-rating period φ* and new φ'
--   Step 7: New μ'
-- ================================================================
CREATE OR REPLACE FUNCTION compute_glicko2_batch()
RETURNS void AS $$
DECLARE
  v_user          record;
  v_opponent      record;
  v_mu            double precision;
  v_phi           double precision;
  v_sigma         double precision;
  v_g             double precision;
  v_e             double precision;
  v_v_sum         double precision;
  v_delta_sum     double precision;
  v_v             double precision;
  v_delta         double precision;
  v_a             double precision;
  v_tau           double precision := 0.5;  -- system constant (controls volatility change)
  v_epsilon       double precision := 0.000001;  -- convergence tolerance
  v_big_a         double precision;
  v_big_b         double precision;
  v_big_c         double precision;
  v_f_a           double precision;
  v_f_b           double precision;
  v_f_c           double precision;
  v_new_sigma     double precision;
  v_phi_star      double precision;
  v_new_phi       double precision;
  v_new_mu        double precision;
  v_new_rating    double precision;
  v_new_rd        double precision;
  v_interactions  int;
  v_batch_ids     uuid[];
  -- Glicko-2 scaling constants
  c_scale         double precision := 173.7178;  -- 400/ln(10)
BEGIN
  -- Collect all unprocessed interaction IDs for this batch
  SELECT array_agg(id) INTO v_batch_ids
  FROM glicko_interactions
  WHERE processed = false;

  -- Nothing to process
  IF v_batch_ids IS NULL OR array_length(v_batch_ids, 1) = 0 THEN
    RETURN;
  END IF;

  -- Ensure all users involved have a Glicko row
  INSERT INTO user_glicko_ratings (user_id)
  SELECT DISTINCT actor_id FROM glicko_interactions WHERE id = ANY(v_batch_ids)
  ON CONFLICT (user_id) DO NOTHING;

  INSERT INTO user_glicko_ratings (user_id)
  SELECT DISTINCT target_id FROM glicko_interactions WHERE id = ANY(v_batch_ids)
  ON CONFLICT (user_id) DO NOTHING;

  -- Process each user who had interactions in this batch
  FOR v_user IN
    SELECT DISTINCT user_id FROM (
      SELECT actor_id AS user_id FROM glicko_interactions WHERE id = ANY(v_batch_ids)
      UNION
      SELECT target_id AS user_id FROM glicko_interactions WHERE id = ANY(v_batch_ids)
    ) AS involved_users
  LOOP
    -- Load current ratings
    SELECT rating, rating_deviation, volatility, interactions_count
    INTO v_new_rating, v_new_rd, v_sigma, v_interactions
    FROM user_glicko_ratings
    WHERE user_id = v_user.user_id;

    -- Step 1: Convert to Glicko-2 scale
    v_mu  := (v_new_rating - 1500.0) / c_scale;
    v_phi := v_new_rd / c_scale;

    -- Step 2-4: Compute v and Δ from all opponents in this batch
    v_v_sum     := 0.0;
    v_delta_sum := 0.0;

    FOR v_opponent IN
      -- Interactions where this user was the actor (sender)
      SELECT
        ugr.rating AS opp_rating,
        ugr.rating_deviation AS opp_rd,
        gi.outcome,
        CASE
          WHEN gi.actor_id = v_user.user_id THEN
            CASE gi.outcome WHEN 'accepted' THEN 1.0 ELSE 0.0 END
          ELSE
            CASE gi.outcome WHEN 'accepted' THEN 0.6 ELSE 0.8 END
        END AS score
      FROM glicko_interactions gi
      JOIN user_glicko_ratings ugr ON ugr.user_id = CASE
        WHEN gi.actor_id = v_user.user_id THEN gi.target_id
        ELSE gi.actor_id
      END
      WHERE gi.id = ANY(v_batch_ids)
        AND (gi.actor_id = v_user.user_id OR gi.target_id = v_user.user_id)
    LOOP
      -- Convert opponent to Glicko-2 scale
      DECLARE
        v_opp_mu  double precision := (v_opponent.opp_rating - 1500.0) / c_scale;
        v_opp_phi double precision := v_opponent.opp_rd / c_scale;
      BEGIN
        -- g(φ) = 1 / sqrt(1 + 3φ²/π²)
        v_g := 1.0 / SQRT(1.0 + 3.0 * v_opp_phi * v_opp_phi / (3.14159265358979 * 3.14159265358979));

        -- E(μ, μj, φj) = 1 / (1 + exp(-g(φj)(μ - μj)))
        v_e := 1.0 / (1.0 + EXP(-v_g * (v_mu - v_opp_mu)));

        -- Accumulate variance: v = [Σ g²E(1-E)]⁻¹
        v_v_sum := v_v_sum + v_g * v_g * v_e * (1.0 - v_e);

        -- Accumulate improvement: Δ = v × Σ g(s-E)
        v_delta_sum := v_delta_sum + v_g * (v_opponent.score - v_e);
      END;
    END LOOP;

    -- Skip if no valid interactions computed
    IF v_v_sum = 0.0 THEN
      CONTINUE;
    END IF;

    -- Step 3: Estimated variance
    v_v := 1.0 / v_v_sum;

    -- Step 4: Estimated improvement
    v_delta := v_v * v_delta_sum;

    -- Step 5: Update volatility σ' using Illinois algorithm
    v_a := LN(v_sigma * v_sigma);

    -- f(x) = (e^x(Δ²-φ²-v-e^x)) / (2(φ²+v+e^x)²) - (x-a)/τ²
    -- Initial bounds
    v_big_a := v_a;

    IF v_delta * v_delta > v_phi * v_phi + v_v THEN
      v_big_b := LN(v_delta * v_delta - v_phi * v_phi - v_v);
    ELSE
      -- Find v_big_b by iterating downward
      DECLARE
        v_k int := 1;
        v_test double precision;
      BEGIN
        LOOP
          v_test := v_a - v_k * v_tau;
          -- f(v_test)
          DECLARE
            v_ex double precision := EXP(v_test);
            v_d2 double precision := v_delta * v_delta;
            v_p2 double precision := v_phi * v_phi;
          BEGIN
            v_f_b := (v_ex * (v_d2 - v_p2 - v_v - v_ex)) /
                     (2.0 * (v_p2 + v_v + v_ex) * (v_p2 + v_v + v_ex))
                     - (v_test - v_a) / (v_tau * v_tau);
          END;
          EXIT WHEN v_f_b < 0;
          v_k := v_k + 1;
          EXIT WHEN v_k > 20;  -- safety limit
        END LOOP;
        v_big_b := v_a - v_k * v_tau;
      END;
    END IF;

    -- Compute f(A) and f(B)
    DECLARE
      v_ex_a double precision := EXP(v_big_a);
      v_ex_b double precision := EXP(v_big_b);
      v_d2   double precision := v_delta * v_delta;
      v_p2   double precision := v_phi * v_phi;
    BEGIN
      v_f_a := (v_ex_a * (v_d2 - v_p2 - v_v - v_ex_a)) /
               (2.0 * (v_p2 + v_v + v_ex_a) * (v_p2 + v_v + v_ex_a))
               - (v_big_a - v_a) / (v_tau * v_tau);
      v_f_b := (v_ex_b * (v_d2 - v_p2 - v_v - v_ex_b)) /
               (2.0 * (v_p2 + v_v + v_ex_b) * (v_p2 + v_v + v_ex_b))
               - (v_big_b - v_a) / (v_tau * v_tau);
    END;

    -- Illinois algorithm iterations
    DECLARE
      v_iter int := 0;
    BEGIN
      WHILE ABS(v_big_b - v_big_a) > v_epsilon AND v_iter < 100 LOOP
        v_big_c := v_big_a + (v_big_a - v_big_b) * v_f_a / (v_f_b - v_f_a);

        -- Compute f(C)
        DECLARE
          v_ex_c double precision := EXP(v_big_c);
          v_d2   double precision := v_delta * v_delta;
          v_p2   double precision := v_phi * v_phi;
        BEGIN
          v_f_c := (v_ex_c * (v_d2 - v_p2 - v_v - v_ex_c)) /
                   (2.0 * (v_p2 + v_v + v_ex_c) * (v_p2 + v_v + v_ex_c))
                   - (v_big_c - v_a) / (v_tau * v_tau);
        END;

        IF v_f_c * v_f_b <= 0 THEN
          v_big_a := v_big_b;
          v_f_a   := v_f_b;
        ELSE
          v_f_a := v_f_a / 2.0;
        END IF;

        v_big_b := v_big_c;
        v_f_b   := v_f_c;
        v_iter  := v_iter + 1;
      END LOOP;
    END;

    v_new_sigma := EXP(v_big_a / 2.0);

    -- Step 6: Pre-rating period RD
    v_phi_star := SQRT(v_phi * v_phi + v_new_sigma * v_new_sigma);

    -- New φ'
    v_new_phi := 1.0 / SQRT(1.0 / (v_phi_star * v_phi_star) + 1.0 / v_v);

    -- Step 7: New μ'
    v_new_mu := v_mu + v_new_phi * v_new_phi * v_delta_sum;

    -- Convert back to Glicko scale
    v_new_rating := v_new_mu * c_scale + 1500.0;
    v_new_rd     := v_new_phi * c_scale;

    -- Floor the rating at 200 (prevent spiral to negative)
    v_new_rating := GREATEST(v_new_rating, 200.0);
    -- Floor RD at 30 (never become "perfectly certain")
    v_new_rd := GREATEST(v_new_rd, 30.0);
    -- Cap RD at 350 (never exceed initial uncertainty)
    v_new_rd := LEAST(v_new_rd, 350.0);

    -- Count interactions for this user in this batch
    SELECT COUNT(*) INTO v_interactions
    FROM glicko_interactions
    WHERE id = ANY(v_batch_ids)
      AND (actor_id = v_user.user_id OR target_id = v_user.user_id);

    -- Write back
    UPDATE user_glicko_ratings
    SET rating           = v_new_rating,
        rating_deviation = v_new_rd,
        volatility       = v_new_sigma,
        interactions_count = interactions_count + v_interactions,
        last_computed_at = NOW()
    WHERE user_id = v_user.user_id;
  END LOOP;

  -- Mark all batch interactions as processed
  UPDATE glicko_interactions
  SET processed = true
  WHERE id = ANY(v_batch_ids);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

COMMENT ON FUNCTION compute_glicko2_batch IS
  'Batch Glicko-2 computation. Runs every 5 minutes via pg_cron. '
  'Processes all unprocessed interaction logs and updates ratings. '
  'Rating Deviation (φ) starts at 350 (max uncertainty) for new users '
  'and converges as interactions accumulate, solving cold-start '
  'mathematically. Volatility (σ) tracks erratic outcome patterns.';

-- ── 6. Nightly tier computation ────────────────────────────────
-- Assigns tier labels based on percentile within gender groups.
-- Users with < 5 total interactions remain "unranked".
-- ================================================================
CREATE OR REPLACE FUNCTION compute_glicko_tiers()
RETURNS void AS $$
BEGIN
  -- Compute percentile-based tiers per gender
  WITH ranked AS (
    SELECT
      g.user_id,
      g.rating,
      g.rating_deviation,
      g.interactions_count,
      u.gender,
      PERCENT_RANK() OVER (
        PARTITION BY u.gender
        ORDER BY g.rating ASC
      ) AS percentile
    FROM user_glicko_ratings g
    JOIN users u ON u.id = g.user_id
    WHERE g.interactions_count >= 5  -- Only rank active users
  )
  UPDATE user_glicko_ratings g
  SET tier = CASE
    WHEN r.percentile >= 0.75 THEN 'platinum'
    WHEN r.percentile >= 0.50 THEN 'gold'
    WHEN r.percentile >= 0.25 THEN 'silver'
    ELSE 'bronze'
  END,
  last_computed_at = NOW()
  FROM ranked r
  WHERE g.user_id = r.user_id;

  -- Reset tier for users with insufficient interactions
  UPDATE user_glicko_ratings
  SET tier = 'unranked'
  WHERE interactions_count < 5;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

COMMENT ON FUNCTION compute_glicko_tiers IS
  'Assigns Glicko tiers (bronze/silver/gold/platinum) based on percentile '
  'distribution within each gender. Users with < 5 interactions remain '
  'unranked. Run nightly at 02:15 UTC.';

-- ── 7. Update compute_global_rank_scores() — blend Glicko ─────
-- The new formula weights:
--   - Completeness: max 10 pts (down from 20)
--   - Glicko tier: 10-25 pts (behavioral signal)
--   - RD confidence bonus: 0-3 pts (low RD = reliable score)
--   - Recency: max 20 pts (unchanged)
--   - New profile boost: +10 for first 7 days (unchanged)
--   - Subscriber boost: +5 (unchanged)
--   - Verified boost: +8 (unchanged)
-- ================================================================
CREATE OR REPLACE FUNCTION compute_global_rank_scores()
RETURNS void AS $$
BEGIN
  UPDATE profiles p
  SET static_rank_score = (
    -- Completeness: max 10 pts (was 20)
    LEAST(COALESCE(p.completeness_score, 0)::float / 10.0, 10.0)

    -- Glicko tier: 10-25 pts (behavioral signal)
    + COALESCE(
        (SELECT CASE g.tier
           WHEN 'platinum' THEN 25
           WHEN 'gold'     THEN 20
           WHEN 'silver'   THEN 15
           WHEN 'bronze'   THEN 10
           ELSE 12  -- unranked gets a middle score
         END
         FROM user_glicko_ratings g WHERE g.user_id = p.user_id),
        12  -- default for users without Glicko row yet
      )

    -- RD confidence bonus: profiles with low RD (high confidence) get a bonus
    + COALESCE(
        (SELECT CASE
           WHEN g.rating_deviation < 100 THEN 3   -- very confident
           WHEN g.rating_deviation < 200 THEN 1   -- moderately confident
           ELSE 0                                   -- still uncertain
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

    -- Weekly subscriber boost: +5
    + CASE
        WHEN p.is_boosted = true AND p.boost_expires_at > NOW() THEN 5
        ELSE 0
      END

    -- Verified profile boost: +8
    + CASE
        WHEN p.is_verified = true THEN 8
        ELSE 0
      END
  )
  WHERE p.visibility = 'visible';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

COMMENT ON FUNCTION compute_global_rank_scores IS
  'V2: Blends Glicko-2 behavioral signals into the rank score. '
  'Completeness weight reduced from 20 to 10 pts. Glicko tier adds '
  '10-25 pts based on interest acceptance patterns. RD confidence '
  'bonus adds 0-3 pts for profiles with stable, well-established '
  'ratings. Verified profiles get an additional +8 boost.';

-- ── 8. Cron jobs ──────────────────────────────────────────────
-- Glicko-2 batch: every 5 minutes (near real-time updates)
-- Glicko tiers: nightly at 02:15 UTC (percentile recalculation)
-- ================================================================
SELECT cron.schedule(
  'compute_glicko2_batch',
  '*/5 * * * *',
  $$SELECT compute_glicko2_batch();$$
);

SELECT cron.schedule(
  'compute_glicko_tiers_nightly',
  '15 2 * * *',
  $$SELECT compute_glicko_tiers();$$
);
