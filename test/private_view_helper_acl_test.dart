import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    'supabase/migrations/246_restore_authenticated_private_view_helpers.sql',
  ).readAsStringSync();

  test('private view helpers remain unavailable to public and anonymous roles',
      () {
    expect(migration, contains('FROM PUBLIC, anon'));
    expect(migration, isNot(contains('TO anon')));
  });

  test('authenticated callers can evaluate the two private-backed views', () {
    expect(
      migration,
      contains('api_private.get_my_profile_private_rows()'),
    );
    expect(
      migration,
      contains('api_private.get_my_guardian_ward_rows()'),
    );
    expect(migration.split('TO authenticated;').length - 1, 2);
  });
}
