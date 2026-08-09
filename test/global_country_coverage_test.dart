import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:silarah/core/data/country_communities_data.dart';
import 'package:silarah/core/data/country_data.dart';
import 'package:silarah/core/data/country_languages_data.dart';

void main() {
  test('the supported-country contract remains 198 entries', () {
    expect(kAllCountries, hasLength(198));
  });

  test('every supported country has offline language coverage', () {
    for (final country in kAllCountries) {
      final languages = kCountryLanguages[country.iso2];
      expect(languages, isNotNull, reason: country.iso2);
      expect(languages, isNotEmpty, reason: country.iso2);
    }
  });

  test('every supported country has country-aware community options', () {
    for (final country in kAllCountries) {
      final communities = CountryCommunityData.forCountry(country.iso2);
      expect(communities, isNotEmpty, reason: country.iso2);
      expect(communities, contains('Other'), reason: country.iso2);
      expect(communities, contains('Prefer not to say'), reason: country.iso2);
      expect(
        communities,
        isNot(contains('${country.name} Muslim community')),
        reason:
            '${country.iso2} must have curated or regional options, not generated fallback copy.',
      );
    }
  });

  test('hosted migrations seed the original launch countries', () {
    final migration = File(
      'supabase/migrations/202_seed_launch_countries_in_hosted_environments.sql',
    ).readAsStringSync();
    for (final code in const [
      'IN',
      'PK',
      'BD',
      'GB',
      'US',
      'CA',
      'AE',
      'SA',
      'MY',
      'ID',
      'TR',
      'EG',
      'NG',
      'DE',
      'FR',
    ]) {
      expect(migration, contains("('$code',"), reason: code);
    }
    expect(migration, contains('ON CONFLICT (iso_code) DO UPDATE'));
  });
}
