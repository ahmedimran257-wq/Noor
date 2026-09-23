# RevenueCat pre-release QA

Silarah uses two deliberately separate billing environments:

- Debug QA uses `REVENUECAT_TEST_KEY` (`test_`) and RevenueCat Test Store.
- Release builds use `REVENUECAT_ANDROID_KEY` (`goog_`) and Google Play Billing.

The app and build scripts reject a Test Store key in release mode. Never upload a
debug/Test Store build to a Play testing track.

## Automated Android Test Store scenarios

Start an Android emulator, then run each scenario from the repository root. When
the RevenueCat dialog appears, press the button named by the script.

```powershell
.\tool\test_revenuecat_android.ps1 -Action valid
.\tool\test_revenuecat_android.ps1 -Action cancel
.\tool\test_revenuecat_android.ps1 -Action failed
```

The valid scenario requires the `premium` entitlement after purchase and restore.
The other scenarios require the expected native error and prove that Premium was
not granted. The remote verifier also requires the current offering to contain
monthly and three-month packages before a device test may start.

Verified on 10 August 2026 with Android emulator `emulator-5554`:

- Monthly Test Store purchase and active `premium` entitlement: passed.
- Restore while Premium is active: passed.
- User cancellation without entitlement: passed.
- Forced billing failure without entitlement: passed.
- Accelerated monthly renewal and final expiry visible in RevenueCat customer
  state: passed.

## Google Play sandbox sign-off

### Configuration evidence — 23 September 2026

- Both Play base plans are active: `silarah_monthly:monthly` and
  `silarah_three_month:three-month`. The three-month plan was activated on
  22 September for India only at exactly INR 749 (Play initially rounded the
  price to INR 750; it was corrected before saving).
- Both products are imported into RevenueCat and attached to `premium`.
- The current `default` offering maps `$rc_monthly` and `$rc_three_month` to
  the matching Play products and base plans. Existing Test Store mappings
  remain unchanged.
- The public SDK API returned both expected Play product/base-plan pairs with
  the production Google Play key. Re-run
  `tool/verify_revenuecat_play_offering.ps1` to check for configuration drift;
  the script never prints keys or performs a purchase.
- Test Store offering verification also passed. The device purchase results
  above remain historical August evidence, not a fresh September test.
- On 23 September, a fresh RevenueCat credential check could read both
  catalogs but still reported the package as not found for subscription-purchase
  validation. Play Console showed the internal track **Inactive**, with only
  draft `Silarah 1.0.0 (42042) - Internal QA` and no delivered test release.
  Catalog setup is not payment sign-off. Prepare and verify a fresh signed
  candidate before requesting internal-release publication approval; do not
  publish the older draft simply to clear this error.
- Google real-time developer notifications are not connected yet. Configure and
  verify delivery before sign-off on renewals, grace/hold and expiry handling.
- No Play release was published and no real-money transaction was performed
  during this configuration work.

Test Store proves the SDK, offering and app entitlement flow. It does not replace
Google Play sandbox testing. Before an internal-testing release is approved:

1. Create and activate `silarah_monthly` and `silarah_three_month` base plans in
   Play at INR 299/month and INR 749/3 months.
2. Import both products into RevenueCat and attach them to entitlement `premium`
   and the current offering.
3. Upload the signed release AAB to the internal track and add license testers.
4. Install from the Play opt-in link; do not sideload the release artifact.
5. Verify purchase, cancellation, renewal, grace/billing issue, restore and expiry
   with two tester accounts and confirm each server event exactly once.

The production webhook intentionally rejects Test Store events. Webhook mutation,
notification and transactional-email testing must use an isolated Supabase staging
project or the Google Play sandbox with a real Supabase UUID as RevenueCat app user
ID; Test Store events must never grant production entitlements.
