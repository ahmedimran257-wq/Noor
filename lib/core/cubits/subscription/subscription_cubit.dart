// SILARAH - Subscription Cubit
// Production RevenueCat flow only.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../services/subscription_service.dart';
import '../../services/supabase_service.dart';
import 'subscription_state.dart';

class SubscriptionCubit extends Cubit<SubscriptionState> {
  SubscriptionCubit() : super(const SubscriptionState());

  static const monthlyProductId = 'silarah_monthly';
  static const annualProductId = 'silarah_annual';

  StreamSubscription<DisplayPricing>? _pricingSub;
  int _entitlementRefreshId = 0;

  Future<void> initialize() async {
    emit(state.copyWith(isLoading: true));

    if (!SupabaseService.isInitialized) {
      emit(state.copyWith(
        isLoading: false,
        error: 'Subscriptions are not configured. Please try again later.',
      ));
      return;
    }

    _pricingSub = SubscriptionService.instance.pricingStream.listen((_) {
      if (!isClosed) emit(state.copyWith(isLoading: false));
    });

    if (!isClosed) {
      emit(state.copyWith(
        isLoading: false,
        status: SubscriptionStatus.none,
        source: PremiumEntitlementSource.none,
        clearExpiresAt: true,
      ));
    }
  }

  Future<void> loginUser(String userId) async {
    if (!SupabaseService.isInitialized) return;

    emit(state.copyWith(isLoading: true));

    CustomerInfo? customerInfo;
    var revenueCatReady = false;
    try {
      await Purchases.logIn(userId);
      customerInfo = await Purchases.getCustomerInfo();
      revenueCatReady = true;

      await SubscriptionService.instance.initialize(userId: userId);
    } catch (e) {
      debugPrint('[SubscriptionCubit] RevenueCat login error: $e');
    }

    // Supabase is authoritative for promotional grants. This runs even when
    // RevenueCat is unavailable so a valid referral reward never shows a
    // paywall merely because the store SDK is offline.
    await _refreshEffectiveEntitlement(customerInfo, isLoading: false);

    if (revenueCatReady) {
      Purchases.addCustomerInfoUpdateListener((info) {
        if (isClosed) return;
        unawaited(_refreshEffectiveEntitlement(info));
      });
    }
  }

  Future<bool> purchase(String productId) async {
    if (state.isReferralOnly) {
      emit(state.copyWith(
        isLoading: false,
        error:
            'Your free referral Premium is active. Plans become available after it ends so no free time is wasted.',
      ));
      return false;
    }

    emit(state.copyWith(isLoading: true, clearError: true));

    if (!SupabaseService.isInitialized) {
      emit(state.copyWith(
        isLoading: false,
        error: 'Subscriptions are not configured. Please try again later.',
      ));
      return false;
    }

    try {
      final success = await SubscriptionService.instance.purchase(
        isAnnual: productId == annualProductId,
      );

      if (isClosed) return false;

      if (success) {
        final info = await Purchases.getCustomerInfo();
        await _refreshEffectiveEntitlement(
          info,
          isLoading: false,
          successMessage: 'JazakAllah khair - SILARAH Premium is now active!',
        );
        return state.isSubscribed;
      } else {
        emit(state.copyWith(
          isLoading: false,
          error: 'Purchase could not be completed. Please try again.',
        ));
        return false;
      }
    } catch (e) {
      debugPrint('[SubscriptionCubit] Purchase error: $e');
      if (!isClosed) {
        emit(state.copyWith(
          isLoading: false,
          error: 'Purchase failed. Please check your connection and try again.',
        ));
      }
      return false;
    }
  }

  Future<void> restore() async {
    emit(state.copyWith(isLoading: true, clearError: true));

    if (!SupabaseService.isInitialized) {
      emit(state.copyWith(
        isLoading: false,
        error: 'Subscriptions are not configured. Please try again later.',
      ));
      return;
    }

    try {
      final success = await SubscriptionService.instance.restorePurchases();

      if (isClosed) return;

      if (success) {
        final info = await Purchases.getCustomerInfo();
        await _refreshEffectiveEntitlement(
          info,
          isLoading: false,
          successMessage: 'Alhamdulillah! Your subscription has been restored.',
        );
      } else {
        emit(state.copyWith(
          isLoading: false,
          error: 'No previous purchases found for this account.',
        ));
      }
    } catch (e) {
      debugPrint('[SubscriptionCubit] Restore error: $e');
      if (!isClosed) {
        emit(state.copyWith(
          isLoading: false,
          error: 'Restore failed. Please try again.',
        ));
      }
    }
  }

