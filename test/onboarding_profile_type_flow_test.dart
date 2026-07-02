import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mithaq/core/cubits/auth/auth_cubit.dart';
import 'package:mithaq/core/cubits/auth/auth_state.dart';
import 'package:mithaq/core/cubits/onboarding/onboarding_cubit.dart';
import 'package:mithaq/core/cubits/onboarding/onboarding_state.dart';
import 'package:mithaq/core/models/onboarding_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SeededAuthCubit extends AuthCubit {
  void seed(AuthState state) => emit(state);
}

void main() {
  test('profile type step fails closed when progress cannot be saved',
      () async {
    SharedPreferences.setMockInitialValues({});
    final authCubit = _SeededAuthCubit()
      ..seed(const AuthAuthenticated(
        userId: 'user-1',
        onboardingStep: 0,
        email: 'user@example.com',
      ));
    addTearDown(authCubit.close);

    final onboardingCubit = OnboardingCubit(authCubit: authCubit);
    addTearDown(onboardingCubit.close);

    await onboardingCubit.saveAndAdvance(
      const OnboardingData(
        profileFor: ProfileFor.myself,
        profileCreatorRelation: 'self',
      ),
    );

    final onboardingState = onboardingCubit.state;
    final authState = authCubit.state;

    expect(onboardingState, isA<OnboardingError>());
    expect((onboardingState as OnboardingError).step, 0);
    expect(onboardingState.message, 'Could not save. Please try again.');
    expect(authState, isA<AuthAuthenticated>());
    expect((authState as AuthAuthenticated).onboardingStep, 0);
    expect(authState.isGuardianPath, isFalse);
  });

  test('quick location is not reached when profile type save fails', () async {
    SharedPreferences.setMockInitialValues({});
    final authCubit = _SeededAuthCubit()
      ..seed(const AuthAuthenticated(
        userId: 'user-1',
        onboardingStep: 0,
        email: 'user@example.com',
      ));
    addTearDown(authCubit.close);

    final onboardingCubit = OnboardingCubit(authCubit: authCubit);
    addTearDown(onboardingCubit.close);

    const profileTypeData = OnboardingData(
      profileFor: ProfileFor.myself,
      profileCreatorRelation: 'self',
    );
    await onboardingCubit.saveAndAdvance(profileTypeData);

    await onboardingCubit.saveAndAdvance(
      profileTypeData.copyWith(
        countryCode: 'IN',
        cityId: '123',
        cityName: 'Kurnool, Andhra Pradesh',
        lat: 15.8281,
        lng: 78.0373,
      ),
    );

    final onboardingState = onboardingCubit.state;
    final authState = authCubit.state;

    expect(onboardingState, isA<OnboardingError>());
    expect((onboardingState as OnboardingError).step, 0);
    expect(authState, isA<AuthAuthenticated>());
    expect((authState as AuthAuthenticated).onboardingStep, 0);
  });

  test('route step sync keeps Continue and Back on the visible screen',
      () async {
    final validProfileData = OnboardingData(
      profileFor: ProfileFor.myself,
      profileCreatorRelation: 'self',
      firstName: 'Imran',
      lastName: 'Ahmed',
      dateOfBirth: DateTime(2001, 7, 8),
      gender: Gender.male,
      countryCode: 'IN',
      cityId: '123',
      cityName: 'Kurnool',
      lat: 15.8281,
      lng: 78.0373,
      motherTongue: 'Urdu',
    );
    SharedPreferences.setMockInitialValues({
      'onboarding_data_cache_user-1': jsonEncode(validProfileData.toJson()),
    });
    final authCubit = _SeededAuthCubit()
      ..seed(const AuthAuthenticated(
        userId: 'user-1',
        onboardingStep: 3,
        email: 'user@example.com',
      ));
    addTearDown(authCubit.close);

    final onboardingCubit = OnboardingCubit(authCubit: authCubit);
    addTearDown(onboardingCubit.close);

    await onboardingCubit.initialize(startStep: 3);
    onboardingCubit.syncRouteStep(2);

    var onboardingState = onboardingCubit.state;
    expect(onboardingState, isA<OnboardingActive>());
    expect((onboardingState as OnboardingActive).step, 2);

    onboardingCubit.goBack();
    await Future<void>.delayed(Duration.zero);

    onboardingState = onboardingCubit.state;
    final authState = authCubit.state;
    expect(onboardingState, isA<OnboardingActive>());
    expect((onboardingState as OnboardingActive).step, 1);
    expect(authState, isA<AuthAuthenticated>());
    expect((authState as AuthAuthenticated).onboardingStep, 1);
  });
}
