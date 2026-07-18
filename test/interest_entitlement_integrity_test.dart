import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:silarah/core/cubits/interests/interests_state.dart';

void main() {
  group('authoritative interest entitlement contract', () {
    final migration129 = File(
      'supabase/migrations/129_interest_entitlements_and_chat_access.sql',
    ).readAsStringSync();
    final migration130 = File(
      'supabase/migrations/130_harden_unknown_gender_chat_access.sql',
    ).readAsStringSync();
    final migration = '$migration129\n$migration130';

    test('uses one gender-neutral free and Premium allowance', () {
      expect(migration, contains('THEN 25 ELSE 5'));
      expect(migration, contains("THEN 'premium'::text ELSE 'free'::text"));
      expect(migration, isNot(contains('approved_at')));
      expect(migration, isNot(contains("v_gender = 'female'")));
    });

    test('owns timestamps and serializes quota writes on the server', () {
      expect(migration, contains('NEW.created_at := now()'));
      expect(migration, contains('pg_advisory_xact_lock'));
      expect(migration, contains('interest_quota_exhausted'));
      expect(migration, contains("AT TIME ZONE 'UTC'"));
    });

    test('keeps the messaging gender rule at both decision and insert gates',
        () {
      expect(
        "v_gender IS DISTINCT FROM 'female'".allMatches(migration).length,
        greaterThanOrEqualTo(2),
      );
      expect(migration, contains('trg_assert_messaging_allowed'));
      expect(migration, contains('subscription_required'));
    });
  });

  test('an unloaded quota is not mistaken for an exhausted quota', () {
    const state = InterestsState();
    expect(state.dailyLimit, 0);
    expect(state.isDailyLimitReached, isFalse);
  });

  test('quota state carries Premium and reset metadata from Supabase', () {
    final reset = DateTime.utc(2026, 7, 18);
    final state = InterestsState(
      interestsSentToday: 25,
      dailyLimit: 25,
      isPremium: true,
      quotaResetsAt: reset,
    );
    expect(state.isDailyLimitReached, isTrue);
    expect(state.remainingToday, 0);
    expect(state.isPremium, isTrue);
    expect(state.quotaResetsAt, reset);
  });

  test('paywall does not advertise a fabricated local price', () {
    final source = File(
      'lib/features/home/screens/paywall_gate_screen.dart',
    ).readAsStringSync();
    expect(source, isNot(contains('₹249')));
    expect(source, contains('Plans are shown in your local currency'));
  });
}
