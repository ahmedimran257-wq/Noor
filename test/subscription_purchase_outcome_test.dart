import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:silarah/core/services/subscription_service.dart';

void main() {
  group('RevenueCat purchase outcomes', () {
    test('cancellation is a silent exit, not a failed payment', () {
      expect(
        classifySubscriptionPurchaseError(
          PurchasesErrorCode.purchaseCancelledError,
        ),
        SubscriptionPurchaseOutcome.cancelled,
      );
    });

    test('pending payment waits for the entitlement listener', () {
      expect(
        classifySubscriptionPurchaseError(
            PurchasesErrorCode.paymentPendingError),
        SubscriptionPurchaseOutcome.pending,
      );
    });

    test('an already-owned product is reconciled separately', () {
      expect(
        classifySubscriptionPurchaseError(
          PurchasesErrorCode.productAlreadyPurchasedError,
        ),
        SubscriptionPurchaseOutcome.alreadyPurchased,
      );
    });

    test('store and configuration errors fail closed', () {
      for (final code in <PurchasesErrorCode>[
        PurchasesErrorCode.storeProblemError,
        PurchasesErrorCode.networkError,
        PurchasesErrorCode.configurationError,
      ]) {
        expect(
          classifySubscriptionPurchaseError(code),
          SubscriptionPurchaseOutcome.failed,
        );
      }
    });
  });
}
