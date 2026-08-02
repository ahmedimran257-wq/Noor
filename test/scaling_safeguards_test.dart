import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('distributed scale safeguards', () {
    test('rate limits are atomic, private, and shared by edge functions', () {
      final migration = File(
        'supabase/migrations/139_distributed_limits_and_free_monitoring.sql',
      ).readAsStringSync();
      final signedUrls = File(
        'supabase/functions/get-signed-url/index.ts',
      ).readAsStringSync();

      expect(migration, contains('consume_edge_rate_limit'));
      expect(migration, contains('ON CONFLICT'));
      expect(migration, contains('TO service_role'));
      expect(signedUrls, contains('consumeDistributedRateLimit'));
      expect(signedUrls, isNot(contains('rateLimitMap')));
    });

    test('free monitoring captures quotas, backlogs, and worker health', () {
      final migration = File(
        'supabase/migrations/139_distributed_limits_and_free_monitoring.sql',
      ).readAsStringSync();

      expect(migration, contains('capture_operational_health_15m'));
      expect(migration, contains('operational_health_snapshots'));
      expect(migration, contains('notification_backlog'));
      expect(migration, contains('transactional_email_failures'));
      expect(migration, contains('notification_dispatch_health'));

      final workerGuard = File(
        'supabase/migrations/140_guard_notification_worker_invocation.sql',
      ).readAsStringSync();
      expect(workerGuard, contains('private.invoke_notification_dispatch'));
      expect(
          workerGuard, contains("current_setting('app.supabase_url', true)"));
      expect(workerGuard, isNot(contains('jukpscfxzwttgtxvrbmj')));

      final vaultFallback = File(
        'supabase/migrations/141_read_worker_url_from_vault.sql',
      ).readAsStringSync();
      expect(vaultFallback, contains("name = 'silarah_supabase_url'"));
      expect(vaultFallback, contains("supabase[.]co"));
      expect(vaultFallback, isNot(contains('jukpscfxzwttgtxvrbmj')));
    });

    test('database security suite follows the current discovery revision RPC',
        () {
      final databaseTests = File(
        'supabase/tests/security_boundaries_test.sql',
      ).readAsStringSync();

      expect(
        databaseTests,
        contains('public.get_my_discovery_revision(jsonb)'),
      );
      expect(
        databaseTests,
        isNot(contains("'public.get_my_discovery_revision()'")),
      );
    });

    test('load tests cannot target the production project', () {
      final harness = File(
        'load-tests/staging_read_paths.js',
      ).readAsStringSync();
      final runner = File(
        'tool/run_staging_load_test.mjs',
      ).readAsStringSync();

      expect(harness, contains('TARGET_ENV'));
      expect(harness, contains('STAGING_PROJECT_REF'));
      expect(harness, contains('productionProjectRef'));
      expect(harness, contains('Safety stop: production'));
      expect(harness, contains('p(95)<1000'));
      expect(harness, contains('Math.min(Math.max(Number(__ENV.MAX_VUS'));
      expect(harness, contains('sleep(iterationSleepSeconds)'));
      expect(runner, contains('Refusing to run load automation against'));
      expect(runner, contains('/auth/v1/admin/users'));
      expect(runner, contains('finally'));
      expect(runner, contains('Promise.all(fixtures.map(deleteFixture))'));
    });
  });
}
