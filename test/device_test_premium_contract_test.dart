import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String migration;

  setUpAll(() {
    migration = File(
      'supabase/migrations/247_expiring_device_test_premium.sql',
    ).readAsStringSync();
  });

  test('test Premium is physically scoped, expiring and service-only', () {
    expect(migration, contains('private.test_premium_grants'));
    expect(migration, contains("auth.role() <> 'service_role'"));
    expect(migration, contains('cardinality(v_ids) NOT BETWEEN 1 AND 5'));
    expect(migration, contains('p_duration_hours NOT BETWEEN 1 AND 168'));
    expect(migration, contains('public.user_fcm_tokens'));
    expect(
        migration, contains("token.updated_at >= now() - interval '24 hours'"));
    expect(migration, contains('public.test_fixture_members'));
    expect(migration, contains('test_premium_device_not_eligible'));
  });

  test('test Premium never impersonates billing, referrals or phone trust', () {
    expect(migration, isNot(contains('UPDATE public.users')));
    expect(
        migration, isNot(contains('INSERT INTO public.subscription_events')));
    expect(
      migration,
      isNot(contains('INSERT INTO public.promotional_premium_grants')),
    );
    expect(migration, isNot(contains('phone_trust_activated_at =')));
  });

  test('all server gates share the same active entitlement source', () {
    expect(migration,
        contains('CREATE OR REPLACE FUNCTION public.has_active_premium'));
    expect(
        migration,
        contains(
            'CREATE OR REPLACE FUNCTION public.get_my_premium_entitlement'));
    expect(
        migration, contains("WHEN v_test_expires_at IS NOT NULL THEN 'test'"));
    expect(migration, contains('v_test_active boolean := false'));
    expect(migration, contains('NOT v_test_active'));
  });

  test('one exact batch can revoke every device test grant', () {
    expect(migration, contains('public.revoke_device_test_premium'));
    expect(migration, contains('WHERE batch_id = p_batch_id'));
    expect(migration, contains('SET revoked_at = coalesce(revoked_at, now())'));
  });
}
