import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    'supabase/migrations/259_guardian_access_lifecycle_and_retire_translation.sql',
  ).readAsStringSync();
  final dashboard = File(
    'lib/features/home/screens/guardian_dashboard_screen.dart',
  ).readAsStringSync();
  final service = File(
    'lib/core/services/wali_mode_service.dart',
  ).readAsStringSync();
  final main = File('lib/main.dart').readAsStringSync();

  test('revocation invalidates cached Guardian content and controls', () {
    expect(migration, contains('guardian_access_state'));
    expect(migration, contains('guardian_access_invalidated'));
    expect(migration, contains('guardian_id = (SELECT auth.uid())'));
    expect(service, contains("table: 'guardian_access_state'"));
    expect(service, contains('Stream<void> get accessChanges'));
    expect(dashboard, contains('_messages.clear()'));
    expect(dashboard, contains('_composer.clear()'));
    expect(
        dashboard, contains('if (_accessVerified && _chat.canSendMessages)'));
    expect(dashboard, contains('if (_accessVerified)'));
    expect(dashboard, contains('_GuardianAccessBanner('));
  });

  test('Guardian accounts do not start member-only live domains', () {
    expect(main, contains('!state.isGuardianOnly'));
    expect(main, contains('identity.isGuardianOnly'));
    expect(dashboard, contains('_waliService.hasRealtimeChannel'));
    expect(dashboard, contains('_dashboardRefresh.stop()'));
  });

  test('Guardian-sent messages do not notify the same Guardian', () {
    expect(migration, contains('IF v_guardian_user_id = auth.uid()'));
    expect(
      migration,
      contains("'Open Silarah to review the conversation.'"),
    );
    expect(migration, isNot(contains('LEFT(NEW.content')));
  });
}
