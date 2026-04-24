// lib/core/cubits/subscription/subscription_cubit.dart
// ============================================================
// NOOR — Subscription Cubit (Step 9 — Mock RevenueCat)
//
// Blueprint (Part 8):
//   class SubscriptionService {
//     static const _monthlyId = 'noor_monthly';
//     static const _annualId  = 'noor_annual';
//     Future<void> initialize() async { ... }
//     Future<List<Package>> getOfferings() async { ... }
//     Future<bool> purchase(Package package) async { ... }
//     Stream<CustomerInfo> get customerInfoStream => ...
//   }
//
// This cubit wraps the above interface.
// In Step 12, replace the mock delays with real RevenueCat SDK calls:
//   - Purchases.configure(PurchasesConfiguration(apiKey))
//   - Purchases.logIn(supabaseUserId)
//   - Purchases.getOfferings()
//   - Purchases.purchasePackage(package)
//   - Purchases.customerInfoStream (replace _initMockStatus)
// ============================================================

import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'subscription_state.dart';

class SubscriptionCubit extends Cubit<SubscriptionState> {
  SubscriptionCubit() : super(const SubscriptionState());

  // Product IDs matching RevenueCat entitlement keys
  static const monthlyProductId = 'noor_monthly';
  static const annualProductId  = 'noor_annual';

  // ── Initialization ────────────────────────────────────────

  /// Called on app start.
  /// Step 12: replace with Purchases.configure() + Purchases.logIn(userId)
  Future<void> initialize() async {
    emit(state.copyWith(isLoading: true));
    // Simulate SDK init
    await Future.delayed(const Duration(milliseconds: 600));
    // Mock: start with no subscription
    if (!isClosed) {
      emit(state.copyWith(
        isLoading: false,
        status:    SubscriptionStatus.none,
      ));
    }
  }

  /// Called after real auth session is established.
  /// Step 12: Purchases.logIn(supabaseUserId) then read customerInfo.
  Future<void> loginUser(String userId) async {
    // No-op in mock — real RC login happens here
  }

  // ── Purchase flow ─────────────────────────────────────────

  /// Initiates a mock purchase for the given plan.
  /// Step 12: replace with Purchases.purchasePackage(package)
  Future<void> purchase(String productId) async {
    emit(state.copyWith(isLoading: true, clearError: true));

    // Simulate RevenueCat purchase round-trip
    await Future.delayed(const Duration(milliseconds: 1500));

    if (isClosed) return;

    // Mock: purchase always succeeds
    final expiry = DateTime.now().add(
      productId == annualProductId
          ? const Duration(days: 365)
          : const Duration(days: 30),
    );

    emit(state.copyWith(
      isLoading:      false,
      status:         SubscriptionStatus.active,
      expiresAt:      expiry,
      successMessage: 'JazakAllah khair — NOOR Premium is now active!',
    ));
  }

  /// Restores previous purchases.
  /// Step 12: Purchases.restorePurchases() — checks entitlements.active
  Future<void> restore() async {
    emit(state.copyWith(isLoading: true, clearError: true));
    await Future.delayed(const Duration(milliseconds: 1200));

    if (isClosed) return;

    // Mock: nothing to restore
    emit(state.copyWith(
      isLoading: false,
      error:     'No previous purchases found for this account.',
    ));
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
}
