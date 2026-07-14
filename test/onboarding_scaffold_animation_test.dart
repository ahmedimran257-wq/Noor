import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silarah/core/cubits/auth/auth_cubit.dart';
import 'package:silarah/core/cubits/auth/auth_state.dart';
import 'package:silarah/core/cubits/onboarding/onboarding_cubit.dart';
import 'package:silarah/features/onboarding/widgets/onboarding_scaffold.dart';

class _SeededAuthCubit extends AuthCubit {
  void seed(AuthState state) => emit(state);
}

void main() {
  testWidgets('delayed CTA reveal keeps opacity inside Flutter bounds',
      (tester) async {
    final authCubit = _SeededAuthCubit()
      ..seed(const AuthAuthenticated(
        userId: 'user-1',
        onboardingStep: 1,
        email: 'user@example.com',
      ));
    final onboardingCubit = OnboardingCubit(authCubit: authCubit);
    addTearDown(authCubit.close);
    addTearDown(onboardingCubit.close);

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: onboardingCubit,
          child: OnboardingScaffold(
            step: 1,
            totalSteps: 5,
            body: const Text('Where are you?'),
            ctaLabel: 'Continue',
            onCta: () {},
          ),
        ),
      ),
    );

    await tester.pump(const Duration(seconds: 1));

    expect(tester.takeException(), isNull);
  });
}
