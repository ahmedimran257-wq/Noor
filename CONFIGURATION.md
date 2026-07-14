# Silarah Runtime Configuration

Do not commit live Supabase, Firebase, RevenueCat, SMTP, service-role, or store
credentials to this repository.

## Flutter App

Create an ignored config file from `config/dart_defines.example.json`, for
example:

```bash
cp config/dart_defines.example.json config/dev.json
```

Fill `config/dev.json` from your secure password manager or CI secrets, then run:

```bash
flutter run --dart-define-from-file=config/dev.json
flutter build appbundle --dart-define-from-file=config/prod.json
```

For connected Android devices, use the guarded installer. It validates the
required Supabase values before building, so an unconfigured APK cannot be
installed accidentally:

```powershell
powershell -ExecutionPolicy Bypass -File tool/install_android.ps1 -Mode debug -Device <device-id>
```

Use separate files and separate backend projects for dev, staging, and prod:

- `config/dev.json`
- `config/staging.json`
- `config/prod.json`

Only `config/*.example.json` files are committed. Real `config/*.json` files are
ignored.

## Firebase Native Files

The checked-in Firebase files contain real Silarah Firebase app config:

- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`
- `firebase.json`

Before Android/iOS release builds for another environment, regenerate all three
files from that environment's Firebase project and verify no `YOUR_` placeholders
remain. Firebase service-account JSON stays in CI/Supabase secrets, never in the
repo.

### Firebase SMS region policy

Production uses Firebase Authentication's global SMS policy: **Deny** mode with
an empty denied-region list. This permits supported international destinations
instead of restricting verification to India. Review Firebase Authentication
SMS delivery metrics regularly and add only regions showing sustained abuse or
poor verification success to the deny list.

## Supabase Cron URLs

Cron migrations use the database setting `app.supabase_url` instead of a
hardcoded project URL. Set it once per Supabase project:

```sql
ALTER DATABASE postgres SET app.supabase_url = 'https://YOUR_PROJECT_REF.supabase.co';
```

Also keep the internal cron secret and service-role values in Supabase secrets or
Vault, never in migrations.

## Email sending domains

Production email is separated by traffic class to protect deliverability:

- Supabase Auth and other transactional mail send as
  `Silarah <noreply@mail.silarah.com>`.
- Brevo marketing mail sends as `Silarah <updates@news.silarah.com>`.

Both subdomains must remain authenticated in Brevo with Cloudflare-managed
verification and DKIM records. The organizational DMARC policy lives at
`_dmarc.silarah.com` and applies to both subdomains unless a more specific
subdomain policy is added.

Supabase Auth is explicitly limited to 100 project-wide emails per hour, with a
60-second resend cooldown per address. This avoids Supabase's low fallback
allowance while retaining basic abuse protection. Brevo's account-level daily
allowance is separate and remains the final delivery ceiling.

## Secret Scanning

CI runs `python tool/secret_scan.py` on push and pull requests. It blocks common
committed live config patterns:

- Supabase project URLs and JWT-style keys
- Firebase API keys
- RevenueCat public SDK keys

If a real key was committed before this change, rotate it in the provider
dashboard even if it was an anon/public client key.
