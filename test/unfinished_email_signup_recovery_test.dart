import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    'supabase/migrations/124_recover_unfinished_email_signup.sql',
  ).readAsStringSync();
  final authCubit = File(
    'lib/core/cubits/auth/auth_cubit.dart',
  ).readAsStringSync();

  test('registration status distinguishes pending from confirmed users', () {
    expect(migration, contains('email_registration_status'));
    expect(migration, contains("THEN 'pending_verification'"));
    expect(migration, contains('email_confirmed_at IS NOT NULL'));
    expect(
      migration,
      contains("email_registration_status(p_email) = 'registered'"),
    );
  });

  test('pending signup requests a new OTP instead of duplicate-account error',
      () {
    expect(authCubit, contains("'email_registration_status'"));
    expect(
      authCubit,
      contains('registrationStatus == _EmailRegistrationStatus.registered'),
    );
    expect(
      authCubit,
      contains('registrationStatus == _EmailRegistrationStatus.unregistered'),
    );
    expect(
      authCubit,
      contains('Your signup is not finished.'),
    );
    expect(authCubit, isNot(contains("'email_is_registered'")));
  });

  test('concurrent submit events are coalesced before registration lookup', () {
    expect(authCubit, contains('OtpRequestCoalescer _otpRequests'));
    expect(authCubit, contains('return _otpRequests.run('));
    expect(authCubit, contains('() => _sendOtpOnce('));
    expect(
      RegExp(r'\.auth\.signInWithOtp\(').allMatches(authCubit),
      hasLength(1),
    );
  });
}
