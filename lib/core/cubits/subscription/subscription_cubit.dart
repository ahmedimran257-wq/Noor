// lib/core/cubits/subscription/subscription_cubit.dart
// ============================================================
// MITHAQ — Subscription Cubit (Real RevenueCat + Mock Fallback)
//
// When Supabase is configured (real mode):
//   • Purchases.logIn(userId) on auth
//   • Purchases.getOfferings() for live pricing
//   • Purchases.purchasePackage() for transactions
//   • Purchases.restorePurchases() for reinstalls
//   • Purchases.addCustomerInfoUpdateListener for real-time sync
//
// When Supabase is NOT configured (mock mode):
//   • Simulates delays for UI demo
// ============================================================

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../../services/supabase_service.dart';
import '../../services/subscription_service.dart';
import 'subscription_state.dart';

class SubscriptionCubit extends Cubit<SubscriptionState> {
  SubscriptionCubit() : super(const SubscriptionState());

  // Product IDs matching RevenueCat entitlement keys
  static const monthlyProductId = 'mithaq_monthly';
  static const annualProductId  = 'mithaq_annual';

  bool get _isRealMode => SupabaseService.isInitialized;

  StreamSubscription<DisplayPricing>? _pricingSub;

  // ── Initialization ────────────────────────────────────────

  /// Called on app start. In real mode, just sets loading state.
  /// Full RevenueCat login happens in loginUser().
  Future<void> initialize() async {
    emit(state.copyWith(isLoading: true));

    if (!_isRealMode) {
      // Mock mode: simulate SDK init
      await Future.delayed(const Duration(milliseconds: 600));
      if (!isClosed) {
        emit(state.copyWith(
          isLoading: false,
          status:    SubscriptionStatus.none,
        ));
      }
      return;
    }

    // Real mode: set up pricing stream listener
    _pricingSub = SubscriptionService.instance.pricingStream.listen((pricing) {
      if (!isClosed) {
        emit(state.copyWith(isLoading: false));
      }
    });

    if (!isClosed) {
      emit(state.copyWith(
        isLoading: false,
        status:    SubscriptionStatus.none,
      ));
    }
  }

  /// Called after real auth session is established.
  /// Logs in with RevenueCat and reads subscription status.
  Future<void> loginUser(String userId) async {
    if (!_isRealMode) return;

    emit(state.copyWith(isLoading: true));

    try {
      // Log in the user with RevenueCat
      await Purchases.logIn(userId);

      // Fetch customer info to check subscription status
      final customerInfo = await Purchases.getCustomerInfo();
      final isActive = customerInfo.entitlements.active.containsKey('premium');

      // Initialize SubscriptionService for pricing
      await SubscriptionService.instance.initialize(userId: userId);

      if (!isClosed) {
        final expiry = isActive
            ? DateTime.tryParse(
                customerInfo.entitlements.active['premium']?.expirationDate ?? '',
              )
            : null;

        emit(state.copyWith(
          isLoading: false,
          status: isActive ? SubscriptionStatus.active : SubscriptionStatus.none,
          expiresAt: expiry,
        ));
      }

      // Listen for subscription changes
      Purchases.addCustomerInfoUpdateListener((info) {
        if (isClosed) return;
        final active = info.entitlements.active.containsKey('premium');
        final exp = active
            ? DateTime.tryParse(
                info.entitlements.active['premium']?.expirationDate ?? '',
              )
            : null;

        emit(state.copyWith(
          status: active ? SubscriptionStatus.active : SubscriptionStatus.none,
          expiresAt: exp,
        ));
      });
    } catch (e) {
      debugPrint('[SubscriptionCubit] RevenueCat login error: $e');
      if (!isClosed) {
        emit(state.copyWith(
          isLoading: false,
          status: SubscriptionStatus.none,
        ));
      }
    }
  }

  // ── Purchase flow ─────────────────────────────────────────

  /// Initiates a purchase for the given plan.
  Future<void> purchase(String productId) async {
    emit(state.copyWith(isLoading: true, clearError: true));

    if (!_isRealMode) {
      // Mock: simulate RevenueCat purchase round-trip
      await Future.delayed(const Duration(milliseconds: 1500));
      if (isClosed) return;

      final expiry = DateTime.now().add(
        productId == annualProductId
            ? const Duration(days: 365)
            : const Duration(days: 30),
      );

      emit(state.copyWith(
        isLoading:      false,
        status:         SubscriptionStatus.active,
        expiresAt:      expiry,
        successMessage: 'JazakAllah khair — MITHAQ Premium is now active!',
      ));
      return;
    }

    // Real mode: purchase via RevenueCat
    try {
      final isAnnual = productId == annualProductId;
      final success = await SubscriptionService.instance.purchase(isAnnual: isAnnual);

      if (isClosed) return;

      if (success) {
        final info = await Purchases.getCustomerInfo();
        final expiry = DateTime.tryParse(
          info.entitlements.active['premium']?.expirationDate ?? '',
        );

        emit(state.copyWith(
          isLoading:      false,
          status:         SubscriptionStatus.active,
          expiresAt:      expiry,
          successMessage: 'JazakAllah khair — MITHAQ Premium is now active!',
        ));
      } else {
        emit(state.copyWith(
          isLoading: false,
          error:     'Purchase could not be completed. Please try again.',
        ));
      }
    } catch (e) {
      debugPrint('[SubscriptionCubit] Purchase error: $e');
      if (!isClosed) {
        emit(state.copyWith(
          isLoading: false,
          error:     'Purchase failed. Please check your connection and try again.',
        ));
      }
    }
  }

  /// Restores previous purchases.
  Future<void> restore() async {
    emit(state.copyWith(isLoading: true, clearError: true));

    if (!_isRealMode) {
      // Mock: nothing to restore
      await Future.delayed(const Duration(milliseconds: 1200));
      if (isClosed) return;
      emit(state.copyWith(
        isLoading: false,
        error:     'No previous purchases found for this account.',
      ));
      return;
    }

    // Real mode: restore via RevenueCat
    try {
      final success = await SubscriptionService.instance.restorePurchases();

      if (isClosed) return;

      if (success) {
        final info = await Purchases.getCustomerInfo();
        final expiry = DateTime.tryParse(
          info.entitlements.active['premium']?.expirationDate ?? '',
        );

        emit(state.copyWith(
          isLoading:      false,
          status:         SubscriptionStatus.active,
          expiresAt:      expiry,
          successMessage: 'Alhamdulillah! Your subscription has been restored.',
        ));
      } else {
        emit(state.copyWith(
          isLoading: false,
          error:     'No previous purchases found for this account.',
        ));
      }
    } catch (e) {
      debugPrint('[SubscriptionCubit] Restore error: $e');
      if (!isClosed) {
        emit(state.copyWith(
          isLoading: false,
          error:     'Restore failed. Please try again.',
        ));
      }
    }
  }

  // ── Simulation helpers (demo / dev only) ──────────────────

  /// Force an active subscription state (for UI testing).
  void debugActivate() {
    emit(state.copyWith(
      status:    SubscriptionStatus.active,
      expiresAt: DateTime.now().add(const Duration(days: 30)),
    ));
  }

  /// Reset to free tier (for UI testing).
  void debugDeactivate() {
    emit(state.copyWith(
      status:    SubscriptionStatus.none,
      expiresAt: null,
    ));
  }

  void clearMessages() {
    emit(state.copyWith(clearError: true, clearSuccess: true));
  }

  @override
  Future<void> close() {
    _pricingSub?.cancel();
    return super.close();
  }
}
