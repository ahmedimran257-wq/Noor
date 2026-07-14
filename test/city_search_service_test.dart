import 'package:flutter_test/flutter_test.dart';
import 'package:silarah/core/services/country_context_service.dart';

void main() {
  final service = CountryContextService.instance;

  test('returns empty results before there is enough query text', () async {
    expect(
      await service.searchCities('d', countryCode: 'IN'),
      isEmpty,
    );
    expect(
      await service.searchRegions('d', countryCode: 'IN'),
      isEmpty,
    );
  });

  test('uses live Photon fallback and keeps only the selected country',
      () async {
    final results = await service.searchCities('kurnool', countryCode: 'IN');

    expect(results, isNotEmpty);
    expect(results.every((r) => r.countryCode == 'IN'), isTrue);
    expect(results.first.city.toLowerCase(), contains('kurnool'));
    expect(results.first.placeId, startsWith('photon-'));
  });

  test('uses live Photon fallback for global capital cities', () async {
    final results = await service.searchCities('jakarta', countryCode: 'ID');

    expect(results, isNotEmpty);
    expect(results.every((r) => r.countryCode == 'ID'), isTrue);
    expect(results.any((r) => r.city.toLowerCase() == 'jakarta'), isTrue);
  });

  test('uses the same live Photon fallback across global countries', () async {
    final samples = <({String query, String countryCode})>[
      (query: 'london', countryCode: 'GB'),
      (query: 'cairo', countryCode: 'EG'),
      (query: 'kuala lumpur', countryCode: 'MY'),
      (query: 'nairobi', countryCode: 'KE'),
      (query: 'toronto', countryCode: 'CA'),
      (query: 'sydney', countryCode: 'AU'),
    ];

    for (final sample in samples) {
      final results = await service.searchCities(
        sample.query,
        countryCode: sample.countryCode,
      );

      expect(results, isNotEmpty, reason: sample.query);
      expect(
        results.every((r) => r.countryCode == sample.countryCode),
        isTrue,
        reason: sample.query,
      );
      expect(
        results.every((r) => r.lat != 0 && r.lng != 0),
        isTrue,
        reason: sample.query,
      );
    }
  });

  test('uses live Photon fallback for global states and regions', () async {
    final regions = await service.searchRegions('bali', countryCode: 'ID');

    expect(regions, isNotEmpty);
    expect(regions.every((r) => r.countryCode == 'ID'), isTrue);
    expect(regions.any((r) => r.name.toLowerCase() == 'bali'), isTrue);
  });

  test('accepts real areas when users type them into city search', () async {
    final results = await service.searchCities('bali', countryCode: 'ID');

    expect(results, isNotEmpty);
    expect(results.every((r) => r.countryCode == 'ID'), isTrue);
    expect(results.any((r) => r.city.toLowerCase().contains('bali')), isTrue);
  });

  test('region filter rejects cities outside the selected state', () async {
    final results = await service.searchCities(
      'kurnool',
      countryCode: 'IN',
      regionName: 'Kerala',
    );

    expect(results, isEmpty);
  });
}
