import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:app_links/app_links.dart';
import 'package:crypto/crypto.dart';
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
/// authorization only; the server grants KYC only after matching DigiLocker
/// account data and HMAC-authenticated issued-document XML.
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

  bool get isConfigured => _clientId.isNotEmpty;

  Future<DigiLockerVerificationResult> verifyIdentity() async {
    if (!isConfigured || !SupabaseService.isInitialized) {
      return const DigiLockerVerificationResult(
        status: DigiLockerVerificationStatus.unavailable,
        message: 'DigiLocker verification is unavailable on this build.',
      );
    }

    final state = _randomState();
    final codeVerifier = _randomCodeVerifier();
    final codeChallenge = base64Url
        .encode(sha256.convert(utf8.encode(codeVerifier)).bytes)
        .replaceAll('=', '');
    final link = AppLinks();
    final callback = Completer<Uri>();
    late final StreamSubscription<Uri> subscription;
    subscription = link.uriLinkStream.listen((uri) {
      if (uri.scheme == 'https' &&
          uri.host == 'silarah.com' &&
          uri.path == '/auth/digilocker/callback' &&
          uri.queryParameters['state'] == state &&
          !callback.isCompleted) {
        callback.complete(uri);
      }
    });

    try {
      final authorizeUri = Uri.parse(_authorizeEndpoint).replace(
        queryParameters: {
          'response_type': 'code',
          'client_id': _clientId,
          'redirect_uri': _redirectUri,
          'state': state,
          'scope': 'openid files.issueddocs',
          'req_doctype': 'ADHAR,PANCR,DRVLC',
          'code_challenge': codeChallenge,
          'code_challenge_method': 'S256',
        },
      );
      if (!await launchUrl(authorizeUri,
          mode: LaunchMode.externalApplication)) {
        return const DigiLockerVerificationResult(
          status: DigiLockerVerificationStatus.unavailable,
          message: 'Could not open DigiLocker securely.',
        );
      }
      final result = await callback.future.timeout(const Duration(minutes: 5));
      if (result.queryParameters['error'] != null) {
        return const DigiLockerVerificationResult(
          status: DigiLockerVerificationStatus.cancelled,
          message: 'DigiLocker authorization was cancelled.',
        );
      }
      final code = result.queryParameters['code'];
      if (code == null || code.isEmpty) {
        return const DigiLockerVerificationResult(
          status: DigiLockerVerificationStatus.authorizationFailed,
          message: 'DigiLocker did not return an authorization code.',
        );
      }
      final response = await SupabaseService.client.functions.invoke(
        'digilocker-verify',
        body: {
          'code': code,
          'redirect_uri': _redirectUri,
          'code_verifier': codeVerifier,
        },
      );
      final data = response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : const <String, dynamic>{};
      final status = data['status']?.toString();
      final message = data['message']?.toString();
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
        message: message ??
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
      await subscription.cancel();
    }
  }

  String _randomState() {
    final bytes = List<int>.generate(24, (_) => Random.secure().nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  String _randomCodeVerifier() {
    final bytes = List<int>.generate(64, (_) => Random.secure().nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }
}
