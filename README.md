# Silarah

Silarah is a Flutter-based Muslim matrimony app with a Supabase backend, a Next.js staff admin panel, RevenueCat subscriptions, Firebase Crashlytics/FCM, and server-controlled privacy, moderation, discovery, chat, and profile state.

This repository contains:

- `lib/` - Flutter mobile app
- `admin/` - staff-only Next.js admin panel
- `supabase/` - database migrations, Edge Functions, and Supabase config
- `assets/` - fonts, app assets, and bundled on-device ML models
- `test/` - Flutter tests
- `tool/` - maintenance scripts, including secret scanning

Do not commit live project config or secrets. See [CONFIGURATION.md](./CONFIGURATION.md).

## Prerequisites

- Flutter SDK matching `pubspec.yaml`
- Dart SDK from Flutter
- Node.js 20+ for the admin panel
- Supabase CLI available through `npx supabase`
- Firebase CLI and FlutterFire CLI for regenerating native Firebase config
- Android Studio / Xcode for platform builds

## Runtime Configuration

The Flutter app reads environment-specific values from Dart defines:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `REVENUECAT_ANDROID_KEY`
- `REVENUECAT_IOS_KEY`
- `FIREBASE_PROJECT_ID`
- `FIREBASE_MESSAGING_SENDER_ID`
- `FIREBASE_STORAGE_BUCKET`
- `FIREBASE_ANDROID_API_KEY`
- `FIREBASE_ANDROID_APP_ID`
- `FIREBASE_IOS_API_KEY`
- `FIREBASE_IOS_APP_ID`
- `FIREBASE_IOS_BUNDLE_ID`

Create ignored config files from the example:

```bash
copy config\dart_defines.example.json config\dev.json
copy config\dart_defines.example.json config\staging.json
copy config\dart_defines.example.json config\prod.json
```

Fill those files from your password manager or CI secrets. Never commit real `config/*.json` files.

Run the Flutter app:

```bash
flutter pub get
flutter run --dart-define-from-file=config/dev.json
```

Build release artifacts:

```bash
flutter build appbundle --release --dart-define-from-file=config/prod.json
flutter build ipa --release --dart-define-from-file=config/prod.json
```

## Firebase Setup

Firebase is used for Crashlytics and FCM. The runtime Firebase files are real
Silarah Firebase app config, generated from project `mithaq-fcf44`:

- `lib/firebase_options.dart`
- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`
- `firebase.json`

For each environment:

1. Create a separate Firebase project for dev, staging, and prod.
2. Register Android package `com.silarah.app`.
3. Register the iOS bundle ID used for that environment.
4. Regenerate environment-specific Firebase config before release builds.
5. Keep service-account JSON and private server keys in CI/Supabase secrets only.
6. Confirm the runtime files do not contain `YOUR_` placeholders.

Current checked-in Firebase app config is public client configuration, not a
service-role secret. Rotate/regenerate it when moving to a new Firebase project.

## Supabase Setup

Use separate Supabase projects for dev, staging, and prod.

1. Link the project:

```bash
npx supabase login
npx supabase link --project-ref YOUR_PROJECT_REF
```

2. Enable required extensions in Supabase:

- `postgis`
- `pgcrypto`
- `pg_cron`
- `pg_net`
- `supabase_vault`
- `pg_trgm`, if required by deployed search migrations

3. Apply migrations in filename order:

```bash
npx supabase db push
```

Migration files are ordered numerically under `supabase/migrations/`. Do not run newer migrations before older migrations.

4. Set database settings used by cron jobs:

```sql
ALTER DATABASE postgres SET app.supabase_url = 'https://YOUR_PROJECT_REF.supabase.co';
```

5. Create required storage buckets from migrations/dashboard expectations:

- `profile-photos` - private
- `kyc-documents` - private

Keep private buckets private. Photo reads must go through access-controlled RPC/Edge Function logic.

## Supabase Secrets

Set Edge Function secrets per environment:

```bash
npx supabase secrets set FIREBASE_PROJECT_ID=your_firebase_project_id
npx supabase secrets set FIREBASE_SERVICE_ACCOUNT="{...service account json...}"
npx supabase secrets set REVENUECAT_WEBHOOK_SECRET=your_revenuecat_webhook_secret
```

Supabase injects these automatically for Edge Functions:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY`

Never expose the service-role key to Flutter, browser JavaScript, or `NEXT_PUBLIC_*` variables.

## Edge Function Deployment

Deploy functions after migrations:

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

Then verify:

```bash
npx supabase functions list
```

Configure Auth hooks in the Supabase dashboard:

- Before User Created hook -> `auth-before-user-created`
- Email OTP template must use `{{ .Token }}` for code-based auth

## Admin Panel

The admin panel lives in `admin/`.

Local setup:

```bash
cd admin
npm install
copy .env.example .env.local
npm run dev -- --port 3001
```

Required admin env values:

- `NEXT_PUBLIC_SUPABASE_URL`
- `NEXT_PUBLIC_SUPABASE_ANON_KEY`
- `NEXT_PUBLIC_ADMIN_SITE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`
- `ADMIN_LOGIN_HASH_SALT`, recommended

Bootstrap the first super admin after creating the Auth user:

```sql
INSERT INTO public.admin_memberships (user_id, role)
VALUES ('AUTH_USER_UUID', 'super_admin');
```

The admin panel requires staff membership and MFA. Staff accounts should not need matrimony profiles.

Deploy with Vercel using `admin/` as the project root. Set separate env values for Preview, Staging, and Production.

## RevenueCat Setup

RevenueCat handles store subscriptions and country-specific pricing.

