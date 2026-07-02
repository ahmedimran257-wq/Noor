// lib/core/cubits/auth/auth_cubit.dart
// ============================================================
// MITHAQ - Auth Cubit
// Production auth uses Supabase email OTP. No local sign-in path.
// ============================================================

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import '../../services/referral_service.dart';
import '../../services/email_address_validation.dart';
import '../../services/legal_consent_service.dart';
import '../../services/supabase_service.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  AuthCubit() : super(const AuthInitial());

  bool get _isRealMode => SupabaseService.isInitialized;

  static const _pendingOtpEmailKey = 'pending_otp_email';
  static const _pendingOtpModeKey = 'pending_otp_mode';
  static const _pendingOtpSentAtKey = 'pending_otp_sent_at';
  static const _pendingOtpMaxAge = Duration(minutes: 15);

  String? _pendingEmail;
  String _pendingAuthMode = 'signin';
  int _sendOtpRequestId = 0;
  int _verifyOtpRequestId = 0;

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

    emit(const AuthUnauthenticated());
  }

  /// Sends an OTP to the provided email address.
  Future<void> sendOtp(
    String email, {
    String mode = 'signin',
    String? countryCode,
    bool isResend = false,
  }) async {
    final requestId = ++_sendOtpRequestId;
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
        if (requestId != _sendOtpRequestId) return;

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
        if (requestId != _sendOtpRequestId) return;

        await _persistPendingOtp(normalizedEmail, _pendingAuthMode);
        emit(AuthOtpSent(email: normalizedEmail));
      } catch (e) {
        if (requestId != _sendOtpRequestId) return;
        debugPrint('AuthCubit: send email OTP error: $e');
        emit(AuthError(message: _friendlyAuthError(e)));
      }
      return;
    }

    emit(const AuthError(
      message: 'Authentication is not configured. Please try again later.',
    ));
  }

  Future<void> resendOtp() async {
    final email = await _pendingOtpEmail();
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
    final requestId = ++_verifyOtpRequestId;
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      emit(const AuthError(
        message: 'Please enter the complete 6-digit verification code.',
      ));
      return;
    }

    emit(const AuthLoading());

    if (_isRealMode) {
      final email = await _pendingOtpEmail();
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
        if (requestId != _verifyOtpRequestId) return;

        final user = response.user ?? SupabaseService.client.auth.currentUser;
        if (user == null) {
          emit(const AuthError(message: 'Authentication failed. No user ID.'));
          return;
        }

        await _ensurePublicUser(user.id, email);
        if (_pendingAuthMode == 'signup') {
          final consentSaved = await LegalConsentService.instance
              .requireAndFlushPendingOnboardingConsents();
          if (!consentSaved) {
            await SupabaseService.client.auth.signOut();
            throw StateError('required_legal_consent_save_failed');
          }
        }
        await _applyPendingReferral();

        final prefs = await SharedPreferences.getInstance();
        final countryCode = prefs.getString('user_country_code');
        final authData = await _loadUserProfile(user.id);
        if (requestId != _verifyOtpRequestId) return;

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
        await _clearPendingOtp();
      } catch (e) {
        if (requestId != _verifyOtpRequestId) return;
        debugPrint('AuthCubit: verify email OTP error: $e');
        emit(AuthError(message: _friendlyAuthError(e)));
      }
      return;
    }

    emit(const AuthError(
      message: 'Authentication is not configured. Please try again later.',
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
    }

    emit(const AuthUnauthenticated());
    await _clearPendingOtp();
  }

  void updateOnboardingStep(
    int step, {
    String? gender,
    bool? isGuardianPath,
    bool? onboardingCompleted,
    bool allowRegression = false,
  }) {
    final current = state;
    if (current is AuthAuthenticated) {
      // Race fix: forward onboarding updates are monotonic so a stale async
      // save cannot regress the authenticated routing state. Back navigation
      // opts in with allowRegression.
      final safeStep = allowRegression
          ? step
          : (step < current.onboardingStep ? current.onboardingStep : step);
      emit(AuthAuthenticated(
        userId: current.userId,
        onboardingStep: safeStep,
        gender: gender ?? current.gender,
        email: current.email,
        countryCode: current.countryCode,
        isGuardianPath: isGuardianPath ?? current.isGuardianPath,
        onboardingCompleted: onboardingCompleted ?? current.onboardingCompleted,
      ));
    }
  }

  Future<void> setGender(String gender) async {
    final normalizedGender = gender.trim().toLowerCase();
    if (normalizedGender != 'male' && normalizedGender != 'female') {
      throw ArgumentError.value(gender, 'gender', 'Expected male or female.');
    }

    final current = state;
    final userId = current is AuthAuthenticated
        ? current.userId
        : SupabaseService.currentUserId;

    if (_isRealMode) {
      if (userId == null) {
        throw StateError(
            'Cannot persist gender without an authenticated user.');
      }

      try {
        final prefs = await SharedPreferences.getInstance();
        final cachedCountryCode =
            prefs.getString('user_country_code')?.toUpperCase();
        final stateCountryCode = current is AuthAuthenticated
            ? current.countryCode?.toUpperCase()
            : null;
        final countryCode = cachedCountryCode ?? stateCountryCode;

        final existingUser = await SupabaseService.client
            .from('users')
            .select('gender, onboarding_completed')
            .eq('id', userId)
            .maybeSingle();
        final existingGender =
            (existingUser?['gender'] as String?)?.trim().toLowerCase();
        final userOnboardingCompleted =
            existingUser?['onboarding_completed'] as bool? ?? false;
        var profileOnboardingCompleted = false;
        try {
          final profileRow = await SupabaseService.client
              .from('profiles')
              .select('onboarding_completed')
              .eq('user_id', userId)
              .maybeSingle();
          profileOnboardingCompleted =
              profileRow?['onboarding_completed'] as bool? ?? false;
        } catch (e) {
          debugPrint('AuthCubit: profile gender lock check unavailable: $e');
        }
        final genderLocked =
            (current is AuthAuthenticated && current.onboardingCompleted) ||
                userOnboardingCompleted ||
                profileOnboardingCompleted;
        final contactFields = <String, dynamic>{
          if (current is AuthAuthenticated &&
              current.email != null &&
              current.email!.isNotEmpty)
            'email': current.email,
          if (countryCode != null && countryCode.isNotEmpty)
            'country_code': countryCode,
        };

        if (existingGender == normalizedGender) {
          // Idempotency fix: pressing Continue again must not trigger a locked
          // gender update. Keep contact/country metadata fresh without touching
          // the gender column.
          if (contactFields.isNotEmpty) {
            await SupabaseService.client
                .from('users')
                .update(contactFields)
                .eq('id', userId);
          }
        } else if (existingGender != null &&
            existingGender.isNotEmpty &&
            genderLocked) {
          throw StateError(
            'gender_change_locked: gender is already set for this account.',
          );
        } else {
          // Gender is the source of truth for Islamic discovery, subscriptions,
          // referrals, and the profiles.gender trigger. Unfinished onboarding
          // may correct an accidental tap; completed profiles stay locked by
          // the app guard and the database trigger.
          final writeFields = <String, dynamic>{
            ...contactFields,
            'gender': normalizedGender,
          };
          if (existingUser == null) {
            await SupabaseService.client.from('users').upsert({
              'id': userId,
              ...writeFields,
            }, onConflict: 'id');
          } else {
            await SupabaseService.client
                .from('users')
                .update(writeFields)
                .eq('id', userId);
          }
        }
      } catch (e) {
        debugPrint('AuthCubit: failed to persist gender: $e');
        rethrow;
      }
    }

    if (current is AuthAuthenticated) {
      emit(AuthAuthenticated(
        userId: current.userId,
        onboardingStep: current.onboardingStep,
        gender: normalizedGender,
        email: current.email,
        countryCode: current.countryCode,
        isGuardianPath: current.isGuardianPath,
        onboardingCompleted: current.onboardingCompleted,
      ));
    }
  }

  Future<bool> setCountryCode(String countryCode) async {
    final normalizedCountryCode = countryCode.trim().toUpperCase();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_country_code', normalizedCountryCode);

    final current = state;
    if (_isRealMode && current is AuthAuthenticated) {
      try {
        await SupabaseService.client.from('users').update(
            {'country_code': normalizedCountryCode}).eq('id', current.userId);
      } catch (e) {
        debugPrint('AuthCubit: failed to persist country code: $e');
        return false;
      }
    } else if (!_isRealMode) {
      return false;
    }

    if (current is AuthAuthenticated) {
      emit(AuthAuthenticated(
        userId: current.userId,
        onboardingStep: current.onboardingStep,
        gender: current.gender,
        email: current.email,
        countryCode: normalizedCountryCode,
        isGuardianPath: current.isGuardianPath,
        onboardingCompleted: current.onboardingCompleted,
      ));
    }
    return true;
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

  Future<void> _persistPendingOtp(String email, String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingOtpEmailKey, email);
    await prefs.setString(_pendingOtpModeKey, mode);
    await prefs.setInt(
      _pendingOtpSentAtKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<String?> _pendingOtpEmail() async {
    if (_pendingEmail != null && _pendingEmail!.isNotEmpty) {
      return _pendingEmail;
    }

    final prefs = await SharedPreferences.getInstance();
    final sentAtMs = prefs.getInt(_pendingOtpSentAtKey);
    if (sentAtMs == null) return null;

    final sentAt = DateTime.fromMillisecondsSinceEpoch(sentAtMs);
    if (DateTime.now().difference(sentAt) > _pendingOtpMaxAge) {
      await _clearPendingOtp();
      return null;
    }

    final email = prefs.getString(_pendingOtpEmailKey);
    final mode = prefs.getString(_pendingOtpModeKey);
    if (email == null || email.isEmpty) return null;

    _pendingEmail = email;
    _pendingAuthMode = mode == 'signup' ? 'signup' : 'signin';
    return email;
  }

  Future<void> _clearPendingOtp() async {
    _pendingEmail = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingOtpEmailKey);
    await prefs.remove(_pendingOtpModeKey);
    await prefs.remove(_pendingOtpSentAtKey);
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
        normalized.contains('invalid token') ||
        normalized.contains('invalid login credentials') ||
        normalized.contains('invalid_grant') ||
        normalized.contains('bad_code_verifier') ||
        normalized.contains('token is expired') ||
        normalized.contains('email link is invalid')) {
      return 'This verification code is invalid or has expired. Please request a new code.';
    }
    if (normalized.contains('error sending') ||
        normalized.contains('confirmation email') ||
        normalized.contains('magic link email') ||
        normalized.contains('gateway timeout')) {
      return 'We could not send the verification code. Please try again in a moment.';
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
    if (normalized.contains('required_legal_consent_save_failed')) {
      return 'Could not save. Please try again.';
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
      Map<String, dynamic>? userRow;
      try {
        userRow = await SupabaseService.client
            .from('users')
            .select(
                'gender, onboarding_step, is_guardian_path, profile_owner_type, onboarding_completed')
            .eq('id', userId)
            .maybeSingle();
      } catch (e) {
        // Older databases may not have the resume-marker columns yet. Fall back
        // to the original minimal user read so authentication still works.
        debugPrint('AuthCubit: user resume columns unavailable: $e');
        userRow = await SupabaseService.client
            .from('users')
            .select('gender')
            .eq('id', userId)
            .maybeSingle();
      }

      if (userRow != null) {
        hasUserRow = true;
        gender = userRow['gender'] as String?;
        onboardingStep = (userRow['onboarding_step'] as int?) ?? 0;
        isGuardianPath =
            (userRow['profile_owner_type'] as String?) == 'guardian' ||
                (userRow['is_guardian_path'] as bool? ?? false);
        onboardingCompleted = userRow['onboarding_completed'] as bool? ?? false;
      }

      final profileRow = await SupabaseService.client
          .from('profiles')
          .select(
              'onboarding_step, profile_owner_type, guardian_mode, gender, onboarding_completed')
          .eq('user_id', userId)
          .maybeSingle();

      if (profileRow != null) {
        hasProfileRow = true;
        onboardingStep =
            (profileRow['onboarding_step'] as int?) ?? onboardingStep;
        final guardianMode = profileRow['guardian_mode'] as String?;
        isGuardianPath =
            (profileRow['profile_owner_type'] as String?) == 'guardian' ||
                (guardianMode != null && guardianMode != 'none');
        gender ??= profileRow['gender'] as String?;
        onboardingCompleted =
            profileRow['onboarding_completed'] as bool? ?? onboardingCompleted;
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
