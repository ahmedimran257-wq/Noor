import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:silarah/l10n/india_launch_ui_copy.dart';

void main() {
  final migration = File(
    'supabase/migrations/210_india_phone_and_mother_tongue_catalogue.sql',
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

  test('Premium purchase completes before phone verification is offered', () {
    final purchaseStart = subscription.indexOf('Future<void> _startPurchase');
    final purchaseCall =
        subscription.indexOf('.purchase(planId)', purchaseStart);
    final postPurchaseOffer = subscription.indexOf(
      '_offerPostPurchasePhoneVerification()',
      purchaseCall,
    );
    expect(purchaseStart, greaterThanOrEqualTo(0));
    expect(purchaseCall, greaterThan(purchaseStart));
    expect(postPurchaseOffer, greaterThan(purchaseCall));
    expect(
      subscription.substring(purchaseStart, purchaseCall),
      isNot(contains('showPhoneVerificationSheet')),
    );
  });

  test('profile phone row gates verification and change behind Premium', () {
    final gate = profile.indexOf('if (!subscription.isSubscribed)');
    final verification = profile.indexOf('showPhoneVerificationSheet(', gate);
    expect(gate, greaterThanOrEqualTo(0));
    expect(profile.substring(gate, verification),
        contains('AppRoutes.subscription'));
    expect(profile, contains('isChangingNumber: _phoneVerified'));
    expect(profile, contains("? 'Change'"));
    expect(profile, contains("'Premium'"));
  });

  test('phone picker is server-driven India-first and greys future markets',
      () {
    expect(subscription, contains('LaunchConfigurationService.load()'));
    expect(subscription, contains('enabledCountryCodes'));
    expect(subscription,
        contains('enabled: widget.enabledCountryCodes.contains(c.iso2)'));
    expect(subscription, contains("context.uiCopy('Coming later')"));
    expect(subscription, contains("country.iso2 == 'IN'"));
    expect(phoneService, contains("'assert_my_phone_country_enabled'"));
    expect(migration, contains('FROM public.launch_countries lc'));
    expect(migration, contains('AND lc.enabled'));
    expect(migration, contains("RAISE EXCEPTION 'subscription_required'"));
  });

  test('phone confirmation cannot bypass Premium through the legacy overload',
      () {
    expect(
      migration,
      contains(
          'PERFORM public.assert_my_phone_country_enabled(v_country_code)'),
    );
    expect(
      migration,
      contains('PERFORM public.confirm_my_verified_phone(v_country_code)'),
    );
    expect(phoneService, contains('PremiumActivationPendingException'));
    expect(phoneService, contains('const Duration(seconds: 2)'));
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
      'Premium is active — verify your phone',
      'Your Premium purchase is complete. Verify an India +91 number by SMS to add the phone badge and, for men, enable sending messages.',
      'Verify your phone with a one-time SMS code. Premium must be active before a number can be verified.',
      'Coming later',
      'India launch: only +91 verification is available. Other countries are shown as coming later.',
      'Premium is still activating. Wait a moment, then tap Verify again — your purchase is safe.',
      'Confirmed by SMS verification code. Change it here with a new OTP; Premium expiry stays unchanged.',
      'Your number remains verified. Activate Premium to change it with a new OTP.',
      'Premium is active. Verify an India +91 number by SMS; women can still message without it.',
      'Available after Premium activation. Women can still message free without phone verification.',
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
