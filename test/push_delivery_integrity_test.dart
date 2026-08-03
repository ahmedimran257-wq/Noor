import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:silarah/core/cubits/notification_prefs/notification_prefs_state.dart';
import 'package:silarah/core/utils/notification_deep_link.dart';

void main() {
  final migration = File(
    'supabase/migrations/186_relationship_and_push_delivery_integrity.sql',
  ).readAsStringSync();

  test('relationship lifecycle produces durable user notifications', () {
    expect(migration, contains("'interest_received'"));
    expect(migration, contains("'interest_accepted'"));
    expect(migration, contains("TG_OP = 'INSERT'"));
    expect(migration, contains("NEW.status = 'accepted'"));
    expect(migration, isNot(contains("NEW.status = 'withdrawn' THEN")));
  });

  test('notification worker recovers its hosted URL from Vault', () {
    expect(migration, contains("name = 'silarah_supabase_url'"));
    expect(migration, contains("name = 'silarah_edge_cron_secret'"));
    expect(migration, contains('trg_wake_notification_dispatch'));
    expect(migration, contains('dispatch_notifications_fallback_5m'));
    expect(
        migration, contains('SELECT private.invoke_notification_dispatch()'));
  });

  test('legacy notification routes are canonicalized before row repair', () {
    final canonicalization = migration.indexOf(
      "WHEN deep_link = '/help-support' THEN 'silarah://help-support'",
    );
    final statusRepair = migration.indexOf(
      "SET delivery_status = 'sent'",
    );
    expect(canonicalization, greaterThanOrEqualTo(0));
    expect(statusRepair, greaterThan(canonicalization));
  });

  test('FCM registration evicts stale devices instead of rejecting refresh',
      () {
    expect(migration,
        contains('CREATE OR REPLACE FUNCTION public.register_my_fcm_token'));
    expect(migration, contains('ranked.position > 5'));
    expect(
        migration, isNot(contains("RAISE EXCEPTION 'device_limit_reached'")));
  });

  test('profile-view preference and deep link are first-class', () {
    const defaults = NotificationPrefsState();
    expect(defaults.profileView, isTrue);
    expect(defaults.copyWith(profileView: false).profileView, isFalse);
    expect(
      notificationPathFromDeepLink('silarah://profile-views'),
      '/profile-views',
    );
  });
}
