import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:silarah/core/models/onboarding_data.dart';
import 'package:silarah/core/services/profile_write_service.dart';

void main() {
  test('Edit Profile never sends fields owned by dedicated secure RPCs', () {
    final fields = ProfileWriteService.buildEditProfileFieldsForTest(
      OnboardingData(
        profileFor: ProfileFor.guardian,
        profileOwnerType: ProfileOwnerType.guardian,
        profileCreatorRelation: 'daughter',
        wardRelationship: 'daughter',
        guardianMode: 'active',
        guardianName: 'Guardian',
        guardianRelationship: 'father',
        guardianEmail: 'guardian@example.test',
        guardianAuthorityScope: 'full',
        guardianPhoneCountryCode: '+91',
        photoPrivacy: PhotoPrivacy.requestOnly,
        firstName: 'Member',
        lastName: 'Profile',
        dateOfBirth: DateTime.utc(1995, 1, 1),
        gender: Gender.female,
        cityId: '1',
        countryCode: 'IN',
        profession: 'Engineer',
        bio: 'Ready for marriage',
        interests: const ['Reading'],
        preferredAgeMin: 25,
        preferredAgeMax: 35,
      ),
    );

    const dedicatedFields = <String>{
      'profile_owner_type',
      'profile_creator_relation',
      'ward_relationship',
      'guardian_mode',
      'guardian_user_id',
      'guardian_name',
      'guardian_relationship',
      'relationship_to_ward',
      'guardian_email',
      'guardian_authority_scope',
      'guardian_phone_country_code',
      'photo_privacy',
    };

    expect(fields.keys.toSet().intersection(dedicatedFields), isEmpty);
    expect(fields['first_name'], 'Member');
    expect(fields['profession'], 'Engineer');
    expect(fields['bio'], 'Ready for marriage');
  });

  test('Edit Profile sends every partner preference including false values',
      () {
    final fields = ProfileWriteService.buildEditPreferenceFieldsForTest(
      const OnboardingData(
        preferredAgeMin: 23,
        preferredAgeMax: 37,
        openToDivorced: true,
        openToWidowed: false,
        openToWithChildren: true,
        openToDiaspora: false,
      ),
    );

    expect(fields['preferred_age_min'], 23);
    expect(fields['preferred_age_max'], 37);
    expect(fields['open_to_divorced'], isTrue);
    expect(fields['open_to_widowed'], isFalse);
    expect(fields['open_to_has_children'], isTrue);
    expect(fields['open_to_diaspora'], isFalse);
  });

  test('private preferences reload through the owner-scoped RPC', () {
    final service = File(
      'lib/core/services/profile_write_service.dart',
    ).readAsStringSync();
    final migration = File(
      'supabase/migrations/248_owner_profile_preference_readback.sql',
    ).readAsStringSync();

    expect(service, contains("rpc('get_my_profile_preferences')"));
    expect(service, isNot(contains(".from('profile_preferences')")));
    expect(migration, contains('SECURITY DEFINER'));
    expect(migration, contains('private.assert_authenticated()'));
    expect(
      migration,
      contains('GRANT EXECUTE ON FUNCTION public.get_my_profile_preferences()'),
    );
    expect(
      migration,
      isNot(contains('GRANT SELECT ON public.profiles')),
      reason: 'The fix must not reopen the private profiles table.',
    );
  });

  test('server remains compatible with legacy Edit Profile payloads', () {
    final migration = File(
      'supabase/migrations/198_profile_edit_contract_compatibility.sql',
    ).readAsStringSync();

    expect(
      migration,
      contains('v_profile_fields := v_requested_profile_fields - ARRAY['),
    );
    expect(migration, contains("'guardian_mode'"));
    expect(migration, contains("'photo_privacy'"));
    expect(
      migration,
      contains('v_profile := public.patch_my_profile(v_profile_fields);'),
    );
    expect(
      migration,
      contains('private.assert_jsonb_keys('),
      reason: 'Preference fields must remain strictly allowlisted.',
    );
  });
}
