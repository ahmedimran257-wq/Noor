// lib/core/cubits/auth/auth_state.dart
// ============================================================
// NOOR — Auth Cubit States
// Mock auth for Step 4. Real Firebase OTP wired in Step 5.
// ============================================================

import 'package:equatable/equatable.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

/// App just launched — checking stored session.
class AuthInitial extends AuthState {
  const AuthInitial();
}

/// Any async auth operation in progress.
class AuthLoading extends AuthState {
  const AuthLoading();
}

/// OTP has been sent (mock: always succeeds immediately).
class AuthOtpSent extends AuthState {
  const AuthOtpSent({required this.phone});

  final String phone;

  @override
  List<Object?> get props => [phone];
}

/// Successfully authenticated. Holds userId for routing decisions.
class AuthAuthenticated extends AuthState {
  const AuthAuthenticated({
    required this.userId,
    required this.onboardingStep,
  });

  final String userId;
  /// 0–13: still in onboarding. 14: onboarding complete.
  final int onboardingStep;

  bool get isOnboardingComplete => onboardingStep >= 14;

  @override
  List<Object?> get props => [userId, onboardingStep];
}

/// Session check found no active session.
class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

/// Any auth error (invalid OTP, network, etc.)
class AuthError extends AuthState {
  const AuthError({required this.message});

  final String message;

  @override
  List<Object?> get props => [message];
}
