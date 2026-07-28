// lib/core/services/subscription_service.dart
// ============================================================
// SILARAH - RevenueCat Subscription Service
// Pricing comes from RevenueCat, with country/tier offering selection.
// No hardcoded prices.
// ============================================================

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'supabase_service.dart';

class DisplayPricing {
  const DisplayPricing({
    required this.monthlyPrice,
    required this.annualPrice,
    required this.monthlyCta,
    required this.annualCta,
    required this.savingsPercent,
    required this.source,
    this.countryCode,
    this.pricingTier,
    this.offeringId,
  });

  final String monthlyPrice;
  final String annualPrice;
  final String monthlyCta;
  final String annualCta;
  final int savingsPercent;
  final PricingSource source;
  final String? countryCode;
  final String? pricingTier;
  final String? offeringId;

  factory DisplayPricing.fromPackages({
    required Package monthlyPackage,
    required Package annualPackage,
    String? countryCode,
    String? pricingTier,
    String? offeringId,
  }) {
    final monthlyProduct = monthlyPackage.storeProduct;
    final annualProduct = annualPackage.storeProduct;
    final monthlyAnnualized = monthlyProduct.price * 12;
    final savings = monthlyAnnualized > 0
        ? ((1 - (annualProduct.price / monthlyAnnualized)) * 100).round()
        : 0;

    return DisplayPricing(
      monthlyPrice: monthlyProduct.priceString,
      annualPrice: annualProduct.priceString,
      monthlyCta: 'Subscribe - ${monthlyProduct.priceString} / month',
      annualCta: 'Subscribe - ${annualProduct.priceString} / year',
      savingsPercent: savings,
      source: PricingSource.revenueCat,
      countryCode: countryCode,
      pricingTier: pricingTier,
      offeringId: offeringId,
    );
  }

  factory DisplayPricing.unavailable() => const DisplayPricing(
        monthlyPrice: '',
        annualPrice: '',
        monthlyCta: '',
        annualCta: '',
        savingsPercent: 0,
        source: PricingSource.unavailable,
      );

  factory DisplayPricing.loading() => const DisplayPricing(
        monthlyPrice: '',
        annualPrice: '',
        monthlyCta: '',
        annualCta: '',
        savingsPercent: 0,
        source: PricingSource.loading,
      );

  bool get isAvailable => source == PricingSource.revenueCat;
}

enum PricingSource { loading, revenueCat, unavailable }

/// Canonical RevenueCat entitlement mapping.
abstract final class SubscriptionEntitlements {
  static const String premium = 'premium';

  static EntitlementInfo? activePremium(CustomerInfo info) {
    return info.entitlements.active[premium];
  }

  static bool isPremiumActive(CustomerInfo info) {
    return activePremium(info) != null;
  }
}

class SubscriptionService {
  SubscriptionService._();
  static final instance = SubscriptionService._();

  final _pricingController = StreamController<DisplayPricing>.broadcast();

  Stream<DisplayPricing> get pricingStream => _pricingController.stream;

  DisplayPricing? _currentPricing;
  DisplayPricing? get currentPricing => _currentPricing;

  bool _isSubscribed = false;
  bool get isSubscribed => _isSubscribed;

  CustomerInfo? _customerInfo;
  CustomerInfo? get customerInfo => _customerInfo;

  Timer? _retryTimer;
  int _retryCount = 0;
  static const _maxRetries = 3;
  static const _retryInterval = Duration(seconds: 30);

  String? _userId;
  String? _countryCode;
  String? _pricingTier;
  Offering? _activeOffering;

  Future<void> initialize({required String userId}) async {
    try {
      _userId = userId;
      await Purchases.logIn(userId);
      await _syncSubscriberAttributes(userId);

      _customerInfo = await Purchases.getCustomerInfo();
      _isSubscribed = _customerInfo != null &&
          SubscriptionEntitlements.isPremiumActive(_customerInfo!);

      await _refreshPricing();

      Purchases.addCustomerInfoUpdateListener((info) {
        _customerInfo = info;
        _isSubscribed = SubscriptionEntitlements.isPremiumActive(info);
      });
    } catch (e) {
      debugPrint('[SubscriptionService] RevenueCat init error: $e');
      _setPricingUnavailable();
      _scheduleRetry();
    }
  }

  Future<void> retryPricing() async {
    _retryCount = 0;
    await _refreshPricing();
  }

  Future<bool> purchase({required bool isAnnual}) async {
    try {
      Offering? offering = _activeOffering;
      if (offering == null) {
        final offerings = await Purchases.syncAttributesAndOfferingsIfNeeded();
        offering = _selectOffering(offerings);
      }
      if (offering == null) throw Exception('No offerings available');

      final package = isAnnual ? offering.annual : offering.monthly;
      if (package == null) throw Exception('Package not available');

      final result = await Purchases.purchasePackage(package);
      _isSubscribed = SubscriptionEntitlements.isPremiumActive(result);
      _customerInfo = result;
      return _isSubscribed;
    } catch (e) {
      debugPrint('[SubscriptionService] Purchase error: $e');
      return false;
    }
  }

  Future<bool> restorePurchases() async {
    try {
      final info = await Purchases.restorePurchases();
      _customerInfo = info;
      _isSubscribed = SubscriptionEntitlements.isPremiumActive(info);
      return _isSubscribed;
    } catch (e) {
      debugPrint('[SubscriptionService] Restore error: $e');
      return false;
    }
  }

  void dispose() {
    _retryTimer?.cancel();
    _pricingController.close();
  }

