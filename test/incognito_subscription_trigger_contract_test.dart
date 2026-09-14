import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    'supabase/migrations/256_fix_incognito_subscription_trigger_identity.sql',
  );

  test('subscription trigger uses users.id and grant user_id explicitly', () {
    expect(migration.existsSync(), isTrue);
    final sql = migration.readAsStringSync();

    expect(sql, contains("TG_TABLE_NAME = 'users'"));
    expect(sql, contains('v_user_id := NEW.id'));
    expect(sql, contains("WHEN TG_OP = 'DELETE' THEN OLD.user_id"));
    expect(sql, contains('ELSE NEW.user_id'));
    expect(sql, contains('private.sync_incognito_entitlement(v_user_id)'));
  });

  test('the broken unconditional OLD/NEW user_id expression is retired', () {
    final sql = migration.readAsStringSync();
    expect(
      sql,
      isNot(contains(
        "CASE WHEN TG_OP = 'DELETE' THEN OLD.user_id ELSE NEW.user_id END",
      )),
    );
  });
}
