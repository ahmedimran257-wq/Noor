import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File('supabase/migrations/282_discovery_feed_page.sql')
      .readAsStringSync();
  final cubit = File('lib/core/cubits/discovery/discovery_feed_cubit.dart')
      .readAsStringSync();

  test('the revision token is read before the page in the same call', () {
    // Read first, the token can only be older than the rows, so a change
    // that lands in between still triggers the next refresh.
    final token = migration.indexOf('public.get_my_discovery_revision(');
    final feed = migration.indexOf('FROM public.get_discovery_feed(');
    expect(token, isNonNegative);
    expect(feed, greaterThan(token));
    expect(migration, contains('SECURITY INVOKER'));
    expect(migration, contains('FROM PUBLIC, anon;'));
    expect(migration, contains('ORDER BY feed.ordinality'));
  });

  test('cold start and filter changes use one round trip', () {
    expect(cubit, contains("'get_discovery_feed_page'"));
    expect(cubit, contains("'p_include_revision': onRevisionToken != null"));
    // Rollout safety: an app update served by a database without the
    // function keeps working through the original two calls.
    expect(cubit, contains("error.code != 'PGRST202'"));
  });

  test('quota and readiness no longer gate the feed request', () {
    expect(cubit,
        contains('final quotaLoad = _Outcome.of(_loadServerViewQuota());'));
    expect(
      cubit,
      contains(
          'final readiness = _Outcome.of(_assertViewerDiscoveryReady(currentUserId));'),
    );
  });
}
