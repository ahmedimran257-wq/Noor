// lib/core/cubits/subscription/subscription_state.dart
// ============================================================
// NOOR — Subscription State
//
// Blueprint (Part 2 & Part 14):
//   • Gender-split: women always free, men must subscribe to message
//   • status: none | active | grace
//   • grace: 24h window on billing_issue (DB trigger enforces this too)
// ============================================================

import 'package:equatable/equatable.dart';

enum SubscriptionStatus { none, active, grace }

class SubscriptionState extends Equatable {
  final SubscriptionStatus status;
  final DateTime?          expiresAt;
  final bool               isLoading;
  final String?            error;
  final String?            successMessage;

  const SubscriptionState({
    this.status         = SubscriptionStatus.none,
    this.expiresAt      = null,
    this.isLoading      = false,
    this.error          = null,
    this.successMessage = null,
  });

  // ── Blueprint Part 14: assert_messaging_allowed logic ─────
  // Women always message free.
  // Men need active or grace (within 24h) to message.
  bool canMessage(String gender) {
    if (gender == 'female') return true;
    return status == SubscriptionStatus.active ||
           status == SubscriptionStatus.grace;
  }

  bool get isSubscribed =>
      status == SubscriptionStatus.active ||
      status == SubscriptionStatus.grace;

  SubscriptionState copyWith({
    SubscriptionStatus? status,
    DateTime?           expiresAt,
    bool?               isLoading,
    String?             error,
    String?             successMessage,
    bool                clearError   = false,
    bool                clearSuccess = false,
  }) {
    return SubscriptionState(
      status:         status         ?? this.status,
      expiresAt:      expiresAt      ?? this.expiresAt,
      isLoading:      isLoading      ?? this.isLoading,
      error:          clearError     ? null : (error   ?? this.error),
      successMessage: clearSuccess   ? null : (successMessage ?? this.successMessage),
    );
  }

  @override
  List<Object?> get props =>
      [status, expiresAt, isLoading, error, successMessage];
}
