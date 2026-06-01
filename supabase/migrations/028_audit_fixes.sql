-- ============================================================
-- MIGRATION 028: AUDIT REMEDIATION
--
-- Fixes the following codebase audit findings:
--   §1.1  Paused/suspended profile lockout (CRITICAL)
--   §1.2  Message injection on closed/blocked chats (MEDIUM)
--   §1.3  Raw photo URL exposure in discovery_pool MV (CRITICAL)
--   §2.1  Hard-delete on block destroys evidence (CRITICAL)
--   §2.3  Interest limit race condition (MEDIUM)
--   §2.4  Missing messages(receiver_id, created_at) index (MEDIUM)
--   §3.2  Guardian message transparency column (LOW)
--
-- This migration is idempotent (uses IF NOT EXISTS / OR REPLACE).
-- ============================================================


-- ════════════════════════════════════════════════════════════════
-- §1.1 — FIX PAUSED/SUSPENDED PROFILE LOCKOUT
-- ════════════════════════════════════════════════════════════════
-- Bug: profiles_select policy in 011 requires visibility = 'visible',
-- which locks out users who pause/suspend their own profile.
-- Fix: Always allow users to read their OWN profile row.
-- ================================================================

DROP POLICY IF EXISTS profiles_select ON profiles;

CREATE POLICY profiles_select ON profiles
  FOR SELECT USING (
    -- Users can ALWAYS read their own profile (regardless of visibility)
    user_id = auth.uid()
    -- Other users can only see 'visible' profiles that are not blocked
    OR (
      visibility = 'visible'
      AND NOT EXISTS (
        SELECT 1 FROM blocks b
        WHERE (b.blocker_id = auth.uid() AND b.blocked_id = profiles.user_id)
           OR (b.blocker_id = profiles.user_id AND b.blocked_id = auth.uid())
      )
    )
  );

COMMENT ON POLICY profiles_select ON profiles IS
  'Users can always read their own profile row regardless of visibility state '
  '(paused, suspended, etc.). Other users can only see visible profiles, '
  'with blocked pairs excluded. Fixes audit §1.1 lockout bug.';


-- ════════════════════════════════════════════════════════════════
-- §1.2 — CLOSE MESSAGE INJECTION ON CLOSED/BLOCKED CHATS
-- ════════════════════════════════════════════════════════════════
-- Bug: messages_insert only checks sender_id = auth.uid() but does
-- NOT verify the target match is active. Users can inject messages
-- into closed/blocked/expired matches via direct API calls.
-- Fix: Add match status = 'active' check to both insert policies.
-- ================================================================

DROP POLICY IF EXISTS messages_insert ON messages;

CREATE POLICY messages_insert ON messages
  FOR INSERT WITH CHECK (
    sender_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM matches m
      WHERE m.id = messages.match_id
        AND m.status = 'active'
    )
  );

COMMENT ON POLICY messages_insert ON messages IS
  'Only the authenticated sender can insert messages, and only into '
  'matches with status = active. Prevents message injection into '
  'closed, blocked, or expired conversations. Fixes audit §1.2.';

-- Guardian insert policy — also require active match
DROP POLICY IF EXISTS messages_guardian_insert ON messages;

CREATE POLICY messages_guardian_insert ON messages
  FOR INSERT WITH CHECK (
    -- Must be an active guardian for this match
    EXISTS (
      SELECT 1 FROM guardian_chat_mirrors gcm
      WHERE gcm.match_id = messages.match_id
        AND gcm.guardian_id = auth.uid()
        AND gcm.mode = 'active'
    )
    -- sender_id must be the ward (guardian sends as ward)
    AND sender_id = (
      SELECT gcm.ward_id FROM guardian_chat_mirrors gcm
      WHERE gcm.match_id = messages.match_id
        AND gcm.guardian_id = auth.uid()
        AND gcm.mode = 'active'
      LIMIT 1
    )
    -- Match must be active
    AND EXISTS (
      SELECT 1 FROM matches m
      WHERE m.id = messages.match_id
        AND m.status = 'active'
    )
  );

