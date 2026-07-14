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
- `kyc-documents`

All sensitive reads must go through access-controlled RPC or Edge Functions. Do not make these buckets public.

## Supabase Secrets

Set per environment:

```bash
npx supabase secrets set FIREBASE_PROJECT_ID=your_firebase_project_id
npx supabase secrets set FIREBASE_SERVICE_ACCOUNT="{...service account json...}"
npx supabase secrets set REVENUECAT_WEBHOOK_SECRET=your_revenuecat_webhook_secret
```

Supabase injects these into Edge Functions:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY`

Never place the service-role key in Flutter, browser JavaScript, or any `NEXT_PUBLIC_*` variable.

## Edge Functions

Deploy after migrations:

```bash
npx supabase functions deploy admin-purge-deleted-users
npx supabase functions deploy auth-before-user-created
npx supabase functions deploy dispatch-notifications
npx supabase functions deploy get-signed-url
npx supabase functions deploy process-kyc
npx supabase functions deploy revenuecat-webhook
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

- Email template must show `{{ .Token }}` for the six-digit code.
- Before User Created hook must call `auth-before-user-created`.
- Disposable email blocking must exist server-side, not only in Flutter.

Firebase remains for Crashlytics and FCM push delivery only.

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

```bash
npx supabase db dump --schema public --file backups/schema_YYYYMMDD.sql
npx supabase db dump --data-only --schema public --file backups/data_YYYYMMDD.sql
```

Restore drills should use a temporary Supabase project, never production.
