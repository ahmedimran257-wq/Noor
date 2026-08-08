import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    'supabase/migrations/199_retire_obsolete_discovery_and_device_pipeline.sql',
  ).readAsStringSync();

  test('retired discovery pipeline is removed without weakening live feed', () {
    expect(migration, contains('FROM public.live_discovery_pool candidate'));
    expect(migration, contains('DROP TABLE IF EXISTS public.recommendations'));
    expect(
      migration,
      contains('DROP MATERIALIZED VIEW IF EXISTS public.discovery_pool'),
    );
    expect(migration, contains('DROP TABLE IF EXISTS public.user_devices'));
    expect(
      migration,
      isNot(contains('FROM public.recommendations r')),
    );
  });

  test('unsafe compatibility RPCs are removed with dependency checks', () {
    expect(
      migration,
      contains(
        'DROP FUNCTION IF EXISTS public.get_nearby_matches(numeric, numeric, numeric) RESTRICT',
      ),
    );
    expect(
      migration,
      contains(
        'DROP FUNCTION IF EXISTS public.submit_selfie_verification(text, text) RESTRICT',
      ),
    );
    expect(migration, isNot(contains('CASCADE')));
  });
}
