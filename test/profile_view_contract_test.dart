import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    'supabase/migrations/144_profile_view_privacy_and_accuracy.sql',
  ).readAsStringSync();
  final deliveryMigration = File(
    'supabase/migrations/186_relationship_and_push_delivery_integrity.sql',
  ).readAsStringSync();
  final activityMigration = File(
    'supabase/migrations/260_profile_view_unread_activity.sql',
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
    expect(service, contains('weeklyDistinctCount'));
    expect(service, contains('activitySummary'));
    expect(activityMigration,
        contains('count(DISTINCT pv.viewer_profile_id)::bigint'));
  });

  test('unseen activity has an authoritative read cursor', () {
    final notifications = File(
      'lib/core/cubits/notifications/notifications_cubit.dart',
    ).readAsStringSync();
    final viewsScreen = File(
      'lib/features/home/screens/profile_views_screen.dart',
    ).readAsStringSync();

    expect(activityMigration, contains('profile_view_activity_state'));
    expect(activityMigration, contains('unseen_viewer_count'));
    expect(activityMigration, contains('mark_profile_views_seen'));
    expect(activityMigration, contains("type = 'profile_view'"));
    expect(activityMigration, contains('ENABLE ROW LEVEL SECURITY'));
    expect(service, contains("rpc('mark_profile_views_seen')"));
    expect(viewsScreen, contains('reconcileProfileViewsSeen'));
    expect(notifications, contains('bellUnreadCount'));
    expect(notifications, contains("n.type != 'profile_view'"));
  });

  test('paywall never promises a nonexistent like action', () {
    expect(paywall, isNot(contains('liked your profile')));
    expect(paywall, contains('See everyone who viewed your profile'));
  });

  test('profile activity has priority over account and growth tools', () {
    final activityRail = profile.indexOf('ProfileHeaderActionRail(');
    final accountStanding = profile.indexOf('_ProfileLifecycleCard(');
    final trustCenter = profile.indexOf('_TrustCenterCard(');
    final boost = profile.indexOf('_BoostSection(');
    final saved = profile.indexOf('_SavedProfilesSection(');
    final referral = profile.indexOf("context.push(AppRoutes.referral)");

    expect(activityRail, greaterThanOrEqualTo(0));
    expect(activityRail, lessThan(accountStanding));
    expect(profile, isNot(contains('_ProfileViewsSpotlight')));
    expect(accountStanding, lessThan(trustCenter));
    expect(boost, lessThan(saved));
    expect(saved, lessThan(referral));
  });
}
