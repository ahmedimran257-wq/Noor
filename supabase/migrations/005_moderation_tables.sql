-- ============================================================
-- MIGRATION 005: MODERATION, SAFETY, AND COMPLIANCE TABLES
-- reports, blocks, content_violations, admin_audit_log,
-- admin_notifications, user_consents, notification_prefs,
-- admins, storage_cleanup_queue
-- ============================================================

-- ------------------------------------------------------------
-- REPORTS
-- Users report other users. 3 unique pending reports from
-- different users triggers automatic suspension.
-- ------------------------------------------------------------
CREATE TABLE reports (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_id      uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  reported_user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  reason           text NOT NULL
                     CHECK (reason IN (
                       'fake_profile','inappropriate_photos','harassment',
                       'scam','underage','already_married','offensive_bio','other'
                     )),
  description      text,
  status           text NOT NULL DEFAULT 'pending'
                     CHECK (status IN ('pending','actioned','dismissed')),
  created_at       timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT no_self_report CHECK (reporter_id != reported_user_id)
);

CREATE UNIQUE INDEX uq_report_per_user ON reports(reporter_id, reported_user_id)
  WHERE status = 'pending';                             -- One pending report per pair
CREATE INDEX idx_reports_reported ON reports(reported_user_id, status);

-- Auto-suspend after 3 unique pending reports from different users
CREATE OR REPLACE FUNCTION check_report_threshold()
RETURNS trigger AS $$
DECLARE
  report_count integer;
BEGIN
  SELECT COUNT(DISTINCT reporter_id) INTO report_count
  FROM reports
  WHERE reported_user_id = NEW.reported_user_id
    AND status = 'pending';

  IF report_count >= 3 THEN
    UPDATE profiles
    SET visibility = 'suspended',
        suspended_reason = 'auto_multiple_reports'
    WHERE user_id = NEW.reported_user_id;

    INSERT INTO admin_notifications (type, message, related_user_id)
    VALUES (
      'auto_suspension',
      'User auto-suspended after receiving 3 unique pending reports.',
      NEW.reported_user_id
    );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE TRIGGER trg_check_report_threshold
  AFTER INSERT ON reports
  FOR EACH ROW
  EXECUTE FUNCTION check_report_threshold();

-- ------------------------------------------------------------
-- BLOCKS
-- Silent. Blocked party is not notified.
-- Severs all existing ties (matches + interests) on creation.
-- ------------------------------------------------------------
CREATE TABLE blocks (
  blocker_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  blocked_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (blocker_id, blocked_id),
  CONSTRAINT no_self_block CHECK (blocker_id != blocked_id)
);

CREATE INDEX idx_blocks_blocked ON blocks(blocked_id);

-- Immediately sever matches and interests when a block is placed
CREATE OR REPLACE FUNCTION sever_ties_on_block()
RETURNS trigger AS $$
BEGIN
  -- Remove the shared conversation
  DELETE FROM matches
  WHERE (user_a = NEW.blocker_id AND user_b = NEW.blocked_id)
     OR (user_b = NEW.blocker_id AND user_a = NEW.blocked_id);

  -- Remove any pending or active interests between the pair
  DELETE FROM interests
  WHERE (sender_id = NEW.blocker_id AND receiver_id = NEW.blocked_id)
     OR (sender_id = NEW.blocked_id AND receiver_id = NEW.blocker_id);

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE TRIGGER trg_sever_ties_on_block
  AFTER INSERT ON blocks
  FOR EACH ROW
  EXECUTE FUNCTION sever_ties_on_block();

