// lib/core/cubits/auth/auth_cubit.dart
// ============================================================
// MITHAQ - Auth Cubit
// Mock auth locally; production auth uses Supabase email OTP.
// ============================================================

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import '../../services/referral_service.dart';
import '../../services/email_address_validation.dart';
import '../../services/supabase_service.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  AuthCubit() : super(const AuthInitial());

  bool get _isRealMode => SupabaseService.isInitialized;

  String? _pendingEmail;
  String _pendingAuthMode = 'signin';

  Future<void> checkSession() async {
    emit(const AuthLoading());

    if (_isRealMode) {
      try {
        final session = SupabaseService.client.auth.currentSession;
        if (session != null) {
          final userId = session.user.id;
          final prefs = await SharedPreferences.getInstance();
          final countryCode = prefs.getString('user_country_code');
          final authData = await _loadUserProfile(userId);
          final onboardingStep = _returningUserStep(authData);

          emit(AuthAuthenticated(
            userId: userId,
            onboardingStep: onboardingStep,
            gender: authData.gender,
            email: session.user.email,
            countryCode: countryCode,
            isGuardianPath: authData.isGuardianPath,
            onboardingCompleted: authData.onboardingCompleted,
          ));
          return;
        }
      } catch (e) {
        debugPrint('Session check error: $e');
      }
      emit(const AuthUnauthenticated());
      return;
    }

    await Future.delayed(const Duration(milliseconds: 800));
    emit(const AuthUnauthenticated());
  }

  /// Sends an OTP to the provided email address.
  Future<void> sendOtp(
    String email, {
    String mode = 'signin',
    String? countryCode,
    bool isResend = false,
  }) async {
    final normalizedEmail = EmailAddressValidation.normalize(email);
    final emailError = EmailAddressValidation.validate(normalizedEmail);
    if (emailError != null) {
      emit(AuthError(message: _emailValidationMessage(emailError)));
      return;
    }

    emit(const AuthLoading());
    _pendingEmail = normalizedEmail;
    _pendingAuthMode = mode == 'signup' ? 'signup' : 'signin';

    if (_isRealMode) {
      try {
        final registered = await _isEmailRegistered(normalizedEmail);
        if (!isResend && _pendingAuthMode == 'signup' && registered) {
          emit(const AuthError(
            message: 'Account already exists. Please log in instead.',
          ));
          return;
        }
        if (!isResend && _pendingAuthMode == 'signin' && !registered) {
          emit(const AuthError(
            message: 'No account found. Please create an account first.',
          ));
          return;
        }

        await SupabaseService.client.auth.signInWithOtp(
          email: normalizedEmail,
          shouldCreateUser: _pendingAuthMode == 'signup',
        );
        emit(AuthOtpSent(email: normalizedEmail));
      } catch (e) {
        debugPrint('AuthCubit: send email OTP error: $e');
        emit(AuthError(message: _friendlyAuthError(e)));
      }
      return;
    }

    await Future.delayed(const Duration(milliseconds: 1200));
    emit(AuthOtpSent(email: normalizedEmail));
  }

  Future<void> resendOtp() async {
    final email = _pendingEmail;
    if (email == null || email.isEmpty) {
      emit(const AuthError(
        message:
            'Your verification code has expired. Please enter your email again.',
      ));
      return;
    }
    await sendOtp(email, mode: _pendingAuthMode, isResend: true);
  }

  /// Verifies the entered OTP code.
  Future<void> verifyOtp(String code, {String? deviceId}) async {
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      emit(const AuthError(
        message: 'Please enter the complete 6-digit verification code.',
      ));
      return;
    }

    emit(const AuthLoading());

    if (_isRealMode) {
      final email = _pendingEmail;
      if (email == null) {
        emit(const AuthError(
          message:
              'Your verification code has expired. Please request a new code.',
        ));
        return;
      }

      try {
        final response = await SupabaseService.client.auth.verifyOTP(
          email: email,
          token: code,
          type: OtpType.email,
        );

        final user = response.user ?? SupabaseService.client.auth.currentUser;
        if (user == null) {
          emit(const AuthError(message: 'Authentication failed. No user ID.'));
          return;
        }

        await _ensurePublicUser(user.id, email);
        await _applyPendingReferral();

        final prefs = await SharedPreferences.getInstance();
        final countryCode = prefs.getString('user_country_code');
        final authData = await _loadUserProfile(user.id);
        final onboardingStep = _pendingAuthMode == 'signup'
            ? authData.onboardingStep
            : _returningUserStep(authData);

        emit(AuthAuthenticated(
          userId: user.id,
          onboardingStep: onboardingStep,
          gender: authData.gender,
          email: email,
          countryCode: countryCode,
          isGuardianPath: authData.isGuardianPath,
          onboardingCompleted: authData.onboardingCompleted,
        ));
      } catch (e) {
        debugPrint('AuthCubit: verify email OTP error: $e');
        emit(AuthError(message: _friendlyAuthError(e)));
      }
      return;
    }

    if (!kDebugMode) {
      emit(
          const AuthError(message: 'Authentication failed. Please try again.'));
      return;
    }

    await Future.delayed(const Duration(milliseconds: 1000));
    final prefs = await SharedPreferences.getInstance();
    emit(AuthAuthenticated(
      userId: 'mock-user-id-001',
      onboardingStep: 0,
      gender: null,
      email: _pendingEmail,
      countryCode: prefs.getString('user_country_code'),
    ));
  }

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

  void updateOnboardingStep(
    int step, {
    String? gender,
    bool? isGuardianPath,
    bool? onboardingCompleted,
  }) {
    final current = state;
    if (current is AuthAuthenticated) {
      emit(AuthAuthenticated(
        userId: current.userId,
        onboardingStep: step,
        gender: gender ?? current.gender,
        email: current.email,
        countryCode: current.countryCode,
        isGuardianPath: isGuardianPath ?? current.isGuardianPath,
        onboardingCompleted: onboardingCompleted ?? current.onboardingCompleted,
      ));
    }
  }

  void setGender(String gender) {
    final current = state;
    if (current is AuthAuthenticated) {
      emit(AuthAuthenticated(
        userId: current.userId,
        onboardingStep: current.onboardingStep,
        gender: gender,
        email: current.email,
        countryCode: current.countryCode,
        isGuardianPath: current.isGuardianPath,
        onboardingCompleted: current.onboardingCompleted,
      ));
    }
  }

  Future<void> setCountryCode(String countryCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_country_code', countryCode);

    final current = state;
    if (current is AuthAuthenticated) {
      emit(AuthAuthenticated(
        userId: current.userId,
        onboardingStep: current.onboardingStep,
        gender: current.gender,
        email: current.email,
        countryCode: countryCode,
        isGuardianPath: current.isGuardianPath,
        onboardingCompleted: current.onboardingCompleted,
      ));
    }
  }

  Future<void> _ensurePublicUser(String userId, String email) async {
    final prefs = await SharedPreferences.getInstance();
    final countryCode = prefs.getString('user_country_code')?.toUpperCase();
    try {
      await SupabaseService.client.from('users').upsert({
        'id': userId,
        'email': email,
        if (countryCode != null && countryCode.isNotEmpty)
          'country_code': countryCode,
      }, onConflict: 'id');
    } catch (_) {
      await SupabaseService.client.auth.signOut();
      rethrow;
    }
  }

  Future<bool> _isEmailRegistered(String email) async {
    final registered = await SupabaseService.client.rpc<bool>(
      'email_is_registered',
      params: {'p_email': email},
    );
    return registered;
  }

  Future<void> _applyPendingReferral() async {
    final prefs = await SharedPreferences.getInstance();
    final pendingCode = prefs.getString('pending_referral_code');
    if (pendingCode == null || pendingCode.isEmpty) return;

    try {
      await ReferralService.instance.applyCode(pendingCode);
      await prefs.remove('pending_referral_code');
    } catch (e) {
      debugPrint('Failed to apply pending referral code: $e');
    }
  }

  String _emailValidationMessage(EmailAddressError error) {
    switch (error) {
      case EmailAddressError.missing:
        return 'Please enter your email address.';
      case EmailAddressError.invalid:
        return 'Please enter a valid email address.';
      case EmailAddressError.disposable:
        return EmailAddressValidation.temporaryEmailMessage;
    }
  }

  String _friendlyAuthError(Object? error, {String? code}) {
    final raw = error?.toString() ?? '';
    final upperCode = code?.toUpperCase();

    if (upperCode == 'EMAIL_ALREADY_REGISTERED' ||
        raw.contains('User already registered')) {
      return 'This email is already registered. Please sign in instead.';
    }
    final normalized = raw.toLowerCase();
    if (normalized.contains('invalid-verification-code') ||
        normalized.contains('token has expired or is invalid') ||
        normalized.contains('otp expired') ||
        normalized.contains('invalid otp') ||
        normalized.contains('token is expired') ||
        normalized.contains('email link is invalid')) {
      return 'This verification code is invalid or has expired. Please request a new code.';
    }
    if (raw.contains('Failed to exchange link for session') ||
        raw.contains('Only the token_hash and type should be provided')) {
      return 'Authentication failed while creating your session. Please try again.';
    }
    if (normalized.contains('too-many-requests') ||
        normalized.contains('too many attempts') ||
        normalized.contains('rate limit') ||
        normalized.contains('email rate limit exceeded')) {
      return 'Too many verification code requests. Please wait a moment and try again.';
    }
    if (normalized.contains('disposable') ||
        normalized.contains('temporary email')) {
      return EmailAddressValidation.temporaryEmailMessage;
    }

    if (raw.contains('No user found') ||
        raw.contains('User not found') ||
        raw.contains('Signups not allowed')) {
      return 'No account found. Please create an account first.';
    }

    return 'Authentication failed. Please try again.';
  }

  Future<_UserProfileData> _loadUserProfile(String userId) async {
    String? gender;
    int onboardingStep = 0;
    bool isGuardianPath = false;
    bool onboardingCompleted = false;
    bool hasUserRow = false;
    bool hasProfileRow = false;

    try {
      final userRow = await SupabaseService.client
          .from('users')
          .select('gender')
          .eq('id', userId)
          .maybeSingle();

      if (userRow != null) {
        hasUserRow = true;
        gender = userRow['gender'] as String?;
      }

      final profileRow = await SupabaseService.client
          .from('profiles')
          .select(
              'onboarding_step, guardian_mode, gender, onboarding_completed')
          .eq('user_id', userId)
          .maybeSingle();

      if (profileRow != null) {
        hasProfileRow = true;
        onboardingStep = (profileRow['onboarding_step'] as int?) ?? 0;
        final guardianMode = profileRow['guardian_mode'] as String?;
        isGuardianPath = guardianMode != null && guardianMode != 'none';
        gender ??= profileRow['gender'] as String?;
        onboardingCompleted =
            profileRow['onboarding_completed'] as bool? ?? false;
      }
    } catch (e) {
      debugPrint('AuthCubit: Error loading user profile: $e');
    }

    return _UserProfileData(
      gender: gender,
      onboardingStep: onboardingStep,
      isGuardianPath: isGuardianPath,
      hasUserRow: hasUserRow,
      hasProfileRow: hasProfileRow,
      onboardingCompleted: onboardingCompleted,
    );
  }

  int _returningUserStep(_UserProfileData authData) {
    return authData.onboardingStep;
  }
}

class _UserProfileData {
  const _UserProfileData({
    required this.gender,
    required this.onboardingStep,
    required this.isGuardianPath,
    required this.hasUserRow,
    required this.hasProfileRow,
    required this.onboardingCompleted,
  });

  final String? gender;
  final int onboardingStep;
  final bool isGuardianPath;
  final bool hasUserRow;
  final bool hasProfileRow;
  final bool onboardingCompleted;
}
