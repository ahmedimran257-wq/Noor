import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:silarah/core/cubits/onboarding/onboarding_state.dart';
import 'package:silarah/core/models/onboarding_data.dart';

void main() {
  // Regression: completion emitted a data-less state, so the Profile tab
  // opened right after onboarding showed "Your Name" and no city.
  test('completed onboarding keeps the saved profile', () {
    const data = OnboardingData(firstName: 'Ayesha', lastName: 'Test');
    const state = OnboardingComplete(data: data);

    expect(state.data.firstName, 'Ayesha');
    expect(state, isNot(const OnboardingComplete()));
  });

  test('cubit emits and exposes the saved data on completion', () {
    final cubit = File('lib/core/cubits/onboarding/onboarding_cubit.dart')
        .readAsStringSync();

    expect(cubit, contains('emit(OnboardingComplete(data: updatedData));'));
    expect(cubit, contains('if (s is OnboardingComplete) return s.data;'));
    expect(cubit, isNot(contains('emit(const OnboardingComplete());')));
  });
}
