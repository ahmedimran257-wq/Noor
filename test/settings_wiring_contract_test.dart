import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:silarah/core/cubits/notification_prefs/notification_prefs_state.dart';

void main() {
  String source(String path) => File(path).readAsStringSync();

  final migration = source(
    'supabase/migrations/220_settings_wiring_and_member_reminders.sql',
  );
  final healthMigration = source(
    'supabase/migrations/221_idle_notification_health_semantics.sql',
  );
  final timezoneMigration = source(
    'supabase/migrations/222_india_notification_timezone.sql',
  );

  test('weekly boost is enforced and has one idempotent reminder per cycle',
      () {
    expect(migration, contains('boost_last_activated_at'));
    expect(migration, contains("+ interval '7 days'"));
    expect(migration, contains('Your next weekly boost is available on'));
    expect(migration, contains('boost_ready_notified_at'));
    expect(migration, contains("'boost_ready'"));
    expect(migration, contains("coalesce(prefs.boost_available, true) = true"));
  });

  test('activity nudge is a bounded real producer, not a decorative switch',
      () {
    expect(migration, contains('private.process_member_reminders'));
    expect(
        migration, contains("p.last_active_at <= now() - interval '7 days'"));
    expect(migration, contains('last_inactive_nudge_at < p.last_active_at'));
    expect(migration, contains("'inactive_nudge'"));
    expect(migration, contains('FOR UPDATE OF u SKIP LOCKED'));
    expect(migration, contains("'process_member_reminders_daily'"));
  });

  test('guardian enable, update, and disable use one atomic backend call', () {
    final service = source('lib/core/services/wali_mode_service.dart');
    final settings = source('lib/features/home/screens/settings_screen.dart');
    final retirement = source(
      'supabase/migrations/253_remove_phone_identity_and_email_guardian.sql',
    );
    expect(retirement, contains('save_my_guardian_configuration'));
    expect(retirement, contains('PERFORM public.set_my_guardian_settings'));
    expect(retirement, contains("lower(trim(p_email))"));
    expect(service, contains("rpc('save_my_guardian_configuration'"));
    expect(service, isNot(contains("rpc('set_guardian_phone'")));
    expect(service, contains("'p_email': guardianEmail"));
    expect(settings, contains('if (_enabled || _serverEnabled)'));
    expect(settings, contains("'Disconnect guardian'"));
    expect(settings, contains('Guardian email'));
    expect(settings, isNot(contains('Guardian phone')));
    expect(settings, isNot(contains('value: _mirror')));
  });

  test('language selection synchronizes server notification language', () {
    final locale = source('lib/core/cubits/locale/locale_cubit.dart');
    final main = source('lib/main.dart');
    expect(locale, contains("'preferred_language': state.languageCode"));
    expect(locale, contains("fields['timezone'] = 'Asia/Kolkata'"));
    expect(locale, contains("rpc(\n        'patch_my_user'"));
    expect(main, contains('syncToServer(countryCode: state.countryCode)'));
    expect(timezoneMigration, contains("NEW.timezone := 'Asia/Kolkata'"));
    expect(timezoneMigration, contains("timezone = 'Asia/Kolkata'"));
  });

  test('notification preferences expose save failures and coherent digests',
      () {
    const defaults = NotificationPrefsState();
    final cubit = source(
      'lib/core/cubits/notification_prefs/notification_prefs_cubit.dart',
    );
    final settings = source('lib/features/home/screens/settings_screen.dart');
    expect(defaults.isLoaded, isFalse);
    expect(defaults.isSaving, isFalse);
    expect(cubit, contains('Notification settings were not saved'));
    expect(cubit, contains('_lastPersisted'));
    expect(cubit, contains('DiscoveryDigestFrequency.off'));
    expect(settings, contains('previous.syncEvent != current.syncEvent'));
  });

  test('service-only runtime audit covers every backend settings family', () {
    expect(migration, contains('public.audit_settings_wiring()'));
    expect(migration, contains("auth.role() <> 'service_role'"));
    for (final key in <String>[
      'notification_dispatch_healthy',
      'guardian_atomic_save',
      'photo_privacy_context',
      'photo_request_management',
      'profile_pause',
      'personal_data_export',
      'weekly_boost',
    ]) {
      expect(migration, contains("'$key'"));
    }
  });

  test('an idle event-driven notification worker is not a false outage', () {
    expect(healthMigration, contains('private.notification_dispatch_health'));
    expect(healthMigration, contains("THEN 'idle'"));
    expect(healthMigration, contains("IN ('healthy', 'idle')"));
    expect(healthMigration,
        contains('admin_dispatch_health_patch_anchor_not_found'));
  });
}
