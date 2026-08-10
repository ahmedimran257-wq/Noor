import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Test Store purchase follows the requested QA outcome',
      (tester) async {
    expect(kDebugMode, isTrue, reason: 'Test Store must run only in debug.');

    const apiKey = String.fromEnvironment('REVENUECAT_TEST_KEY');
    const action = String.fromEnvironment(
      'REVENUECAT_TEST_ACTION',
      defaultValue: 'valid',
    );
    expect(<String>{'valid', 'cancel', 'failed'}, contains(action));
    expect(
      apiKey.startsWith('test_'),
      isTrue,
      reason: 'A RevenueCat Test Store key is required.',
    );

    await Purchases.setLogLevel(LogLevel.debug);
    final configuration = PurchasesConfiguration(apiKey)
      ..appUserID =
          'rc-device-smoke-$action-${DateTime.now().millisecondsSinceEpoch}';
    await Purchases.configure(configuration);

    final offerings = await Purchases.getOfferings();
    final current = offerings.current;
    expect(current, isNotNull, reason: 'A current offering is required.');

    final monthly = current!.monthly;
    final annual = current.annual;
    expect(monthly, isNotNull, reason: 'The monthly package is required.');
    expect(annual, isNotNull, reason: 'The annual package is required.');

    if (action == 'valid') {
      final purchase = await Purchases.purchase(
        PurchaseParams.package(monthly!),
      );
      expect(purchase.customerInfo.entitlements.active['premium'], isNotNull);

      final restored = await Purchases.restorePurchases();
      expect(restored.entitlements.active['premium'], isNotNull);
      return;
    }

    PlatformException? purchaseError;
    try {
      await Purchases.purchase(PurchaseParams.package(monthly!));
    } on PlatformException catch (error) {
      purchaseError = error;
    }
    expect(purchaseError, isNotNull, reason: '$action must not grant Premium.');

    final errorCode = PurchasesErrorHelper.getErrorCode(purchaseError!);
    if (action == 'cancel') {
      expect(errorCode, PurchasesErrorCode.purchaseCancelledError);
    } else {
      expect(errorCode, isNot(PurchasesErrorCode.purchaseCancelledError));
    }

    final customerInfo = await Purchases.getCustomerInfo();
    expect(customerInfo.entitlements.active['premium'], isNull);
  });
}
