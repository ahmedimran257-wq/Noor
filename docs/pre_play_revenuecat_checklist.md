# Pre-Play RevenueCat checklist

Saved: 14 September 2026

## Current candidate — 23 September 2026

- Play Console's latest releases/bundles page shows uploaded code `42042`
  and an inactive internal track with that older draft. Do not publish it.
- The new candidate is permanently versioned `1.0.0+42043` in `pubspec.yaml`.
- Both Play products are now imported, attached to `premium`, and mapped to
  the current offering. The production-key offering verifier passes.
- Freeze this updated source, run CI on that exact commit, build with the real
  upload key, and record the new AAB certificate/hash before replacing the draft.
- Production database was checked at migration 259; staging at 264. The five
  pending backend migrations must be backed up, deployed and verified before
  the new app is delivered. Never run a clean reset against production.
- Actual Google Play purchase validation, real-time notifications, license
  testing and Play-delivered payment lifecycle evidence remain required.

The original checklist below records the September 14 baseline; its statements
about an empty Play draft and reserved code 42042 are historical, not current.

## Before the first Internal Testing AAB

1. Freeze and commit the complete release source, including the latest app,
   legal, pricing, localization, website and asset changes.
2. Play Console was checked on 14 September 2026. Silarah has an empty Internal
   Testing draft and no uploaded app bundles, so there is no existing Play-side
   version code. The release source reserves `1.0.0+42042`, above the 42039
   release baseline and the locally installed 42041 ARM64 split APK.
3. Run the final release gate on that exact commit:
   - Dart formatting, Flutter analysis and the complete Flutter test suite.
   - Secret scan and Supabase migration validation.
   - Admin lint, type-check, production build and dependency audit.
   - Supabase Edge Function formatting, linting and tests.
   - Website, legal and pricing contract tests.
4. Build a production AAB for `com.silarah.app` with the Silarah upload key and
   the RevenueCat Google Play public SDK key (`goog_`), never the Test Store
   key. Validate its bundle metadata, certificate, version code and SHA-256.
5. Upload only to Google Play Internal Testing.

## After uploading, before public production

1. Create and activate the India subscription plans: monthly at INR 299 and
   three months at INR 749.
2. Import the Play subscription/base plans into RevenueCat and connect them to
   the `premium` entitlement, the `$rc_monthly` and `$rc_three_month` packages,
   and the current production offering.
3. Confirm RevenueCat Play service credentials, production webhook
   authorization and idempotent server synchronization.
4. Add Internal Testing and license testers, opt in on both physical devices,
   and install the Play-delivered build.
5. Test monthly and three-month purchases, displayed prices, approval,
   decline, pending purchase, restore, renewal, cancellation, expiry, grace
   period, account hold, refund, entitlement revocation and webhook replay.
6. Verify referral Premium interaction and every paid entitlement: browsing,
   interests, messaging rules, advanced filters, profile viewers and boosts.

## Later production gates

- Complete Google merchant/payment verification before accepting real paid
  subscriptions.
- Decide Play Integrity App Check enforcement after release-device metrics are
  verified.
- Classify the remaining Supabase Security Advisor findings.
- Complete the final backup restore drill, Play listing, Data safety and policy
  declarations, and exact-release-candidate QA.
