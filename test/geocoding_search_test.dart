import 'package:flutter_test/flutter_test.dart';
import 'package:silarah/core/services/country_context_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final service = CountryContextService.instance;

  test('Search rural and global cities via live Photon fallback', () async {
    SharedPreferences.setMockInitialValues({});

    final resultsIn = await service.searchCities(
      'kurnool',
      countryCode: 'IN',
    );
    expect(resultsIn, isNotEmpty);
    expect(resultsIn.first.city.toLowerCase(), contains('kurnool'));
    expect(resultsIn.every((r) => r.countryCode == 'IN'), isTrue);
    expect(resultsIn.first.placeId, startsWith('photon-'));

    final resultsAnantapur = await service.searchCities(
      'anantapur',
      countryCode: 'IN',
    );
    expect(resultsAnantapur, isNotEmpty);
    expect(
      resultsAnantapur.map((r) => r.city.toLowerCase()),
      contains('anantapur'),
    );
    expect(resultsAnantapur.every((r) => r.countryCode == 'IN'), isTrue);
    expect(resultsAnantapur.first.placeId, startsWith('photon-'));
  });
}
