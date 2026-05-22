-- ============================================================
-- MIGRATION 019: GRANULAR PHOTO PRIVACY — PER-USER PHOTO UNLOCK
--
-- Fixes Audit Finding 3.2 (Medium):
--   Photo privacy is too binary (public/mutual_only). Women
--   who observe strict Hijab/Niqab need per-user photo unlock
--   independent of match status.
--
-- Changes:
--   1. Create photo_access_requests table
--   2. Extend photo_privacy CHECK to add 'request_only'
--   3. Update can_view_photo() to check access requests
--   4. RLS policies for photo_access_requests
--   5. Notification on photo access request/grant
-- ============================================================

-- ── 1. Photo Access Requests table ────────────────────────────
CREATE TABLE photo_access_requests (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  requester_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  owner_id     uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status       text NOT NULL DEFAULT 'pending'
                 CHECK (status IN ('pending','granted','denied','revoked')),
  created_at   timestamptz NOT NULL DEFAULT now(),
  responded_at timestamptz,
  CONSTRAINT no_self_request CHECK (requester_id != owner_id),
  UNIQUE (requester_id, owner_id)
);

CREATE INDEX idx_photo_access_owner   ON photo_access_requests(owner_id, status);
CREATE INDEX idx_photo_access_requester ON photo_access_requests(requester_id, status);

COMMENT ON TABLE photo_access_requests IS
  'Per-user photo access request system. Supports ''request_only'' photo '
  'privacy mode where users can selectively grant photo visibility to '
  'specific people, independent of match status. Addresses the needs of '
  'women who observe strict Hijab/Niqab.';

-- ── 2. Extend photo_privacy CHECK ─────────────────────────────
ALTER TABLE profiles DROP CONSTRAINT IF EXISTS profiles_photo_privacy_check;
-- Also handle the inline CHECK from the original column definition
ALTER TABLE profiles DROP CONSTRAINT IF EXISTS profiles_photo_privacy_check1;

-- Rebuild with new option
ALTER TABLE profiles ADD CONSTRAINT profiles_photo_privacy_check
  CHECK (photo_privacy IN ('public', 'mutual_only', 'request_only'));

COMMENT ON COLUMN profiles.photo_privacy IS
  'Photo visibility mode. public: all feed viewers see photos. '
  'mutual_only: photos visible only after mutual match. '
  'request_only: photos visible only to users who have been '
  'granted access via photo_access_requests (most restrictive).';

-- ── 3. Update can_view_photo() — add request_only check ──────
CREATE OR REPLACE FUNCTION can_view_photo(p_viewer uuid, p_owner_profile uuid)
RETURNS boolean AS $$
DECLARE
  v_owner_user_id uuid;
  v_privacy       text;
BEGIN
  -- Anonymous: never
  IF p_viewer IS NULL THEN RETURN false; END IF;

  -- Own photos: always visible
  IF EXISTS (
    SELECT 1 FROM profiles WHERE id = p_owner_profile AND user_id = p_viewer
  ) THEN RETURN true; END IF;

  -- Get the owner's privacy setting and user_id
  SELECT pr.photo_privacy, pr.user_id INTO v_privacy, v_owner_user_id
  FROM profiles pr
  WHERE pr.id = p_owner_profile
    AND pr.visibility = 'visible';

  IF v_privacy IS NULL THEN RETURN false; END IF;

  -- Public: visible to all
  IF v_privacy = 'public' THEN RETURN true; END IF;

  -- Mutual_only: viewer must have an accepted match with the owner
  IF v_privacy = 'mutual_only' THEN
    IF EXISTS (
      SELECT 1
      FROM matches m
      WHERE m.status = 'active'
        AND (
          (m.user_a = p_viewer AND m.user_b = v_owner_user_id)
          OR (m.user_b = p_viewer AND m.user_a = v_owner_user_id)
        )
    ) THEN RETURN true; END IF;
    RETURN false;
  END IF;

  -- Request_only: viewer must have been granted access
  IF v_privacy = 'request_only' THEN
    IF EXISTS (
      SELECT 1 FROM photo_access_requests par
      WHERE par.requester_id = p_viewer
        AND par.owner_id = v_owner_user_id
        AND par.status = 'granted'
    ) THEN RETURN true; END IF;
    RETURN false;
  END IF;

  RETURN false;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public;

