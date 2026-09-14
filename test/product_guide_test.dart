import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silarah/core/models/onboarding_data.dart';
import 'package:silarah/core/cubits/auth/auth_cubit.dart';
import 'package:silarah/core/cubits/onboarding/onboarding_cubit.dart';
import 'package:silarah/core/cubits/onboarding/onboarding_state.dart';
import 'package:silarah/core/theme/app_colors.dart';
import 'package:silarah/core/theme/app_theme.dart';
import 'package:silarah/core/widgets/buttons/silarah_primary_button.dart';
import 'package:silarah/core/widgets/silarah_product_guide.dart';
import 'package:silarah/features/onboarding/screens/photo_upload_screen.dart';
import 'package:silarah/features/onboarding/screens/splash_brand_screen.dart';
import 'package:silarah/features/onboarding/screens/profile_for_whom_screen.dart';
import 'package:silarah/features/onboarding/screens/basic_identity_screen.dart';
import 'package:silarah/l10n/generated/app_localizations.dart';
import 'package:silarah/l10n/product_guide_ui_copy.dart';
import 'package:silarah/l10n/ui_copy.dart';

Widget _app(
        {required Widget home,
        required SilarahThemeMode mode,
        String language = 'en',
        double scale = 1,
        Key? captureKey}) =>
    MaterialApp(
      theme: AppTheme.forMode(mode),
      locale: Locale(language),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate
      ],
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
            disableAnimations: true, textScaler: TextScaler.linear(scale)),
        child: RepaintBoundary(key: captureKey, child: child!),
      ),
      home: home,
    );

