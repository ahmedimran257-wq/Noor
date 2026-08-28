import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    'supabase/migrations/249_release_gate_security_cost_and_index_hardening.sql',
  ).readAsStringSync();

  test('pre-auth writes and exact referral lookup have distributed limits', () {
    expect(migration, contains('private.enforce_pre_auth_rate_limit'));
    expect(migration, contains("'signup_consent', 20, 900"));
    expect(migration, contains("'referral_validate', 120, 900"));
    expect(migration, contains('public.consume_edge_rate_limit'));
    expect(migration, contains('extensions.digest'));
    expect(migration,
        contains('DROP FUNCTION IF EXISTS public.email_is_registered'));
    expect(
      migration,
      contains('DROP FUNCTION IF EXISTS public.email_registration_status'),
    );
  });

  test('remaining auth RLS expression is initialized once per statement', () {
    expect(
      migration,
      contains('USING (user_id = (SELECT auth.uid()))'),
    );
  });

  test('idle photo purge exits before reading secrets or using network', () {
    final functionStart = migration.indexOf(
      'CREATE OR REPLACE FUNCTION private.invoke_photo_verification_purge_worker',
    );
    final functionEnd = migration.indexOf(
      'REVOKE ALL ON FUNCTION private.invoke_photo_verification_purge_worker',
      functionStart,
    );
    final function = migration.substring(functionStart, functionEnd);
    expect(function.indexOf('IF NOT EXISTS'),
        lessThan(function.indexOf('vault.decrypted_secrets')));
    expect(function.indexOf('RETURN;'),
        lessThan(function.indexOf('net.http_post')));
    expect(function, contains('purge_after <= now()'));
    expect(function, contains('purge_attempts < 12'));
  });

  test('non-urgent jobs are conditional and run every fifteen minutes', () {
    expect(migration, contains("'refresh_admin_metric_snapshots_15m'"));
    expect(migration, contains("'compute_glicko2_batch_15m'"));
    expect(migration, contains("'*/15 * * * *'"));
    expect(
      migration,
      contains('WHERE EXISTS (SELECT 1 FROM public.glicko_interactions'),
    );
  });

  test('operational retention excludes user content and pending ranking work',
      () {
    expect(migration, contains('cleanup_operational_history_daily'));
    expect(migration, contains("end_time < now() - interval '14 days'"));
    expect(migration, contains("finished_at < now() - interval '30 days'"));
    expect(migration, contains('WHERE processed = true'));
    expect(migration, isNot(contains('DELETE FROM public.messages')));
    expect(migration, isNot(contains('DELETE FROM public.profiles')));
    expect(migration, isNot(contains('DELETE FROM public.user_consents')));
  });

  test('live Performance Advisor foreign-key findings are indexed', () {
    for (final index in <String>[
      'idx_admin_session_boundaries_admin',
      'idx_discovery_availability_candidate_profile',
      'idx_guardian_match_approvals_ward',
      'idx_guardian_match_approvals_guardian',
      'idx_interest_expiry_events_recipient',
      'idx_match_closure_operations_actor',
      'idx_match_closure_operations_message',
      'idx_signup_consent_transactions_consumed_by',
      'idx_storage_deletion_jobs_photo',
      'idx_storage_deletion_jobs_user',
      'idx_upload_reservations_user',
      'idx_upload_reservations_profile',
      'idx_upload_reservations_replaced_photo',
    ]) {
      expect(migration, contains(index), reason: 'missing $index');
    }
  });

  test('service audit follows current jobs and exposes cost guards', () {
    expect(migration, contains("'process_interest_expiry_5m'"));
    expect(migration, contains("'photo_purge_due'"));
    expect(migration, contains("'unprocessed_ranking_events'"));
    expect(migration, contains("'idle_photo_worker_guard', true"));
    expect(migration, contains("'operational_retention'"));
  });
}
