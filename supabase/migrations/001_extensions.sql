-- ============================================================
-- MIGRATION 001: EXTENSIONS
-- NOOR Muslim Matrimony App
-- Run FIRST before any other migration.
-- ============================================================

-- PostGIS: Geospatial distance filtering (ST_DWithin, geography)
CREATE EXTENSION IF NOT EXISTS postgis;

-- pgcrypto: Guardian phone encryption (pgp_sym_encrypt/decrypt)
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- pg_cron: Scheduled jobs (interest expiry, rank computation, etc.)
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- pg_net: HTTP calls from cron (e.g. triggering Edge Functions)
CREATE EXTENSION IF NOT EXISTS pg_net;

-- Supabase Vault: Secure secret storage for encryption keys
-- (Must be enabled via Supabase Dashboard > Extensions — not SQL)
-- CREATE EXTENSION IF NOT EXISTS supabase_vault;
