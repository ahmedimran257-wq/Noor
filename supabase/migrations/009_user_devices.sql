-- ============================================================
-- MIGRATION 009: USER DEVICES TABLE
-- Supports the new-device circuit-breaker in firebase-auth-exchange.
-- Tracks known devices per user for SIM-swap / account takeover protection.
-- ============================================================

CREATE TABLE user_devices (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  device_id    text NOT NULL,                          -- Hardware fingerprint from Flutter
  last_seen_at timestamptz NOT NULL DEFAULT now(),
  app_version  text,
  created_at   timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, device_id)
);

CREATE INDEX idx_user_devices_user ON user_devices(user_id);

COMMENT ON TABLE user_devices IS
  'Tracks known device IDs per user. Used by the firebase-auth-exchange Edge Function '
  'to detect new devices logging into established accounts (>30 days old). '
  'On new device detection, a secondary verification (DOB or PIN) is required '
  'to prevent SIM-swap / telecom number recycling account takeover attacks.';

-- RLS: Users can read their own devices (for settings UI in Phase 2)
ALTER TABLE user_devices ENABLE ROW LEVEL SECURITY;

CREATE POLICY devices_select ON user_devices
  FOR SELECT USING (user_id = auth.uid());

-- Inserts/updates are done by the Edge Function using service role
