import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

/// Exchanges device-bound sign-in codes from the verified SILARAH callback.
///
/// Callback credentials are consumed here and are never forwarded to widgets,
/// logs, analytics, or error messages.
class AuthCallbackService {
  AuthCallbackService._() : _auth = null;

  @visibleForTesting
  AuthCallbackService.forTesting(GoTrueClient auth) : _auth = auth;

  final GoTrueClient? _auth;

  static final instance = AuthCallbackService._();
  static const callbackHost = 'silarah.com';
  static const callbackPath = '/auth/callback';

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _subscription;
  Future<void>? _initialization;

  Future<void> initialize() => _initialization ??= _initializeOnce();

  Future<void> _initializeOnce() async {
    _subscription = _appLinks.uriLinkStream.listen(
      (uri) => unawaited(handleUri(uri)),
      onError: (_) {
        debugPrint('[AuthCallbackService] Auth callback stream unavailable.');
      },
    );

    final initialUri = await _appLinks.getInitialLink();
    if (initialUri != null) await handleUri(initialUri);
  }

  @visibleForTesting
  static bool isAuthCallback(Uri uri) =>
      uri.scheme == 'https' &&
      uri.host.toLowerCase() == callbackHost &&
      uri.port == 443 &&
      uri.userInfo.isEmpty &&
      uri.path == callbackPath;

  Future<bool> handleUri(Uri uri) async {
    if (!isAuthCallback(uri) || uri.hasFragment) return false;
    final auth = _auth ??
        (SupabaseService.isInitialized ? SupabaseService.client.auth : null);
    if (auth == null) return false;

    try {
      final codes = uri.queryParametersAll['code'];
      if (codes == null || codes.length != 1 || codes.single.trim().isEmpty) {
        return false;
      }
      if (const ['access_token', 'refresh_token', 'error', 'error_description']
          .any(uri.queryParameters.containsKey)) {
        return false;
      }

      // A matching hostname proves app routing, not who initiated sign-in.
      // PKCE requires this device's verifier; link-supplied tokens do not.
      await auth.exchangeCodeForSession(codes.single.trim());
      return true;
    } catch (_) {
      // Never include the URI or exception: either may contain credentials.
      debugPrint('[AuthCallbackService] Auth callback could not be completed.');
      return false;
    }
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    _initialization = null;
  }
}