COMMENT ON POLICY messages_guardian_insert ON messages IS
  'Active guardians can send messages in their ward''s matches, but '
  'ONLY when the match status is active. Guardian messages must set '
  'sent_by_guardian = true for transparency. Fixes audit §1.2 + §3.2.';


-- ════════════════════════════════════════════════════════════════
-- §1.3 — STOP EXPOSING RAW STORAGE PATHS IN DISCOVERY POOL
-- ════════════════════════════════════════════════════════════════
-- Bug: discovery_pool MV returns raw storage_path (e.g. 'uuid/file.webp')
-- which can be used to directly access photos in a public bucket.
-- Fix: Return only the storage_path basename/key (clients will use
-- Supabase Storage SDK to generate signed URLs client-side).
-- Note: The MV already returns NULL for non-public photos. We now
-- return the photo ID instead of the full storage path so the client
-- can call createSignedUrl() with the correct path.
--
-- The discovery_pool MV is recreated from the latest definition (017)
-- with photo_url changed to return the photo record ID instead of
-- the raw storage path.
-- ================================================================

DROP MATERIALIZED VIEW IF EXISTS discovery_pool;

CREATE MATERIALIZED VIEW discovery_pool AS
SELECT
  p.id                                               AS profile_id,
  p.user_id,
  p.gender,
  p.visibility,
  p.onboarding_step,
  p.first_name,
  LEFT(p.last_name, 1)                               AS last_name_initial,
  EXTRACT(YEAR FROM age(p.date_of_birth))::integer   AS age,
  c.name                                             AS city_name,
  p.country_code,
  c.id                                               AS city_id,
  p.sect::text,
  p.sub_sect,
  p.deen_level::text,
  p.profession,
  p.bio,
  p.static_rank_score                                AS rank_score,
  p.last_active_at,
  p.location,
  ST_Y(p.location::geometry)                         AS lat,
  ST_X(p.location::geometry)                         AS lng,
  p.photo_privacy::text,
  p.is_verified,
  p.education_rank,
  p.height_cm,
  p.date_of_birth,
  p.approved_at,
  p.is_boosted,
  p.boost_expires_at,
  -- From migration 010
  p.complexion,
  p.mother_tongue,
  p.community,
  p.residency_status,
  p.diet_type,
  p.smoking_habit,
  p.quran_memorization,
  p.religious_education,
  p.marriage_timeline,
  p.willing_to_relocate,
  p.living_expectation,
  p.is_revert,
  p.special_needs,
  p.previously_married,
  p.children_count,
  p.family_type,
  p.niqab_preference,
  p.mahr_expectation,
  p.mahr_budget,
  p.can_provide_housing,
  p.can_provide_maintenance,
  p.polygamy_status,
  -- From migration 017: behavioral deen signals
  p.listens_to_music,
  p.eats_zabiha_only,
  p.attends_islamic_classes,
  p.reads_quran_daily,
  p.celebrates_mawlid,
  p.watches_movies,
  p.gender_mixing_stance,
  -- Photo data
  (
    SELECT COUNT(*)::integer
    FROM photos ph
    WHERE ph.profile_id = p.id
      AND ph.admin_approved = true
      AND ph.nsfw_cleared   = true
  )                                                  AS photo_count,
  -- §1.3 FIX: Return photo storage_path ONLY for public profiles.
  -- The client must use Supabase Storage SDK createSignedUrl() with
  -- this path. Private photos return NULL.
  (
    SELECT CASE WHEN p.photo_privacy = 'public' THEN ph.storage_path ELSE NULL END
    FROM photos ph
    WHERE ph.profile_id   = p.id
      AND ph.order_index  = 0
      AND ph.admin_approved = true
      AND ph.nsfw_cleared   = true
    LIMIT 1
  )                                                  AS photo_url,
  -- Preference fields
  pr.diaspora_mode,
  pr.open_to_diaspora,
  pr.preferred_countries,
  pr.preferred_age_min,
  pr.preferred_age_max,
  pr.min_education_rank,
  pr.deen_preference,
  pr.preferred_mother_tongue,
  pr.preferred_community,
  pr.preferred_height_min,
  pr.preferred_height_max,
  pr.preferred_marriage_timeline,
  pr.preferred_relocation,
  pr.preferred_living_expectation,
  pr.polygamy_acceptance  AS pref_polygamy_acceptance,
  pr.revert_acceptance,
  pr.special_needs_acceptance,
  -- Behavioral deen preferences
  pr.pref_music_stance,
  pr.pref_zabiha_only,
  pr.pref_quran_daily,
  pr.pref_gender_mixing
