import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // A staging load test showed the feed going from ~0.3 s to ~5 s per call
  // once Postgres switched to a generic plan. CREATE OR REPLACE FUNCTION
  // resets function settings, so the newest migration that touches the feed
  // must also (re)apply the per-call planning setting.
  test('the newest Discovery feed migration keeps per-call plans', () {
    final migrations = Directory('supabase/migrations')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.sql'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    final touching = migrations
        .where((f) => f
            .readAsStringSync()
            .contains('FUNCTION public.get_discovery_feed('))
        .toList();
    expect(touching, isNotEmpty);
    final latest = touching.last;
    expect(
      latest.readAsStringSync(),
      contains('plan_cache_mode = force_custom_plan'),
      reason: '${latest.path} redefines get_discovery_feed without '
          'force_custom_plan; Discovery will slow down sharply at scale.',
    );
  });
}