  void clearMessages() {
    emit(state.copyWith(clearError: true, clearSuccess: true));
  }

  /// Refreshes paid and promotional access without requiring a new login.
  /// Referral rewards can arrive while the app is already open, so login-only
  /// entitlement hydration is not sufficient.
  Future<void> refreshEntitlement({bool showLoading = false}) async {
    if (!SupabaseService.isInitialized) return;
    if (showLoading && !isClosed) emit(state.copyWith(isLoading: true));

    CustomerInfo? customerInfo;
    try {
      customerInfo = await Purchases.getCustomerInfo();
    } catch (e) {
      debugPrint('[SubscriptionCubit] RevenueCat refresh error: $e');
    }
    await _refreshEffectiveEntitlement(customerInfo, isLoading: false);
  }

  void clear() {
    _entitlementRefreshId++;
    if (!isClosed) emit(const SubscriptionState());
  }

  Future<void> _refreshEffectiveEntitlement(
    CustomerInfo? customerInfo, {
    bool? isLoading,
    String? successMessage,
  }) async {
    final refreshId = ++_entitlementRefreshId;
    final revenueCatActive = customerInfo != null &&
        SubscriptionEntitlements.isPremiumActive(customerInfo);
    final revenueCatExpiry = revenueCatActive
        ? DateTime.tryParse(
            SubscriptionEntitlements.activePremium(customerInfo)
                    ?.expirationDate ??
                '',
          )
        : null;

    final server = await _loadServerEntitlement();
    if (isClosed || refreshId != _entitlementRefreshId) return;

    final active = revenueCatActive || server.isActive;
    final hasIndefiniteEntitlement =
        (revenueCatActive && revenueCatExpiry == null) ||
            (server.isActive && server.expiresAt == null);
    final expiry = hasIndefiniteEntitlement
        ? null
        : _laterOf(revenueCatExpiry, server.expiresAt);
    final source = _effectiveSource(
      active: active,
      revenueCatActive: revenueCatActive,
      serverSource: server.source,
    );

    emit(state.copyWith(
      isLoading: isLoading ?? false,
      status: active ? SubscriptionStatus.active : SubscriptionStatus.none,
      source: source,
      expiresAt: expiry,
      clearExpiresAt: expiry == null,
      successMessage: successMessage,
    ));
  }

  Future<_ServerPremiumEntitlement> _loadServerEntitlement() async {
    try {
      final response =
          await SupabaseService.client.rpc('get_my_premium_entitlement');
      final Map<String, dynamic>? row = switch (response) {
        final List<dynamic> rows when rows.isNotEmpty =>
          Map<String, dynamic>.from(rows.first as Map),
        final Map<dynamic, dynamic> value => Map<String, dynamic>.from(value),
        _ => null,
      };
      if (row == null) return const _ServerPremiumEntitlement();

      return _ServerPremiumEntitlement(
        isActive: row['is_active'] == true,
        source: PremiumEntitlementSource.fromServer(row['source']?.toString()),
        expiresAt: DateTime.tryParse(row['expires_at']?.toString() ?? ''),
      );
    } catch (e) {
      debugPrint('[SubscriptionCubit] Server entitlement error: $e');
      return const _ServerPremiumEntitlement();
    }
  }

  DateTime? _laterOf(DateTime? first, DateTime? second) {
    if (first == null) return second;
    if (second == null) return first;
    return first.isAfter(second) ? first : second;
  }

  PremiumEntitlementSource _effectiveSource({
    required bool active,
    required bool revenueCatActive,
    required PremiumEntitlementSource serverSource,
  }) {
    if (!active) return PremiumEntitlementSource.none;
    if (revenueCatActive && serverSource == PremiumEntitlementSource.referral) {
      return PremiumEntitlementSource.paidAndReferral;
    }
    if (revenueCatActive && serverSource == PremiumEntitlementSource.none) {
      return PremiumEntitlementSource.paid;
    }
    return serverSource;
  }

  @override
  Future<void> close() {
    _pricingSub?.cancel();
    return super.close();
  }
}

class _ServerPremiumEntitlement {
  const _ServerPremiumEntitlement({
    this.isActive = false,
    this.source = PremiumEntitlementSource.none,
    this.expiresAt,
  });

  final bool isActive;
  final PremiumEntitlementSource source;
  final DateTime? expiresAt;
}
