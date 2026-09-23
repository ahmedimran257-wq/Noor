import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('RevenueCat billing writes are indexed and retry-safe', () {
    final migration = File(
      'supabase/migrations/261_revenuecat_event_index_and_idempotency.sql',
    ).readAsStringSync();
    final providerIdentity = File(
      'supabase/migrations/151_billing_event_integrity.sql',
    ).readAsStringSync();

    expect(
      providerIdentity,
      contains('CREATE UNIQUE INDEX IF NOT EXISTS '
          'idx_subscription_events_provider_event'),
    );
    expect(migration, contains('idx_subscription_events_user_time'));
    expect(migration, contains('ON CONFLICT DO NOTHING'));
    expect(migration, contains('RETURNING id INTO v_event_id'));
    expect(migration, contains("'reason', 'duplicate_event'"));
    expect(migration, contains('FOR UPDATE'));
    expect(migration, contains('p_event_timestamp_ms <= coalesce(v_last_ts'));
    expect(migration, contains('ON CONFLICT (dedupe_key) DO NOTHING'));
  });
}
