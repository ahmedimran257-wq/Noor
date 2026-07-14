import 'package:flutter_test/flutter_test.dart';
import 'package:silarah/core/cubits/discovery/discovery_filter.dart';

void main() {
  test('explicit maxDistanceKm is the canonical radius', () {
    const filter = DiscoveryFilter(
      maxDistanceKm: 75,
      distanceLabel: '50km',
    );

    expect(filter.effectiveMaxDistanceKm, 75);
    expect(filter.activeCount, 1);
  });

  test('legacy distance labels remain wired', () {
    const filter = DiscoveryFilter(distanceLabel: '100km');

    expect(filter.effectiveMaxDistanceKm, 100);
    expect(filter.activeCount, 1);
  });

  test('non-radius location choices do not create a radius', () {
    const filter = DiscoveryFilter(distanceLabel: 'Same City');

    expect(filter.effectiveMaxDistanceKm, isNull);
    expect(filter.activeCount, 1);
  });
}
