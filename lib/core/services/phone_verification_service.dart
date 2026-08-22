// SILARAH - Firebase phone ownership for Premium and Guardian trust checks.
// Matrimony signup and sign-in remain Supabase email OTP only.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase;
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import '../data/country_data.dart';
import 'supabase_service.dart';

class PhoneVerificationStatus {
  const PhoneVerificationStatus({
    required this.isVerified,
    this.isTrustBadgeActive = false,
    this.phone,
    this.countryCode,
    this.verifiedAt,
  });

  final bool isVerified;
  final bool isTrustBadgeActive;
  final String? phone;
  final String? countryCode;
  final DateTime? verifiedAt;
}

enum PhoneVerificationPurpose { premium, guardian }

class PhoneVerificationException implements Exception {
  const PhoneVerificationException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => code;
}

class PhoneVerificationService {
  PhoneVerificationService._();
  static final instance = PhoneVerificationService._();

  String? _verificationId;
  int? _resendToken;
  String? _challengePhone;

  Future<PhoneVerificationStatus> currentStatus() async {
    if (!SupabaseService.isInitialized ||
        SupabaseService.currentUserId == null) {
      return const PhoneVerificationStatus(isVerified: false);
    }

    try {
      final row = await SupabaseService.client
          .from('users')
          .select(
              'phone, phone_country_code, phone_verified_at, phone_trust_activated_at')
          .eq('id', SupabaseService.currentUserId!)
          .maybeSingle();

      final verifiedAtRaw = row?['phone_verified_at'] as String?;
      final phone = row?['phone'] as String?;
      return PhoneVerificationStatus(
        isVerified: phone != null &&
            phone.isNotEmpty &&
            verifiedAtRaw != null &&
            verifiedAtRaw.isNotEmpty,
        isTrustBadgeActive:
            (row?['phone_trust_activated_at'] as String?)?.isNotEmpty == true,
        phone: phone,
        countryCode: row?['phone_country_code'] as String?,
        verifiedAt:
            verifiedAtRaw != null ? DateTime.tryParse(verifiedAtRaw) : null,
      );
    } catch (e) {
      debugPrint('[PhoneVerificationService] status error: $e');
      return const PhoneVerificationStatus(isVerified: false);
    }
  }

