# Silarah Supabase Backend

This directory contains Silarah database migrations, Edge Functions, and Supabase project configuration.

Use one Supabase project per environment:

- Development
- Staging
- Production

Never share a production project with local development builds.

## Required Extensions

Enable these in the Supabase dashboard before applying migrations:

- `postgis`
- `pgcrypto`
- `pg_cron`
- `pg_net`
- `supabase_vault`
- `pg_trgm`, when search migrations require it

## Link Project

```bash
npx supabase login
npx supabase link --project-ref YOUR_PROJECT_REF
```

## Apply Migrations

Migrations are ordered by filename under `supabase/migrations/`.

```bash
npx supabase db push
```

For review before applying:

```bash
npx supabase db push --dry-run
```

Do not manually skip migration numbers. Later migrations depend on earlier tables, functions, indexes, and policies.

## Project Settings

Cron migrations use a database setting for the project URL instead of hardcoded project refs:

```sql
ALTER DATABASE postgres SET app.supabase_url = 'https://YOUR_PROJECT_REF.supabase.co';
```

## Storage Buckets

Create private buckets:

- `profile-photos`
- `photo-verification-captures` (temporary; 48-hour maximum)

All sensitive reads must go through access-controlled RPC or Edge Functions. Do not make these buckets public.

## Supabase Secrets

Set per environment:

```bash
npx supabase secrets set FIREBASE_PROJECT_ID=your_firebase_project_id
npx supabase secrets set FIREBASE_SERVICE_ACCOUNT_B64=base64_encoded_service_account_json
npx supabase secrets set REVENUECAT_WEBHOOK_SECRET=your_revenuecat_webhook_secret
npx supabase secrets set BREVO_API_KEY=your_server_side_brevo_api_key
```

Do not pass Firebase service-account JSON directly on a command line. Shell
quoting can corrupt both JSON property quotes and PEM newlines. On PowerShell,
create the value without printing it:

```powershell
$json = Get-Content -Raw .\firebase-service-account.json |
  ConvertFrom-Json | ConvertTo-Json -Depth 20 -Compress
$base64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($json))
npx supabase secrets set "FIREBASE_SERVICE_ACCOUNT_B64=$base64"
```

Delete the downloaded credential after the secret is stored, and remove any
legacy `FIREBASE_SERVICE_ACCOUNT` secret after a successful worker probe.

Supabase injects these into Edge Functions:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY`

Never place the service-role key in Flutter, browser JavaScript, or any `NEXT_PUBLIC_*` variable.

`BREVO_API_KEY` is used only by the RevenueCat webhook to deliver membership
transactional mail. Keep it in Supabase Edge Function secrets; never ship it in
the Flutter application.

## Edge Functions

Deploy after migrations:

```bash
npx supabase functions deploy admin-purge-deleted-users
npx supabase functions deploy auth-before-user-created
npx supabase functions deploy brevo-key-keepalive
npx supabase functions deploy dispatch-notifications
npx supabase functions deploy get-signed-url
npx supabase functions deploy revenuecat-webhook
npx supabase functions deploy photo-verification
npx supabase functions deploy purge-photo-verification-captures --no-verify-jwt
npx supabase functions deploy validate-photo-upload
npx supabase functions deploy translate-message
```

Verify deployment:

```bash
npx supabase functions list
```

## Auth

Silarah uses Supabase email OTP, not Firebase SMS OTP, for signup/sign-in.

Dashboard requirements:

- **Confirm signup** uses
  `auth/email_templates/silarah_welcome_verification_code.html`.
- **Magic Link / email OTP** uses
  `auth/email_templates/silarah_verification_code.html`.
- Both templates must show `{{ .Token }}` for the six-digit code.
- Before User Created hook must call `auth-before-user-created`.
- Disposable email blocking must exist server-side, not only in Flutter.

Firebase remains for Crashlytics and FCM push delivery only.

## Transactional membership email

RevenueCat is the billing source of truth. Its authenticated webhook atomically
updates subscription state, records the provider event, writes a durable and
idempotent email outbox row, queues the corresponding in-app/FCM notification,
and sends the email through Brevo. The following provider events are wired:

- `INITIAL_PURCHASE`
- `RENEWAL`
- `PRODUCT_CHANGE`
- `CANCELLATION`
- `EXPIRATION`
- `REFUND`
- `BILLING_ISSUE`

The database outbox prevents concurrent webhook deliveries from producing
duplicate mail. Failed delivery returns a retryable response to RevenueCat and
remains recoverable from the outbox. Store receipts and tax invoices continue
to come from Google Play or Apple; Silarah emails describe account entitlement
state and link to the real subscription-management screen.

Brevo labels the production API key as `No expiration`, but Brevo also expires
keys after 90 days without activity. The `brevo_api_key_keepalive` cron job calls
the private `brevo-key-keepalive` function monthly. It performs a read-only
provider account check, sends no email, and requires the Vault-backed cron
credential, so no manual expiry reminder is needed.

## Cron Jobs

Cron jobs call internal Edge Functions through `pg_net` and an internal cron secret. Keep cron credentials in Vault/Supabase secrets, not in migrations.

Check jobs:

```sql
SELECT jobname, schedule, active FROM cron.job ORDER BY jobname;
```

## Verification Queries

Tables:

```sql
SELECT tablename
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY tablename;
```

RLS:

```sql
SELECT tablename, rowsecurity
FROM pg_tables
WHERE schemaname = 'public'
  AND rowsecurity = false;
```

This should return no user-facing tables.

Triggers:

```sql
SELECT trigger_name, event_object_table
FROM information_schema.triggers
WHERE trigger_schema = 'public'
ORDER BY event_object_table, trigger_name;
```

Functions:

```sql
SELECT proname
FROM pg_proc
JOIN pg_namespace n ON n.oid = pg_proc.pronamespace
WHERE n.nspname = 'public'
ORDER BY proname;
```

## Release Checklist

- `npx supabase db push --dry-run` reviewed
- Migrations applied to staging before production
- Edge Functions deployed and listed as active
- Auth hook configured
- OTP email template uses `{{ .Token }}`
- RevenueCat webhook test passes
- FCM dispatch function sends a test notification
- Private photo signed URL function enforces access rules
- Admin actions write audit logs
- Backup/restore procedure tested outside production

## Backup And Restore

Before major backend changes:

```powershell
.\tool\backup_supabase.ps1 -ProjectRef <production-project-ref>
```

This writes a custom-format public database archive, readable schema/data
exports, and a SHA-256 manifest to the Git-ignored `supabase/backups/`
directory. Register the weekly local job with:

```powershell
.\tool\register_supabase_backup_task.ps1 -ProjectRef <production-project-ref>
```

Storage objects and Supabase-managed schemas require separate backup
procedures. Restore drills should use a temporary Supabase project, never
production.
