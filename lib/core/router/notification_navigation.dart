import 'package:flutter/widgets.dart';
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

/// Returns from a full-screen route without ever exposing an empty navigator.
///
/// External notification routes intentionally become the router root. Such a
/// route has nothing to pop, so a raw Navigator.pop() leaves a blank platform
/// surface. Ordinary in-app pushes still pop normally; notification roots
/// return to their stable home tab.
void popOrGoToFallback(GoRouter router, String fallbackPath) {
  if (!fallbackPath.startsWith('/')) {
    throw ArgumentError.value(
      fallbackPath,
      'fallbackPath',
      'Must be an absolute app path',
    );
  }
  if (router.canPop()) {
    router.pop();
  } else {
    router.go(fallbackPath);
  }
}

/// Gives a route opened as an external-notification root a safe system Back
/// destination while preserving ordinary in-app push/pop behavior.
class NotificationRouteBackScope extends StatelessWidget {
  const NotificationRouteBackScope({
    super.key,
    required this.fallbackPath,
    required this.child,
  });

  final String fallbackPath;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final router = GoRouter.of(context);
    return PopScope(
      canPop: router.canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) popOrGoToFallback(router, fallbackPath);
      },
      child: child,
    );
  }
}

/// Keeps Android Back predictable when a notification opens a secondary home
/// tab as the app's root destination.
///
/// Bottom-navigation tabs are not navigator pages. Allowing the platform Back
/// action to pop the root while Messages, Interests, or Profile is selected can
/// expose the activity's launch surface on some Android builds. Return to
/// Discover first; a second Back from Discover retains the normal Android exit
/// behavior.
class HomeTabBackScope extends StatelessWidget {
  const HomeTabBackScope({
    super.key,
    required this.currentTab,
    required this.onReturnToPrimaryTab,
    required this.child,
  });

  final int currentTab;
  final VoidCallback onReturnToPrimaryTab;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: currentTab == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && currentTab != 0) onReturnToPrimaryTab();
      },
      child: child,
    );
  }
}
