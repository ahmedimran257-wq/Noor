import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String editor;
  late String writer;
  late String migration;

  setUpAll(() {
    editor = File(
      'lib/features/home/screens/edit_profile_screen.dart',
    ).readAsStringSync();
    writer = File(
      'lib/core/services/profile_write_service.dart',
    ).readAsStringSync();
    migration = File(
      'supabase/migrations/122_atomic_profile_location.sql',
    ).readAsStringSync();
  });

  test('Edit Profile requires a verified global city result', () {
    expect(editor, contains('CitySearchField('));
    expect(editor, contains('RegionSearchField('));
    expect(editor, contains('CountryPickerScreen('));
    expect(editor, contains('Select a city from the verified search results.'));
    expect(editor, contains('discovery.clear()'));
    expect(editor, contains('discovery.loadInitial(force: true)'));
    expect(editor, isNot(contains('_cityCtrl')));
  });

  test('profile writer uses the atomic location RPC', () {
    expect(writer, contains("'update_profile_location'"));
    expect(writer, contains('bool locationChanged = false'));
    expect(writer, contains("fields.remove('city_id')"));
    expect(writer, contains("fields.remove('country_code')"));
  });

  test('database synchronizes city, country, and discovery coordinates', () {
    expect(migration,
        contains('CREATE OR REPLACE FUNCTION public.update_profile_location'));
    expect(migration, contains('UPDATE public.users'));
    expect(migration, contains('UPDATE public.profiles'));
    expect(migration, contains("location_source = 'city'"));
    expect(migration, contains('guard_profile_location_mutation'));
    expect(migration,
        contains('The selected city does not belong to that country.'));
  });
}
