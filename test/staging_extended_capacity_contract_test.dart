import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String scenario;
  late String runner;

  setUpAll(() {
    scenario = File('load-tests/staging_extended_paths.js').readAsStringSync();
    runner = File('tool/run_staging_extended_load_test.mjs').readAsStringSync();
  });

  test('extended capacity covers authorized chat and notification creation',
      () {
    expect(scenario, contains('chatAndNotificationStorm'));
    expect(scenario, contains('/rest/v1/rpc/send_chat_message'));
    expect(scenario, contains('/rest/v1/rpc/get_chat_messages_v2'));
    expect(scenario, contains('chat_message_success'));
    expect(scenario, contains('chat_read_success'));
    expect(runner, contains('verifyChat'));
    expect(runner, contains('silarah://chat/'));
    expect(runner, contains('Notification due-state verification'));
    expect(runner, contains('profile_view: true'));
  });

  test('chat fixtures are staging-only and cleaned after every outcome', () {
    for (final source in [scenario, runner]) {
      expect(source, contains('jukpscfxzwttgtxvrbmj'));
      expect(source, contains('I_UNDERSTAND_STAGING_EXTENDED_LOAD'));
    }
    expect(runner, contains('finally'));
    expect(runner, contains('for (const fixture of fixtures)'));
    expect(runner, contains('assertCleanup'));
  });

  test('chat capacity does not generate fake outbound FCM traffic', () {
    expect(
      runner,
      contains(
        'if (scenarioNames.includes("notifications") && !scenarioNames.includes("chat"))',
      ),
    );
    expect(runner, contains('CHAT_SPREAD_SECONDS'));
    expect(scenario, contains('chatSpreadSeconds'));
    expect(scenario, contains('(__VU * 15485863) % spreadMs'));
  });

  test('realtime capacity requires a common sustained authenticated hold', () {
    expect(scenario, contains('exec.scenario.startTime'));
    expect(scenario, contains('realtime_sustained_success'));
    expect(scenario, contains('realtime_held_connections'));
    expect(scenario, contains('gate.begin(Date.now())'));
    expect(scenario, contains('gate.sample(Date.now())'));
    expect(scenario, contains('gate.finish(Date.now(), intentionalClose)'));
    expect(runner, contains('distinctIdentities: sessions.length'));
  });

  test('account purge cannot recreate a revision for the deleted user', () {
    final migration = File(
      'supabase/migrations/257_safe_discovery_revision_on_account_purge.sql',
    ).readAsStringSync();
    expect(migration, contains('EXISTS ('));
    expect(migration, contains('FROM public.users existing_user'));
    expect(migration, contains('existing_user.id = p_user_id'));
  });
}
