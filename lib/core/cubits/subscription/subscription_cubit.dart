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
  CustomerInfoUpdateListener? _customerInfoListener;
  Timer? _expiryTimer;
  Future<void>? _logoutInFlight;
  String? _loggedInUserId;

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

    final pendingLogout = _logoutInFlight;
    if (pendingLogout != null) await pendingLogout;
    _detachCustomerInfoListener();
    _expiryTimer?.cancel();
    _loggedInUserId = userId;

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
      final listenerUserId = userId;
      _customerInfoListener = (info) {
        if (isClosed || _loggedInUserId != listenerUserId) return;
        unawaited(_refreshEffectiveEntitlement(info));
      };
      Purchases.addCustomerInfoUpdateListener(_customerInfoListener!);
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
    _expiryTimer?.cancel();
    _detachCustomerInfoListener();
    _loggedInUserId = null;
    SubscriptionService.instance.clearUser();
    if (!isClosed) emit(const SubscriptionState());
  }

  Future<void> logoutUser() {
    clear();
    final operation = _performRevenueCatLogout();
    _logoutInFlight = operation;
    return operation.whenComplete(() {
      if (identical(_logoutInFlight, operation)) _logoutInFlight = null;
    });
  }

  Future<void> _performRevenueCatLogout() async {
    try {
      await Purchases.logOut();
    } catch (error) {
      // Logging out an already-anonymous RevenueCat identity is harmless.
      debugPrint('[SubscriptionCubit] RevenueCat logout skipped: $error');
    }
  }

  void _detachCustomerInfoListener() {
    final listener = _customerInfoListener;
    if (listener == null) return;
    Purchases.removeCustomerInfoUpdateListener(listener);
    _customerInfoListener = null;
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

    // A transient Supabase failure must not revoke an unexpired promotional
    // entitlement already proven by the server on this session.
    if (!server.isAvailable &&
        !revenueCatActive &&
        state.isSubscribed &&
        (state.expiresAt == null || state.expiresAt!.isAfter(DateTime.now()))) {
      emit(state.copyWith(isLoading: isLoading ?? false));
      _armExpiryRefresh(state.expiresAt);
      return;
    }

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
    _armExpiryRefresh(expiry);
  }

  void _armExpiryRefresh(DateTime? expiresAt) {
    _expiryTimer?.cancel();
    if (expiresAt == null || _loggedInUserId == null) return;
    final delay = expiresAt.difference(DateTime.now());
    _expiryTimer = Timer(
      delay.isNegative ? const Duration(milliseconds: 250) : delay,
      () {
        if (!isClosed && _loggedInUserId != null) {
          unawaited(refreshEntitlement());
        }
      },
    );
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
      if (row == null) {
        return const _ServerPremiumEntitlement(isAvailable: true);
      }

      return _ServerPremiumEntitlement(
        isAvailable: true,
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
    _expiryTimer?.cancel();
    _detachCustomerInfoListener();
    return super.close();
  }
}

class _ServerPremiumEntitlement {
  const _ServerPremiumEntitlement({
    this.isAvailable = false,
    this.isActive = false,
    this.source = PremiumEntitlementSource.none,
    this.expiresAt,
  });

  final bool isAvailable;
  final bool isActive;
  final PremiumEntitlementSource source;
  final DateTime? expiresAt;
}
