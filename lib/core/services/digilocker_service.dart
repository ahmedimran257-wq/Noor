import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:app_links/app_links.dart';
import 'package:url_launcher/url_launcher.dart';

import 'supabase_service.dart';

/// Optional India-only convenience path. The standard on-device KYC flow is
/// always the baseline and never waits on this provider.
class DigiLockerService {
  DigiLockerService._();
  static final instance = DigiLockerService._();

  static const _clientId = String.fromEnvironment('DIGILOCKER_CLIENT_ID');
  static const _redirectUri = String.fromEnvironment(
    'DIGILOCKER_REDIRECT_URI',
    defaultValue: 'mithaq://digilocker/callback',
  );
  static const _authorizeEndpoint =
      'https://digilocker.meripehchaan.gov.in/public/oauth2/1/authorize';

  bool get isConfigured => _clientId.isNotEmpty;

  Future<bool> verifyOptionalAadhaar() async {
    if (!isConfigured || !SupabaseService.isInitialized) return false;

    final state = _randomState();
    final link = AppLinks();
    final callback = Completer<Uri>();
    late final StreamSubscription<Uri> subscription;
    subscription = link.uriLinkStream.listen((uri) {
      if (uri.scheme == 'mithaq' &&
          uri.host == 'digilocker' &&
          uri.path == '/callback' &&
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
        },
      );
      if (!await launchUrl(authorizeUri,
          mode: LaunchMode.externalApplication)) {
        return false;
      }
      final result = await callback.future.timeout(const Duration(minutes: 5));
      final code = result.queryParameters['code'];
      if (code == null || code.isEmpty) return false;
      final response = await SupabaseService.client.functions.invoke(
        'digilocker-verify',
        body: {'code': code, 'redirect_uri': _redirectUri},
      );
      return response.status >= 200 &&
          response.status < 300 &&
          response.data is Map &&
          (response.data as Map)['status'] == 'verified';
    } on TimeoutException {
      return false;
    } finally {
      await subscription.cancel();
    }
  }

  String _randomState() {
    final bytes = List<int>.generate(24, (_) => Random.secure().nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }
}