1. Create separate RevenueCat projects/apps for dev/staging/prod, or use clearly separated offerings.
2. Add Android and iOS apps in RevenueCat.
3. Configure products in Play Console/App Store Connect.
4. Set Flutter public SDK keys through Dart defines:
   - `REVENUECAT_ANDROID_KEY`
   - `REVENUECAT_IOS_KEY`
5. Configure webhook:

```text
https://YOUR_PROJECT_REF.supabase.co/functions/v1/revenuecat-webhook
```

6. Store webhook secret with:

```bash
npx supabase secrets set REVENUECAT_WEBHOOK_SECRET=...
```

Subscription state must be updated only by server-side webhook/RPC logic, not by trusting client state.

## Test And Verification Commands

Run before every handoff:

```bash
dart format --set-exit-if-changed lib test
flutter analyze
flutter test --dart-define-from-file=config/dart_defines.example.json
python tool\secret_scan.py
python tool\validate_supabase_migrations.py
```

Admin panel:

```bash
cd admin
npm ci
npm run lint
npm run typecheck
npm run build
npm audit --omit=dev --audit-level=moderate
```

Supabase:

```bash
python tool\validate_supabase_migrations.py
deno fmt --check supabase/functions
deno lint supabase/functions
deno test --allow-env --allow-net supabase/functions
npx supabase db push --dry-run
npx supabase functions list
```

## CI/CD

GitHub Actions runs `.github/workflows/ci.yml` on pull requests and pushes to `main`/`master`.

The pipeline enforces:

- committed secret/live-config scanning
- Dart formatting, `flutter analyze`, and Flutter tests
- admin `npm ci`, lint, TypeScript typecheck, production build, and dependency audit
- Supabase migration filename/secret validation
- Edge Function Deno formatting, linting, and tests
- optional linked Supabase migration dry-run when `SUPABASE_ACCESS_TOKEN` and `SUPABASE_PROJECT_REF` repository secrets are configured

Configure these GitHub repository secrets to enable full Supabase dry-run validation:

- `SUPABASE_ACCESS_TOKEN`
- `SUPABASE_PROJECT_REF`

Use focused device testing for:

- Email OTP signup and returning-user session restore
- Onboarding save/resume
- Discovery feed and filters
- Interest limits and subscription gates
- Chat inbox, message pagination, reports, and blocking
- Private photo access rules
- Admin profile approval/rejection
- Push notification delivery
- RevenueCat purchase and webhook sync

## Production / Staging Separation

Maintain separate environments:

- Dev: local iteration and test accounts
- Staging: release candidate validation with staging Supabase/Firebase/RevenueCat
- Prod: live users only

Each environment needs its own:

- Supabase project
- Firebase project
- RevenueCat keys/products or isolated offerings
- Admin panel deployment/env
- Storage buckets
- Auth email/SMS providers
- Edge Function secrets

Do not connect a dev app build to the production Supabase project.

## Release Checklist

Before releasing:

- `flutter analyze` passes
- `flutter test` passes
- `python tool\secret_scan.py` passes
- Admin `npm run lint` and `npm run build` pass
- Supabase migrations are applied to staging first
- Edge Functions are deployed and active
- Auth email OTP template sends `{{ .Token }}`
- Disposable email hook is active
- RevenueCat webhook test succeeds
- Firebase Crashlytics receives a non-fatal test event
- FCM push test succeeds
- Private photo URLs cannot be signed directly by the client
- Profile visibility, approval, and pause flows are server-enforced
- Free limits are enforced by Supabase/RPC, not local storage
- Admin audit logs record sensitive reads and writes
- Android app bundle/IPA built with `config/prod.json`
- Native Firebase files for prod were injected by CI and not committed
- Backup job and restore drill are current

## Backup And Restore Plan

Minimum production backup posture:

- Keep a checksummed logical backup before every production migration:

```powershell
.\tool\backup_supabase.ps1 -ProjectRef <production-project-ref>
```

- Register the same command as a weekly local task (Sunday 03:00 by default):

```powershell
.\tool\register_supabase_backup_task.ps1 -ProjectRef <production-project-ref>
```

The backup command creates `public.dump`, `public_schema.sql`,
`public_data.sql`, and a SHA-256 `manifest.json` under the Git-ignored
`supabase/backups/` directory. The custom archive is the primary restore
artifact. PostgreSQL 17 client tools and a standalone Supabase CLI are
required; pass `-PgDumpPath` or `-SupabaseCliPath` when they are not installed
in the default local tools directory.

- Enable managed Supabase daily backups/PITR before the production risk or
  recovery objective requires it; local logical backups are supplemental.
- Supabase-managed `auth`/`storage` schemas and Storage object files are not
  included in the public-schema logical dump.

- Keep storage backup procedures for private buckets:
  - `profile-photos`
  - `kyc-documents`

Restore drill:

1. Create a temporary Supabase project.
2. Restore schema and data.
3. Deploy Edge Functions.
4. Set secrets.
5. Run smoke tests against the restored project.
6. Document restore time and any manual steps.

Never test restore directly against production.

## Security Hygiene

- No live keys in source.
- No service-role key in client code or `NEXT_PUBLIC_*`.
- Rotate any key that was previously committed.
- Keep `.env`, `.env.*`, and real `config/*.json` ignored.
- Run `python tool\secret_scan.py` before pushing.
- Review migrations for hardcoded project URLs before merge.

## Useful Documentation

- [CONFIGURATION.md](./CONFIGURATION.md) - runtime config and secret hygiene
- [admin/README.md](./admin/README.md) - admin panel setup
- [supabase/README.md](./supabase/README.md) - Supabase backend notes
