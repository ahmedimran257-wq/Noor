import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Future<T> withPhotonFixtures<T>(Future<T> Function() body) {
  final client = MockClient((request) async {
    if (request.url.host != 'photon.komoot.io' || request.url.path != '/api') {
      return http.Response('Not found', 404);
    }

    final query = request.url.queryParameters['q']?.toLowerCase().trim() ?? '';
    final fixture = _fixtures[query];
    final features =
        fixture == null ? const <Map<String, Object?>>[] : [fixture];
    return http.Response(
      jsonEncode({'type': 'FeatureCollection', 'features': features}),
      200,
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );
  });

  return http.runWithClient(body, () => client);
}

Map<String, Object?> _feature({
  required int id,
  required String name,
  required String country,
  required String countryCode,
  required String state,
  required double longitude,
  required double latitude,
  String osmValue = 'city',
}) {
  return {
    'type': 'Feature',
    'geometry': {
      'type': 'Point',
      'coordinates': [longitude, latitude],
    },
    'properties': {
      'osm_id': id,
      'osm_key': 'place',
      'osm_value': osmValue,
      'name': name,
      'country': country,
      'countrycode': countryCode.toLowerCase(),
      'state': state,
    },
  };
}

final _fixtures = <String, Map<String, Object?>>{
  'kurnool': _feature(
    id: 101,
    name: 'Kurnool',
    country: 'India',
    countryCode: 'IN',
    state: 'Andhra Pradesh',
    longitude: 78.0373,
    latitude: 15.8281,
  ),
  'anantapur': _feature(
    id: 102,
    name: 'Anantapur',
    country: 'India',
    countryCode: 'IN',
    state: 'Andhra Pradesh',
    longitude: 77.6006,
    latitude: 14.6819,
  ),
  'jakarta': _feature(
    id: 201,
    name: 'Jakarta',
    country: 'Indonesia',
    countryCode: 'ID',
    state: 'Jakarta',
    longitude: 106.8272,
    latitude: -6.1754,
  ),
  'london': _feature(
    id: 301,
    name: 'London',
    country: 'United Kingdom',
    countryCode: 'GB',
    state: 'England',
    longitude: -0.1276,
    latitude: 51.5072,
  ),
  'cairo': _feature(
    id: 302,
    name: 'Cairo',
    country: 'Egypt',
    countryCode: 'EG',
    state: 'Cairo',
    longitude: 31.2357,
    latitude: 30.0444,
  ),
  'kuala lumpur': _feature(
    id: 303,
    name: 'Kuala Lumpur',
    country: 'Malaysia',
    countryCode: 'MY',
    state: 'Kuala Lumpur',
    longitude: 101.6869,
    latitude: 3.1390,
  ),
  'nairobi': _feature(
    id: 304,
    name: 'Nairobi',
    country: 'Kenya',
    countryCode: 'KE',
    state: 'Nairobi County',
    longitude: 36.8219,
    latitude: -1.2921,
  ),
  'toronto': _feature(
    id: 305,
    name: 'Toronto',
    country: 'Canada',
    countryCode: 'CA',
    state: 'Ontario',
    longitude: -79.3832,
    latitude: 43.6532,
  ),
  'sydney': _feature(
    id: 306,
    name: 'Sydney',
    country: 'Australia',
    countryCode: 'AU',
    state: 'New South Wales',
    longitude: 151.2093,
    latitude: -33.8688,
  ),
  'bali': _feature(
    id: 401,
    name: 'Bali',
    country: 'Indonesia',
    countryCode: 'ID',
    state: 'Bali',
    longitude: 115.1889,
    latitude: -8.4095,
    osmValue: 'state',
  ),
};
