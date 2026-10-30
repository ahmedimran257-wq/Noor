import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final auth = File('lib/core/cubits/auth/auth_cubit.dart').readAsStringSync();
  final snapshot =
      File('lib/core/services/my_account_snapshot.dart').readAsStringSync();

  test('account restore runs only for accounts awaiting deletion', () {
    // It used to run first on every launch, a write and a round trip in
    // front of every other startup read.
    final hydrate = auth.substring(
      auth.indexOf('Future<void> _emitAuthenticatedFromSession('),
      auth.indexOf('/// Sends an OTP to the provided email address.'),
    );
    expect(hydrate, isNot(contains('_recoverPendingDeletionForSession')));
    expect(
      auth,
      contains("if (userRow?['deletion_status'] == 'pending_deletion') {"),
    );
    expect(snapshot, contains('deletion_status'));
  });

  test('user and profile rows load together at startup', () {
    final profileStart =
        auth.indexOf('final profileLoad = MyAccountSnapshot.instance.profile');
    final userRead =
        auth.indexOf('userRow = await MyAccountSnapshot.instance.user');
    expect(profileStart, isNonNegative);
    expect(userRead, greaterThan(profileStart));
  });
}