  Future<void> sendCode({
    required CountryInfo country,
    required String nationalDigits,
    PhoneVerificationPurpose purpose = PhoneVerificationPurpose.premium,
    bool isChangingNumber = false,
    String? guardianInvitationCode,
  }) async {
    final phone = _fullPhone(country, nationalDigits);
    await _assertAllowed(
      country: country,
      phone: phone,
      purpose: purpose,
      isChangingNumber: isChangingNumber,
      guardianInvitationCode: guardianInvitationCode,
    );

    final sent = Completer<void>();
    _verificationId = null;
    _challengePhone = phone;

    try {
      await firebase.FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone,
        timeout: const Duration(seconds: 60),
        forceResendingToken: _resendToken,
        verificationCompleted: (_) {
          // Android may auto-detect the SMS. The explicit code remains the
          // confirmation boundary so the same UI works consistently on iOS.
        },
        verificationFailed: (error) {
          if (!sent.isCompleted) sent.completeError(_firebaseError(error));
        },
        codeSent: (verificationId, resendToken) {
          _verificationId = verificationId;
          _resendToken = resendToken;
          if (!sent.isCompleted) sent.complete();
        },
        codeAutoRetrievalTimeout: (verificationId) {
          _verificationId ??= verificationId;
          if (!sent.isCompleted) {
            sent.completeError(const PhoneVerificationException(
              'sms_timeout',
              'The SMS timed out. Please request a new code.',
            ));
          }
        },
      );
      await sent.future.timeout(const Duration(seconds: 70));
    } on PhoneVerificationException {
      rethrow;
    } on firebase.FirebaseAuthException catch (error) {
      throw _firebaseError(error);
    } catch (_) {
      throw const PhoneVerificationException(
        'sms_send_failed',
        'Could not send the SMS. Check your connection and try again.',
      );
    }
  }

  Future<void> verifyCode({
    required CountryInfo country,
    required String nationalDigits,
    required String code,
    PhoneVerificationPurpose purpose = PhoneVerificationPurpose.premium,
    String? guardianInvitationCode,
  }) async {
    final phone = _fullPhone(country, nationalDigits);
    final verificationId = _verificationId;
    if (verificationId == null || _challengePhone != phone) {
      throw const PhoneVerificationException(
        'sms_challenge_missing',
        'Request a new SMS code before verifying.',
      );
    }

    firebase.UserCredential credential;
    try {
      credential = await firebase.FirebaseAuth.instance.signInWithCredential(
        firebase.PhoneAuthProvider.credential(
          verificationId: verificationId,
          smsCode: code,
        ),
      );
    } on firebase.FirebaseAuthException catch (error) {
      throw _firebaseError(error);
    }

    try {
      final idToken = await credential.user?.getIdToken(true);
      if (idToken == null || idToken.isEmpty) {
        throw const PhoneVerificationException(
          'phone_token_missing',
          'Phone verification could not be completed. Try again.',
        );
      }
      final result = await SupabaseService.client.functions.invoke(
        'verify-firebase-phone',
        body: {
          'firebase_id_token': idToken,
          'country_code': country.iso2,
          'purpose': purpose.name,
          if (purpose == PhoneVerificationPurpose.guardian)
            'invitation_code': guardianInvitationCode?.trim().toUpperCase(),
        },
      );
      if (result.status < 200 || result.status >= 300) {
        throw _edgeError(result.data);
      }
      // Firebase is only the SMS proof provider, not a second Silarah account
      // store. Remove the short-lived Firebase user after Supabase records the
      // signed phone proof. Failure to clean up must not undo verification.
      try {
        await credential.user?.delete();
      } catch (error) {
        debugPrint('[PhoneVerificationService] Firebase cleanup error: $error');
      }
      _verificationId = null;
      _challengePhone = null;
    } on PhoneVerificationException {
      rethrow;
    } on FunctionException catch (error) {
      throw _edgeError(error.details);
    } finally {
      await firebase.FirebaseAuth.instance.signOut();
    }
  }

  Future<void> _assertAllowed({
    required CountryInfo country,
    required String phone,
    required PhoneVerificationPurpose purpose,
    required bool isChangingNumber,
    String? guardianInvitationCode,
  }) async {
    if (purpose == PhoneVerificationPurpose.guardian) {
      final code = guardianInvitationCode?.trim().toUpperCase() ?? '';
      try {
        final allowed = await SupabaseService.client.rpc(
          'check_guardian_invitation_phone',
          params: {'p_code': code, 'p_phone': phone},
        );
        if (allowed != true) {
          throw const PhoneVerificationException(
            'guardian_invitation_unavailable',
            'The invitation code or phone number does not match, or the invitation has expired.',
          );
        }
        return;
      } on PhoneVerificationException {
        rethrow;
      } catch (_) {
        throw const PhoneVerificationException(
          'guardian_invitation_unavailable',
          'The invitation code or phone number does not match, or the invitation has expired.',
        );
      }
    }

    try {
      await SupabaseService.client.rpc(
        'begin_my_paid_phone_verification',
        params: {
          'p_country_code': country.iso2,
          'p_is_change': isChangingNumber,
        },
      );
    } catch (error) {
      final normalized = error.toString().toLowerCase();
      if (normalized.contains('phone_verification_rate_limited')) {
        throw const PhoneVerificationException(
          'sms_rate_limited',
          'Too many SMS attempts. Please try again tomorrow.',
        );
      }
      if (normalized.contains('paid_subscription_required')) {
        throw const PhoneVerificationException(
          'paid_subscription_required',
          'A paid Premium subscription is required to change this number.',
        );
      }
      if (normalized.contains('completed_account_required')) {
        throw const PhoneVerificationException(
          'completed_account_required',
          'Complete your profile before verifying a phone number.',
        );
      }
      rethrow;
    }
  }

  String _fullPhone(CountryInfo country, String nationalDigits) {
    final digits = nationalDigits.replaceAll(RegExp(r'\D'), '');
    return '${country.dialCode}$digits';
  }

  PhoneVerificationException _firebaseError(
    firebase.FirebaseAuthException error,
  ) {
    switch (error.code) {
      case 'invalid-phone-number':
        return const PhoneVerificationException(
          'invalid_phone_number',
          'Enter a valid 10-digit India mobile number.',
        );
      case 'invalid-verification-code':
      case 'session-expired':
        return const PhoneVerificationException(
          'invalid_sms_code',
          'This SMS code is invalid or expired. Request a new code.',
        );
      case 'too-many-requests':
      case 'quota-exceeded':
        return const PhoneVerificationException(
          'sms_rate_limited',
          'Too many SMS attempts. Please wait before trying again.',
        );
      case 'operation-not-allowed':
        return const PhoneVerificationException(
          'sms_provider_disabled',
          'Phone verification is temporarily unavailable. Please contact support.',
        );
      case 'network-request-failed':
        return const PhoneVerificationException(
          'network_unavailable',
          'No internet connection. Reconnect and try again.',
        );
      default:
        debugPrint(
          '[PhoneVerificationService] Firebase phone error: ${error.code}',
        );
        return const PhoneVerificationException(
          'sms_verification_failed',
          'Phone verification could not be completed. Please try again.',
        );
    }
  }

  PhoneVerificationException _edgeError(Object? details) {
    final text = details?.toString().toLowerCase() ?? '';
    if (text.contains('phone_already_in_use')) {
      return const PhoneVerificationException(
        'phone_already_in_use',
        'This phone number is already verified on another account.',
      );
    }
    if (text.contains('phone_verification_intent_required')) {
      return const PhoneVerificationException(
        'phone_verification_intent_required',
        'This verification request expired. Request a new SMS code.',
      );
    }
    if (text.contains('guardian_invitation_unavailable')) {
      return const PhoneVerificationException(
        'guardian_invitation_unavailable',
        'The Guardian invitation is invalid or has expired.',
      );
    }
    return const PhoneVerificationException(
      'phone_save_failed',
      'The verified phone could not be saved. Please try again.',
    );
  }
}
