-- ============================================================
-- MIGRATION 040: USER CONSENTS + ACCOUNT DELETION COLUMNS
--
-- Phase 1 Critical Fixes:
--   Item 9:  Add deletion_reason and deletion_requested_at to users
--   Item 13: Create user_consents table for GDPR Article 9
--            Special Category data consent logging
-- ============================================================

-- ── Item 9: Account deletion tracking columns ────────────────
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS deletion_reason        text,
  ADD COLUMN IF NOT EXISTS deletion_requested_at  timestamptz;

COMMENT ON COLUMN users.deletion_reason IS
  'Reason selected by user during account deletion flow.';

COMMENT ON COLUMN users.deletion_requested_at IS
  'Timestamp when deletion was requested. Grace period of 30 days before purge.';


-- ── Item 13: User consents table ─────────────────────────────
CREATE TABLE IF NOT EXISTS user_consents (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  consent_type  text NOT NULL,
  version       text NOT NULL DEFAULT '1.0',
  granted_at    timestamptz NOT NULL DEFAULT now(),
  revoked_at    timestamptz,
  
  CONSTRAINT unique_active_consent UNIQUE (user_id, consent_type, version)
);

CREATE INDEX IF NOT EXISTS idx_user_consents_user_id
  ON user_consents(user_id);

-- Enable RLS
ALTER TABLE user_consents ENABLE ROW LEVEL SECURITY;

-- Users can insert their own consent records
CREATE POLICY user_consents_insert ON user_consents
  FOR INSERT WITH CHECK (user_id = auth.uid());

-- Users can read their own consent records
CREATE POLICY user_consents_select ON user_consents
  FOR SELECT USING (user_id = auth.uid());

COMMENT ON TABLE user_consents IS
  'Stores explicit consent records per GDPR Article 9 requirements. '
  'Each row records when a user granted (or revoked) consent for a specific '
  'data processing purpose. consent_type ''special_category_religious'' is '
  'required before processing sect, prayer frequency, or Islamic identity data.';
