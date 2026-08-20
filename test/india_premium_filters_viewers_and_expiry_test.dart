import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:silarah/core/cubits/discovery/discovery_filter.dart';
import 'package:silarah/core/cubits/interests/interests_state.dart';
import 'package:silarah/core/models/discovery_profile.dart';

void main() {
  final migration = File(
    'supabase/migrations/218_india_filters_viewers_and_interest_expiry.sql',
  ).readAsStringSync();
  final optionsService = File(
    'lib/core/services/discovery_filter_options_service.dart',
  ).readAsStringSync();
  final feedCubit = File(
    'lib/core/cubits/discovery/discovery_feed_cubit.dart',
  ).readAsStringSync();
  final viewersScreen = File(
    'lib/features/home/screens/profile_views_screen.dart',
  ).readAsStringSync();

  const profile = DiscoveryProfile(
    id: '10000000-0000-4000-8000-000000000001',
    firstName: 'Test',
    lastNameInitial: 'M',
    age: 29,
    cityName: 'Hyderabad',
  );

  test('India catalogue is independent of the live discovery population', () {
    expect(optionsService, contains("'get_india_discovery_filter_facets'"));
    expect(migration, contains("'mother_tongue', language"));
    expect(migration, contains("'community', value"));
    expect(migration, contains("WHERE state_code <> 'ALL'"));
  });

  test('state and city are one Premium location preference', () {
    const filter = DiscoveryFilter(
      stateName: 'Telangana',
      cityId: '12',
      cityName: 'Hyderabad',
    );
    expect(filter.isActive, isTrue);
    expect(filter.activeCount, 1);
    expect(feedCubit, contains("'state_name': f.stateName!.trim()"));
    expect(feedCubit, contains("'city_id': f.cityId!.trim()"));
    expect(migration, contains("'india_location'"));
    expect(migration, contains('invalid_city_filter'));
  });

  test('viewer identities use authorized projections, signed photos and route',
      () {
    expect(viewersScreen, contains('AuthorizedProfileService.load'));
    expect(viewersScreen, contains('getAuthorizedPhotoUrls'));
    expect(viewersScreen, contains("context.push('/profile/\${p.id}')"));
    expect(migration, contains('recent_view.viewer_profile_id = p.id'));
    expect(migration, contains('recent_view.viewer_profile_id = owner.id'));
  });

  test('server expires_at controls the visible interest countdown', () {
    final now = DateTime.now();
    final entry = InterestEntry(
      id: 'interest',
      profile: profile,
      timeAgo: 'now',
      sentAt: now,
      createdAt: now.subtract(const Duration(days: 30)),
      serverExpiresAt: now.add(const Duration(hours: 25)),
    );
    expect(entry.effectiveStatus, InterestStatus.pending);
    expect(entry.daysRemaining, 2);
    expect(entry.hoursRemaining, 25);
  });

  test('expiry lifecycle is idempotent and does not blame the receiver', () {
    expect(migration,
        contains('PRIMARY KEY (interest_id, recipient_id, event_type)'));
    expect(migration, contains("'receiver_reminder'"));
    expect(migration, contains("'sender_reminder'"));
    expect(migration, contains("'interest_expired'"));
    expect(
      migration,
      isNot(contains('You did not accept')),
    );
  });
}
