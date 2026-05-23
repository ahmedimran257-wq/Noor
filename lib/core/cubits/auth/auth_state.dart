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
    this.gender,
    this.countryCode,
    this.isGuardianPath = false,
  });

  final String  userId;
  /// 0–10: still in onboarding (myself shortest). ≥11: complete.
  /// Myself path: 11 steps (0–10), Guardian path: 12 steps (0–11).
  final int     onboardingStep;
  /// 'male' | 'female' | null (unknown until onboarding sets it)
  final String? gender;
  /// Country code for regional pricing (e.g., 'IN', 'US', 'AE')
  final String? countryCode;
  /// Whether the user is on the guardian onboarding path.
  /// Guardian path has 12 steps (0–11), myself path has 11 steps (0–10).
  final bool isGuardianPath;

  /// Completion threshold: guardians complete at step 12, myself at 11.
  bool get isOnboardingComplete => onboardingStep >= (isGuardianPath ? 12 : 11);

  @override
  List<Object?> get props => [userId, onboardingStep, gender, countryCode, isGuardianPath];
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
