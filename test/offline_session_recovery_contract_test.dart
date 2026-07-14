import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:silarah/core/services/supabase_service.dart';

void main() {
  test('session recovery distinguishes absence, invalidity and transience', () {
    const absent = SessionRecoveryResult.noSession();
    const transient = SessionRecoveryResult.transientFailure('offline');
    const invalid = SessionRecoveryResult.invalidSession('revoked');

    expect(absent.status, SessionRecoveryStatus.noSession);
    expect(transient.status, SessionRecoveryStatus.transientFailure);
    expect(invalid.status, SessionRecoveryStatus.invalidSession);
  });

  test('offline initial session cannot emit a false logout', () {
    final auth =
        File('lib/core/cubits/auth/auth_cubit.dart').readAsStringSync();
    final handler = auth.substring(
      auth.indexOf('Future<void> _handleAuthEvent'),
      auth.indexOf('Future<void> _emitAuthenticatedFromSession'),
    );

    expect(
      handler.indexOf('if (event == AuthChangeEvent.initialSession) return;'),
      lessThan(handler.indexOf('SupabaseService.recoverSession()')),
    );
    expect(auth, contains('AuthSessionCheckResult.retryableFailure'));
    expect(auth, contains('SessionRecoveryStatus.transientFailure'));
    expect(auth, contains('const AuthLoading()'));
  });

  test('profile read failure cannot masquerade as onboarding step zero', () {
    final auth =
        File('lib/core/cubits/auth/auth_cubit.dart').readAsStringSync();

    expect(auth, contains('throw AuthProfileHydrationException(e)'));
    expect(auth, contains('await _emitAuthenticatedFromSession'));
    expect(
      auth.indexOf('_hydratedSessionUserId = userId;'),
      greaterThan(auth.indexOf('final authData = await _loadUserProfile')),
    );
  });

  test('startup gate opens only after identity recovery is authoritative', () {
    final main = File('lib/main.dart').readAsStringSync();

    expect(main, contains('final result = await _authCubit.checkSession()'));
    expect(main, contains('AuthSessionCheckResult.authenticated'));
    expect(main, contains('AuthSessionCheckResult.signedOut'));
    expect(main, contains('_startupRecoveryInFlight'));
    expect(
      main.indexOf('_StartupNetworkState.ready',
          main.indexOf('final result = await _authCubit.checkSession()')),
      greaterThan(
          main.indexOf('final result = await _authCubit.checkSession()')),
    );
  });
}
