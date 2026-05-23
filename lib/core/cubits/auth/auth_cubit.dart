// lib/core/cubits/auth/auth_cubit.dart
// ============================================================
// NOOR — Auth Cubit
// Supports both mock mode (no Supabase) and real Firebase+Supabase auth.
// Checks SupabaseService.isInitialized to determine which to use.
// ============================================================

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/supabase_service.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  AuthCubit() : super(const AuthInitial());

  /// Whether we're in real backend mode (Supabase configured)
  bool get _isRealMode => SupabaseService.isInitialized;

  // ── Session Check on App Start ────────────────────────────

  /// Called in main.dart / app router on startup.
  /// In production: checks Supabase for existing valid session.
  /// In mock: always returns unauthenticated so splash is shown.
  Future<void> checkSession() async {
    emit(const AuthLoading());

    if (_isRealMode) {
      // Real mode: check Supabase for existing session
      try {
        final session = SupabaseService.client.auth.currentSession;
        if (session != null) {
          // Load user profile data from our users table
          final userId = session.user.id;
          final prefs = await SharedPreferences.getInstance();
          final countryCode = prefs.getString('user_country_code');

          // TODO: Load actual gender and onboarding_step from Supabase
          emit(AuthAuthenticated(
            userId: userId,
            onboardingStep: 0, // TODO: Load from profiles table
            gender: null,       // TODO: Load from users table
            countryCode: countryCode,
          ));
          return;
        }
      } catch (e) {
        debugPrint('Session check error: $e');
      }
      emit(const AuthUnauthenticated());
    } else {
      // Mock mode: simulate session check delay
      await Future.delayed(const Duration(milliseconds: 800));
      emit(const AuthUnauthenticated());
    }
  }

  // ── OTP Flow ──────────────────────────────────────────────

  /// Simulates sending an OTP to the provided phone number.
  /// In real mode: calls Firebase Auth verifyPhoneNumber() on device,
  /// then exchanges the Firebase ID token via Edge Function.
  Future<void> sendOtp(String phone) async {
    if (phone.trim().length < 7) {
      emit(const AuthError(message: 'Please enter a valid phone number.'));
      return;
    }
    emit(const AuthLoading());

    if (_isRealMode) {
      // Real mode: Use Firebase Auth SDK to send OTP
      // TODO: Implement with firebase_auth package
      // For now, fall through to mock behavior
    }

    // Mock: simulate SMS send latency
    await Future.delayed(const Duration(milliseconds: 1200));
    emit(AuthOtpSent(phone: phone));
  }

  /// Verifies the entered OTP code.
  /// In real mode: receives Firebase ID token, exchanges via Edge Function.
  /// In mock mode: any 6-digit code is accepted.
  Future<void> verifyOtp(String code, {String? firebaseIdToken, String? deviceId}) async {
    if (code.length != 6) {
      emit(const AuthError(message: 'Please enter the complete 6-digit code.'));
      return;
    }
    emit(const AuthLoading());

    String? userId;
    String? countryCode;

    if (_isRealMode && firebaseIdToken != null) {
      // Real mode: exchange Firebase token for Supabase session
      try {
        final response = await SupabaseService.client.functions.invoke(
          'firebase-auth-exchange',
          body: {
            'firebase_id_token': firebaseIdToken,
            'device_id': deviceId ?? 'unknown',
          },
        );

        if (response.data != null) {
          final data = response.data as Map<String, dynamic>;
          if (data['status'] == 'authenticated') {
            userId = data['user_id'] as String?;
            // Store the access token for subsequent API calls
            // TODO: Set up Supabase auth session properly
          } else if (data['status'] == 'secondary_verification_required') {
            emit(AuthError(message: 'New device detected. Please verify your identity.'));
            return;
          }
        }
      } catch (e) {
        debugPrint('Auth exchange error: $e');
        emit(const AuthError(message: 'Authentication failed. Please try again.'));
        return;
      }
    } else {
      // Mock mode: simulate verification delay
      await Future.delayed(const Duration(milliseconds: 1000));
    }

    // Load country code from SharedPreferences for regional pricing
    final prefs = await SharedPreferences.getInstance();
    countryCode = prefs.getString('user_country_code');

    // Use mock user ID if not set (mock mode or failed real auth)
    userId ??= 'mock-user-id-001';

    emit(AuthAuthenticated(
      userId:          userId,
      onboardingStep:  0,
      gender:          'male', // TODO: Load from Supabase users table
      countryCode:     countryCode,
    ));
  }

  // ── Sign Out ──────────────────────────────────────────────

  Future<void> signOut() async {
    emit(const AuthLoading());

    if (_isRealMode) {
      try {
        await SupabaseService.client.auth.signOut();
      } catch (e) {
        debugPrint('Sign out error: $e');
      }
    } else {
      await Future.delayed(const Duration(milliseconds: 300));
    }

    emit(const AuthUnauthenticated());
  }

  // ── Update onboarding step locally (called by OnboardingCubit) ───

  /// Updates the cached onboarding step after each step is saved.
  /// Also propagates gender once the ProfileForWhom screen sets it.
  void updateOnboardingStep(int step, {String? gender, bool? isGuardianPath}) {
    final current = state;
    if (current is AuthAuthenticated) {
      emit(AuthAuthenticated(
        userId:         current.userId,
        onboardingStep: step,
        gender:         gender ?? current.gender,
        isGuardianPath: isGuardianPath ?? current.isGuardianPath,
      ));
    }
  }

  /// Called by ProfileForWhomScreen after gender is selected.
  /// Sets gender on AuthAuthenticated so all downstream widgets
  /// (subscription gate, profile card) read the correct value.
  void setGender(String gender) {
    final current = state;
    if (current is AuthAuthenticated) {
      emit(AuthAuthenticated(
        userId:         current.userId,
        onboardingStep: current.onboardingStep,
        gender:         gender,
        countryCode:    current.countryCode,
        isGuardianPath: current.isGuardianPath,
      ));
    }
  }

  /// Sets country code for regional pricing and persists to SharedPreferences.
  Future<void> setCountryCode(String countryCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_country_code', countryCode);

    final current = state;
    if (current is AuthAuthenticated) {
      emit(AuthAuthenticated(
        userId:         current.userId,
        onboardingStep: current.onboardingStep,
        gender:         current.gender,
        countryCode:    countryCode,
        isGuardianPath: current.isGuardianPath,
      ));
    }
  }
}
