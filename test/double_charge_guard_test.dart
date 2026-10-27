import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // Monthly and 3-month are separate Play subscriptions; buying one while the
  // other is active starts a second subscription and charges twice.
  test('purchases check the store live before charging', () {
    final service =
        File('lib/core/services/subscription_service.dart').readAsStringSync();
    final check =
        service.indexOf('final current = await Purchases.getCustomerInfo();');
    final charge = service.indexOf('await Purchases.purchase(');
    expect(check, isNonNegative);
    expect(charge, greaterThan(check),
        reason: 'The live entitlement check must run before the purchase.');
    expect(service,
        contains('outcome: SubscriptionPurchaseOutcome.alreadyPurchased'));
  });

  test('a paid member or a second tap cannot start another purchase', () {
    final cubit = File('lib/core/cubits/subscription/subscription_cubit.dart')
        .readAsStringSync();
    expect(cubit, contains('if (state.isLoading) return false;'));
    expect(cubit, contains('if (state.hasPaidPremium) {'));
  });
}
