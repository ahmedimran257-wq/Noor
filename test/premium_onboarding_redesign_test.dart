import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silarah/features/onboarding/screens/splash_brand_screen.dart';
import 'package:silarah/l10n/generated/app_localizations.dart';

void main() {
  test('welcome screen uses deterministic staggered orchestration', () {
    final source = File(
      'lib/features/onboarding/screens/splash_brand_screen.dart',
    ).readAsStringSync();

    expect(source, contains('with TickerProviderStateMixin'));
    expect(source, contains('Duration(milliseconds: 1350)'));
    expect(source, contains('Duration(seconds: 14)'));
    expect(source, contains('_lockupOpacity'));
    expect(source, contains('_heroOpacity'));
    expect(source, contains('_ambient.repeat()'));
    expect(source, contains('_primaryOpacity'));
    expect(source, contains('_secondaryOpacity'));
    expect(source, contains('_tertiaryOpacity'));
    expect(source, contains('MediaQuery.disableAnimationsOf(context)'));
    expect(source, contains('revealCompleted.addListener'));
    expect(source, contains('!SilarahLaunchSequence.revealCompleted.value'));
    expect(source, contains('HapticFeedback.lightImpact()'));
    expect(RegExp(r'haptic:\s*false').allMatches(source).length, 2);
  });

  test('welcome and shared navigation surfaces avoid decorative green casts',
      () {
    final welcome = File(
      'lib/features/onboarding/screens/splash_brand_screen.dart',
    ).readAsStringSync();
    final onboarding = File(
      'lib/features/onboarding/widgets/onboarding_scaffold.dart',
    ).readAsStringSync();
    final navigation = File(
      'lib/features/home/widgets/silarah_bottom_nav.dart',
    ).readAsStringSync();
    final secondaryButton = File(
      'lib/core/widgets/buttons/silarah_secondary_button.dart',
    ).readAsStringSync();

    expect(welcome, contains('_WelcomeCanvas'));
    expect(welcome, contains('_UnionArchPainter'));
    expect(welcome, isNot(contains("'Assalamu Alaikum'")));
    expect(welcome, isNot(contains("'السلام عليكم'")));
    expect(welcome, isNot(contains('AppColors.inkTeal')));
    expect(onboarding, isNot(contains('AppColors.inkTeal')));
    expect(navigation, isNot(contains('AppColors.inkTeal')));
    expect(secondaryButton, isNot(contains('AppColors.inkTeal')));
  });

  testWidgets('premium welcome composition is stable on compact phones',
      (tester) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    for (final size in [const Size(360, 640), const Size(412, 915)]) {
      tester.view
        ..physicalSize = size
        ..devicePixelRatio = 1;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: const SplashBrandScreen(),
        ),
      );
      await tester.pump();

      expect(find.text('Silarah'), findsOneWidget);
      expect(
        find.text('Marriage, approached with intention.'),
        findsOneWidget,
      );
      expect(find.text('Assalamu Alaikum'), findsNothing);
      expect(find.text('Create Profile'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  test('email auth depth and focus treatment retain one field shell', () {
    final email = File(
      'lib/features/onboarding/screens/email_verification_screen.dart',
    ).readAsStringSync();
    final frame = File(
      'lib/core/widgets/inputs/silarah_field_frame.dart',
    ).readAsStringSync();

    expect(email, contains('_QuietAuthCanvas'));
    expect(email, contains('_AuthBotanicalEdgePainter'));
    expect(email, isNot(contains('RadialGradient')));
    expect(email, contains('HapticFeedback.lightImpact()'));
    expect(email, contains('haptic: false'));
    expect(frame, contains('AppColors.champagneGold.withValues(alpha: 0.11)'));
    expect(frame, contains('if (focused && enabled && !hasError)'));
    expect(email, isNot(contains('UnderlineInputBorder')));
  });
}
