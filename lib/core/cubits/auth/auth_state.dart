// lib/core/cubits/auth/auth_state.dart
// ============================================================
// MITHAQ — Auth Cubit States
// Mock auth for local development. Real auth uses Supabase email OTP.
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
  const AuthOtpSent({required this.email});

  final String email;

  @override
  List<Object?> get props => [email];
}

/// Successfully authenticated. Holds userId for routing decisions.
class AuthAuthenticated extends AuthState {
  const AuthAuthenticated({
    required this.userId,
    required this.onboardingStep,
    this.gender,
    this.email,
    this.countryCode,
    this.isGuardianPath = false,
    this.onboardingCompleted = false,
  });

  final String userId;

  /// Fast-start onboarding uses steps 0-4. Completion is tracked by
  /// [onboardingCompleted], not inferred from this number.
  final int onboardingStep;

  /// 'male' | 'female' | null (unknown until onboarding sets it)
  final String? gender;

  /// Supabase email OTP auth identifier.
  final String? email;

  /// Country code for regional pricing (e.g., 'IN', 'US', 'AE')
  final String? countryCode;

  /// Whether the user is on the guardian onboarding path.
  /// Guardian and self paths now share the same five-step fast-start flow.
  final bool isGuardianPath;

  /// Persisted server-side. Do not infer completion from a numeric step.
  final bool onboardingCompleted;

  /// Completion is persisted server-side.
  bool get isOnboardingComplete => onboardingCompleted;

  @override
  List<Object?> get props => [
        userId,
        onboardingStep,
        gender,
        email,
        countryCode,
        isGuardianPath,
        onboardingCompleted
      ];
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
