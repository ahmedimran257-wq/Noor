import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../legal/legal_documents.dart';
import 'supabase_service.dart';

class LegalConsentService {
  LegalConsentService._();

  static final instance = LegalConsentService._();

  static const _transactionIdKey = 'pending_signup_consent_transaction_id_v3';
  static const _transactionExpiresAtKey =
      'pending_signup_consent_transaction_expires_at_v3';
  static const _legacyPendingConsentKey =
      'pending_legal_onboarding_consents_v2';
  static const _transactionLifetime = Duration(minutes: 30);

  Future<bool> recordPendingOnboardingConsents() async {
    if (!SupabaseService.isInitialized) return false;

    try {
      final transactionId = await SupabaseService.client.rpc<String>(
        'begin_signup_consent_transaction',
        params: {
          'p_policy_version': LegalDocuments.version,
          'p_acceptances': const {
            'terms_of_service': true,
            'privacy_policy': true,
            'community_guidelines': true,
            'age_verification': true,
            'special_category_religious': true,
          },
        },
      );
      if (transactionId.isEmpty) return false;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_transactionIdKey, transactionId);
      await prefs.setInt(
        _transactionExpiresAtKey,
        DateTime.now().add(_transactionLifetime).millisecondsSinceEpoch,
      );
      await prefs.remove(_legacyPendingConsentKey);
      return true;
    } catch (e) {
      debugPrint(
        'LegalConsentService: consent transaction creation failed: $e',
      );
      return false;
    }
  }

  Future<bool> hasPendingOnboardingConsents() async {
    return await _validTransactionId() != null;
  }

  Future<bool> bindPendingTransactionToEmail(String email) async {
    final transactionId = await _validTransactionId();
    if (transactionId == null || !SupabaseService.isInitialized) return false;

    try {
      return await SupabaseService.client.rpc<bool>(
        'bind_signup_consent_transaction',
        params: {
          'p_transaction_id': transactionId,
          'p_email': email,
        },
      );
    } catch (e) {
      debugPrint('LegalConsentService: consent binding failed: $e');
      return false;
    }
  }

  Future<bool> flushPendingOnboardingConsents() async {
    if (!SupabaseService.isInitialized ||
        SupabaseService.currentUserId == null) {
      return false;
    }

    final transactionId = await _validTransactionId();
    if (transactionId == null) return false;

    try {
      await SupabaseService.client.rpc(
        'finalize_signup_consents',
        params: {'p_transaction_id': transactionId},
      );
      await clearPendingTransaction();
      return true;
    } catch (e) {
      debugPrint('LegalConsentService: consent finalization failed: $e');
      return false;
    }
  }

  Future<bool> requireAndFlushPendingOnboardingConsents() {
    return flushPendingOnboardingConsents();
  }

  Future<bool> finalizeSignupAndProvision() async {
    if (!SupabaseService.isInitialized ||
        SupabaseService.currentUserId == null) {
      return false;
    }
    final transactionId = await _validTransactionId();
    if (transactionId == null) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await SupabaseService.client.rpc<void>(
        'finalize_signup_and_provision_my_user',
        params: {
          'p_transaction_id': transactionId,
          'p_country_code': prefs.getString('user_country_code'),
        },
      );
      await clearPendingTransaction();
      return true;
    } catch (e) {
      debugPrint('LegalConsentService: atomic signup finalization failed: $e');
      return false;
    }
  }

  Future<void> clearPendingTransaction() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_transactionIdKey);
    await prefs.remove(_transactionExpiresAtKey);
    await prefs.remove(_legacyPendingConsentKey);
  }

  Future<String?> _validTransactionId() async {
    final prefs = await SharedPreferences.getInstance();
    final transactionId = prefs.getString(_transactionIdKey);
    final expiresAtMs = prefs.getInt(_transactionExpiresAtKey);
    if (transactionId == null ||
        transactionId.isEmpty ||
        expiresAtMs == null ||
        DateTime.now().millisecondsSinceEpoch >= expiresAtMs) {
      await clearPendingTransaction();
      return null;
    }
    return transactionId;
  }
}
