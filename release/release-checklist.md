# First production release checklist

## Automated and repository gates

- [x] `flutter analyze` has zero findings.
- [x] Full Flutter test suite passes (212 tests on 18 July 2026).
- [x] Admin lint, typecheck, build and production audit pass.
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
- [ ] Crashlytics initializes and the release mapping upload is wired; confirm a
      controlled event in the Firebase dashboard for the final release candidate.
- [ ] RevenueCat Test Store offering and SDK initialization are verified; complete
      purchase/restore/cancel/webhook lifecycle with the unlocked review account.
- [x] Legal pages, deletion URL, sitemap and canonical domain are live.
- [ ] Device QA checklist is signed off.

## Requires the Google Play developer account

- [ ] Create the Play app with package `com.silarah.app`.
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