  Future<void> _refreshPricing() async {
    try {
      if (_userId != null) {
        await _syncSubscriberAttributes(_userId!);
      }

      final offerings = await Purchases.syncAttributesAndOfferingsIfNeeded();
      final offering = _selectOffering(offerings);
      if (offering == null) {
        debugPrint('[SubscriptionService] No offering configured.');
        _setPricingUnavailable();
        _scheduleRetry();
        return;
      }
      _activeOffering = offering;

      final monthlyPackage = offering.monthly;
      final annualPackage = offering.annual;
      if (monthlyPackage == null || annualPackage == null) {
        debugPrint('[SubscriptionService] Missing monthly/annual package.');
        _setPricingUnavailable();
        _scheduleRetry();
        return;
      }

      _currentPricing = DisplayPricing.fromPackages(
        monthlyPackage: monthlyPackage,
        annualPackage: annualPackage,
        countryCode: _countryCode,
        pricingTier: _pricingTier,
        offeringId: offering.identifier,
      );
      _pricingController.add(_currentPricing!);

      _retryTimer?.cancel();
      _retryCount = 0;

      debugPrint(
        '[SubscriptionService] Pricing loaded: '
        '${_currentPricing!.monthlyPrice}/mo, '
        '${_currentPricing!.annualPrice}/yr, '
        'offering=${offering.identifier}, '
        'country=${_countryCode ?? "store"}, '
        'tier=${_pricingTier ?? "default"}',
      );
    } catch (e) {
      debugPrint('[SubscriptionService] Offerings fetch error: $e');
      _setPricingUnavailable();
      _scheduleRetry();
    }
  }

  void _setPricingUnavailable() {
    _currentPricing = DisplayPricing.unavailable();
    _pricingController.add(_currentPricing!);
  }

  void _scheduleRetry() {
    if (_retryCount >= _maxRetries) return;
    _retryTimer?.cancel();
    _retryCount++;
    _retryTimer = Timer(_retryInterval, _refreshPricing);
  }

  Offering? _selectOffering(Offerings offerings) {
    final country = _countryCode?.toLowerCase();
    final tier = _pricingTier?.toLowerCase();
    final candidates = <String>[
      if (country != null) 'country_$country',
      if (country != null) 'silarah_$country',
      if (country != null) country,
      if (tier != null) 'tier_$tier',
      if (tier != null) 'silarah_$tier',
      if (tier != null) tier,
    ];

    for (final id in candidates) {
      final offering = offerings.getOffering(id);
      if (offering != null) return offering;
    }
    return offerings.current;
  }

  Future<void> _syncSubscriberAttributes(String userId) async {
    final context = await _loadPricingContext(userId);
    _countryCode = context.countryCode;
    _pricingTier = context.pricingTier;

    final attributes = <String, String>{
      if (_countryCode != null) 'country_code': _countryCode!,
      if (_pricingTier != null) 'pricing_tier': _pricingTier!,
    };
    if (attributes.isNotEmpty) {
      await Purchases.setAttributes(attributes);
    }
    if (context.email != null && context.email!.isNotEmpty) {
      await Purchases.setEmail(context.email!);
    }
    if (context.verifiedPhone != null && context.verifiedPhone!.isNotEmpty) {
      await Purchases.setPhoneNumber(context.verifiedPhone!);
    }
  }

  Future<_PricingContext> _loadPricingContext(String userId) async {
    String? countryCode;
    String? email;
    String? verifiedPhone;
    String? pricingTier;

    if (SupabaseService.isInitialized) {
      try {
        final user = await SupabaseService.client
            .from('users')
            .select('email, phone, phone_verified_at, country_code')
            .eq('id', userId)
            .maybeSingle();
        countryCode = (user?['country_code'] as String?)?.toUpperCase();
        email = user?['email'] as String?;
        final phoneVerifiedAt = user?['phone_verified_at'] as String?;
        if (phoneVerifiedAt != null && phoneVerifiedAt.isNotEmpty) {
          verifiedPhone = user?['phone'] as String?;
        }
      } catch (e) {
        debugPrint('[SubscriptionService] user context error: $e');
      }

      if (countryCode == null || countryCode.isEmpty) {
        try {
          final profile = await SupabaseService.client
              .from('my_profile_private')
              .select('country_code')
              .eq('user_id', userId)
              .maybeSingle();
          countryCode = (profile?['country_code'] as String?)?.toUpperCase();
        } catch (e) {
          debugPrint('[SubscriptionService] profile context error: $e');
        }
      }

      if (countryCode != null && countryCode.isNotEmpty) {
        pricingTier = await _loadPricingTier(countryCode);
      }
    }

    if (countryCode == null || countryCode.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      countryCode = prefs.getString('user_country_code')?.toUpperCase();
    }

    return _PricingContext(
      countryCode: countryCode,
      pricingTier: pricingTier,
      email: email,
      verifiedPhone: verifiedPhone,
    );
  }

  Future<String?> _loadPricingTier(String countryCode) async {
    try {
      final row = await SupabaseService.client
          .from('countries')
          .select('pricing_tier')
          .eq('code', countryCode)
          .maybeSingle();
      return row?['pricing_tier'] as String?;
    } catch (_) {
      try {
        final row = await SupabaseService.client
            .from('countries')
            .select('pricing_tier')
            .eq('iso_code', countryCode)
            .maybeSingle();
        return row?['pricing_tier'] as String?;
      } catch (e) {
        debugPrint('[SubscriptionService] pricing tier lookup error: $e');
        return null;
      }
    }
  }
}

class _PricingContext {
  const _PricingContext({
    this.countryCode,
    this.pricingTier,
    this.email,
    this.verifiedPhone,
  });

  final String? countryCode;
  final String? pricingTier;
  final String? email;
  final String? verifiedPhone;
}
