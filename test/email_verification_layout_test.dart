import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mithaq/core/cubits/auth/auth_cubit.dart';
import 'package:mithaq/core/cubits/auth/auth_state.dart';
import 'package:mithaq/core/cubits/onboarding/onboarding_cubit.dart';
import 'package:mithaq/features/onboarding/screens/email_verification_screen.dart';

class _DuplicateAccountAuthCubit extends AuthCubit {
  @override
  Future<void> sendOtp(
    String email, {
    String mode = 'signin',
    String? countryCode,
    bool isResend = false,
  }) async {
    emit(const AuthError(
      message: 'Account already exists. Please log in instead.',
    ));
  }
}

void main() {
  testWidgets(
    'account-found recovery stays keyboard-safe on compact screens',
    (tester) async {
      tester.view.devicePixelRatio = 2;
      tester.view.physicalSize = const Size(720, 1280);
      tester.view.viewInsets = const FakeViewPadding(bottom: 520);
      addTearDown(tester.view.reset);

      final authCubit = _DuplicateAccountAuthCubit();
      addTearDown(authCubit.close);

      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<AuthCubit>.value(value: authCubit),
            BlocProvider<OnboardingCubit>(
              create: (_) => OnboardingCubit(authCubit: authCubit),
            ),
          ],
          child: const MaterialApp(
            home: EmailVerificationScreen(mode: EmailAuthMode.signUp),
          ),
        ),
      );

      await tester.enterText(
        find.byType(TextField).first,
        'ahmedimran257@gmail.com',
      );
      await tester.ensureVisible(find.text('Send verification code'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send verification code'));
      await tester.pumpAndSettle();

      expect(find.text('Account found'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
