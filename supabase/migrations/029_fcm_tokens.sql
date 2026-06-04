-- ============================================================
-- MIGRATION 029: FCM TOKEN STORAGE
-- Stores Firebase Cloud Messaging device tokens per user.
-- Replaces the OneSignal external_id targeting approach.
--
-- The dispatch-notifications Edge Function queries this table
-- to resolve user_id → FCM token(s) before sending pushes.
-- ============================================================

CREATE TABLE user_fcm_tokens (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  device_id   text NOT NULL,                          -- From user_devices.device_id
  fcm_token   text NOT NULL,                          -- Firebase Cloud Messaging registration token
  platform    text NOT NULL DEFAULT 'android',        -- 'android' or 'ios'
  updated_at  timestamptz NOT NULL DEFAULT now(),
  created_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, device_id)
);

CREATE INDEX idx_fcm_tokens_user ON user_fcm_tokens(user_id);

COMMENT ON TABLE user_fcm_tokens IS
  'Stores FCM registration tokens per user per device. '
  'Tokens are upserted on each app launch and refreshed when Firebase rotates them. '
  'On logout or account deletion, the row is deleted to prevent ghost pushes.';

-- RLS: Users can manage their own FCM tokens
ALTER TABLE user_fcm_tokens ENABLE ROW LEVEL SECURITY;

CREATE POLICY fcm_tokens_select ON user_fcm_tokens
  FOR SELECT USING (user_id = auth.uid());

CREATE POLICY fcm_tokens_insert ON user_fcm_tokens
  FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY fcm_tokens_update ON user_fcm_tokens
  FOR UPDATE USING (user_id = auth.uid());

CREATE POLICY fcm_tokens_delete ON user_fcm_tokens
  FOR DELETE USING (user_id = auth.uid());
