import 'package:flutter_test/flutter_test.dart';
import 'package:mithaq/core/models/onboarding_data.dart';

void main() {
  test('persists stateName separately from cityName', () {
    const data = OnboardingData(
      countryCode: 'IN',
      stateName: 'Andhra Pradesh',
      cityName: 'Kurnool, Andhra Pradesh',
    );

    final restored = OnboardingData.fromJson(data.toJson());

    expect(restored.countryCode, 'IN');
    expect(restored.stateName, 'Andhra Pradesh');
    expect(restored.cityName, 'Kurnool, Andhra Pradesh');
  });
}
