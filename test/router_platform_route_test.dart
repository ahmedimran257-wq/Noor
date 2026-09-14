import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:silarah/core/cubits/auth/auth_cubit.dart';
import 'package:silarah/core/router/app_router.dart';
import 'package:silarah/core/router/notification_navigation.dart';

void main() {
  test('router ignores empty platform routes from notification intents', () {
    final authCubit = AuthCubit();
    final router = buildAppRouter(
      authCubit,
      initialLocation: AppRoutes.boot,
    );
    addTearDown(() async {
      router.dispose();
      await authCubit.close();
    });

    expect(router.overridePlatformDefaultLocation, isTrue);
    expect(router.routeInformationProvider.value.uri.path, AppRoutes.boot);
  });

  test('push notification replaces the launch route with its destination', () {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, __) => const SizedBox.shrink()),
        GoRoute(
          path: '/notifications',
          builder: (_, __) => const SizedBox.shrink(),
        ),
      ],
    );
    addTearDown(router.dispose);

    navigateFromPushNotification(router, '/notifications');

    expect(
      router.routeInformationProvider.value.uri.path,
      '/notifications',
    );
  });

  test('push notification rejects a relative route', () {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, __) => const SizedBox.shrink()),
      ],
    );
    addTearDown(router.dispose);

    expect(
      () => navigateFromPushNotification(router, 'notifications'),
      throwsArgumentError,
    );
  });

  test('notification-root back returns to a stable fallback', () {
    final router = GoRouter(
      initialLocation: '/profile-views',
      routes: [
        GoRoute(
          path: '/profile-views',
          builder: (_, __) => const SizedBox.shrink(),
        ),
        GoRoute(path: '/home', builder: (_, __) => const SizedBox.shrink()),
      ],
    );
    addTearDown(router.dispose);

    popOrGoToFallback(router, '/home?tab=3');

    expect(router.routeInformationProvider.value.uri.path, '/home');
    expect(
        router.routeInformationProvider.value.uri.queryParameters['tab'], '3');
  });

  testWidgets('ordinary in-app back pops instead of replacing home',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(path: '/home', builder: (_, __) => const SizedBox.shrink()),
        GoRoute(
          path: '/profile-views',
          builder: (_, __) => const SizedBox.shrink(),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    final popped = router.push<void>('/profile-views');
    await tester.pumpAndSettle();

    popOrGoToFallback(router, '/home?tab=3');
    await tester.pumpAndSettle();
    await popped;

    expect(router.routeInformationProvider.value.uri.path, '/home');
    expect(router.routeInformationProvider.value.uri.query, isEmpty);
  });
}
