import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:silarah/core/cubits/subscription/subscription_state.dart';

void main() {
  late String migration;
  late String subscriptionCubit;
  late String referralService;

  setUpAll(() {
    migration = File(
      'supabase/migrations/215_three_day_referral_premium_for_both.sql',
    ).readAsStringSync();
    subscriptionCubit = File(
      'lib/core/cubits/subscription/subscription_cubit.dart',
    ).readAsStringSync();
    referralService =
        File('lib/core/services/referral_service.dart').readAsStringSync();
  });

  test('grants three independent Premium days to both participants', () {
    expect(migration, contains("v_starts_at + interval '3 days'"));
    expect(migration, contains("'referrer'\n  );"));
    expect(migration, contains("'referred'\n  );"));
    expect(migration, contains("reward_type = '3_days_premium_both'"));
    expect(
      migration,
      isNot(contains('UPDATE public.users SET subscription_status')),
    );
  });

  test('merges paid and referral Premium with authoritative expiry', () {
    expect(migration, contains('public.promotional_premium_grants'));
    expect(migration, contains('public.get_my_premium_entitlement()'));
    expect(
      migration,
      contains('u.subscription_expires_at > now()'),
    );
    expect(migration, contains('g.expires_at > now()'));
    expect(
      subscriptionCubit,
      contains("rpc('get_my_premium_entitlement')"),
    );
    expect(subscriptionCubit, contains('revenueCatActive || server.isActive'));
  });

  test('prevents completed accounts from attaching a signup referral', () {
    expect(migration, contains("'ineligible_existing_account'"));
    expect(
      migration,
      contains('p.onboarding_completed = true'),
    );
  });

  test('referral statistics use the new three-day reward', () {
    expect(referralService, contains("'3_days_premium_both'"));
    expect(referralService, contains('rewardsEarned * 3'));
  });

  test('every locale promises three days to both users', () {
    final arbFiles = Directory('lib/l10n')
        .listSync()
        .whereType<File>()
        .where((file) => RegExp(r'app_[a-z]+\.arb$').hasMatch(file.path));

    for (final file in arbFiles) {
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final body = json['referral_body']?.toString() ?? '';
      expect(body, isNotEmpty, reason: file.path);
      expect(
        RegExp(r'(^|\D)(3|٣|۳|৩)(\D|$)').hasMatch(body),
        isTrue,
        reason: '${file.path}: $body',
      );
      expect(body, isNot(contains('7')), reason: file.path);
      expect(body, isNot(contains('٧')), reason: file.path);
      expect(body, isNot(contains('۷')), reason: file.path);
      expect(body, isNot(contains('৭')), reason: file.path);
    }
  });

  test('expired entitlement timestamps can be cleared from client state', () {
    final expired = SubscriptionState(
      status: SubscriptionStatus.active,
      expiresAt: DateTime.utc(2026, 8, 14),
    );

    final cleared = expired.copyWith(
      status: SubscriptionStatus.none,
      clearExpiresAt: true,
    );

    expect(cleared.status, SubscriptionStatus.none);
    expect(cleared.expiresAt, isNull);
  });
}
