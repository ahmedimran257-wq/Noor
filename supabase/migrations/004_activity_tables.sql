-- ============================================================
-- MIGRATION 004: ACTIVITY TABLES
-- photos, interests, matches, messages
-- ============================================================

-- ------------------------------------------------------------
-- PHOTOS
-- Up to 4 photos per profile. Quota enforced by Edge Function,
-- NOT a DB trigger (prevents pre-signed URL bypass).
-- ------------------------------------------------------------
CREATE TABLE photos (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id     uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  storage_path   text NOT NULL,                         -- Supabase Storage path: {user_id}/{uuid}.webp
  status         text NOT NULL DEFAULT 'pending_upload'
                   CHECK (status IN ('pending_upload','active')),
  order_index    int NOT NULL DEFAULT 0,                -- 0 = primary; 0,1,2,3 allowed
  admin_approved boolean NOT NULL DEFAULT false,
  nsfw_cleared   boolean NOT NULL DEFAULT false,
  created_at     timestamptz NOT NULL DEFAULT now()
);

-- Prevents two photos from sharing the same order slot on a profile
CREATE UNIQUE INDEX idx_photos_primary       ON photos(profile_id, order_index);
CREATE INDEX         idx_photos_profile      ON photos(profile_id);
CREATE INDEX         idx_photos_pending      ON photos(admin_approved, nsfw_cleared)
                                              WHERE admin_approved = false;

COMMENT ON TABLE photos IS
  'IMPORTANT: Photo upload quota (max 4) is enforced by the get-signed-url Edge Function, '
  'NOT a database trigger. Triggers cannot prevent bypass via pre-signed URL hoarding. '
  'The Edge Function checks count, generates URL, and inserts a ''pending_upload'' placeholder '
  'as a single atomic sequence before returning the URL to the client.';

-- Photo visibility helper — called by RLS policy
CREATE OR REPLACE FUNCTION can_view_photo(p_viewer uuid, p_owner_profile uuid)
RETURNS boolean AS $$
BEGIN
  -- Anonymous: never
  IF p_viewer IS NULL THEN RETURN false; END IF;

  -- Own photos: always visible
  IF EXISTS (
    SELECT 1 FROM profiles WHERE id = p_owner_profile AND user_id = p_viewer
  ) THEN RETURN true; END IF;

  -- Public photo_privacy + visible profile
  IF EXISTS (
    SELECT 1 FROM profiles pr
    WHERE pr.id = p_owner_profile
      AND pr.photo_privacy = 'public'
      AND pr.visibility = 'visible'
  ) THEN RETURN true; END IF;

  -- mutual_only: viewer must have an accepted match with the owner
  IF EXISTS (
    SELECT 1
    FROM matches m
    JOIN profiles a ON a.user_id = m.user_a
    JOIN profiles b ON b.user_id = m.user_b
    WHERE
      (m.user_a = p_viewer AND b.id = p_owner_profile)
      OR
      (m.user_b = p_viewer AND a.id = p_owner_profile)
  ) THEN RETURN true; END IF;

  RETURN false;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public;

-- ------------------------------------------------------------
-- INTERESTS
-- Sender expresses interest in receiver. Lifecycle enforced
-- by triggers and a daily pg_cron expiry job.
-- ------------------------------------------------------------
CREATE TABLE interests (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sender_id   uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  receiver_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status      text NOT NULL DEFAULT 'pending'
                CHECK (status IN ('pending','accepted','declined','expired','withdrawn')),
  created_at  timestamptz NOT NULL DEFAULT now(),
  expires_at  timestamptz NOT NULL DEFAULT (now() + interval '14 days'),

  CONSTRAINT no_self_interest CHECK (sender_id != receiver_id)
);

-- Prevent duplicate active interests between the same pair (order-independent)
CREATE UNIQUE INDEX uq_interest_pair ON interests(
  LEAST(sender_id, receiver_id),
  GREATEST(sender_id, receiver_id)
) WHERE status IN ('pending', 'accepted');

CREATE INDEX idx_interests_sender_day         ON interests(sender_id, created_at);
CREATE INDEX idx_interests_receiver_status    ON interests(receiver_id, status, created_at);
CREATE INDEX idx_interests_expires            ON interests(expires_at) WHERE status = 'pending';

-- Daily interest cap + duplicate prevention
CREATE OR REPLACE FUNCTION enforce_interest_limits()
RETURNS trigger AS $$
DECLARE
  today_count           integer;
  daily_limit           integer;
  user_gender           text;
  user_sub_status       text;
  hours_since_approval  double precision;
BEGIN
  SELECT gender, subscription_status
  INTO user_gender, user_sub_status
  FROM users WHERE id = NEW.sender_id;
  -- Note: accepts slight race condition boundary rather than imposing FOR UPDATE deadlocks.

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

