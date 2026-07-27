import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silarah/core/services/connectivity_service.dart';
import 'package:silarah/core/widgets/silarah_launch_sequence.dart';
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
  testWidgets('obsidian launch shifts fluidly and completes exactly once',
      (tester) async {
    var completions = 0;
    await tester.pumpWidget(
      _testApp(
        SilarahLaunchSequence(
          onCompleted: () => completions++,
        ),
      ),
    );
    expect(SilarahLaunchSequence.revealCompleted.value, isFalse);

    final wordmark = find.text('Silarah');
    expect(wordmark, findsOneWidget);
    final initialTracking = tester.widget<Text>(wordmark).style!.letterSpacing!;
    // The sequence intentionally begins in the post-frame callback so native
    // startup time cannot consume Flutter's brand animation.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1100));
    final settledTracking = tester.widget<Text>(wordmark).style!.letterSpacing!;
    expect(settledTracking, lessThan(initialTracking - 6));
    expect(find.byType(Image), findsNothing);

    await tester.pump(const Duration(milliseconds: 1400));
    await tester.pump(const Duration(milliseconds: 1));
    expect(completions, 1);
    expect(SilarahLaunchSequence.revealCompleted.value, isTrue);

    // Session hydration can outlive the motion on a slow network. The lockup
    // must hold until root bootstrap removes it, never expose a black stall.
    await tester.pump(const Duration(seconds: 3));
    expect(find.byType(Image), findsNothing);
    expect(find.text('Silarah'), findsOneWidget);
    expect(completions, 1);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('launch clock waits until the native surface is released',
      (tester) async {
    var completions = 0;
    await tester.pumpWidget(
      _testApp(
        SilarahLaunchSequence(
          play: false,
          onCompleted: () => completions++,
        ),
      ),
    );

    final wordmark = find.text('Silarah');
    final heldTracking = tester.widget<Text>(wordmark).style!.letterSpacing!;
    await tester.pump(const Duration(seconds: 4));
    expect(
      tester.widget<Text>(wordmark).style!.letterSpacing,
      heldTracking,
    );
    expect(completions, 0);
    expect(SilarahLaunchSequence.revealCompleted.value, isFalse);

    await tester.pumpWidget(
      _testApp(
        SilarahLaunchSequence(
          play: true,
          onCompleted: () => completions++,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1100));
    expect(
      tester.widget<Text>(wordmark).style!.letterSpacing,
      lessThan(heldTracking - 6),
    );
    await tester.pump(const Duration(milliseconds: 1401));
    expect(completions, 1);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('normal startup shows only the brand sequence, not the tower',
      (tester) async {
    await tester.pumpWidget(
      _testApp(
        const SilarahLaunchSequence(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.byType(SilarahLaunchSequence), findsOneWidget);
    expect(find.byType(StartupOfflineScreen), findsNothing);
    expect(find.text('Check connection'), findsNothing);

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
        StartupOfflineScreen(onRetry: () async => false),
        disableAnimations: true,
      ),
    );
    await tester.pump(const Duration(milliseconds: 550));

    expect(tester.takeException(), isNull);
    expect(find.text('Reconnection is automatic'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('mobile tower renders good, poor, and offline signal states',
      (tester) async {
    for (final quality in [
      BackendConnectionQuality.good,
      BackendConnectionQuality.poor,
      BackendConnectionQuality.offline,
    ]) {
      await tester.pumpWidget(
        _testApp(
          StartupOfflineScreen(
            key: ValueKey(quality),
            onRetry: () async => false,
            quality: quality,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 120));
      expect(find.byType(CustomPaint), findsWidgets);
      expect(tester.takeException(), isNull);
    }

    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('session hydration is guarded by backend connectivity', () {
    final mainSource = File('lib/main.dart').readAsStringSync();
    final connectivitySource =
        File('lib/core/services/connectivity_service.dart').readAsStringSync();
    final fcmSource =
        File('lib/core/services/fcm_service.dart').readAsStringSync();

    expect(
      RegExp(r'_authCubit\.checkSession\(\)').allMatches(mainSource).length,
      1,
      reason: 'Session checks must only happen inside the network-ready gate.',
    );
    expect(mainSource, contains('_resolveStartupConnectivity'));
    expect(mainSource, contains('_StartupNetworkState.offline'));
    expect(
      mainSource,
      contains("_StartupNetworkState.checking => const ColoredBox("),
    );
    expect(
      mainSource,
      isNot(contains('_StartupNetworkState.checking => StartupOfflineScreen(')),
    );
    expect(
      RegExp(r'home: SilarahLaunchSequence\(').allMatches(mainSource).length,
      1,
      reason: 'Only the root bootstrap may own the startup animation.',
    );
    expect(mainSource, contains('play: _launchMayAnimate'));
    expect(mainSource, contains('firstPresentedFrame'));
    expect(
      mainSource,
      contains('initialize(requestPermission: false)'),
      reason: 'Fresh installs must never show a permission dialog at launch.',
    );
    expect(fcmSource, contains('initialize(requestPermission: true)'));
    expect(
      fcmSource.indexOf('Future<void> _initialize()'),
      lessThan(fcmSource.indexOf('Future<void> _registerForPush()')),
    );
    expect(connectivitySource, contains("'/auth/v1/health'"));
    expect(connectivitySource, contains('Future<bool>? _checkInFlight'));
    expect(connectivitySource, contains('Stopwatch()..start()'));
    expect(connectivitySource, contains('Duration(milliseconds: 1100)'));

    final networkUiSource = File(
      'lib/core/widgets/startup_offline_screen.dart',
    ).readAsStringSync();
    expect(networkUiSource, contains('class _MobileTowerPainter'));
    expect(networkUiSource, contains('AppColors.onlineGreen'));
    expect(networkUiSource, contains('AppColors.expiryAmber'));
    expect(networkUiSource, contains('AppColors.errorRed'));
  });
}
