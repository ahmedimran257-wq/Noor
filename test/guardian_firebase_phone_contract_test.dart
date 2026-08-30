import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final retirement = File(
    'supabase/migrations/253_remove_phone_identity_and_email_guardian.sql',
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
  final service = File(
    'lib/core/services/wali_mode_service.dart',
  ).readAsStringSync();
  final ownership = File(
    'supabase/migrations/227_separate_guardian_ownership_and_oversight.sql',
  ).readAsStringSync();
  final selfLinkDefense = File(
    'supabase/migrations/229_guardian_self_link_defense.sql',
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
    expect(guardianScreen, contains('Continue without Guardian'));
    expect(service, contains("'accept_my_guardian_invitation'"));
    expect(router, contains('guardianInvitationPending'));
    expect(router, contains('authState.isGuardianOnly'));
  });

  test('Guardian codes are hash-only, expiring, one-time and email-bound', () {
    expect(retirement, contains('private.guardian_invitation_hash'));
    expect(retirement, contains("private.guardian_invitation_hash(p_code)"));
    expect(retirement, contains("now() + interval '7 days'"));
    expect(retirement, contains('guardian_invitation_consumed_at = now()'));
    expect(retirement, contains('guardian_invitation_attempts + 1 >= 5'));
    expect(retirement, contains("now() + interval '24 hours'"));
    expect(retirement, contains('email_confirmed_at'));
    expect(
      retirement,
      contains(
        'lower(trim(v_profile.guardian_email)) IS DISTINCT FROM v_verified_email',
      ),
    );
    expect(settings, contains('Guardian email'));
    expect(settings, isNot(contains('Guardian phone')));
  });

  test('Guardian-managed ownership stays separate from connected oversight',
      () {
    expect(ownership, contains('guardian_user_id = user_id'));
    expect(ownership, contains('NEW.guardian_user_id := NULL'));
    expect(ownership, contains("p.profile_owner_type::text = 'guardian'"));
    expect(profileWriter, contains("'guardian_user_id': null"));
    expect(profileWriter, isNot(contains("guardian_user_id': _userId")));
    expect(selfLinkDefense, contains('WHERE guardian_user_id = user_id'));
  });

  test('public profiles disclose management without Guardian contacts', () {
    expect(profileCard, contains('Guardian-managed profile'));
    final trustStart = retirement.indexOf(
      'CREATE FUNCTION public.get_member_trust_summaries',
    );
    final trustEnd = retirement.indexOf(
      'REVOKE ALL ON FUNCTION public.get_member_trust_summaries',
    );
    expect(trustStart, greaterThanOrEqualTo(0));
    expect(trustEnd, greaterThan(trustStart));
    final projection = retirement.substring(trustStart, trustEnd);
    expect(projection, isNot(contains('guardian_email')));
    expect(projection, isNot(contains('guardian_phone')));
    expect(projection, isNot(contains('guardian_name')));
  });
}
