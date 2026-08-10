# First production release checklist

## Automated and repository gates

- [x] `flutter analyze` has zero findings.
- [x] Full Flutter test suite passes (366 tests on 10 August 2026).
- [x] Admin lint, typecheck, Next.js build, OpenNext Cloudflare build and
      production dependency audit pass.
- [x] Supabase migration validation and Edge Function tests pass.
- [x] Secret scan passes; no production secrets or signing material are tracked.
- [x] Release AAB is signed by the permanent upload certificate, not debug.
- [x] AAB size report is reviewed and no obsolete large assets remain.
- [ ] Source is committed, pushed and tagged from a clean worktree.

## External configuration that can be completed before Play purchase

- [x] Upload SHA-1/SHA-256 are registered on the Firebase Android app.
- [x] `/.well-known/assetlinks.json` contains the upload certificate until Play
      App Signing provides the production app-signing certificate.
- [x] Support, safety, privacy and grievance addresses receive transactional mail.
- [ ] Crashlytics initializes and the release mapping upload is wired. Upload
      symbols and confirm a controlled event in Firebase for candidate
      `1.0.0+16011` before widening the tester group.
- [x] RevenueCat Test Store exposes the current monthly and annual packages;
      Android purchase, restore, cancellation, forced failure and accelerated
      renewal pass. Production webhook state remains a Play sandbox/staging gate.
- [x] Legal pages, deletion URL, sitemap and canonical domain are live.
- [ ] Device QA checklist is signed off.

## Requires the Google Play developer account

- [x] Create the Play app with package `com.silarah.app`.
- [ ] Complete the Google Play merchant verification currently under review.
- [ ] Enrol in Play App Signing and save the app-signing SHA-1/SHA-256.
- [ ] Replace/add the Play app-signing SHA-256 in Digital Asset Links and Firebase.
- [ ] Create `silarah_monthly` and `silarah_annual` subscription base plans.
- [ ] Import production products into RevenueCat and attach them to the Silarah
      entitlement/current offering.
- [ ] Complete App content: Data safety, content rating, target audience, ads,
      account deletion, privacy policy and reviewer access.
- [ ] Upload listing graphics/screenshots and the signed AAB to internal testing.
- [ ] For a new personal account, complete Google’s required closed-test eligibility
      process before requesting production access.
