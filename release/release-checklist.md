# First production release checklist

## Automated and repository gates

- [x] `flutter analyze` has zero findings.
- [x] CI-equivalent Flutter suite passes (453 tests on 31 August 2026).
- [x] Admin lint, typecheck, Next.js build, OpenNext Cloudflare build and
      production dependency audit pass.
- [x] Supabase migration validation and Edge Function tests pass.
- [x] Secret scan passes; no production secrets or signing material are tracked.
- [x] Release-signed APK smoke test updates and launches on the OnePlus without
      Flutter plugin-registration, Firebase Messaging, App Check or Shared
      Preferences startup errors (ABI-split local test build `34029`; not a
      store artifact). Offline cold start and automatic online recovery pass.
- [ ] Rebuild the final release AAB with the permanent upload certificate;
      the previous AAB predates the latest Gradle/source changes and is invalid.
- [ ] Review the size and signature of that exact final AAB.
- [ ] Source is committed, pushed and tagged from a clean worktree.

## External configuration that can be completed before Play purchase

- [x] Upload SHA-1/SHA-256 are registered on the Firebase Android app.
- [ ] Register the final Play app-signing SHA-256 for Play Integrity, confirm
      App Check metrics with the exact release candidate, then enable enforcement
      for supported Firebase products after monitoring valid-token traffic.
- [x] `/.well-known/assetlinks.json` contains the upload certificate until Play
      App Signing provides the production app-signing certificate.
- [x] Support, safety, privacy and grievance addresses receive transactional mail.
- [ ] Crashlytics initializes and the release mapping upload is wired. Upload
      symbols and confirm a controlled event in Firebase for the exact final
      candidate (current source version `1.0.0+27026`) before widening testers.
- [x] RevenueCat Test Store exposes the current monthly and annual packages;
      Android purchase, restore, cancellation, forced failure and accelerated
      renewal/expiry pass. Production webhook state remains a Play sandbox/staging
      gate.
- [x] Legal pages, deletion URL, sitemap and canonical domain are live.
- [x] Production and staging migration history match local source through migration 254;
      Security Advisor categories are classified in
      `release/supabase-security-signoff.md`.
- [x] Fresh version 2 post-254 production app-owned backup has passed checksums,
      archive-catalogue and snapshot-inventory checks.
- [x] Production app-owned data restored into a uniquely named staging-side
      ephemeral database; all 84 table counts matched and cleanup succeeded.
- [ ] Capture refreshed post-254 Security/Performance Advisor dashboard totals;
      direct ACL, ownership, cache, blocking and long-query checks are recorded.
- [x] Reconcile Data safety and public processor wording against the final
      Brevo email and Firebase architecture.
- [ ] Device QA checklist is signed off.

## Requires the Google Play developer account

- [x] Create the Play app with package `com.silarah.app`.
- [ ] Complete the standard Google Payments merchant profile, bank and tax setup required for Google Play Billing in India. Do not configure BillDesk or alternative billing for this India-only release.
- [ ] Enrol in Play App Signing and save the app-signing SHA-1/SHA-256.
- [ ] Replace/add the Play app-signing SHA-256 in Digital Asset Links and Firebase.
- [ ] Create `silarah_monthly` and `silarah_annual` subscription base plans.
- [ ] Import production products into RevenueCat and attach them to the Silarah
      entitlement/current offering.
- [ ] Complete App content: Data safety, content rating, target audience, ads,
      account deletion, privacy policy and reviewer access.
- [ ] Capture the final-build screenshots and upload them with the
      signed AAB to internal/closed testing. Do not upload the current AAB.
- [ ] For a new personal account, complete Google’s required closed-test eligibility
      process before requesting production access.
