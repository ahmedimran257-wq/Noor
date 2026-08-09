import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RevenueCat environment isolation', () {
    test('debug Test Store key cannot leak into release selection', () {
      final mainSource = File('lib/main.dart').readAsStringSync();
      final configSource =
          File('lib/core/config/app_config.dart').readAsStringSync();
      final installerSource =
          File('tool/install_android.ps1').readAsStringSync();

      expect(configSource,
          contains("String.fromEnvironment('REVENUECAT_TEST_KEY')"));
      expect(
        mainSource,
        contains('kDebugMode && AppConfig.revenueCatTestKey.isNotEmpty'),
      );
      expect(installerSource, contains("'REVENUECAT_TEST_KEY'"));
      expect(
        installerSource,
        contains('Debug builds must use a RevenueCat Test Store key'),
      );
      expect(
        installerSource,
        contains('Android release builds must use a RevenueCat Play Store key'),
      );
      expect(
        installerSource,
        contains("Firebase configuration does not contain com.silarah.app"),
      );
      expect(installerSource, contains('install -r'));
    });
  });

  group('paywall failure state', () {
    test('never renders placeholder prices or a zero-percent saving', () {
      final serviceSource = File(
        'lib/core/services/subscription_service.dart',
      ).readAsStringSync();
      final screenSource = File(
        'lib/features/home/screens/subscription_screen.dart',
      ).readAsStringSync();

      expect(serviceSource, isNot(contains("monthlyPrice: '--'")));
      expect(serviceSource, isNot(contains("annualPrice: '--'")));
      expect(
        screenSource,
        contains('if (_pricing.source == PricingSource.loading)'),
      );
      expect(screenSource, contains('else if (!_pricing.isAvailable)'));
      expect(screenSource, contains("savings! > 0"));
      expect(
        screenSource,
        isNot(contains('Premium features currently unavailable')),
      );
    });
  });

  group('RevenueCat entitlement contract', () {
    test('uses only the Silarah premium entitlement identifier', () {
      final serviceSource = File(
        'lib/core/services/subscription_service.dart',
      ).readAsStringSync();
      final cubitSource = File(
        'lib/core/cubits/subscription/subscription_cubit.dart',
      ).readAsStringSync();

      expect(serviceSource, contains("premium = 'premium'"));
      expect(serviceSource, isNot(contains('Noor Pro')));
      expect(serviceSource, contains('isPremiumActive'));
      expect(cubitSource, contains('SubscriptionEntitlements.isPremiumActive'));
      expect(cubitSource, isNot(contains("active['premium']")));
    });

    test('looks up regional pricing by the canonical ISO country column', () {
      final serviceSource = File(
        'lib/core/services/subscription_service.dart',
      ).readAsStringSync();

      expect(serviceSource, contains(".eq('iso_code', countryCode)"));
      expect(serviceSource, isNot(contains(".eq('code', countryCode)")));
    });

    test('webhook fails closed when its vendor secret is absent', () {
      final webhook = File(
        'supabase/functions/revenuecat-webhook/index.ts',
      ).readAsStringSync();
      expect(webhook, contains('REVENUECAT_WEBHOOK_SECRET.length < 32'));
      expect(webhook, contains('return new Response("Service Unavailable"'));
    });
  });
}
