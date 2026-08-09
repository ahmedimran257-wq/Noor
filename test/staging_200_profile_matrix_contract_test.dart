import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String workflow;
  late String matrix;

  setUpAll(() {
    workflow = File(
      '.github/workflows/staging-200-profile-matrix.yml',
    ).readAsStringSync();
    matrix = File(
      'tool/staging_200_profile_matrix.mjs',
    ).readAsStringSync();
  });

  test('200-profile workflow is manual, staging-only and evidence-producing',
      () {
    expect(workflow, contains('workflow_dispatch'));
    expect(workflow, isNot(contains('schedule:')));
    expect(workflow, contains('environment: staging'));
    expect(workflow, contains('STAGING_SUPABASE_SERVICE_ROLE_KEY'));
    expect(workflow, contains('staging_conversation_lifecycle.mjs'));
    expect(workflow, contains('staging-200-profile-report.json'));
    expect(
      RegExp(r'uses:\s+\S+@[0-9a-f]{40}').allMatches(workflow).length,
      3,
    );
  });

  test('matrix creates exactly 100 men and 100 women then cleans everything',
      () {
    expect(matrix, contains('const PROFILE_COUNT = 200'));
    expect(matrix, contains('gender.male === 100'));
    expect(matrix, contains('gender.female === 100'));
    expect(matrix, contains('Refusing to create 200 test profiles in production'));
    expect(matrix, contains('KNOWN_PRODUCTION_REF'));
    expect(matrix, contains('finally'));
    expect(matrix, contains('/auth/v1/admin/users/'));
    expect(matrix, contains('/storage/v1/object/profile-photos'));
    expect(matrix, contains('report.cleanup.completed = true'));
  });

  test('matrix covers filters, quotas, media, relationships and notifications',
      () {
    for (final contract in <String>[
      'get_discovery_feed',
      'search_profiles_by_name_city',
      'premium_filter_required',
      'record_profile_view',
      'get_my_profile_viewers',
      'get_interest_quota',
      'interest_quota_exhausted',
      'send_interest',
      'withdraw_interest',
      'get_prior_match_context',
      'read_profile_photos',
      'interest_received',
      'profile_view',
      'every Premium preference is enforced by the database',
    ]) {
      expect(matrix, contains(contract), reason: 'Missing $contract coverage');
    }
  });

  test('every discovery preference sold as Premium is server-enforced', () {
    final migration = File(
      'supabase/migrations/201_enforce_all_premium_discovery_filters.sql',
    ).readAsStringSync();

    expect(migration, contains('assert_discovery_filter_entitlement'));
    expect(migration, contains("'verified_only'"));
    expect(migration, contains("'mother_tongue'"));
    expect(migration, contains("'community'"));
    expect(migration, contains("'living_expectation'"));
    expect(migration, contains("RAISE EXCEPTION 'premium_filter_required'"));
    expect(migration, contains('get_discovery_feed'));
    expect(
      migration,
      contains('FROM PUBLIC, anon, authenticated'),
    );
  });
}