-- ------------------------------------------------------------
-- CONTENT VIOLATIONS
-- Records each bio/message content filter hit.
-- Escalation to messaging suspension handled by Edge Function.
-- ------------------------------------------------------------
CREATE TABLE content_violations (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id        uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  violation_type text NOT NULL
                   CHECK (violation_type IN ('phone_number','social_media','url')),
  original_content text,                               -- Stored for admin review; purged after 90d
  created_at     timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_content_violations_user_time ON content_violations(user_id, created_at);

-- ------------------------------------------------------------
-- ADMIN AUDIT LOG
-- Every admin action is immutably logged here.
-- admin_id can be a users.id (for guardian actions) or
-- admins.id (for admin panel actions).
-- ------------------------------------------------------------
CREATE TABLE admin_audit_log (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_id       uuid NOT NULL,
  action_type    text NOT NULL,
  target_user_id uuid,
  details        jsonb,
  created_at     timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_audit_log_admin      ON admin_audit_log(admin_id, created_at);
CREATE INDEX idx_audit_log_target     ON admin_audit_log(target_user_id, created_at);
CREATE INDEX idx_audit_log_action     ON admin_audit_log(action_type);

-- ------------------------------------------------------------
-- ADMIN NOTIFICATIONS
-- Internal queue for the admin panel's notification feed.
-- Not pushed to users — for admin review only.
-- ------------------------------------------------------------
CREATE TABLE admin_notifications (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  type            text NOT NULL,
  message         text NOT NULL,
  related_user_id uuid,
  is_read         boolean NOT NULL DEFAULT false,
  created_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_admin_notifs_unread ON admin_notifications(is_read, created_at)
  WHERE is_read = false;

-- ------------------------------------------------------------
-- USER CONSENTS
-- GDPR / legal compliance: every checkbox logged with version.
-- Re-consent required when ToS version changes.
-- ------------------------------------------------------------
CREATE TABLE user_consents (
  user_id       uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  consent_type  text NOT NULL
                  CHECK (consent_type IN ('terms_of_service','privacy_policy','age_verification')),
  version       text NOT NULL,                         -- e.g. '1.0.0'
  granted_at    timestamptz NOT NULL DEFAULT now(),
  ip_address    text,
  app_version   text,
  PRIMARY KEY (user_id, consent_type, version)
);

-- ------------------------------------------------------------
-- NOTIFICATION PREFERENCES
-- Per-user push notification settings and quiet hours.
-- ------------------------------------------------------------
CREATE TABLE notification_prefs (
  user_id              uuid PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  new_interest         boolean NOT NULL DEFAULT true,
  interest_accepted    boolean NOT NULL DEFAULT true,
  new_message          boolean NOT NULL DEFAULT true,
  profile_approved     boolean NOT NULL DEFAULT true,
  interest_expiring    boolean NOT NULL DEFAULT true,
  inactive_nudge       boolean NOT NULL DEFAULT true,
  boost_available      boolean NOT NULL DEFAULT true,
  quiet_start          time NOT NULL DEFAULT time '23:00',-- Local quiet hours
  quiet_end            time NOT NULL DEFAULT time '08:00'
);

-- ------------------------------------------------------------
-- NOTIFICATIONS
-- Timezone-aware push queue. Dispatched by the
-- dispatch-notifications Edge Function every minute.
-- ------------------------------------------------------------
CREATE TABLE notifications (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  type         text NOT NULL,                          -- new_interest | interest_accepted | etc.
  title        text NOT NULL,
  body         text NOT NULL,
  deep_link    text,                                   -- noor://screen/param
  scheduled_at timestamptz NOT NULL,
  sent_at      timestamptz,
  read_at      timestamptz,
  created_at   timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_notifications_user_sched ON notifications(user_id, scheduled_at);
CREATE INDEX idx_notifications_due        ON notifications(scheduled_at)
  WHERE sent_at IS NULL;

-- Timezone-aware notification scheduler
-- Delays notifications generated during quiet hours to 08:00 local time
CREATE OR REPLACE FUNCTION queue_notification(
  p_user_id  uuid,
  p_type     text,
  p_title    text,
  p_body     text,
  p_deep_link text DEFAULT NULL
)
RETURNS void AS $$
DECLARE
  tz         text;
  now_local  time;
  deliver_at timestamptz;
BEGIN
  SELECT timezone INTO tz FROM users WHERE id = p_user_id;

  -- Fallback to UTC if the stored timezone is invalid
  IF NOT EXISTS (SELECT 1 FROM pg_timezone_names WHERE name = tz) THEN
    tz := 'UTC';
  END IF;

  -- Check if current local time falls within quiet hours (23:00–08:00)
  now_local := (NOW() AT TIME ZONE tz)::time;
  IF now_local >= time '23:00' OR now_local < time '08:00' THEN
    -- Schedule for 08:00 next morning local time
    deliver_at := (
      date_trunc('day', NOW() AT TIME ZONE tz) + interval '1 day' + time '08:00'
    ) AT TIME ZONE tz AT TIME ZONE 'UTC';
  ELSE
    deliver_at := NOW();
  END IF;

  INSERT INTO notifications (user_id, type, title, body, deep_link, scheduled_at)
  VALUES (p_user_id, p_type, p_title, p_body, p_deep_link, deliver_at);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Atomic notification checkout — prevents double-delivery via SKIP LOCKED
CREATE OR REPLACE FUNCTION checkout_notifications(batch_size int DEFAULT 500)
RETURNS TABLE (id uuid, user_id uuid, title text, body text, deep_link text)
AS $$
BEGIN
  RETURN QUERY
  UPDATE notifications n
  SET sent_at = NOW()
  WHERE n.id IN (
    SELECT n2.id FROM notifications n2
    WHERE n2.scheduled_at <= NOW() AND n2.sent_at IS NULL
    ORDER BY n2.scheduled_at ASC
    LIMIT batch_size
    FOR UPDATE SKIP LOCKED
  )
  RETURNING n.id, n.user_id, n.title, n.body, n.deep_link;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- ------------------------------------------------------------
-- ADMINS
-- Staff-only accounts. Access via web admin panel only.
-- NOT accessible from Flutter mobile app.
-- ------------------------------------------------------------
CREATE TABLE admins (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email         text UNIQUE NOT NULL,
  password_hash text NOT NULL,                         -- bcrypt hash — never plaintext
  role          text NOT NULL
                  CHECK (role IN ('moderator','admin','super_admin')),
  created_at    timestamptz NOT NULL DEFAULT now()
);

-- ------------------------------------------------------------
-- STORAGE CLEANUP QUEUE
-- Populated when a user row is hard-deleted.
-- Processed by the admin-purge-deleted-users Edge Function,
-- which handles Supabase Storage object removal.
-- ------------------------------------------------------------
CREATE TABLE storage_cleanup_queue (
  user_id    uuid PRIMARY KEY,
  status     text NOT NULL DEFAULT 'pending'
               CHECK (status IN ('pending','processing','done','failed')),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE OR REPLACE FUNCTION queue_storage_cleanup()
RETURNS trigger AS $$
BEGIN
  INSERT INTO storage_cleanup_queue (user_id) VALUES (OLD.id)
  ON CONFLICT (user_id) DO NOTHING;
  RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE TRIGGER clean_storage_on_user_delete
  AFTER DELETE ON users
  FOR EACH ROW
  EXECUTE FUNCTION queue_storage_cleanup();
