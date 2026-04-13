// lib/core/cubits/auth/auth_cubit.dart
// ============================================================
// NOOR — Auth Cubit (Mock Implementation)
// Step 4: mock OTP. Step 5: replaced with Firebase + Supabase.
//
// Mock rules:
//   sendOtp(phone)      → always emits AuthOtpSent after 1s delay
//   verifyOtp(code)     → any 6-digit code → AuthAuthenticated
//   checkSession()      → always emits AuthUnauthenticated (fresh start)
// ============================================================

import 'package:flutter_bloc/flutter_bloc.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  AuthCubit() : super(const AuthInitial());

  // ── Session Check on App Start ────────────────────────────

  /// Called in main.dart / app router on startup.
  /// In production: checks Supabase for existing valid session.
  /// In mock: always returns unauthenticated so splash is shown.
  Future<void> checkSession() async {
    emit(const AuthLoading());
    // Simulate a brief session check delay
    await Future.delayed(const Duration(milliseconds: 800));
    // Mock: no stored session
    emit(const AuthUnauthenticated());
  }

  // ── OTP Flow ──────────────────────────────────────────────

  /// Simulates sending an OTP to the provided phone number.
  /// Production: calls Firebase Auth verifyPhoneNumber().
  Future<void> sendOtp(String phone) async {
    if (phone.trim().length < 7) {
      emit(const AuthError(message: 'Please enter a valid phone number.'));
      return;
    }
    emit(const AuthLoading());
    // Mock: simulate SMS send latency
    await Future.delayed(const Duration(milliseconds: 1200));
    emit(AuthOtpSent(phone: phone));
  }

  /// Verifies the entered OTP code.
  /// Mock: any 6-digit code is accepted.
  /// Production: calls firebase.PhoneAuthCredential → Supabase exchange.
  Future<void> verifyOtp(String code) async {
    if (code.length != 6) {
      emit(const AuthError(message: 'Please enter the complete 6-digit code.'));
      return;
    }
    emit(const AuthLoading());
    await Future.delayed(const Duration(milliseconds: 1000));

    // Mock: always succeeds, starts at onboarding step 0
    emit(const AuthAuthenticated(
      userId:          'mock-user-id-001',
      onboardingStep:  0,
    ));
  }

  // ── Sign Out ──────────────────────────────────────────────

  Future<void> signOut() async {
    emit(const AuthLoading());
    await Future.delayed(const Duration(milliseconds: 300));
    emit(const AuthUnauthenticated());
  }

  // ── Update onboarding step locally (called by OnboardingCubit) ───

  /// Updates the cached onboarding step after each step is saved.
  void updateOnboardingStep(int step) {
    final current = state;
    if (current is AuthAuthenticated) {
      emit(AuthAuthenticated(
        userId:         current.userId,
        onboardingStep: step,
      ));
    }
  }
}
