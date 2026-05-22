// lib/core/services/subscription_service.dart
// ============================================================
// NOOR — RevenueCat Subscription Service
//
// Fixes Audit Finding 8.1 (High):
//   Hardcoded Dart pricing table is a liability during currency
//   crashes. This service fetches pricing EXCLUSIVELY from
//   RevenueCat Offerings. No hardcoded fallback.
//
// If RevenueCat is unreachable, an error state is shown instead
// of stale prices. This prevents split-brain pricing where the
// UI shows one price but Apple/Google charges another.
//
// Usage:
//   final service = SubscriptionService();
//   await service.initialize();
//   final pricing = service.currentPricing;
// ============================================================

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// Represents pricing information for display in the UI.
class DisplayPricing {
  const DisplayPricing({
    required this.monthlyPrice,
    required this.annualPrice,
    required this.monthlyCta,
    required this.annualCta,
    required this.savingsPercent,
    required this.source,
  });

  final String monthlyPrice;
  final String annualPrice;
  final String monthlyCta;
  final String annualCta;
  final int savingsPercent;
  final PricingSource source;

  /// Creates from a RevenueCat Package.
  factory DisplayPricing.fromPackages({
    required Package monthlyPackage,
    required Package annualPackage,
  }) {
    final monthlyProduct = monthlyPackage.storeProduct;
    final annualProduct = annualPackage.storeProduct;

    // Calculate savings percentage
    final monthlyAnnualized = monthlyProduct.price * 12;
    final savings = monthlyAnnualized > 0
        ? ((1 - (annualProduct.price / monthlyAnnualized)) * 100).round()
        : 0;

    return DisplayPricing(
      monthlyPrice: monthlyProduct.priceString,
      annualPrice: annualProduct.priceString,
      monthlyCta: 'Subscribe — ${monthlyProduct.priceString} / month',
      annualCta: 'Subscribe — ${annualProduct.priceString} / year',
      savingsPercent: savings,
      source: PricingSource.revenueCat,
    );
  }

  /// Error state when RevenueCat is unreachable.
  ///
  /// Shows a user-friendly message instead of stale/incorrect prices.
  /// This prevents the dangerous "split-brain" scenario where the UI
  /// shows one price but the app store charges a different amount.
  factory DisplayPricing.unavailable() => const DisplayPricing(
    monthlyPrice: '--',
    annualPrice: '--',
    monthlyCta: 'Premium features currently unavailable',
    annualCta: 'Please check your connection and try again',
    savingsPercent: 0,
    source: PricingSource.unavailable,
  );

  /// Whether pricing is available for purchase.
  bool get isAvailable => source == PricingSource.revenueCat;
}

enum PricingSource { revenueCat, unavailable }

/// Manages RevenueCat subscriptions and pricing display.
///
/// Primary and ONLY pricing source: RevenueCat Offerings.
/// If RevenueCat is unreachable, displays an error state with
/// automatic retry (3 attempts, 30s apart).
///
/// **No hardcoded fallback prices.** Showing a user a price that
/// doesn't match the actual billing amount is a legal liability
/// (deceptive pricing → chargebacks → app store bans).
class SubscriptionService {
  SubscriptionService._();
  static final instance = SubscriptionService._();

  final _pricingController = StreamController<DisplayPricing>.broadcast();

  /// Stream of pricing updates. Emits whenever pricing changes
  /// (e.g., on init, on offering refresh, on retry success).
  Stream<DisplayPricing> get pricingStream => _pricingController.stream;

  DisplayPricing? _currentPricing;

  /// The current display pricing. Null until [initialize] completes.
  DisplayPricing? get currentPricing => _currentPricing;

  bool _isSubscribed = false;

  /// Whether the current user has an active subscription.
  bool get isSubscribed => _isSubscribed;

  CustomerInfo? _customerInfo;

  /// Current RevenueCat customer info.
  CustomerInfo? get customerInfo => _customerInfo;

  // Retry state
  Timer? _retryTimer;
  int _retryCount = 0;
  static const _maxRetries = 3;
  static const _retryInterval = Duration(seconds: 30);

