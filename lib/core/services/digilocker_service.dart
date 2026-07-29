import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:app_links/app_links.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher.dart';

import 'supabase_service.dart';

enum DigiLockerVerificationStatus {
  verified,
  identityMismatch,
  insufficientEvidence,
  authorizationFailed,
  cancelled,
  unavailable,
  providerError,
}

class DigiLockerVerificationResult {
  const DigiLockerVerificationResult({
    required this.status,
    required this.message,
    this.reason,
  });

  final DigiLockerVerificationStatus status;
  final String message;
  final String? reason;

  bool get isVerified => status == DigiLockerVerificationStatus.verified;
}

/// Optional India-only evidence-based identity verification. OAuth success is
/// authorization only; the server grants KYC after verifying issued evidence.
///
/// The PKCE verifier and state are encrypted at rest and tied to the current
/// account. This lets a callback be completed after Android kills the process
/// without accepting a callback created for another signed-in identity.
class DigiLockerService {
  DigiLockerService._();
  static final instance = DigiLockerService._();

  static const _clientId = String.fromEnvironment('DIGILOCKER_CLIENT_ID');
  static const _redirectUri = String.fromEnvironment(
    'DIGILOCKER_REDIRECT_URI',
    defaultValue: 'https://silarah.com/auth/digilocker/callback',
  );
  static const _authorizeEndpoint =
      'https://digilocker.meripehchaan.gov.in/public/oauth2/1/authorize';
  static const _attemptKey = 'digilocker_oauth_attempt_v1';
  static const _attemptLifetime = Duration(minutes: 10);
  static const _storage = FlutterSecureStorage();

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;
  Completer<Uri>? _callbackCompleter;
  Uri? _pendingCallback;
  Future<DigiLockerVerificationResult>? _inFlight;
  bool _initialized = false;

