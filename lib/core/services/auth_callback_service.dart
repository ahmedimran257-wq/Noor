import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

import 'supabase_service.dart';

/// Installs sessions returned through the verified SILARAH auth callback.
///
/// Callback credentials are consumed here and are never forwarded to widgets,
/// logs, analytics, or error messages.
class AuthCallbackService {
  AuthCallbackService._();

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
      uri.path == callbackPath;

  Future<bool> handleUri(Uri uri) async {
    if (!isAuthCallback(uri) || !SupabaseService.isInitialized) return false;

    try {
      final code = uri.queryParameters['code']?.trim();
      if (code != null && code.isNotEmpty) {
        await SupabaseService.client.auth.exchangeCodeForSession(code);
        return true;
      }

      final fragment = uri.fragment.isEmpty
          ? const <String, String>{}
          : Uri.splitQueryString(uri.fragment);
      final refreshToken = fragment['refresh_token']?.trim();
      if (refreshToken == null || refreshToken.isEmpty) return false;

      await SupabaseService.client.auth.setSession(refreshToken);
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
