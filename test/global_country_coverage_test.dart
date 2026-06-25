import 'package:flutter_test/flutter_test.dart';
import 'package:mithaq/core/data/country_communities_data.dart';
import 'package:mithaq/core/data/country_data.dart';
import 'package:mithaq/core/data/country_languages_data.dart';

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
    }
  });
}
