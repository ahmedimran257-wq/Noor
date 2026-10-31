import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    'supabase/migrations/283_free_plan_limits_and_staff_alert_email.sql',
  ).readAsStringSync();
  final worker =
      File('supabase/functions/staff-alert-email/index.ts').readAsStringSync();
  final shell = File(
    'admin_android/app/src/main/java/com/silarah/admin/MainActivity.kt',
  ).readAsStringSync();

  test('limits alert at 70 and 85 percent from the 15-minute capture', () {
    expect(migration, contains("p_key || '_70'"));
    expect(migration, contains('v_percent >= 70'));
    expect(migration, contains("p_key || '_85'"));
    expect(migration, contains('v_percent >= 85'));
    expect(migration, contains("'freePlan'"));
  });

  test('staff are emailed once when an alert first fires', () {
    // The inbox repeats every 6 hours while an alert stays active; email
    // must not, or a limit holding at 72 % would mail staff four times a day.
    expect(migration,
        contains('v_newly_active := p_active AND (NOT FOUND OR NOT v_previous.is_active);'));
    expect(migration, contains('IF v_newly_active AND'));
    expect(migration, contains('FROM PUBLIC, anon, authenticated;'));
    expect(worker, contains('isAuthorizedCronRequest'));
  });

  test('push dispatcher is not reported unhealthy just for being idle', () {
    // It only runs when work is due, so a quiet 15 minutes is normal.
    expect(migration, contains('v_stale_due > 0'));
  });

  test('admin app stays on the admin host and hides staff screens', () {
    expect(shell, contains('private const val HOST = "admin.silarah.com"'));
    expect(shell, contains('uri.scheme == "https" && uri.host == HOST'));
    expect(shell, contains('FLAG_SECURE'));
    expect(shell, contains('MIXED_CONTENT_NEVER_ALLOW'));
    expect(shell, contains('allowFileAccess = false'));
  });
}
