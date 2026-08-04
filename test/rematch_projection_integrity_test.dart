import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('active match projection cannot classify closed history as chat', () {
    final migration = File(
      'supabase/migrations/189_active_match_projection_and_rematch_sync.sql',
    ).readAsStringSync();
    final interests = File('lib/core/cubits/interests/interests_cubit.dart')
        .readAsStringSync();

    expect(migration, contains("AND m.status = 'active'"));
    expect(migration,
        contains('CREATE OR REPLACE FUNCTION public.get_my_matches'));
    expect(interests, contains("row as Map)['status'] == 'active'"));
    expect(interests, contains('void markMatchClosed(String matchId)'));
  });

  test('relationship changes refresh card context without feed or photo reload',
      () {
    final cubit = File('lib/core/cubits/discovery/discovery_feed_cubit.dart')
        .readAsStringSync();
    final migration = File(
      'supabase/migrations/189_active_match_projection_and_rematch_sync.sql',
    ).readAsStringSync();

    expect(cubit, contains('_refreshRelationshipContext(serverToken)'));
    expect(cubit, contains("'get_prior_match_context'"));
    expect(cubit, contains('_catalogRevisionOf(loadedToken)'));
    expect(migration, contains("SELECT 'client_clock'::text"));
  });

  test('cooldown expires from a local timer and rematch has explicit copy', () {
    final discovery =
        File('lib/features/home/screens/discovery_feed_screen.dart')
            .readAsStringSync();
    final detail = File('lib/features/home/screens/profile_detail_screen.dart')
        .readAsStringSync();

    expect(discovery, contains('Timer? _rematchCountdownTimer'));
    expect(discovery, contains("'Send Interest Again'"));
    expect(discovery, contains("'Rematch available in \$cooldownDays day"));
    expect(detail, contains("'Send interest again'"));
    expect(discovery, contains("'Unlock Chat'"));
  });

  test('match-ended events reconcile both participants across devices', () {
    final migration = File(
      'supabase/migrations/189_active_match_projection_and_rematch_sync.sql',
    ).readAsStringSync();
    final main = File('lib/main.dart').readAsStringSync();

    expect(migration, contains("'match_ended'"));
    expect(migration, contains('trg_queue_match_ended_notification'));
    expect(main, contains("message.data['type'] == 'match_ended'"));
    expect(main, contains('_discoveryFeedCubit.refreshIfChanged'));
    expect(main, contains('_interestsCubit.refreshIfChanged'));
  });

  test('discovery search preserves its declared city text contract', () {
    final migration = File(
      'supabase/migrations/190_fix_discovery_search_city_contract.sql',
    ).readAsStringSync();

    expect(migration, contains("coalesce(city.name, '')::text"));
    expect(migration, contains('unauthorized_profile_search'));
    expect(migration, contains("m.status IN ('blocked','reported')"));
  });
}
