import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final auditBoundary = File(
    'supabase/migrations/160_second_audit_privilege_boundary.sql',
  ).readAsStringSync();
  final repair = File(
    'supabase/migrations/173_canonicalize_notification_deep_links.sql',
  ).readAsStringSync();
  final accountActions = File(
    'supabase/migrations/120_silent_shadowban_and_admin_status.sql',
  ).readAsStringSync();

  test('notification queue canonicalizes every legacy admin destination', () {
    expect(
      repair,
      contains('CREATE OR REPLACE FUNCTION public.queue_notification('),
    );
    expect(repair, contains("'silarah://help-support'"));
    expect(repair, contains("'silarah://profile'"));
    expect(repair, contains("'silarah://discover'"));
    expect(repair, contains("'silarah://verify-identity'"));
    expect(repair, contains("'silarah://chat/'"));
    expect(repair, contains('Unsupported notification deep link'));

    expect(accountActions, contains("'/help-support'"));
    expect(accountActions, contains("'/home?tab=3'"));
  });

  test('repair preserves the audit allowlist and queue privilege boundary', () {
    expect(
      auditBoundary,
      contains("deep_link ~ '^silarah://[A-Za-z0-9/_?&=.%:-]+\$'"),
    );
    expect(
      repair,
      contains('FROM PUBLIC, anon, authenticated;'),
    );
    expect(
      repair,
      contains('TO service_role;'),
    );
    expect(
      repair,
      isNot(contains('DROP CONSTRAINT')),
    );
  });
}
