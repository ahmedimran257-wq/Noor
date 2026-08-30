import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String manager;
  late String migration;

  setUpAll(() {
    manager = File(
      'tool/manage_production_test_profiles.mjs',
    ).readAsStringSync();
    migration = File(
      'supabase/migrations/217_reversible_production_test_profiles.sql',
    ).readAsStringSync();
  });

  test('production fixtures require an explicit owner acknowledgement', () {
    expect(manager, contains('ALLOW_PRODUCTION_TEST_FIXTURES'));
    expect(manager, contains('confirmed-by-owner'));
    expect(manager, contains('KNOWN_PRODUCTION_REF'));
    expect(manager, contains('Production URL/project reference mismatch'));
    expect(manager, contains('MAX_PROFILE_COUNT = 500'));
  });

  test('default batch is exactly 250 women and 250 men', () {
    expect(manager, contains('DEFAULT_PROFILE_COUNT = 500'));
    expect(manager, contains('count % 2 === 0'));
    expect(manager, contains('index % 2 === 0 ? "male" : "female"'));
    expect(manager, contains('male: count / 2'));
    expect(manager, contains('female: count / 2'));
    expect(manager, contains('Gender split is not 50/50'));
  });

  test('fixtures are unmistakably synthetic and do not sign in', () {
    expect(manager, contains(r'`Test ${member.gender'));
    expect(manager, contains('"female" ? "Woman" : "Man"'));
    expect(manager, contains('This is not a real member'));
    expect(manager, contains('silarah_test_fixture: true'));
    expect(manager, contains('fakeAccountsSignedIn: 0'));
    expect(manager, isNot(contains('/auth/v1/token?grant_type=password')));
  });

  test('cleanup uses the protected registry instead of heuristics', () {
    expect(migration, contains('public.test_fixture_batches'));
    expect(migration, contains('public.test_fixture_members'));
    expect(migration, contains('REFERENCES auth.users(id) ON DELETE CASCADE'));
    expect(
        migration, contains('REVOKE ALL ON TABLE public.test_fixture_members'));
    expect(manager, contains('async function removeBatch'));
    expect(manager, contains(r'await deleteWhere("users", `id=${list}`)'));
    expect(manager, contains('/auth/v1/admin/users/'));
    expect(manager, contains('removedProfiles'));
    expect(manager, contains('fixture_city_ids'));
    expect(manager, contains('occupiedIds'));
    expect(manager, isNot(contains('email=like')));
  });

  test('fixture inventory cannot fan out discovery push notifications', () {
    expect(migration, contains('v_is_test_fixture'));
    expect(migration, contains("batch.status IN ('creating', 'active')"));
    expect(migration, contains('IF v_is_test_fixture THEN'));
    expect(migration, contains('private.enqueue_discovery_availability_event'));
    expect(manager, contains('notificationFanoutSuppressed: true'));
  });

  test('Premium filter dimensions and minimal storage are represented', () {
    for (final contract in <String>[
      'mother_tongue',
      'community',
      'living_expectation',
      'photo_verified_at',
      'guardian_user_id',
      'marriage_timeline',
      'willing_to_relocate',
      'quran_memorization',
      'previously_married',
      'children_count',
      'education_rank',
      'INDIA_TEST_CITY_CENTRES',
      'storageObjects: count',
      'contentType: "image/jpeg"',
      'Expected one unique storage path per test profile',
    ]) {
      expect(manager, contains(contract), reason: 'Missing $contract');
    }
    expect(manager, isNot(contains('phone_verified_at')));
  });

  test('fixture preferences merge with the profile bootstrap trigger', () {
    expect(manager, contains('onConflict: "profile_id"'));
    expect(manager, contains('mergeDuplicates: true'));
    expect(manager, contains('resolution=merge-duplicates'));
  });
}
