import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    'supabase/migrations/223_guardian_invitation_acceptance_and_firebase_phone.sql',
  ).readAsStringSync();
  final guardianScreen = File(
    'lib/features/home/screens/guardian_connect_screen.dart',
  ).readAsStringSync();
  final splash = File(
    'lib/features/onboarding/screens/splash_brand_screen.dart',
  ).readAsStringSync();
  final settings = File(
    'lib/features/home/screens/settings_screen.dart',
  ).readAsStringSync();
  final router = File('lib/core/router/app_router.dart').readAsStringSync();
  final verifier = File(
    'supabase/functions/verify-firebase-phone/index.ts',
  ).readAsStringSync();
  final phoneService = File(
    'lib/core/services/phone_verification_service.dart',
  ).readAsStringSync();

  test('Guardian acceptance has complete pre-auth and member entry paths', () {
    expect(splash, contains('AppRoutes.guardianConnect'));
    expect(settings, contains("'Accept a Guardian invitation'"));
    expect(guardianScreen, contains('rememberPendingInvitation(code)'));
    expect(guardianScreen, contains('AppRoutes.legal'));
    expect(guardianScreen, contains('mode=signin'));
    expect(guardianScreen, contains('acceptInvitation(code)'));
    expect(router, contains('guardianInvitationPending'));
    expect(router, contains('authState.isGuardianOnly'));
  });

  test('Guardian codes are one-time, hashed, expiring and phone-bound', () {
    expect(migration, contains('private.guardian_invitation_hash'));
    expect(migration,
        contains("extensions.digest(upper(trim(p_code)), 'sha256')"));
    expect(migration, contains("now() + interval '7 days'"));
    expect(migration, contains('guardian_invitation_consumed_at'));
    expect(migration, contains('guardian_invitation_locked_until'));
    expect(migration, contains('v_stored_phone IS DISTINCT FROM v_phone'));
    expect(migration, contains('guardian_user_id = v_guardian_id'));
  });

  test('Firebase SMS proof is validated server-side before phone trust', () {
    expect(phoneService,
        contains('firebase.FirebaseAuth.instance.verifyPhoneNumber'));
    expect(phoneService, contains('credential.user?.getIdToken(true)'));
    expect(phoneService, contains("'verify-firebase-phone'"));
    expect(phoneService, isNot(contains('OtpType.phoneChange')));
    expect(phoneService, isNot(contains('verifyOTP')));
    expect(verifier, contains('crypto.subtle.verify'));
    expect(verifier, contains('https://securetoken.google.com/'));
    expect(verifier, contains('sign_in_provider !== "phone"'));
    expect(verifier, contains('assert_guardian_invitation_phone'));
    expect(verifier, contains(r'/^\+91[6-9][0-9]{9}$/'));
  });

  test('Firebase identity is temporary and Supabase remains authoritative', () {
    expect(phoneService, contains('credential.user?.delete()'));
    expect(verifier, contains('.from("users")'));
    expect(verifier, contains('phone_verified_at'));
    expect(verifier, isNot(contains('auth.admin.updateUserById')));
  });
}
