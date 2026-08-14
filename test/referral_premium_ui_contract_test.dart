import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final mainSource = File('lib/main.dart').readAsStringSync();
  final subscription = File(
    'lib/features/home/screens/subscription_screen.dart',
  ).readAsStringSync();
  final profile = File(
    'lib/features/home/screens/my_profile_screen.dart',
  ).readAsStringSync();
  final fcm = File('lib/core/services/fcm_service.dart').readAsStringSync();
  final notifications = File(
    'lib/core/cubits/notifications/notifications_cubit.dart',
  ).readAsStringSync();
  final subscriptionCubit = File(
    'lib/core/cubits/subscription/subscription_cubit.dart',
  ).readAsStringSync();

  test('reward events and app resume refresh promotional access', () {
    expect(mainSource, contains("item.type == 'referral_reward'"));
    expect(mainSource, contains('refreshEntitlement()'));
    expect(mainSource, contains('AppLifecycleState.resumed'));
  });

  test('referral subscription surface protects remaining free time', () {
    expect(subscription, contains('state.isReferralOnly'));
    expect(subscription, contains('_ReferralPremiumActiveView'));
    expect(subscription, contains('PopScope'));
    expect(subscription, contains("context.go('/home?tab=3')"));
    expect(subscriptionCubit, contains('if (state.isReferralOnly)'));
    expect(
      subscriptionCubit,
      contains('Plans become available after it ends'),
    );
  });

  test('profile exposes a prominent referral Premium banner', () {
    expect(profile, contains('_ReferralPremiumProfileBanner'));
    expect(profile, contains('subscription.isReferralOnly'));
    expect(profile, contains('referral_premiumFeaturesUnlocked'));
  });

  test('legacy referral pushes no longer open checkout', () {
    expect(fcm, contains("type == 'referral_reward'"));
    expect(fcm, contains("? '/home?tab=3'"));
    expect(notifications, contains("item.type == 'referral_reward'"));
    expect(notifications, contains("return '/home?tab=3'"));
  });
}
