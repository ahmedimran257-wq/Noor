import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../legal/legal_documents.dart';
import 'supabase_service.dart';

class LegalConsentService {
  LegalConsentService._();

  static final instance = LegalConsentService._();

  static const _pendingConsentKey = 'pending_legal_onboarding_consents_v2';

  Future<bool> recordPendingOnboardingConsents() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.setBool(_pendingConsentKey, true);
    } catch (e) {
      debugPrint('LegalConsentService: pending consent save failed: $e');
      return false;
    }
  }

  Future<bool> hasPendingOnboardingConsents() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_pendingConsentKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> flushPendingOnboardingConsents() async {
    if (!SupabaseService.isInitialized ||
        SupabaseService.currentUserId == null) {
      return false;
    }

    if (!await hasPendingOnboardingConsents()) return true;

    try {
      await SupabaseService.client.rpc(
        'record_onboarding_consents',
        params: {'p_policy_version': LegalDocuments.version},
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_pendingConsentKey);
      return true;
    } catch (e) {
      debugPrint('LegalConsentService: consent flush failed: $e');
      return false;
    }
  }

  Future<bool> requireAndFlushPendingOnboardingConsents() async {
    if (!await hasPendingOnboardingConsents()) return false;
    return flushPendingOnboardingConsents();
  }
}
