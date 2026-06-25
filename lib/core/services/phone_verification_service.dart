// lib/core/services/phone_verification_service.dart
// ============================================================
// MITHAQ - Phone verification for premium purchase trust checks.
// Not used during signup. Signup stays email OTP only.
// ============================================================

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import '../data/country_data.dart';
import 'supabase_service.dart';

class PhoneVerificationStatus {
  const PhoneVerificationStatus({
    required this.isVerified,
    this.phone,
    this.countryCode,
    this.verifiedAt,
  });

  final bool isVerified;
  final String? phone;
  final String? countryCode;
  final DateTime? verifiedAt;
}

class PhoneVerificationService {
  PhoneVerificationService._();
  static final instance = PhoneVerificationService._();

  Future<PhoneVerificationStatus> currentStatus() async {
    if (!SupabaseService.isInitialized ||
        SupabaseService.currentUserId == null) {
      return const PhoneVerificationStatus(isVerified: false);
    }

    try {
      final row = await SupabaseService.client
          .from('users')
          .select('phone, phone_country_code, phone_verified_at')
          .eq('id', SupabaseService.currentUserId!)
          .maybeSingle();

      final verifiedAtRaw = row?['phone_verified_at'] as String?;
      final phone = row?['phone'] as String?;
      return PhoneVerificationStatus(
        isVerified: phone != null &&
            phone.isNotEmpty &&
            verifiedAtRaw != null &&
            verifiedAtRaw.isNotEmpty,
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
  }) async {
    final phone = _fullPhone(country, nationalDigits);
    await SupabaseService.client.auth.updateUser(
      UserAttributes(phone: phone),
    );
  }

  Future<void> verifyCode({
    required CountryInfo country,
    required String nationalDigits,
    required String code,
  }) async {
    final phone = _fullPhone(country, nationalDigits);
    await SupabaseService.client.auth.verifyOTP(
      phone: phone,
      token: code,
      type: OtpType.phoneChange,
    );

    await SupabaseService.client.from('users').update({
      'phone': phone,
      'phone_country_code': country.iso2.toUpperCase(),
      'phone_verified_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', SupabaseService.currentUserId!);
  }

  String _fullPhone(CountryInfo country, String nationalDigits) {
    final digits = nationalDigits.replaceAll(RegExp(r'\D'), '');
    return '${country.dialCode}$digits';
  }
}