  /// Initialize RevenueCat and fetch current offerings.
  ///
  /// Call this once during app startup, after authentication.
  /// If RevenueCat is unreachable, shows an error state and
  /// retries up to 3 times at 30-second intervals.
  Future<void> initialize({required String userId}) async {
    try {
      // Log in the user with RevenueCat
      await Purchases.logIn(userId);

      // Fetch customer info to check subscription status
      _customerInfo = await Purchases.getCustomerInfo();
      _isSubscribed = _customerInfo?.entitlements.active.containsKey('premium') ?? false;

      // Fetch offerings for pricing display
      await _refreshPricing();

      // Listen for subscription changes
      Purchases.addCustomerInfoUpdateListener((info) {
        _customerInfo = info;
        _isSubscribed = info.entitlements.active.containsKey('premium');
      });
    } catch (e) {
      debugPrint('[SubscriptionService] RevenueCat init error: $e');
      _setPricingUnavailable();
      _scheduleRetry();
    }
  }

  /// Refresh pricing from RevenueCat offerings.
  Future<void> _refreshPricing() async {
    try {
      final offerings = await Purchases.getOfferings();
      final currentOffering = offerings.current;

      if (currentOffering == null) {
        debugPrint('[SubscriptionService] No current offering configured in RevenueCat.');
        _setPricingUnavailable();
        _scheduleRetry();
        return;
      }

      final monthlyPackage = currentOffering.monthly;
      final annualPackage = currentOffering.annual;

      if (monthlyPackage == null || annualPackage == null) {
        debugPrint('[SubscriptionService] Missing monthly/annual package in offering.');
        _setPricingUnavailable();
        _scheduleRetry();
        return;
      }

      _currentPricing = DisplayPricing.fromPackages(
        monthlyPackage: monthlyPackage,
        annualPackage: annualPackage,
      );
      _pricingController.add(_currentPricing!);

      // Reset retry state on success
      _retryTimer?.cancel();
      _retryCount = 0;

      debugPrint(
        '[SubscriptionService] ✅ Pricing loaded from RevenueCat: '
        '${_currentPricing!.monthlyPrice}/mo, ${_currentPricing!.annualPrice}/yr',
      );
    } catch (e) {
      debugPrint('[SubscriptionService] Offerings fetch error: $e');
      _setPricingUnavailable();
      _scheduleRetry();
    }
  }

  /// Set pricing to unavailable error state.
  void _setPricingUnavailable() {
    _currentPricing = DisplayPricing.unavailable();
    _pricingController.add(_currentPricing!);
    debugPrint(
      '[SubscriptionService] ⚠️ RevenueCat unreachable. '
      'Pricing unavailable. Retry $_retryCount/$_maxRetries.',
    );
  }

  /// Schedule a retry attempt if we haven't exceeded the max.
  void _scheduleRetry() {
    if (_retryCount >= _maxRetries) {
      debugPrint('[SubscriptionService] ❌ Max retries reached. Pricing unavailable.');
      return;
    }

    _retryTimer?.cancel();
    _retryCount++;
    _retryTimer = Timer(_retryInterval, () async {
      debugPrint('[SubscriptionService] 🔄 Retry attempt $_retryCount/$_maxRetries...');
      await _refreshPricing();
    });
  }

  /// Manually trigger a pricing refresh (e.g., from a "Try Again" button).
  Future<void> retryPricing() async {
    _retryCount = 0;
    await _refreshPricing();
  }

  /// Purchase a subscription package.
  ///
  /// [isAnnual] determines whether to purchase the monthly or annual plan.
  /// Returns true if purchase was successful.
  Future<bool> purchase({required bool isAnnual}) async {
    try {
      final offerings = await Purchases.getOfferings();
      final currentOffering = offerings.current;

      if (currentOffering == null) {
        throw Exception('No offerings available');
      }

      final package = isAnnual ? currentOffering.annual : currentOffering.monthly;

      if (package == null) {
        throw Exception('Package not available');
      }

      final result = await Purchases.purchasePackage(package);
      _isSubscribed = result.entitlements.active.containsKey('premium');
      _customerInfo = result;

      return _isSubscribed;
    } catch (e) {
      debugPrint('[SubscriptionService] Purchase error: $e');
      return false;
    }
  }

  /// Restore previous purchases (e.g., after reinstall).
  Future<bool> restorePurchases() async {
    try {
      final info = await Purchases.restorePurchases();
      _customerInfo = info;
      _isSubscribed = info.entitlements.active.containsKey('premium');
      return _isSubscribed;
    } catch (e) {
      debugPrint('[SubscriptionService] Restore error: $e');
      return false;
    }
  }

  /// Dispose of resources.
  void dispose() {
    _retryTimer?.cancel();
    _pricingController.close();
  }
}
