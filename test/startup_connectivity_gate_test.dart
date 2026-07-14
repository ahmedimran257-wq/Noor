import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silarah/core/widgets/startup_offline_screen.dart';
import 'package:silarah/l10n/generated/app_localizations.dart';

Widget _testApp(Widget child, {bool disableAnimations = false}) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        disableAnimations: disableAnimations,
      ),
      child: child!,
    ),
    home: child,
  );
}

void main() {
  testWidgets('startup check remains outside authentication UI',
      (tester) async {
    await tester.pumpWidget(
      _testApp(const StartupOfflineScreen(checking: true)),
    );
    await tester.pump(const Duration(milliseconds: 550));

    expect(find.text('Preparing your private space'), findsOneWidget);
    expect(find.text('VERIFYING CONNECTION'), findsOneWidget);
    expect(find.text('Check connection'), findsNothing);
    expect(find.byType(CustomPaint), findsWidgets);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('offline retry is single-flight and reports a failed check',
      (tester) async {
    var calls = 0;
    final retryCompleter = Completer<bool>();

    await tester.pumpWidget(
      _testApp(
        StartupOfflineScreen(
          onRetry: () {
            calls++;
            return retryCompleter.future;
          },
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 550));

    final retryButton = find.text('Check connection');
    await tester.tap(retryButton);
    await tester.tap(retryButton);
    await tester.pump();
    expect(calls, 1);
    expect(find.text('Checking securely'), findsOneWidget);

    retryCompleter.complete(false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('STILL WAITING'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('connectivity seal respects reduced-motion preference',
      (tester) async {
    await tester.pumpWidget(
      _testApp(
        const StartupOfflineScreen(checking: true),
        disableAnimations: true,
      ),
    );
    await tester.pump(const Duration(milliseconds: 550));

    expect(tester.takeException(), isNull);
    expect(find.text('Protected connection'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('session hydration is guarded by backend connectivity', () {
    final mainSource = File('lib/main.dart').readAsStringSync();
    final connectivitySource =
        File('lib/core/services/connectivity_service.dart').readAsStringSync();

    expect(
      RegExp(r'_authCubit\.checkSession\(\)').allMatches(mainSource).length,
      1,
      reason: 'Session checks must only happen inside the network-ready gate.',
    );
    expect(mainSource, contains('_resolveStartupConnectivity'));
    expect(mainSource, contains('_StartupNetworkState.offline'));
    expect(connectivitySource, contains("'/auth/v1/health'"));
    expect(connectivitySource, contains('Future<bool>? _checkInFlight'));
  });
}