void _phone(WidgetTester tester, Size size) {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = size;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

class _SeededOnboarding extends OnboardingCubit {
  _SeededOnboarding({required super.authCubit, required OnboardingData data}) {
    emit(OnboardingActive(step: 2, data: data));
  }
}

void main() {
  tearDown(() => AppColors.activate(SilarahThemeMode.blackWhite));

  test('every guide locale includes every sentence', () {
    final keys = productGuideUiCopy['ar']!.keys.toSet();
    expect(productGuideUiCopy.keys.toSet(),
        {'ar', 'bn', 'de', 'fr', 'hi', 'id', 'ms', 'tr', 'ur'});
    for (final entry in productGuideUiCopy.entries) {
      expect(entry.value.keys.toSet(), keys, reason: entry.key);
      expect(
          entry.value.values.every((value) => value.trim().isNotEmpty), isTrue);
    }
  });

  for (final mode in SilarahThemeMode.values) {
    for (final language in ['en', 'ar', 'de']) {
      testWidgets('optional guide fits $mode $language at large text',
          (tester) async {
        _phone(tester, const Size(320, 640));
        await tester.pumpWidget(_app(
          mode: mode,
          language: language,
          scale: 2,
          home: Builder(
              builder: (context) => Scaffold(
                      body: TextButton(
                    onPressed: () => SilarahProductGuide.show(context),
                    child: const Text('Open guide'),
                  ))),
        ));
        await tester.pumpAndSettle();
        expect(find.byType(SilarahPrimaryButton), findsNothing);
        await tester.tap(find.text('Open guide'));
        await tester.pumpAndSettle();
        expect(find.byType(SilarahPrimaryButton), findsOneWidget);
        expect(tester.takeException(), isNull);
        final context = tester.element(find.byType(SilarahPrimaryButton));
        final control = find.text(context.uiCopy('You remain in control'));
        await tester.scrollUntilVisible(control, 200,
            scrollable: find.descendant(
                of: find.byType(ListView), matching: find.byType(Scrollable)),
            maxScrolls: 30);
        await tester.pumpAndSettle();
        expect(control, findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byType(SilarahPrimaryButton));
        await tester.pumpAndSettle();
        expect(find.byType(SilarahPrimaryButton), findsNothing);
      });
    }
  }

  testWidgets('welcome scales without clipping primary actions',
      (tester) async {
    _phone(tester, const Size(320, 640));
    await tester.pumpWidget(_app(
        home: const SplashBrandScreen(),
        mode: SilarahThemeMode.ivoryEmerald,
        language: 'ar',
        scale: 2));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.byType(SilarahPrimaryButton));
    await tester.pumpAndSettle();
    expect(find.byType(SilarahPrimaryButton).hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('photo audience follows the selected policy', (tester) async {
    for (final privacy in PhotoPrivacy.values) {
      await tester.pumpWidget(_app(
          mode: SilarahThemeMode.blackWhite,
          home: Scaffold(body: PhotoAudienceSummary(privacy: privacy))));
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(
          tester.element(find.byType(PhotoAudienceSummary)));
      final expected = switch (privacy) {
        PhotoPrivacy.publicAll => l10n.photo_privacy_everyone_sub,
        PhotoPrivacy.mutualOnly => l10n.photo_privacy_mutual_sub,
        PhotoPrivacy.requestOnly => l10n.photo_privacy_request_sub,
      };
      expect(find.text(expected), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('family profile explanation remains reachable with large text',
      (tester) async {
    _phone(tester, const Size(320, 640));
    final auth = AuthCubit();
    final onboarding = OnboardingCubit(authCubit: auth);
    addTearDown(auth.close);
    addTearDown(onboarding.close);
    await tester.pumpWidget(_app(
      mode: SilarahThemeMode.ivoryEmerald,
      scale: 2,
      home: MultiBlocProvider(providers: [
        BlocProvider<AuthCubit>.value(value: auth),
        BlocProvider<OnboardingCubit>.value(value: onboarding),
      ], child: const ProfileForWhomScreen()),
    ));
    await tester.pumpAndSettle();
    final l10n =
        AppLocalizations.of(tester.element(find.byType(ProfileForWhomScreen)));
    final family = find.text(l10n.onboarding_profileForWhom_guardianCardTitle);
    await tester.ensureVisible(family);
    await tester.pumpAndSettle();
    await tester.tap(family);
    await tester.pumpAndSettle();
    final daughter =
        find.text(l10n.onboarding_profileForWhom_relation_daughter);
    await tester.ensureVisible(daughter);
    await tester.pumpAndSettle();
    expect(daughter.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'optional identity details stay optional and saved values remain visible',
      (tester) async {
    _phone(tester, const Size(360, 800));
    final auth = AuthCubit();
    final onboarding = _SeededOnboarding(
        authCubit: auth,
        data: const OnboardingData(
          firstName: 'Amina',
          motherTongue: 'Urdu',
          complexion: 'Medium',
        ));
    addTearDown(auth.close);
    addTearDown(onboarding.close);
    await tester.pumpWidget(_app(
      mode: SilarahThemeMode.blackWhite,
      home: MultiBlocProvider(providers: [
        BlocProvider<AuthCubit>.value(value: auth),
        BlocProvider<OnboardingCubit>.value(value: onboarding),
      ], child: const BasicIdentityScreen()),
    ));
    await tester.pumpAndSettle();
    final optional =
        find.byKey(const PageStorageKey('identity-optional-details'));
    expect(tester.widget<ExpansionTile>(optional).initiallyExpanded, isTrue);
    // Required height and language are not inside the optional disclosure.
    expect(find.descendant(of: optional, matching: find.text('Urdu')),
        findsNothing);
    expect(find.text('Urdu'), findsOneWidget);
    final l10n =
        AppLocalizations.of(tester.element(find.byType(BasicIdentityScreen)));
    await tester.ensureVisible(find.text(l10n.guide_optional_details));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.guide_optional_details));
    await tester.pumpAndSettle();
    expect(onboarding.currentData.complexion, 'Medium');
    expect(onboarding.currentData.motherTongue, 'Urdu');
    expect(tester.takeException(), isNull);
  });

  testWidgets('guide visual review capture', (tester) async {
    final output = Platform.environment['SILARAH_GUIDE_CAPTURE'];
    if (output == null) return;
    _phone(tester, const Size(412, 915));
    await tester.runAsync(() async {
      for (final family in ['Inter', 'PlayfairDisplay']) {
        await (FontLoader(family)
              ..addFont(rootBundle.load('assets/fonts/$family.ttf')))
            .load();
      }
      await (FontLoader('MaterialIcons')
            ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
          .load();
    });
    final capture = GlobalKey();
    await tester.pumpWidget(_app(
      mode: SilarahThemeMode.ivoryEmerald,
      captureKey: capture,
      home: Builder(
          builder: (context) => Scaffold(
                  body: TextButton(
                onPressed: () => SilarahProductGuide.show(context),
                child: const Text('Open guide'),
              ))),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open guide'));
    await tester.pumpAndSettle();
    final boundary =
        capture.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(output).writeAsBytes(data!.buffer.asUint8List());
      image.dispose();
    });
  });
}
