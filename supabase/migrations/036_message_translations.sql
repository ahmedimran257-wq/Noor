-- ============================================================
-- MIGRATION 036: MESSAGE TRANSLATIONS (MUSLIMA FEATURE)
-- Adds translations column to messages table.
-- ============================================================

ALTER TABLE messages
  ADD COLUMN IF NOT EXISTS translations JSONB DEFAULT '{}'::jsonb;

COMMENT ON COLUMN messages.translations IS
  'Stores translations of the message content as key-value pairs (e.g. {"ur": "ہیلو", "tr": "merhaba"}).';
