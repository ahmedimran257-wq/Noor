// ignore_for_file: avoid_print
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mithaq/core/services/country_context_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() {
    HttpOverrides.global = null;
  });

  test('Search rural and global cities via Photon fallback', () async {
    SharedPreferences.setMockInitialValues({});
    
    // Search Kurnool (rural/major city in India)
    final resultsIn = await CountryContextService.instance.searchCities(
      'kurnool',
      countryCode: 'IN',
    );
    print('Photon Search results for Kurnool:');
    for (final r in resultsIn) {
      print('- ${r.city}, ${r.state}, ${r.countryCode}, placeId: ${r.placeId}, lat: ${r.lat}, lng: ${r.lng}');
    }
    expect(resultsIn, isNotEmpty);
    expect(resultsIn.first.city.toLowerCase(), contains('kurnool'));
    expect(resultsIn.first.placeId, startsWith('photon-'));

    // Search a rural district in India (e.g. Anantapur)
    final resultsAnantapur = await CountryContextService.instance.searchCities(
      'anantapur',
      countryCode: 'IN',
    );
    print('Photon Search results for Anantapur:');
    for (final r in resultsAnantapur) {
      print('- ${r.city}, ${r.state}, ${r.countryCode}, placeId: ${r.placeId}');
    }
    expect(resultsAnantapur, isNotEmpty);
    expect(resultsAnantapur.first.city.toLowerCase(), contains('anantapur'));
    expect(resultsAnantapur.first.placeId, startsWith('photon-'));
  });
}