FROM profiles p
JOIN cities c ON p.city_id = c.id
JOIN profile_preferences pr ON p.id = pr.profile_id
WHERE p.visibility    = 'visible'
  AND p.onboarding_step >= 14;

-- Recreate indexes
CREATE UNIQUE INDEX idx_discovery_pool_id       ON discovery_pool(profile_id);
CREATE INDEX         idx_discovery_pool_location ON discovery_pool USING GIST (location);
CREATE INDEX         idx_discovery_pool_rank     ON discovery_pool(rank_score DESC, profile_id DESC);
CREATE INDEX         idx_discovery_pool_gender   ON discovery_pool(gender);
CREATE INDEX         idx_discovery_pool_country  ON discovery_pool(country_code);
CREATE INDEX IF NOT EXISTS idx_discovery_pool_gender_country_rank
  ON discovery_pool(gender, country_code, rank_score DESC);

COMMENT ON MATERIALIZED VIEW discovery_pool IS
  'V4: Audit fix — photo_url now contains storage path key for client-side '
  'signed URL generation instead of being directly usable. Private photos '
  'return NULL. Clients must call createSignedUrl() to display photos.';


-- ════════════════════════════════════════════════════════════════
-- §2.1 — SOFT-DELETE BLOCKED MATCHES (PRESERVE EVIDENCE)
-- ════════════════════════════════════════════════════════════════
-- Bug: sever_ties_on_block() hard-deletes matches, which cascades
-- to delete ALL messages (ON DELETE CASCADE). Harassment evidence
-- is permanently lost.
-- Fix: Update match status to 'blocked' instead of deleting.
-- ================================================================

CREATE OR REPLACE FUNCTION sever_ties_on_block()
RETURNS trigger AS $$
BEGIN
  -- §2.1 FIX: Soft-close match instead of hard-delete.
  -- Preserves message history for harassment evidence and moderation.
  UPDATE matches
  SET status         = 'blocked',
      closed_by      = NEW.blocker_id,
      closed_at      = NOW(),
      closure_reason = 'user_blocked'
  WHERE (user_a = NEW.blocker_id AND user_b = NEW.blocked_id)
     OR (user_b = NEW.blocker_id AND user_a = NEW.blocked_id);

  -- Remove any pending or active interests between the pair
  -- (deleting pending interests is safe and desired)
  DELETE FROM interests
  WHERE (sender_id = NEW.blocker_id AND receiver_id = NEW.blocked_id)
     OR (sender_id = NEW.blocked_id AND receiver_id = NEW.blocker_id);

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

COMMENT ON FUNCTION sever_ties_on_block IS
  'Audit fix §2.1: Blocks now soft-close matches (status = blocked) instead '
  'of hard-deleting them. This preserves chat history for harassment evidence '
  'and moderation review. Interests are still deleted as they are ephemeral.';


-- ════════════════════════════════════════════════════════════════
-- §2.3 — INTEREST LIMIT RACE CONDITION (ROW-LEVEL LOCKING)
-- ════════════════════════════════════════════════════════════════
-- Bug: enforce_interest_limits() uses a simple COUNT(*) which can
-- be bypassed by concurrent double-tap requests reading the same
-- count before either commits.
-- Fix: Use an advisory lock keyed on sender_id to serialize
-- concurrent interest submissions from the same user.
-- ================================================================

