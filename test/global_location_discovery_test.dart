import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String cubit;
  late String sheet;
  late String migration;
  late String liveSourceMigration;
  late String entitlementMigration;

  setUpAll(() {
    cubit = File(
      'lib/core/cubits/discovery/discovery_feed_cubit.dart',
    ).readAsStringSync();
    sheet = File(
      'lib/features/home/widgets/discovery_filter_sheet.dart',
    ).readAsStringSync();
    migration = File(
      'supabase/migrations/131_authoritative_global_location_discovery.sql',
    ).readAsStringSync();
    liveSourceMigration = File(
      'supabase/migrations/132_live_location_discovery_source.sql',
    ).readAsStringSync();
    entitlementMigration = File(
      'supabase/migrations/133_discovery_filter_entitlement_preflight.sql',
    ).readAsStringSync();
  });

  test('Flutter serializes every geographic discovery mode', () {
    expect(cubit, contains("'location_scope': f.locationScope"));
    expect(cubit, contains("'same_region': true"));
    expect(cubit, contains("'country_codes': f.browseCountries"));
    expect(cubit, contains("'diaspora_mode': f.diasporaMode"));
    expect(cubit, contains("'diaspora_countries': f.diasporaCountries"));
  });

  test('filter sheet exposes region, global countries, and diaspora', () {
    expect(sheet, contains("'Same State / Region'"));
    expect(sheet, contains("label: 'BROWSE COUNTRIES'"));
    expect(sheet, contains("label: 'DIASPORA MODE'"));
    expect(sheet, contains('_showCountrySelector(diaspora: false)'));
    expect(sheet, contains('_showCountrySelector(diaspora: true)'));
  });

  test('members can explicitly opt into diaspora introductions', () {
    final model = File(
      'lib/core/models/onboarding_data.dart',
    ).readAsStringSync();
    final writer = File(
      'lib/core/services/profile_write_service.dart',
    ).readAsStringSync();
    final editor = File(
      'lib/features/home/screens/edit_profile_screen.dart',
    ).readAsStringSync();

    expect(model, contains('final bool? openToDiaspora;'));
    expect(writer, contains("'open_to_diaspora': data.openToDiaspora"));
    expect(editor, contains('Open to members living abroad'));
  });

  test('database applies geography before ranking the full eligible pool', () {
    expect(migration, contains('WITH eligible AS MATERIALIZED'));
    expect(migration, contains("WHEN 'same_city' THEN"));
    expect(migration, contains("WHEN 'same_region' THEN"));
    expect(migration, contains("WHEN 'same_country' THEN"));
    expect(migration, contains("WHEN 'countries' THEN"));
    expect(migration, contains("WHEN 'diaspora' THEN"));
    expect(migration, contains('candidate_city.region_id'));
    expect(migration, contains('upper(dp.country_code::text) = ANY'));
    expect(migration, isNot(contains('FROM public.recommendations rec')));
  });

  test('premium geography and locality ranking are server authoritative', () {
    expect(migration, contains('public.has_active_premium(p_viewer_id)'));
    expect(migration, contains("RAISE EXCEPTION 'premium_filter_required'"));
    expect(migration, contains('s.location_score * 0.10'));
    expect(migration, contains('s.mutual_preference_score * 0.72'));
    expect(migration, contains('s.quality_score * 0.18'));
  });

  test('expired saved Premium geography recovers without breaking feed', () {
    expect(cubit, contains("'get_discovery_filter_access'"));
    expect(cubit, contains('_enforceLocationFilterAccess(filter)'));
    expect(cubit, contains('clearBrowseCountries: true'));
    expect(cubit, contains('clearDiasporaCountries: true'));
    expect(
      entitlementMigration,
      contains('public.has_active_premium(v_user_id)'),
    );
    expect(entitlementMigration, contains('TO authenticated;'));
  });

  test('interactive discovery bypasses the daily materialized cache', () {
    expect(
      liveSourceMigration,
      contains('CREATE OR REPLACE VIEW public.live_discovery_pool'),
    );
    expect(
      liveSourceMigration,
      contains("'FROM public.live_discovery_pool dp'"),
    );
    expect(
      liveSourceMigration,
      contains("p.visibility = 'visible'"),
    );
    expect(liveSourceMigration, contains('photo_totals.photo_count'));
  });

  test('country payloads are bounded and validated', () {
    expect(migration, contains('jsonb_array_length'));
    expect(migration, contains("RAISE EXCEPTION 'too_many_country_codes'"));
    expect(migration, contains("RAISE EXCEPTION 'unknown_country_code'"));
    expect(
      migration,
      contains("RAISE EXCEPTION 'unknown_diaspora_country_code'"),
    );
  });
}
