import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final containmentMigration = File(
    'supabase/migrations/160_second_audit_privilege_boundary.sql',
  ).readAsStringSync();
  final authCubit = File(
    'lib/core/cubits/auth/auth_cubit.dart',
  ).readAsStringSync();

  test('registration status oracles are unavailable to API callers', () {
    expect(containmentMigration, contains('email_registration_status(text)'));
    expect(containmentMigration, contains('email_is_registered(text)'));
    expect(
      containmentMigration,
      contains('FROM PUBLIC, anon, authenticated'),
    );
  });

  test('OTP requests do not preflight whether an account exists', () {
    expect(authCubit, isNot(contains("'email_registration_status'")));
    expect(authCubit, isNot(contains("'email_is_registered'")));
    expect(authCubit, isNot(contains('_EmailRegistrationStatus')));
    expect(authCubit, contains('bindPendingTransactionToEmail'));
    expect(
      authCubit,
      contains('We could not send a verification code.'),
    );
  });

  test('concurrent submit events are coalesced before the OTP request', () {
    expect(authCubit, contains('OtpRequestCoalescer _otpRequests'));
    expect(authCubit, contains('return _otpRequests.run('));
    expect(authCubit, contains('() => _sendOtpOnce('));
    expect(
      RegExp(r'\.auth\.signInWithOtp\(').allMatches(authCubit),
      hasLength(1),
    );
  });
}