CREATE TRIGGER trg_enforce_interest_limits
  BEFORE INSERT ON interests
  FOR EACH ROW
  EXECUTE FUNCTION enforce_interest_limits();

-- Auto-create a match when an interest is accepted
CREATE OR REPLACE FUNCTION create_match_on_accept()
RETURNS trigger AS $$
BEGIN
  IF NEW.status = 'accepted' THEN
    INSERT INTO matches (user_a, user_b)
    SELECT
      LEAST(NEW.sender_id, NEW.receiver_id),
      GREATEST(NEW.sender_id, NEW.receiver_id)
    ON CONFLICT (LEAST(user_a, user_b), GREATEST(user_a, user_b))
    DO NOTHING;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE TRIGGER trg_create_match_on_accept
  AFTER UPDATE OF status ON interests
  FOR EACH ROW
  WHEN (OLD.status IS DISTINCT FROM NEW.status AND NEW.status = 'accepted')
  EXECUTE FUNCTION create_match_on_accept();

-- ------------------------------------------------------------
-- MATCHES
-- Created automatically when an interest is accepted.
-- Each match unlocks a chat channel: 'match:{id}'.
-- ------------------------------------------------------------
CREATE TABLE matches (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_a     uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  user_b     uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- user_a is always LEAST(user_a, user_b) — enforced by the trigger insert
CREATE UNIQUE INDEX uq_match_pair ON matches(
  LEAST(user_a, user_b),
  GREATEST(user_a, user_b)
);
CREATE INDEX idx_matches_user_a ON matches(user_a);
CREATE INDEX idx_matches_user_b ON matches(user_b);

-- ------------------------------------------------------------
-- MESSAGES
-- Text-only in Phase 1. Guarded by two BEFORE INSERT triggers:
-- trg_enforce_probation and trg_assert_messaging_allowed.
-- ------------------------------------------------------------
CREATE TABLE messages (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  match_id       uuid NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
  sender_id      uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  receiver_id    uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  content        text NOT NULL CHECK (char_length(content) BETWEEN 1 AND 2000),
  created_at     timestamptz NOT NULL DEFAULT now(),
  read_at        timestamptz,
  deleted_by_a   boolean NOT NULL DEFAULT false,   -- Soft delete by user_a
  deleted_by_b   boolean NOT NULL DEFAULT false    -- Soft delete by user_b
);

CREATE INDEX idx_messages_match_time ON messages(match_id, created_at);
CREATE INDEX idx_messages_sender     ON messages(sender_id, created_at);
CREATE INDEX idx_messages_unread     ON messages(receiver_id, read_at) WHERE read_at IS NULL;

-- Guard 1: 48-hour probation — blocks new accounts from sending messages
CREATE OR REPLACE FUNCTION enforce_probation_period()
RETURNS trigger AS $$
DECLARE
  user_created_at timestamptz;
BEGIN
  SELECT created_at INTO user_created_at FROM users WHERE id = NEW.sender_id;

  IF user_created_at > (NOW() - INTERVAL '48 hours') THEN
    RAISE EXCEPTION
      'Your account is in a 48-hour security period. '
      'You can browse and send Interests immediately — messaging unlocks soon.';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE TRIGGER trg_enforce_probation
  BEFORE INSERT ON messages
  FOR EACH ROW
  EXECUTE FUNCTION enforce_probation_period();

-- Guard 2: subscription gate + messaging suspension
CREATE OR REPLACE FUNCTION assert_messaging_allowed()
RETURNS trigger AS $$
DECLARE
  v_gender          text;
  v_sub             text;
  v_expires         timestamptz;
  v_suspended_until timestamptz;
BEGIN
  SELECT gender, subscription_status, subscription_expires_at, messaging_suspended_until
  INTO v_gender, v_sub, v_expires, v_suspended_until
  FROM users WHERE id = NEW.sender_id;

  -- Content-violation suspension gate
  IF v_suspended_until IS NOT NULL AND v_suspended_until > NOW() THEN
    RAISE EXCEPTION 'Messaging suspended until %. Please review our community guidelines.',
      v_suspended_until;
  END IF;

  -- Male subscription gate
  IF v_gender = 'male' THEN
    IF v_sub = 'active' THEN
      RETURN NEW;
    END IF;
    -- 24h grace period after billing_issue
    IF v_sub = 'grace' AND v_expires IS NOT NULL
       AND v_expires > NOW() - INTERVAL '24 hours' THEN
      RETURN NEW;
    END IF;
    RAISE EXCEPTION 'Subscribe to unlock messaging. Women always message free on NOOR.';
  END IF;

  RETURN NEW;  -- Women always pass
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Runs AFTER probation check — order matters
CREATE TRIGGER trg_assert_messaging_allowed
  BEFORE INSERT ON messages
  FOR EACH ROW
  EXECUTE FUNCTION assert_messaging_allowed();
