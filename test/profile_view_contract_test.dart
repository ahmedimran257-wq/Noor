import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    'supabase/migrations/144_profile_view_privacy_and_accuracy.sql',
  ).readAsStringSync();
  final deliveryMigration = File(
    'supabase/migrations/186_relationship_and_push_delivery_integrity.sql',
  ).readAsStringSync();
  final service = File(
    'lib/core/services/profile_view_service.dart',
  ).readAsStringSync();
  final detail = File(
    'lib/features/home/screens/profile_detail_screen.dart',
  ).readAsStringSync();
  final paywall = File(
    'lib/features/home/screens/subscription_screen.dart',
  ).readAsStringSync();
  final profile = File(
    'lib/features/home/screens/my_profile_screen.dart',
  ).readAsStringSync();

  test('profile detail is the single recording boundary', () {
    expect(detail, contains('ProfileViewService.instance.record'));
    expect(detail, contains('!widget.isOwnProfile'));
    expect(service, contains("'p_notify_owner': true"));
    expect(deliveryMigration, contains("interval '6 hours'"));
    expect(deliveryMigration, contains("'silarah://profile-views'"));
    expect(
      deliveryMigration,
      contains("p_type = 'profile_view'"),
    );
  });

  test('weekly count is distinct and free while identities are premium-only',
      () {
    expect(migration, contains('count(DISTINCT pv.viewer_profile_id)'));
    expect(migration, contains('public.has_active_premium(auth.uid())'));
    expect(migration, contains("RAISE EXCEPTION 'premium_required'"));
    expect(profile, contains('weeklyDistinctCount'));
  });

  test('paywall never promises a nonexistent like action', () {
    expect(paywall, isNot(contains('liked your profile')));
    expect(paywall, contains('See everyone who viewed your profile'));
  });

  test('profile activity has priority over account and growth tools', () {
    final spotlight = profile.indexOf('_ProfileViewsSpotlight(');
    final accountStanding = profile.indexOf('_ProfileLifecycleCard(');
    final trustCenter = profile.indexOf('_TrustCenterCard(');
    final boost = profile.indexOf('_BoostSection(');
    final saved = profile.indexOf('_SavedProfilesSection(');
    final referral = profile.indexOf("context.push(AppRoutes.referral)");

    expect(spotlight, greaterThanOrEqualTo(0));
    expect(spotlight, lessThan(accountStanding));
    expect(accountStanding, lessThan(trustCenter));
    expect(boost, lessThan(saved));
    expect(saved, lessThan(referral));
  });
}
