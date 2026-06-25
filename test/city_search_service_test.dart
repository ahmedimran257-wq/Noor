import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mithaq/core/services/country_context_service.dart';

void main() {
  final service = CountryContextService.instance;

  tearDown(service.resetCitySearchTestOverrides);

  test('returns the Supabase cache before Photon', () async {
    var photonCalled = false;
    service.cityCacheSearchOverride = (_, __) async => const [
          CityResult(
            city: 'Hyderabad',
            state: 'Telangana',
            country: 'India',
            countryCode: 'IN',
            postalCode: '',
            fullAddress: 'Hyderabad, Telangana, India',
            placeId: '42',
            lat: 17.385,
            lng: 78.4867,
          ),
        ];
    service.photonRequestOverride = (_) {
      photonCalled = true;
      return Future.value(http.Response('{}', 200));
    };

    final results = await service.searchCities('hyde', countryCode: 'IN');

    expect(results.single.placeId, '42');
    expect(photonCalled, isFalse);
  });

  test('falls back to Photon and keeps only the selected country', () async {
    service.cityCacheSearchOverride = (_, __) async => const [];
    service.photonRequestOverride = (_) async => http.Response(
          jsonEncode({
            'features': [
              _photonFeature('Kurnool', 'IN', 78.04, 15.83),
              _photonFeature('Kurnool', 'US', -122.0, 37.0),
            ],
          }),
          200,
        );

    final results = await service.searchCities('kurnool', countryCode: 'IN');

    expect(results, hasLength(1));
    expect(results.single.countryCode, 'IN');
    expect(results.single.city, 'Kurnool');
  });

  test('returns empty results after a Photon timeout', () async {
    service.cityCacheSearchOverride = (_, __) async => const [];
    service.photonTimeout = const Duration(milliseconds: 1);
    service.photonRequestOverride = (_) => Completer<http.Response>().future;

    expect(
      await service.searchCities('delhi', countryCode: 'IN'),
      isEmpty,
    );
  });

  test('returns empty results when Photon has no features', () async {
    service.cityCacheSearchOverride = (_, __) async => const [];
    service.photonRequestOverride = (_) async => http.Response(
          jsonEncode({'features': []}),
          200,
        );

    expect(
      await service.searchCities('unknown', countryCode: 'IN'),
      isEmpty,
    );
  });
}

Map<String, Object> _photonFeature(
  String city,
  String countryCode,
  double lng,
  double lat,
) =>
    {
      'properties': {
        'name': city,
        'state': 'State',
        'country': 'Country',
        'countrycode': countryCode.toLowerCase(),
        'osm_id': 1,
      },
      'geometry': {
        'coordinates': [lng, lat],
      },
    };
