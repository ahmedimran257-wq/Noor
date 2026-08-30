import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String migration;

  setUpAll(() {
    migration = File(
      'supabase/migrations/206_india_launch_and_photo_trust.sql',
    ).readAsStringSync();
  });

  test('India launch configuration is enforced by the server', () {
    expect(migration, contains("c.iso_code = 'IN'"));
    expect(migration, contains('get_launch_configuration'));
    expect(migration, contains('enforce_enabled_launch_country'));
    expect(migration, contains('trg_enforce_user_launch_country'));
    expect(migration, contains('trg_enforce_profile_launch_country'));
    expect(migration, contains("RAISE EXCEPTION 'launch_country_unavailable'"));
    expect(migration, contains('JOIN public.launch_countries market'));

    final picker =
        File('lib/core/widgets/country_picker_screen.dart').readAsStringSync();
    final quickLocation = File(
      'lib/features/onboarding/screens/quick_location_screen.dart',
    ).readAsStringSync();
    expect(picker, contains('LaunchConfigurationService.load()'));
    expect(picker, contains('_launch.enabledCountries'));
    expect(quickLocation, contains("country.iso2 == 'IN'"));
    expect(quickLocation, contains('launch.enabledCountries'));
  });

  test('photo badge can only be granted after private staff review', () {
    expect(migration, contains('photo_verification_submissions'));
    expect(migration, contains("auth.role() <> 'service_role'"));
    expect(
        migration,
        contains(
            'ALTER TABLE public.photo_verification_submissions ENABLE ROW LEVEL SECURITY'));
    expect(migration, contains('admin_review_photo_verification'));
    expect(migration, contains('photo_verification_checklist_incomplete'));
    expect(migration, contains('has_verification_badge = true'));
    expect(migration, contains('photo_verified_at = now()'));
    expect(
        migration,
        contains(
            'DROP FUNCTION IF EXISTS public.submit_my_photo_badge_verification'));
  });

  test('temporary captures have a hard 48-hour deletion lifecycle', () {
    expect(migration, contains("now() + interval '48 hours'"));
    expect(migration, contains("v_deadline - interval '10 minutes'"));
    expect(migration, contains('checkout_photo_verification_purges'));
    expect(migration, contains('finish_photo_verification_purge'));
    expect(migration, contains("'photo_verification_capture_purge'"));

    final worker = File(
      'supabase/functions/purge-photo-verification-captures/index.ts',
    ).readAsStringSync();
    expect(worker, contains('isAuthorizedCronRequest'));
    expect(
      worker,
      matches(RegExp(r'\.remove\(\s*paths,?\s*\)', multiLine: true)),
    );
    expect(worker, contains('finish_photo_verification_purge'));
  });

  test('guided check uses easy smile and blink with manual fallback', () {
    final screen = File(
      'lib/features/verification/screens/badge_verification_screen.dart',
    ).readAsStringSync();
    final service = File(
      'lib/core/services/photo_verification_service.dart',
    ).readAsStringSync();
    expect(screen, contains('Give a gentle smile'));
    expect(screen, contains('Blink once naturally'));
    expect(screen, contains('Capture this step'));
    expect(service, contains('manual_accessibility_v1'));
    expect(screen.toLowerCase(), isNot(contains('turn your head')));
    expect(screen.toLowerCase(), isNot(contains('face embedding')));
  });

  test('verification uploads cannot reuse the retired ID endpoint', () {
    final mediaEndpoint = File(
      'supabase/functions/get-signed-url/index.ts',
    ).readAsStringSync();
    expect(mediaEndpoint, isNot(contains('kyc_selfie')));
    expect(mediaEndpoint, isNot(contains('kyc_id')));
    expect(mediaEndpoint, isNot(contains('kyc-documents')));
    expect(File('supabase/functions/process-kyc/index.ts').existsSync(), false);
    expect(File('assets/models/mobilefacenet.tflite').existsSync(), false);
  });

  test('outgoing chat delegates the gender-aware Premium policy to server', () {
    final chat = File(
      'lib/features/home/screens/chat_screen.dart',
    ).readAsStringSync();
    final policy = File(
      'supabase/migrations/253_remove_phone_identity_and_email_guardian.sql',
    ).readAsStringSync();
    expect(chat, isNot(contains('PhoneVerificationService')));
    expect(chat, isNot(contains('showPhoneVerificationSheet')));
    expect(policy, contains("IF v_gender = 'female' THEN"));
    expect(policy, contains("RAISE EXCEPTION 'subscription_required'"));
    final triggerMigration = File(
      'supabase/migrations/208_gender_messaging_and_verified_phone_change.sql',
    ).readAsStringSync();
    expect(triggerMigration,
        contains('private.assert_outgoing_chat_entitlement(v_me)'));
  });

  test('trust filters are server-authoritative and premium gated', () {
    final filters = File(
      'lib/features/home/widgets/discovery_filter_sheet.dart',
    ).readAsStringSync();
    final filterBar = File(
      'lib/features/home/widgets/discovery_filter_bar.dart',
    ).readAsStringSync();
    final filterModel = File(
      'lib/core/cubits/discovery/discovery_filter.dart',
    ).readAsStringSync();
    expect(filters, contains('Photo verified'));
    expect(filters, isNot(contains('Phone verified')));
    expect(filters, isNot(contains('Photo + phone')));
    expect(filters, contains('Guardian connected'));
    expect(filters, contains('All India'));
    expect(filterBar, contains("label: 'Trust checks'"));
    expect(filterBar, contains("scrollToSection: 'verified'"));
    expect(filterBar, isNot(contains('Verified Only')));
    expect(filterModel, isNot(contains('verifiedOnly')));
    final retirement = File(
      'supabase/migrations/253_remove_phone_identity_and_email_guardian.sql',
    ).readAsStringSync();
    expect(retirement,
        contains("lower(trim(p_filters->>'trust_filter')) = 'photo'"));
    expect(retirement,
        contains("lower(trim(p_filters->>'trust_filter')) = 'guardian'"));
    expect(migration,
        contains("v_features := array_append(v_features, 'trust_filter')"));
  });

  test('profile trust row starts photo and Guardian checks directly', () {
    final profile = File(
      'lib/features/home/screens/my_profile_screen.dart',
    ).readAsStringSync();
    final settings = File(
      'lib/features/home/screens/settings_screen.dart',
    ).readAsStringSync();

    expect(profile, isNot(contains('showPhoneVerificationSheet(')));
    expect(profile, isNot(contains('onPhoneVerification')));
    expect(profile, contains('AppRoutes.badgeVerification'));
    expect(profile, contains("SettingsScreen(initialSection: 'guardian')"));
    expect(profile, contains('onGuardianConnection: _openGuardianSettings'));
    expect(settings, contains("case 'guardian':"));
    expect(settings, contains('key: _guardianKey'));
  });
}
