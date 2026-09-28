import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:silarah/core/services/auth_callback_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _VerifierStorage extends GotrueAsyncStorage {
  String? value;

  @override
  Future<String?> getItem({required String key}) async => value;

  @override
  Future<void> setItem({required String key, required String value}) async {
    this.value = value;
  }

  @override
  Future<void> removeItem({required String key}) async => value = null;
}

Map<String, dynamic> _session(String userId) => {
      'access_token': 'fixture-access-token',
      'refresh_token': 'fixture-refresh-token',
      'token_type': 'bearer',
      'expires_in': 3600,
      'user': {
        'id': userId,
        'app_metadata': <String, dynamic>{},
        'user_metadata': <String, dynamic>{},
        'aud': 'authenticated',
        'created_at': '2026-01-01T00:00:00Z',
      },
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late GoTrueClient auth;
  late AuthCallbackService callbacks;
  late _VerifierStorage storage;
  late List<http.Request> requests;
  late bool rejectExchange;

  setUp(() async {
    storage = _VerifierStorage();
    requests = [];
    rejectExchange = false;
    auth = GoTrueClient(
      url: 'https://auth.example.invalid',
      autoRefreshToken: false,
      flowType: AuthFlowType.pkce,
      asyncStorage: storage,
      httpClient: MockClient((request) async {
        requests.add(request);
        if (rejectExchange) {
          return http.Response(
              jsonEncode({'msg': 'Invalid code', 'code': 'invalid_grant'}),
              400);
        }
        return http.Response(jsonEncode(_session('link-account')), 200);
      }),
    );
    await auth.setInitialSession(jsonEncode(_session('original-account')));
    callbacks = AuthCallbackService.forTesting(auth);
  });

  tearDown(() async {
    await callbacks.dispose();
    auth.dispose();
  });

  test('link credentials cannot replace the current account', () async {
    for (final link in [
      'https://silarah.com/auth/callback#refresh_token=attacker-token',
      'https://silarah.com/auth/callback#%72efresh_token=attacker-token',
      'https://silarah.com/auth/callback#access_token=attacker&refresh_token=attacker-token',
      'https://silarah.com/auth/callback?refresh_token=attacker-token',
      'https://silarah.com/auth/callback?code=one&refresh_token=attacker-token',
      'https://silarah.com/auth/callback?code=one&access_token=attacker-token',
      'https://silarah.com/auth/callback?code=one&code=two',
      'https://silarah.com/auth/callback?code=',
      'https://silarah.com/auth/callback?code=one#refresh_token=attacker-token',
      'https://silarah.com/auth/callback?code=one&error=access_denied',
      'https://attacker.example/auth/callback?code=one',
      'http://silarah.com/auth/callback?code=one',
      'https://silarah.com:444/auth/callback?code=one',
      'https://name@silarah.com/auth/callback?code=one',
    ]) {
      storage.value = 'device-verifier';
      expect(await callbacks.handleUri(Uri.parse(link)), isFalse,
          reason: 'Rejected callback must not install a session');
      expect(requests, isEmpty);
      expect(auth.currentUser?.id, 'original-account');
      expect(storage.value, 'device-verifier');
    }
  });

  test('a sign-in code without this device verifier cannot change accounts',
      () async {
    expect(
      await callbacks.handleUri(
        Uri.parse('https://silarah.com/auth/callback?code=other-device-code'),
      ),
      isFalse,
    );
    expect(requests, isEmpty);
    expect(auth.currentUser?.id, 'original-account');
  });

  test('valid PKCE code uses the device verifier and cannot be replayed',
      () async {
    storage.value = 'device-verifier';
    final callback =
        Uri.parse('https://silarah.com/auth/callback?code=valid-code');
    expect(await callbacks.handleUri(callback), isTrue);
    expect(requests, hasLength(1));
    expect(requests.single.url.queryParameters['grant_type'], 'pkce');
    expect(jsonDecode(requests.single.body), {
      'auth_code': 'valid-code',
      'code_verifier': 'device-verifier',
    });
    expect(auth.currentUser?.id, 'link-account');
    expect(storage.value, isNull);
    expect(await callbacks.handleUri(callback), isFalse);
    expect(requests, hasLength(1));
  });

  test('app callback is the sole URI session handler and stays PKCE-only', () {
    final source =
        File('lib/core/services/supabase_service.dart').readAsStringSync();
    expect(source, contains('detectSessionInUri: false'));
    expect(source, contains('authFlowType: AuthFlowType.pkce'));
  });

  test('a rejected code preserves the current session', () async {
    storage.value = 'device-verifier';
    rejectExchange = true;
    expect(
      await callbacks.handleUri(
        Uri.parse('https://silarah.com/auth/callback?code=invalid-code'),
      ),
      isFalse,
    );
    expect(requests, hasLength(1));
    expect(auth.currentUser?.id, 'original-account');
  });

  test('numeric email OTP sign-in still works without a callback verifier',
      () async {
    await auth.verifyOTP(
      email: 'member@example.invalid',
      token: '123456',
      type: OtpType.email,
    );
    expect(requests.single.url.path, '/verify');
    expect(auth.currentUser?.id, 'link-account');
    expect(storage.value, isNull);
  });
}
