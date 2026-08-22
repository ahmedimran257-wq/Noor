import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:silarah/l10n/india_launch_ui_copy.dart';

void main() {
  final migration = File(
    'supabase/migrations/210_india_phone_and_mother_tongue_catalogue.sql',
  ).readAsStringSync();
  final phoneBeforePurchase = File(
    'supabase/migrations/225_phone_before_paid_premium.sql',
  ).readAsStringSync();
  final runtimeRepair = File(
    'supabase/migrations/228_repair_phone_completion_and_guardian_acceptance.sql',
  ).readAsStringSync();
  final subscription = File(
    'lib/features/home/screens/subscription_screen.dart',
  ).readAsStringSync();
  final profile = File(
    'lib/features/home/screens/my_profile_screen.dart',
  ).readAsStringSync();
  final phoneService = File(
    'lib/core/services/phone_verification_service.dart',
  ).readAsStringSync();
  final contextService = File(
    'lib/core/services/country_context_service.dart',
  ).readAsStringSync();
  final firebaseVerifier = File(
    'supabase/functions/verify-firebase-phone/index.ts',
  ).readAsStringSync();

  test('phone verification completes before paid Premium purchase starts', () {
    final purchaseStart = subscription.indexOf('Future<void> _startPurchase');
    final paidGuard =
        subscription.indexOf('if (entitlement.hasPaidPremium)', purchaseStart);
    final verification =
        subscription.indexOf('showPhoneVerificationSheet(', purchaseStart);
    final purchaseCall =
        subscription.indexOf('.purchase(planId)', purchaseStart);
    expect(purchaseStart, greaterThanOrEqualTo(0));
    expect(paidGuard, greaterThan(purchaseStart));
    expect(paidGuard, lessThan(purchaseCall));
    expect(verification, greaterThan(purchaseStart));
    expect(purchaseCall, greaterThan(verification));
    expect(subscription, contains('isBeforePurchase: true'));
    expect(subscription, contains('_purchaseFlowInProgress'));
  });

  test('profile recovers paid unverified accounts without another purchase',
      () {
    final verificationStart =
        profile.indexOf('Future<void> _startPhoneVerification');
    final paidRecovery =
        profile.indexOf('if (subscription.hasPaidPremium)', verificationStart);
    final directOtp =
        profile.indexOf('showPhoneVerificationSheet(', paidRecovery);
    final checkout =
        profile.indexOf('context.push(AppRoutes.subscription)', directOtp);
    expect(profile, contains('if (!_phoneVerified)'));
    expect(paidRecovery, greaterThan(verificationStart));
    expect(directOtp, greaterThan(paidRecovery));
    expect(checkout, greaterThan(directOtp));
    expect(profile, contains('isChangingNumber: _phoneVerified'));
    expect(profile, contains("? 'Change'"));
    expect(profile, contains("'Premium'"));
  });

  test('OTP entry has a localized, rate-limited resend cooldown', () {
    expect(subscription, contains('Timer? _resendTimer'));
    expect(subscription, contains('_resendSeconds = 60'));
    expect(subscription, contains('l10n.auth_label_resendCodeIn'));
    expect(subscription, contains('l10n.auth_label_resendCode'));
    expect(subscription, contains('_resendTimer?.cancel()'));
  });

  test('phone picker is server-driven India-first and greys future markets',
      () {
    expect(subscription, contains('LaunchConfigurationService.load()'));
    expect(subscription, contains('enabledCountryCodes'));
    expect(subscription,
        contains('enabled: widget.enabledCountryCodes.contains(c.iso2)'));
    expect(subscription, contains("context.uiCopy('Coming later')"));
    expect(subscription, contains("country.iso2 == 'IN'"));
    expect(phoneService, contains("'begin_my_paid_phone_verification'"));
    expect(migration, contains('FROM public.launch_countries lc'));
    expect(migration, contains('AND lc.enabled'));
    expect(phoneBeforePurchase, contains('phone_verification_intents'));
    expect(phoneBeforePurchase, contains("interval '15 minutes'"));
    expect(phoneBeforePurchase,
        contains("RAISE EXCEPTION 'phone_verification_rate_limited'"));
  });

  test('Firebase phone confirmation requires a server checkout intent', () {
    expect(firebaseVerifier, contains('"assert_my_phone_verification_intent"'));
    expect(firebaseVerifier,
        contains('claims.firebase?.sign_in_provider !== "phone"'));
    expect(firebaseVerifier, contains('claims.aud !== FIREBASE_PROJECT_ID'));
    expect(phoneBeforePurchase,
        contains('public.begin_my_paid_phone_verification'));
    expect(phoneBeforePurchase,
        contains('public.assert_my_phone_verification_intent'));
    expect(phoneBeforePurchase,
        contains('public.complete_paid_phone_verification'));
    expect(phoneBeforePurchase,
        contains('DELETE FROM private.phone_verification_intents'));
    expect(firebaseVerifier, contains('"complete_paid_phone_verification"'));
    expect(runtimeRepair, contains("auth.role() <> 'service_role'"));
    expect(phoneBeforePurchase, contains('p_is_change'));
    expect(phoneBeforePurchase, contains('paid_subscription_required'));
  });

  test('women remain free and referral-only men do not consume paid SMS', () {
    expect(phoneBeforePurchase, contains("IF v_gender = 'female' THEN"));
    expect(phoneBeforePurchase, contains('v_referral_active'));
    expect(phoneBeforePurchase,
        contains('IF v_paid_active AND v_phone_verified_at IS NULL THEN'));
  });

  test('catalogue covers all 28 states and 8 union territories', () {
    final rowPattern = RegExp(
      r"\('([A-Z]{2,3})','[^']+',((?:true)|(?:false)),'[^']+',\d+\)",
    );
    final units = <String, bool>{};
    for (final match in rowPattern.allMatches(migration)) {
      final code = match.group(1)!;
      if (code == 'ALL') continue;
      units[code] = match.group(2) == 'true';
    }
    expect(units.length, 36);
    expect(units.values.where((isUt) => !isUt).length, 28);
    expect(units.values.where((isUt) => isUt).length, 8);
  });

  test('state selection ranks real regional languages without excluding India',
      () {
    expect(migration, contains('Census of India C-16 (2011)'));
    expect(migration, contains("('KA','Karnataka',false,'Kannada',1)"));
    expect(migration, contains("('TS','Telangana',false,'Telugu',1)"));
    expect(migration, contains("('JK','Jammu and Kashmir',true,'Kashmiri',1)"));
    expect(migration,
        contains("mt.state_code = 'ALL' OR mt.state_code = v_state_code"));
    expect(migration, contains("THEN 'state'::text ELSE 'india'::text"));
    expect(contextService, contains("'get_mother_tongues_for_location'"));
    expect(contextService, contains("const cacheVersion = 'v2'"));
    expect(contextService, contains("'p_state_name':"));
    expect(contextService, contains("'p_city_name':"));
  });

  test('new India phone copy is complete in every production locale', () {
    const sources = <String>[
      'Verify phone before purchase',
      'Verify an India +91 number once, then your selected Premium purchase will continue. Your subscription remains tied to your account, not this phone number.',
      'Verify your phone with a one-time SMS code.',
      'Confirmed by SMS. Change it with a new OTP; Premium expiry stays unchanged.',
      'Confirmed by SMS. A paid Premium plan enables OTP-protected number changes.',
      'Verified once when you continue with a paid Premium purchase. Women still message free.',
      'Coming later',
      'India launch: only +91 verification is available. Other countries are shown as coming later.',
    ];
    for (final locale in const [
      'ar',
      'bn',
      'de',
      'fr',
      'hi',
      'id',
      'ms',
      'tr',
      'ur'
    ]) {
      final copy = indiaLaunchUiCopy[locale]!;
      for (final source in sources) {
        expect(copy[source], isNotNull, reason: '$locale: $source');
        expect(copy[source], isNot(source), reason: '$locale: $source');
      }
    }
  });
}
