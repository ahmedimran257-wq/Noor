import 'package:go_router/go_router.dart';

/// Opens an external push destination as the router's canonical location.
///
/// A terminated Android app can be launched with an empty platform route.
/// Stacking a push destination on that route preserves an invalid base that
/// fails when authentication refreshes. Replacing it also gives notification
/// taps the expected single, deterministic entry point.
void navigateFromPushNotification(GoRouter router, String path) {
  if (!path.startsWith('/')) {
    throw ArgumentError.value(path, 'path', 'Must be an absolute app path');
  }
  router.go(path);
}