  bool get isConfigured => _clientId.isNotEmpty;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    _linkSubscription = _appLinks.uriLinkStream.listen(_captureCallback);
    final initial = await _appLinks.getInitialLink();
    if (initial != null) _captureCallback(initial);
  }

  Future<void> shutdownForTesting() async {
    await _linkSubscription?.cancel();
    _linkSubscription = null;
    _initialized = false;
  }

  Future<DigiLockerVerificationResult> verifyIdentity() {
    return _inFlight ??= _verifyIdentityOnce().whenComplete(() {
      _inFlight = null;
    });
  }

  Future<DigiLockerVerificationResult> _verifyIdentityOnce() async {
    if (!isConfigured || !SupabaseService.isInitialized) {
      return const DigiLockerVerificationResult(
        status: DigiLockerVerificationStatus.unavailable,
        message: 'DigiLocker verification is unavailable on this build.',
      );
    }
    await initialize();

    final userId = SupabaseService.currentUserId;
    if (userId == null) {
      return const DigiLockerVerificationResult(
        status: DigiLockerVerificationStatus.authorizationFailed,
        message: 'Sign in again before using DigiLocker.',
      );
    }

    var attempt = await _loadAttempt(userId);
    var callback = _takeMatchingPendingCallback(attempt?.state);
    if (attempt == null || callback == null) {
      attempt ??= await _createAttempt(userId);
      callback = _takeMatchingPendingCallback(attempt.state);
    }

    try {
      if (callback == null) {
        final authorizeUri = Uri.parse(_authorizeEndpoint).replace(
          queryParameters: {
            'response_type': 'code',
            'client_id': _clientId,
            'redirect_uri': _redirectUri,
            'state': attempt.state,
            'scope': 'openid files.issueddocs',
            'req_doctype': 'ADHAR,PANCR,DRVLC',
            'code_challenge': attempt.codeChallenge,
            'code_challenge_method': 'S256',
          },
        );
        _callbackCompleter = Completer<Uri>();
        if (!await launchUrl(
          authorizeUri,
          mode: LaunchMode.externalApplication,
        )) {
          return const DigiLockerVerificationResult(
            status: DigiLockerVerificationStatus.unavailable,
            message: 'Could not open DigiLocker securely.',
          );
        }
        callback = _takeMatchingPendingCallback(attempt.state) ??
            await _callbackCompleter!.future.timeout(
              const Duration(minutes: 10),
            );
      }

      if (callback.queryParameters['state'] != attempt.state) {
        return const DigiLockerVerificationResult(
          status: DigiLockerVerificationStatus.authorizationFailed,
          message: 'DigiLocker returned an invalid authorization response.',
        );
      }
      if (callback.queryParameters['error'] != null) {
        return const DigiLockerVerificationResult(
          status: DigiLockerVerificationStatus.cancelled,
          message: 'DigiLocker authorization was cancelled.',
        );
      }
      final code = callback.queryParameters['code'];
      if (code == null || code.isEmpty) {
        return const DigiLockerVerificationResult(
          status: DigiLockerVerificationStatus.authorizationFailed,
          message: 'DigiLocker did not return an authorization code.',
        );
      }

      // Recheck the account after the external app round trip.
      if (SupabaseService.currentUserId != attempt.userId) {
        return const DigiLockerVerificationResult(
          status: DigiLockerVerificationStatus.authorizationFailed,
          message: 'The signed-in account changed during verification.',
        );
      }
      final response = await SupabaseService.client.functions.invoke(
        'digilocker-verify',
        body: {
          'code': code,
          'redirect_uri': _redirectUri,
          'code_verifier': attempt.codeVerifier,
        },
      );
      final data = response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : const <String, dynamic>{};
      final status = data['status']?.toString();
      return DigiLockerVerificationResult(
        status: switch (status) {
          'verified' => DigiLockerVerificationStatus.verified,
          'identity_mismatch' => DigiLockerVerificationStatus.identityMismatch,
          'insufficient_evidence' =>
            DigiLockerVerificationStatus.insufficientEvidence,
          'authorization_failed' =>
            DigiLockerVerificationStatus.authorizationFailed,
          'unavailable' => DigiLockerVerificationStatus.unavailable,
          _ => DigiLockerVerificationStatus.providerError,
        },
        message: data['message']?.toString() ??
            'DigiLocker evidence could not be verified. No badge was granted.',
        reason: data['reason']?.toString(),
      );
    } on TimeoutException {
      return const DigiLockerVerificationResult(
        status: DigiLockerVerificationStatus.cancelled,
        message: 'DigiLocker authorization timed out. No badge was granted.',
      );
    } catch (_) {
      return const DigiLockerVerificationResult(
        status: DigiLockerVerificationStatus.providerError,
        message:
            'DigiLocker evidence could not be verified. No badge was granted.',
      );
    } finally {
      _callbackCompleter = null;
      await _storage.delete(key: _attemptKey);
    }
  }

  void _captureCallback(Uri uri) {
    if (!_isCallback(uri)) return;
    final completer = _callbackCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete(uri);
    } else {
      _pendingCallback = uri;
    }
  }

  Uri? _takeMatchingPendingCallback(String? state) {
    final callback = _pendingCallback;
    if (callback == null ||
        state == null ||
        callback.queryParameters['state'] != state) {
      return null;
    }
    _pendingCallback = null;
    return callback;
  }

  bool _isCallback(Uri uri) {
    final expected = Uri.parse(_redirectUri);
    return uri.scheme == expected.scheme &&
        uri.host == expected.host &&
        uri.path == expected.path;
  }

  Future<_DigiLockerAttempt?> _loadAttempt(String userId) async {
    try {
      final raw = await _storage.read(key: _attemptKey);
      if (raw == null) return null;
      final attempt = _DigiLockerAttempt.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
      if (attempt.userId != userId ||
          DateTime.now().difference(attempt.createdAt) > _attemptLifetime) {
        await _storage.delete(key: _attemptKey);
        return null;
      }
      return attempt;
    } catch (_) {
      await _storage.delete(key: _attemptKey);
      return null;
    }
  }

  Future<_DigiLockerAttempt> _createAttempt(String userId) async {
    final codeVerifier = _randomToken(64);
    final attempt = _DigiLockerAttempt(
      userId: userId,
      state: _randomToken(24),
      codeVerifier: codeVerifier,
      codeChallenge: base64Url
          .encode(sha256.convert(utf8.encode(codeVerifier)).bytes)
          .replaceAll('=', ''),
      createdAt: DateTime.now().toUtc(),
    );
    await _storage.write(
      key: _attemptKey,
      value: jsonEncode(attempt.toJson()),
    );
    return attempt;
  }

  String _randomToken(int length) {
    final bytes = List<int>.generate(
      length,
      (_) => Random.secure().nextInt(256),
    );
    return base64UrlEncode(bytes).replaceAll('=', '');
  }
}

class _DigiLockerAttempt {
  const _DigiLockerAttempt({
    required this.userId,
    required this.state,
    required this.codeVerifier,
    required this.codeChallenge,
    required this.createdAt,
  });

  factory _DigiLockerAttempt.fromJson(Map<String, dynamic> json) {
    return _DigiLockerAttempt(
      userId: json['user_id'] as String,
      state: json['state'] as String,
      codeVerifier: json['code_verifier'] as String,
      codeChallenge: json['code_challenge'] as String,
      createdAt: DateTime.parse(json['created_at'] as String).toUtc(),
    );
  }

  final String userId;
  final String state;
  final String codeVerifier;
  final String codeChallenge;
  final DateTime createdAt;

  Map<String, String> toJson() => {
        'user_id': userId,
        'state': state,
        'code_verifier': codeVerifier,
        'code_challenge': codeChallenge,
        'created_at': createdAt.toIso8601String(),
      };
}