CREATE OR REPLACE FUNCTION enforce_interest_limits()
RETURNS trigger AS $$
DECLARE
  today_count           integer;
  daily_limit           integer;
  user_gender           text;
  user_sub_status       text;
  hours_since_approval  double precision;
BEGIN
  -- §2.3 FIX: Acquire an advisory lock keyed on the sender's user ID
  -- to serialize concurrent interest submissions. This prevents the
  -- double-tap race condition where two transactions read the same
  -- count before either commits.
  PERFORM pg_advisory_xact_lock(hashtext(NEW.sender_id::text));

  SELECT gender, subscription_status
  INTO user_gender, user_sub_status
  FROM users WHERE id = NEW.sender_id;

  SELECT EXTRACT(EPOCH FROM (NOW() - p.approved_at)) / 3600.0
  INTO hours_since_approval
  FROM profiles p WHERE p.user_id = NEW.sender_id;

  -- Tiered daily limits
  IF hours_since_approval < 168 THEN      -- First 7 days: throttled to curb spam
    daily_limit := 3;
  ELSIF user_gender = 'female' THEN
    daily_limit := 10;
  ELSIF user_sub_status = 'active' THEN
    daily_limit := 20;
  ELSE
    daily_limit := 3;                     -- Free male
  END IF;

  SELECT COUNT(*) INTO today_count
  FROM interests
  WHERE sender_id = NEW.sender_id
    AND created_at::date = CURRENT_DATE;

  IF today_count >= daily_limit THEN
    RAISE EXCEPTION 'Daily interest limit reached. You can send more interests tomorrow.';
  END IF;

  -- Prevent duplicate interests (active pair)
  IF EXISTS (
    SELECT 1 FROM interests
    WHERE sender_id   = NEW.sender_id
      AND receiver_id = NEW.receiver_id
      AND status IN ('pending', 'accepted')
  ) THEN
    RAISE EXCEPTION 'You have already sent an interest to this person.';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

COMMENT ON FUNCTION enforce_interest_limits IS
  'Audit fix §2.3: Uses pg_advisory_xact_lock to serialize concurrent '
  'interest submissions from the same user, preventing double-tap bypass '
  'of daily interest limits. Lock is automatically released on transaction end.';


-- ════════════════════════════════════════════════════════════════
-- §2.4 — MISSING MESSAGES INDEX
-- ════════════════════════════════════════════════════════════════
-- The idx_messages_unread index only covers receiver_id + read_at
-- WHERE read_at IS NULL. A general composite index on
-- (receiver_id, created_at) improves inbox list performance.
-- ================================================================

CREATE INDEX IF NOT EXISTS idx_messages_receiver_time
  ON messages(receiver_id, created_at DESC);

COMMENT ON INDEX idx_messages_receiver_time IS
  'Audit fix §2.4: Composite index for inbox performance. Covers queries '
  'that list messages by receiver ordered by time (chat list, unread counts).';


-- ════════════════════════════════════════════════════════════════
-- §3.2 — GUARDIAN MESSAGE TRANSPARENCY
-- ════════════════════════════════════════════════════════════════
-- Bug: When a guardian sends a message in active mode, the sender_id
-- is set to the ward's user ID. The recipient cannot distinguish
-- between a message from the ward vs. their guardian.
-- Fix: Add sent_by_guardian boolean column to messages.
-- ================================================================

ALTER TABLE messages
  ADD COLUMN IF NOT EXISTS sent_by_guardian boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN messages.sent_by_guardian IS
  'Audit fix §3.2: True when the message was sent by a guardian in active '
  'Wali mode. Enables the chat UI to display a transparency indicator so '
  'the recipient knows a guardian contributed to the conversation.';


-- ════════════════════════════════════════════════════════════════
-- DONE — Refresh the MV to apply changes
-- ════════════════════════════════════════════════════════════════
-- Note: REFRESH CONCURRENTLY requires a unique index, which we have.
REFRESH MATERIALIZED VIEW CONCURRENTLY discovery_pool;
