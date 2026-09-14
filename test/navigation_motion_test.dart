import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:silarah/core/theme/app_colors.dart';
import 'package:silarah/core/theme/app_theme.dart';

const _surface = ValueKey('detail-surface');

Widget _detail() => const Scaffold(
      key: _surface,
      backgroundColor: Colors.white,
      body: Center(child: Text('Detail')),
    );

void main() {
  tearDown(() => AppColors.activate(SilarahThemeMode.blackWhite));

  for (final direction in TextDirection.values) {
    testWidgets('opaque push/pop is continuous in $direction', (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(MaterialApp(
        navigatorKey: navigator,
        theme: AppTheme.forMode(SilarahThemeMode.blackWhite),
        builder: (_, child) =>
            Directionality(textDirection: direction, child: child!),
        home: const Scaffold(body: Text('Home')),
      ));
      final route = MaterialPageRoute<void>(builder: (_) => _detail());
      navigator.currentState!.push(route);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final sign = direction == TextDirection.ltr ? 1 : -1;
      final width =
          tester.view.physicalSize.width / tester.view.devicePixelRatio;
      final start = tester.getTopLeft(find.byKey(_surface)).dx * sign;
      expect(start, greaterThan(0));
      expect(start, lessThan(width));
      expect(
          find.ancestor(
              of: find.byKey(_surface), matching: find.byType(FadeTransition)),
          findsNothing,
          reason: 'Whole screens must not become transparent over each other.');
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.byKey(_surface)).dx, closeTo(0, .01));

      navigator.currentState!.pop();
      await tester.pump();
      var previous = 0.0;
      for (var frame = 0; frame < 25; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        final x = tester.getTopLeft(find.byKey(_surface)).dx * sign;
        expect(x, greaterThanOrEqualTo(previous - .01),
            reason: 'Back must never reverse or snap.');
        expect(x - previous, lessThan(width * .2),
            reason: 'No single-frame route jump.');
        previous = x;
      }
      await tester.pumpAndSettle();
      expect(find.byKey(_surface), findsNothing);
      expect(find.text('Home'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('a cancelled edge swipe restores the same page', (tester) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigator,
      theme: AppTheme.forMode(SilarahThemeMode.ivoryEmerald),
      home: const Scaffold(body: Text('Home')),
    ));
    navigator.currentState!
        .push(MaterialPageRoute<void>(builder: (_) => _detail()));
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(const Offset(1, 200));
    await gesture.moveBy(const Offset(150, 0));
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.getTopLeft(find.byKey(_surface)).dx, greaterThan(0));
    await gesture.moveBy(const Offset(-120, 0));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.byKey(_surface), findsOneWidget);
    expect(tester.getTopLeft(find.byKey(_surface)).dx, closeTo(0, .01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('router and imperative routes share one transition',
      (tester) async {
    final router = GoRouter(routes: [
      GoRoute(
          path: '/',
          pageBuilder: (_, state) => MaterialPage<void>(
              key: state.pageKey, child: const Scaffold(body: Text('Home')))),
      GoRoute(
          path: '/detail',
          pageBuilder: (_, state) =>
              MaterialPage<void>(key: state.pageKey, child: _detail())),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(
      theme: AppTheme.forMode(SilarahThemeMode.oled),
      routerConfig: router,
    ));
    router.push<void>('/detail');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.byType(CupertinoPageTransition), findsWidgets);
    expect(
        find.ancestor(
            of: find.byKey(_surface), matching: find.byType(FadeTransition)),
        findsNothing);
    await tester.pumpAndSettle();
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('reduced motion leaves page geometry stationary', (tester) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigator,
      theme: AppTheme.forMode(SilarahThemeMode.blackWhite),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!,
      ),
      home: const Scaffold(body: Text('Home')),
    ));
    navigator.currentState!
        .push(MaterialPageRoute<void>(builder: (_) => _detail()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.getTopLeft(find.byKey(_surface)).dx, 0);
    expect(find.byType(CupertinoPageTransition), findsNothing);
    await tester.pumpAndSettle();
  });

  test('profile media cannot fly between differently cropped surfaces', () {
    final source = File('lib/features/home/screens/profile_detail_screen.dart')
        .readAsStringSync();
    expect(source, isNot(contains('background: Hero(')));
    final router = File('lib/core/router/app_router.dart').readAsStringSync();
    expect(router, isNot(contains('CustomTransitionPage')));
  });
}
