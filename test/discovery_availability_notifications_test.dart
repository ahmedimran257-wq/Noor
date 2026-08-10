import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:silarah/core/cubits/notification_prefs/notification_prefs_state.dart';

void main() {
  String source(String path) => File(path).readAsStringSync();

  final migration = source(
    'supabase/migrations/205_compatible_discovery_notifications.sql',
  );

  test('zero-to-available alerts are exact, private, and bounded', () {
    expect(migration, contains('private.discovery_notification_state'));
    expect(migration, contains('state.inventory_empty = true'));
    expect(migration, contains('public.get_discovery_feed('));
    expect(migration, contains('remaining_recipient_budget'));
    expect(migration, contains('BETWEEN 0 AND 500'));
    expect(migration,
        contains("last_feed_opened_at >= now() - interval '30 days'"));
    expect(
        migration, contains("last_alerted_at < now() - interval '24 hours'"));
    expect(migration, contains("'silarah://discover'"));
    expect(
      migration,
      contains('New compatible profiles are available'),
    );
    expect(
      migration,
      isNot(contains('A new member in {city}')),
    );
  });

  test('availability work cannot bypass member or Premium boundaries', () {
    expect(
      migration,
      contains("auth.role() <> ''service_role'' AND auth.uid() IS DISTINCT"),
    );
    expect(
      migration,
      contains('private.assert_discovery_filter_entitlement(v_user_id'),
    );
    expect(
      migration,
      contains("IF auth.role() <> 'service_role' THEN"),
    );
    expect(
      migration,
      contains('TO authenticated, service_role'),
    );
    expect(
      migration,
      contains('FROM PUBLIC, anon, authenticated'),
    );
  });

  test('digests are opt-in, interval-limited, and prove new inventory', () {
    const defaults = NotificationPrefsState();
    expect(defaults.newCompatibleProfiles, isTrue);
    expect(
      defaults.discoveryDigestFrequency,
      DiscoveryDigestFrequency.off,
    );
    expect(migration, contains("DEFAULT 'off'"));
    expect(migration, contains("IN ('off', 'daily', 'weekly')"));
    expect(
        migration, contains('candidate.approved_at > v_state.last_digest_at'));
    expect(migration, contains("WHEN 'daily' THEN interval '1 day'"));
    expect(migration, contains("ELSE interval '7 days'"));
  });

  test('client records inventory without delaying a loaded feed', () {
    final cubit = source('lib/core/cubits/discovery/discovery_feed_cubit.dart');
    expect(cubit, contains("'record_discovery_inventory'"));
    expect(cubit, contains('unawaited(_recordDiscoveryInventory('));
    expect(cubit, contains('hasProfiles: batch.isNotEmpty'));
    expect(
      cubit.indexOf('emit(state.copyWith('),
      lessThan(cubit.indexOf('unawaited(_recordDiscoveryInventory(')),
    );
  });

  test('worker failure is isolated from critical push delivery', () {
    final worker = source(
      'supabase/functions/dispatch-notifications/index.ts',
    );
    final availability = worker.indexOf(
      'process_discovery_availability_notifications',
    );
    final checkout = worker.indexOf('checkout_notifications');
    expect(availability, greaterThanOrEqualTo(0));
    expect(checkout, greaterThan(availability));
    expect(worker, contains('Discovery availability batch failed'));
  });

  test('settings expose master alert and digest frequency controls', () {
    final settings = source('lib/features/home/screens/settings_screen.dart');
    final prefs = source(
      'lib/core/cubits/notification_prefs/notification_prefs_cubit.dart',
    );
    expect(settings, contains('settings_notify_compatibleProfiles'));
    expect(settings, contains('settings_notify_discoveryDigest'));
    expect(settings, contains('DiscoveryDigestFrequency.values'));
    expect(prefs, contains("'new_compatible_profiles'"));
    expect(prefs, contains("'discovery_digest_frequency'"));
  });
}
