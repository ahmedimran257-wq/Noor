# NOOR — Supabase Setup Guide

## Prerequisites

- Supabase CLI installed: `npm install -g supabase`
- A Supabase project created at [supabase.com](https://supabase.com) in the **Mumbai (ap-south-1)** region
- Firebase project with Phone Auth enabled
- RevenueCat account with Android app configured

---

## Step 1: Enable Extensions in Supabase Dashboard

Before running migrations, enable these extensions in the Supabase Dashboard under **Database → Extensions**:

| Extension       | Purpose                                     |
|----------------|---------------------------------------------|
| `postgis`       | Geospatial distance filtering               |
| `pgcrypto`      | Guardian phone encryption                   |
| `pg_cron`       | Scheduled jobs                              |
| `pg_net`        | HTTP calls from cron to Edge Functions      |
| `supabase_vault`| Secure encryption key storage               |

---

## Step 2: Link Your Project

```bash
supabase login
supabase link --project-ref YOUR_PROJECT_REF
```

---

## Step 3: Run Migrations in Order

Run each migration file in the Supabase SQL editor or via CLI:

```bash
# Via CLI (recommended)
supabase db push

# Or run manually in SQL editor in this exact order:
# 001_extensions.sql
# 002_reference_tables.sql
# 003_core_tables.sql
# 004_activity_tables.sql
# 005_moderation_tables.sql
# 006_discovery_engine.sql
# 007_rls_policies.sql
# 008_cron_jobs.sql
# 009_user_devices.sql
```

---

## Step 4: Seed Reference Data

```bash
# Run in SQL editor or with psql:
# seed/001_countries.sql
# seed/002_income_brackets.sql
```

After seeding countries, update the search_vector for cities when you add city data:

```sql
UPDATE cities SET search_vector =
  to_tsvector('simple', coalesce(name,'') || ' ' || coalesce(name_local,''));
```

---

## Step 5: Create Storage Bucket

In Supabase Dashboard → Storage → New Bucket:

- Name: `profile-photos`
- Public: **OFF** (all access via signed URLs only)
- Allowed MIME types: `image/webp, image/jpeg`
- Max file size: `1MB`

Or via CLI:
```bash
supabase storage create profile-photos --public=false
```

---

## Step 6: Configure Vault for Guardian Phone Encryption

In Supabase Dashboard → Database → Vault:

1. Click "Add a new secret"
2. Name: `guardian_key_v1`
3. Value: A strong 32-character random key (generate with `openssl rand -base64 32`)

This key is used by `set_guardian_phone()` to AES-encrypt guardian contact numbers.

---

## Step 7: Set Edge Function Environment Variables

```bash
# Firebase
supabase secrets set FIREBASE_PROJECT_ID=your_firebase_project_id

# RevenueCat
supabase secrets set REVENUECAT_WEBHOOK_SECRET=your_webhook_secret

# OneSignal
supabase secrets set ONESIGNAL_APP_ID=your_app_id
supabase secrets set ONESIGNAL_REST_API_KEY=your_rest_api_key
```

The `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are automatically injected by Supabase.

---

## Step 8: Deploy Edge Functions

```bash
# Deploy all functions
supabase functions deploy firebase-auth-exchange
supabase functions deploy revenuecat-webhook
supabase functions deploy get-signed-url
supabase functions deploy dispatch-notifications
supabase functions deploy admin-purge-deleted-users
```

---

## Step 9: Configure RevenueCat Webhook

In the RevenueCat dashboard:

1. Go to **Project → Integrations → Webhooks**
2. Add endpoint: `https://YOUR_PROJECT_REF.supabase.co/functions/v1/revenuecat-webhook`
3. Copy the webhook secret and set it via: `supabase secrets set REVENUECAT_WEBHOOK_SECRET=...`

---

## Step 10: Update pg_cron Service Role Key

In `migration/008_cron_jobs.sql`, the purge job uses a placeholder URL. Update it:

```sql
-- In Supabase SQL Editor:
SELECT cron.unschedule('trigger_purge_deleted_accounts');

SELECT cron.schedule(
  'trigger_purge_deleted_accounts',
  '15 3 * * *',
  $$
    SELECT net.http_post(
      url  := 'https://YOUR_PROJECT_REF.supabase.co/functions/v1/admin-purge-deleted-users',
      body := '{}'::jsonb,
      headers := jsonb_build_object(
        'Authorization', 'Bearer YOUR_SERVICE_ROLE_KEY',
        'Content-Type',  'application/json'
      )
    );
  $$
);
```

⚠️ **Security Note**: Your service role key is stored in cron.job. Rotate it using Supabase Dashboard → Settings → API → Rotate Key if compromised.

---

## Step 11: Initialize the Discovery Pool

After seeding data and running migrations:

```sql
-- Initial population of the materialized view
REFRESH MATERIALIZED VIEW discovery_pool;
```

---

## Step 12: Verify Everything

```sql
-- Check all tables exist
SELECT tablename FROM pg_tables WHERE schemaname = 'public' ORDER BY tablename;

-- Check all triggers are active
SELECT trigger_name, event_object_table FROM information_schema.triggers
WHERE trigger_schema = 'public' ORDER BY event_object_table;

-- Check scheduled jobs
SELECT jobname, schedule, active FROM cron.job;

-- Check RLS is enabled on all tables
SELECT tablename, rowsecurity FROM pg_tables
WHERE schemaname = 'public' AND rowsecurity = false;
-- ^ This should return 0 rows (all tables RLS-enabled)
```

---

## Environment Variables Summary

| Variable | Where Set | Description |
|---|---|---|
| `FIREBASE_PROJECT_ID` | `supabase secrets` | Firebase project ID for token verification |
| `REVENUECAT_WEBHOOK_SECRET` | `supabase secrets` | HMAC signing secret from RevenueCat |
| `ONESIGNAL_APP_ID` | `supabase secrets` | OneSignal app identifier |
| `ONESIGNAL_REST_API_KEY` | `supabase secrets` | OneSignal API key for sending pushes |
| `SUPABASE_URL` | Auto-injected | Your Supabase project URL |
| `SUPABASE_SERVICE_ROLE_KEY` | Auto-injected | Full bypass key (keep private) |
| `SUPABASE_ANON_KEY` | Auto-injected | Public key for client-side auth |

---

## Architecture Notes

- **Auth**: Firebase phone OTP → `firebase-auth-exchange` Edge Function → Supabase JWT
- **Photos**: All uploads via `get-signed-url` Edge Function. No direct client-to-storage uploads.
- **Subscriptions**: RevenueCat webhook → `revenuecat-webhook` Edge Function → `users` table
- **Notifications**: Timezone-aware queue in `notifications` table + `dispatch-notifications` cron
- **Account Deletion**: 30-day grace → `admin-purge-deleted-users` Edge Function (Zombie Auth proof)
- **Discovery**: `discovery_pool` materialized view refreshed nightly at 02:30 UTC
- **Chat**: Supabase Realtime Broadcast (low-latency) + async REST insert (persistence)
