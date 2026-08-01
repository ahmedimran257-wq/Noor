import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Basic Identity reuses the service-verified Quick Location city', () {
    final source = File(
      'supabase/migrations/166_repair_basic_identity_after_city_hardening.sql',
    ).readAsStringSync();

    expect(source,
        contains('CREATE OR REPLACE FUNCTION public.save_basic_identity_step'));
    expect(source, contains('u.onboarding_city_id'));
    expect(source, contains('verified_location_required'));
    expect(source, isNot(contains('public.get_or_create_city(')));
    expect(
      source,
      contains('GRANT EXECUTE ON FUNCTION public.save_basic_identity_step'),
    );
  });

  test('client records a safe Basic Identity RPC failure classification', () {
    final source =
        File('lib/core/services/profile_write_service.dart').readAsStringSync();

    expect(source, contains('Basic Identity RPC failed'));
    expect(source, isNot(contains('p_first_name}:')));
  });
}
