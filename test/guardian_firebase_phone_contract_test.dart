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
  final ownershipMigration = File(
    'supabase/migrations/227_separate_guardian_ownership_and_oversight.sql',
  ).readAsStringSync();
  final runtimeRepair = File(
    'supabase/migrations/228_repair_phone_completion_and_guardian_acceptance.sql',
  ).readAsStringSync();
  final profileWriter = File(
    'lib/core/services/profile_write_service.dart',
  ).readAsStringSync();
  final profileCard = File(
    'lib/core/widgets/cards/silarah_profile_card.dart',
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
    expect(
      runtimeRepair,
      isNot(contains('updated_at = now()')),
      reason: 'Guardian acceptance must match the public.users schema.',
    );
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

  test('guardian-managed ownership is separate from connected oversight', () {
    expect(
      ownershipMigration,
      contains('guardian_user_id = user_id'),
      reason: 'Existing self-links must be repaired.',
    );
    expect(
      ownershipMigration,
      contains('NEW.guardian_user_id := NULL'),
      reason: 'Old clients cannot recreate a self-linked Guardian.',
    );
    expect(
      ownershipMigration,
      contains("p.profile_owner_type::text = 'guardian'"),
    );
    expect(
      ownershipMigration,
      contains('p.guardian_user_id <> p.user_id'),
    );
    expect(profileWriter, contains("'guardian_user_id': null"));
    expect(profileWriter, isNot(contains("guardian_user_id': _userId")));
  });

  test('public profiles disclose management without Guardian contact details',
      () {
    expect(
      ownershipMigration,
      contains("'guardian_managed', p.profile_owner_type::text = 'guardian'"),
    );
    expect(profileCard, contains('Guardian-managed profile'));
    final trustStart = ownershipMigration.indexOf(
      'CREATE FUNCTION public.get_member_trust_summaries',
    );
    final trustEnd = ownershipMigration.indexOf(
      'REVOKE ALL ON FUNCTION public.get_member_trust_summaries',
    );
    final trustProjection = ownershipMigration.substring(trustStart, trustEnd);
    expect(trustProjection, isNot(contains('guardian_email')));
    expect(trustProjection, isNot(contains('guardian_phone')));
    expect(trustProjection, isNot(contains('guardian_name')));
  });
}