COMMENT ON FUNCTION can_view_photo IS
  'V2: Supports three privacy modes — public, mutual_only, request_only. '
  'The request_only mode checks photo_access_requests for a granted entry, '
  'enabling per-user photo access independent of match status.';

-- ── 4. Notification triggers ──────────────────────────────────

-- Notify photo owner when someone requests access
CREATE OR REPLACE FUNCTION notify_photo_access_request()
RETURNS trigger AS $$
DECLARE
  v_requester_name text;
BEGIN
  SELECT first_name INTO v_requester_name
  FROM profiles WHERE user_id = NEW.requester_id;

  PERFORM queue_notification(
    NEW.owner_id,
    'photo_access_request',
    'Photo access request',
    format('%s would like to see your photos', COALESCE(v_requester_name, 'Someone')),
    'noor://photo-requests'
  );

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE TRIGGER trg_notify_photo_access_request
  AFTER INSERT ON photo_access_requests
  FOR EACH ROW
  EXECUTE FUNCTION notify_photo_access_request();

-- Notify requester when access is granted
CREATE OR REPLACE FUNCTION notify_photo_access_granted()
RETURNS trigger AS $$
DECLARE
  v_owner_name text;
BEGIN
  IF NEW.status = 'granted' AND OLD.status = 'pending' THEN
    SELECT first_name INTO v_owner_name
    FROM profiles WHERE user_id = NEW.owner_id;

    PERFORM queue_notification(
      NEW.requester_id,
      'photo_access_granted',
      'Photo access granted',
      format('%s has shared their photos with you', COALESCE(v_owner_name, 'Someone')),
      format('noor://profile/%s', (SELECT id FROM profiles WHERE user_id = NEW.owner_id))
    );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE TRIGGER trg_notify_photo_access_granted
  AFTER UPDATE OF status ON photo_access_requests
  FOR EACH ROW
  WHEN (NEW.status = 'granted' AND OLD.status = 'pending')
  EXECUTE FUNCTION notify_photo_access_granted();

-- ── 5. RLS policies ──────────────────────────────────────────
ALTER TABLE photo_access_requests ENABLE ROW LEVEL SECURITY;

-- Owner can see all requests to them
CREATE POLICY par_owner_select ON photo_access_requests
  FOR SELECT USING (owner_id = auth.uid());

-- Requester can see their own requests
CREATE POLICY par_requester_select ON photo_access_requests
  FOR SELECT USING (requester_id = auth.uid());

-- Anyone can create a request (to someone else)
CREATE POLICY par_insert ON photo_access_requests
  FOR INSERT WITH CHECK (requester_id = auth.uid());

-- Only the owner can update (grant/deny/revoke)
CREATE POLICY par_owner_update ON photo_access_requests
  FOR UPDATE
  USING (owner_id = auth.uid())
  WITH CHECK (owner_id = auth.uid());

-- Daily limit: max 10 photo access requests per day per user
CREATE OR REPLACE FUNCTION enforce_photo_request_limit()
RETURNS trigger AS $$
DECLARE
  v_today_count integer;
BEGIN
  SELECT COUNT(*) INTO v_today_count
  FROM photo_access_requests
  WHERE requester_id = NEW.requester_id
    AND created_at::date = CURRENT_DATE;

  IF v_today_count >= 10 THEN
    RAISE EXCEPTION 'You can send up to 10 photo access requests per day.';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE TRIGGER trg_enforce_photo_request_limit
  BEFORE INSERT ON photo_access_requests
  FOR EACH ROW
  EXECUTE FUNCTION enforce_photo_request_limit();
