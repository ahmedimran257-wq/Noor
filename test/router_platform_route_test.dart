import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
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
}
