import 'package:flutter_test/flutter_test.dart';
import 'package:mithaq/core/mock/mock_profiles.dart';
import 'package:mithaq/core/models/onboarding_data.dart';
import 'package:mithaq/core/services/compatibility_service.dart';

void main() {
  const candidateBase = MockProfile(
    firstName: 'A',
    lastNameInitial: 'B',
    age: 28,
    cityName: 'Hyderabad',
    sect: 'sunni',
    deenLevel: 'practicing',
  );

  test('uses candidate preferences instead of candidate traits', () {
    final candidate = candidateBase.copyWith(
      partnerSect: 'shia',
      partnerDeenLevel: 'moderate',
      partnerEducationMinRank: 6,
    );
    const viewer = OnboardingData(
      sect: Sect.sunni,
      deenLevel: DeenLevel.practicing,
      educationRank: 5,
    );

    final result = calculateCompatibility(
      viewer: viewer,
      candidate: candidate,
    );

    expect(result.total, 3);
    expect(result.matched, 0);
  });

  test('matches age, same-as-mine, deen, and minimum education', () {
    final candidate = candidateBase.copyWith(
      partnerAgeMin: 24,
      partnerAgeMax: 30,
      partnerSect: 'Same as mine',
      partnerDeenLevel: 'practicing',
      partnerEducationMinRank: 5,
    );
    final viewer = OnboardingData(
      dateOfBirth: DateTime(2000, 7, 1),
      sect: Sect.sunni,
      deenLevel: DeenLevel.practicing,
      educationRank: 5,
    );

    final result = calculateCompatibility(
      viewer: viewer,
      candidate: candidate,
      today: DateTime(2026, 6, 22),
    );

    expect(result.total, 4);
    expect(result.matched, 4);
    expect(result.fraction, 1);
  });

  test('does not invent checks for unrestricted preferences', () {
    final candidate = candidateBase.copyWith(
      partnerSect: 'Any',
      partnerDeenLevel: 'No preference',
      partnerEducationMinRank: 1,
    );

    final result = calculateCompatibility(
      viewer: const OnboardingData(),
      candidate: candidate,
    );

    expect(result.total, 0);
    expect(result.matched, 0);
  });
}
