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
      ));
    }
  }

  Future<void> loginUser(String userId) async {
    if (!SupabaseService.isInitialized) return;

    emit(state.copyWith(isLoading: true));

    try {
      await Purchases.logIn(userId);
      final customerInfo = await Purchases.getCustomerInfo();
      final isActive = SubscriptionEntitlements.isPremiumActive(customerInfo);

      await SubscriptionService.instance.initialize(userId: userId);

      if (!isClosed) {
        final expiry = isActive
            ? DateTime.tryParse(
                SubscriptionEntitlements.activePremium(customerInfo)
                        ?.expirationDate ??
                    '',
              )
            : null;

        emit(state.copyWith(
          isLoading: false,
          status:
              isActive ? SubscriptionStatus.active : SubscriptionStatus.none,
          expiresAt: expiry,
        ));
      }

      Purchases.addCustomerInfoUpdateListener((info) {
        if (isClosed) return;
        final active = SubscriptionEntitlements.isPremiumActive(info);
        final expiry = active
            ? DateTime.tryParse(
                SubscriptionEntitlements.activePremium(info)?.expirationDate ??
                    '',
              )
            : null;

        emit(state.copyWith(
          status: active ? SubscriptionStatus.active : SubscriptionStatus.none,
          expiresAt: expiry,
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

  Future<void> purchase(String productId) async {
    emit(state.copyWith(isLoading: true, clearError: true));

    if (!SupabaseService.isInitialized) {
      emit(state.copyWith(
        isLoading: false,
        error: 'Subscriptions are not configured. Please try again later.',
      ));
      return;
    }

    try {
      final success = await SubscriptionService.instance.purchase(
        isAnnual: productId == annualProductId,
      );

      if (isClosed) return;

      if (success) {
        final info = await Purchases.getCustomerInfo();
        final expiry = DateTime.tryParse(
          SubscriptionEntitlements.activePremium(info)?.expirationDate ?? '',
        );

        emit(state.copyWith(
          isLoading: false,
          status: SubscriptionStatus.active,
          expiresAt: expiry,
          successMessage: 'JazakAllah khair - SILARAH Premium is now active!',
        ));
      } else {
        emit(state.copyWith(
          isLoading: false,
          error: 'Purchase could not be completed. Please try again.',
        ));
      }
    } catch (e) {
      debugPrint('[SubscriptionCubit] Purchase error: $e');
      if (!isClosed) {
        emit(state.copyWith(
          isLoading: false,
          error: 'Purchase failed. Please check your connection and try again.',
        ));
      }
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
        final expiry = DateTime.tryParse(
          SubscriptionEntitlements.activePremium(info)?.expirationDate ?? '',
        );

        emit(state.copyWith(
          isLoading: false,
          status: SubscriptionStatus.active,
          expiresAt: expiry,
          successMessage: 'Alhamdulillah! Your subscription has been restored.',
        ));
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

  @override
  Future<void> close() {
    _pricingSub?.cancel();
    return super.close();
  }
}
