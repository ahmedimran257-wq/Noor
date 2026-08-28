import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:silarah/core/cubits/theme/theme_cubit.dart';
import 'package:silarah/core/services/app_lifecycle_service.dart';
import 'package:silarah/core/theme/app_colors.dart';
import 'package:silarah/core/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => AppColors.activate(SilarahThemeMode.blackWhite));

  test('theme modes have stable persistence identities', () {
    expect(
      SilarahThemeMode.values.map((mode) => mode.storageValue).toSet(),
      {'black_white', 'oled', 'ivory_emerald'},
    );
    expect(
      SilarahThemeMode.fromStorage('prism_luxe'),
      SilarahThemeMode.oled,
      reason: 'The retired dark identity migrates without a bright flash.',
    );
    expect(
      SilarahThemeMode.fromStorage('unknown'),
      SilarahThemeMode.blackWhite,
    );
    expect(
      SilarahThemeMode.fromStorage('obsidian'),
      SilarahThemeMode.blackWhite,
      reason: 'Removed identities migrate safely to Black & White.',
    );
    expect(
      SilarahThemeMode.fromStorage('rose'),
      SilarahThemeMode.blackWhite,
    );
    expect(
      SilarahThemeMode.fromStorage('floral_pink'),
      SilarahThemeMode.blackWhite,
    );
    expect(
      SilarahThemeMode.fromStorage('porcelain'),
      SilarahThemeMode.blackWhite,
    );
  });

  test('theme selection applies immediately and persists', () async {
    SharedPreferences.setMockInitialValues({});
    final cubit = ThemeCubit();

    await cubit.applyMode(SilarahThemeMode.ivoryEmerald);
    expect(cubit.state.activeMode, SilarahThemeMode.ivoryEmerald);
    expect(cubit.state.selectedMode, SilarahThemeMode.ivoryEmerald);
    expect(AppColors.active.mode, SilarahThemeMode.ivoryEmerald);
    expect(
      (await SharedPreferences.getInstance())
          .getString(ThemeCubit.preferenceKey),
      'ivory_emerald',
    );
    await cubit.close();

    final restored = ThemeCubit();
    await restored.ready;
    expect(restored.state.activeMode, SilarahThemeMode.ivoryEmerald);
    expect(AppColors.active.mode, SilarahThemeMode.ivoryEmerald);
    await restored.close();
  });

  test('removed saved identities are normalized during load', () async {
    SharedPreferences.setMockInitialValues({
      ThemeCubit.preferenceKey: 'porcelain',
    });
    final cubit = ThemeCubit();
    await cubit.ready;
    expect(cubit.state.activeMode, SilarahThemeMode.blackWhite);
    expect(
      (await SharedPreferences.getInstance())
          .getString(ThemeCubit.preferenceKey),
      'black_white',
    );
    await cubit.close();
  });

  test('preloaded startup theme applies atomically before first frame',
      () async {
    final cubit = ThemeCubit(initialMode: SilarahThemeMode.oled);
    await cubit.ready;
    expect(cubit.state.activeMode, SilarahThemeMode.oled);
    expect(AppColors.active.mode, SilarahThemeMode.oled);
    await cubit.close();
  });

  test('each identity produces the correct Material brightness and canvas', () {
    for (final mode in SilarahThemeMode.values) {
      final palette = SilarahPalette.forMode(mode);
      final theme = AppTheme.forMode(mode);
      expect(
          theme.brightness, mode.isDark ? Brightness.dark : Brightness.light);
      expect(theme.scaffoldBackgroundColor, palette.background);
      expect(theme.colorScheme.primary, palette.accent);
    }
    expect(
      SilarahPalette.blackWhite.background,
      const Color(0xFFFFFFFF),
      reason: 'Black & White is intentionally a true-white theme.',
    );
    expect(
      SilarahPalette.blackWhite.accent,
      const Color(0xFF000000),
      reason: 'Black & White uses absolute black for primary actions.',
    );
    expect(
      SilarahPalette.oled.background,
      const Color(0xFF000000),
      reason: 'Pure OLED must use a literal black canvas.',
    );
    expect(
      SilarahPalette.oled.navBar,
      const Color(0xFF000000),
      reason: 'Pure OLED navigation pixels must also switch off.',
    );
    expect(
      SilarahPalette.ivoryEmerald.background,
      const Color(0xFFF7F3EA),
      reason: 'Ivory & Emerald uses a deliberately warm paper canvas.',
    );
    expect(SilarahThemeMode.ivoryEmerald.isDark, isFalse);
    expect(SilarahThemeMode.ivoryEmerald.isChromatic, isFalse);
    expect(
      SilarahPalette.ivoryEmerald.spectrum.toSet(),
      hasLength(6),
      reason: 'Semantic accents remain distinct without becoming rainbow UI.',
    );
    const monochrome = SilarahPalette.blackWhite;
    final monochromeColors = <Color>[
      monochrome.background,
      monochrome.backgroundDeep,
      monochrome.accent,
      monochrome.accentHighlight,
      monochrome.accentPressed,
      monochrome.complementary,
      monochrome.decorativeDepth,
      monochrome.contentPrimary,
      monochrome.contentSecondary,
      monochrome.surface,
      monochrome.surfaceInteractive,
      monochrome.input,
      monochrome.border,
      monochrome.accentBorder,
      monochrome.accentGlow,
      monochrome.success,
      monochrome.danger,
      monochrome.messageReceived,
      monochrome.progressTrack,
      monochrome.divider,
      monochrome.surfaceElevated,
      monochrome.surfaceMid,
      monochrome.surfaceDark,
      monochrome.surfacePressed,
      monochrome.surfacePanelTop,
      monochrome.premium,
      monochrome.online,
      monochrome.message,
      monochrome.warning,
      monochrome.gradientCore,
      monochrome.dropdown,
      monochrome.snackbar,
      monochrome.navBar,
      monochrome.navBorder,
      ...monochrome.spectrum,
    ];
    expect(
      monochromeColors.every(
        (color) => color.r == color.g && color.g == color.b,
      ),
      isTrue,
      reason: 'Black & White must contain no chromatic colour values.',
    );
  });

  test('core text and accents meet WCAG AA contrast in every palette', () {
    for (final mode in SilarahThemeMode.values) {
      final palette = SilarahPalette.forMode(mode);
      expect(
        _contrast(palette.contentPrimary, palette.background),
        greaterThanOrEqualTo(4.5),
        reason: '${mode.label} primary content contrast',
      );
      expect(
        _contrast(palette.contentSecondary, palette.background),
        greaterThanOrEqualTo(4.5),
        reason: '${mode.label} secondary content contrast',
      );
      expect(
        _contrast(palette.accent, palette.background),
        greaterThanOrEqualTo(4.5),
        reason: '${mode.label} accent contrast',
      );
      AppColors.activate(mode);
      expect(
        _contrast(AppColors.onSnackbar, palette.snackbar),
        greaterThanOrEqualTo(4.5),
        reason: '${mode.label} snackbar content contrast',
      );
    }
  });

  test('every semantic feedback surface selects WCAG-readable content', () {
    for (final mode in SilarahThemeMode.values) {
      final palette = SilarahPalette.forMode(mode);
      final feedbackSurfaces = <String, Color>{
        'standard snackbar': palette.snackbar,
        'error snackbar': palette.danger,
        'success snackbar': palette.success,
        'interactive snackbar': palette.surfaceInteractive,
        'elevated snackbar': palette.surfaceElevated,
      };

      for (final entry in feedbackSurfaces.entries) {
        final foreground = AppColors.readableOn(entry.value);
        expect(
          foreground,
          anyOf(const Color(0xFF000000), const Color(0xFFFFFFFF)),
          reason: '${mode.label} ${entry.key} uses an absolute neutral',
        );
        expect(
          _contrast(foreground, entry.value),
          greaterThanOrEqualTo(4.5),
          reason: '${mode.label} ${entry.key} content contrast',
        );
      }
    }
  });

  test('photo safety feedback uses its semantic foreground token', () {
    final source = File(
      'lib/features/onboarding/screens/photo_upload_screen.dart',
    ).readAsStringSync();
    expect(
      source,
      contains('AppColors.readableOn(AppColors.softCoral)'),
      reason: 'Photo moderation errors must never inherit page text colour.',
    );
    expect(
      source,
      contains('AppColors.readableOn(AppColors.surfaceGlassHover)'),
      reason: 'Photo status feedback must adapt in light and dark themes.',
    );
  });

  test('Android system chrome never adds a contrast divider artifact', () {
    for (final mode in SilarahThemeMode.values) {
      final overlay = AppTheme.forMode(mode).appBarTheme.systemOverlayStyle;
      expect(overlay?.systemNavigationBarDividerColor, Colors.transparent);
      expect(overlay?.systemNavigationBarContrastEnforced, isFalse);
    }
    final androidStyles = File(
      'android/app/src/main/res/values/styles.xml',
    ).readAsStringSync();
    expect(androidStyles, contains('android:navigationBarDividerColor'));
    expect(androidStyles, contains('android:enforceNavigationBarContrast'));
  });

  test('launch sequence is white-first and uses one complete wordmark', () {
    final revealSource = File(
      'lib/core/widgets/silarah_launch_sequence.dart',
    ).readAsStringSync();
    expect(
      Directory('android/app/src/main/res')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('silarah_splash_mark.png')),
      isEmpty,
      reason: 'No separate legacy splash artwork may return.',
    );
    expect(revealSource, contains('Duration(milliseconds: 1250)'));
    expect(revealSource, contains('_wordTracking'));
    expect(revealSource, contains("'Silarah'"));
    expect(revealSource, contains("'السلام عليكم'"));
    expect(revealSource, contains('alpha: .58'));
    expect(
      revealSource,
      contains('WidgetsBinding.instance.addPostFrameCallback'),
      reason: 'Brand motion must start after the native launch hand-off.',
    );
    expect(revealSource, contains('final bool play'));
    expect(revealSource, contains('if (!widget.play'));
    expect(revealSource, isNot(contains('_departureOpacity')));
    expect(revealSource, contains('_BrandBloomPainter'));
    expect(revealSource, isNot(contains('silarah_liquid_mark.png')));
    expect(revealSource, isNot(contains("Text(\n          'ilarah'")));
    expect(revealSource, contains('AppColors.obsidianNight'));
    expect(revealSource, isNot(contains('SvgPicture')));
    expect(revealSource, isNot(contains('VideoPlayerController')));
    expect(revealSource, isNot(contains('Timer(')));
    expect(revealSource, isNot(contains('_exitOpacity')));
    expect(revealSource.toLowerCase(), isNot(contains('sparkle')));
    expect(
      File('lib/core/widgets/startup_brand_reveal.dart').existsSync(),
      isFalse,
    );

    final mainSource = File('lib/main.dart').readAsStringSync();
    expect(mainSource, contains('SilarahLaunchSequence'));
    final mainEntryPoint = mainSource.indexOf('void main()');
    expect(
      mainSource.indexOf('runApp('),
      lessThan(mainSource.indexOf('Firebase.initializeApp(', mainEntryPoint)),
      reason: 'Core SDK startup must not hold Android\'s static splash.',
    );
    expect(mainSource, isNot(contains('precacheImage(')));
    expect(
      mainSource,
      isNot(contains('deferFirstFrame')),
      reason: 'Flutter must replace the native surface without a dead frame.',
    );
    expect(mainSource, isNot(contains('endOfFrame')));
    expect(mainSource, isNot(contains('allowFirstFrame')));
    expect(mainSource, isNot(contains('_launchMayAnimate')));
    expect(mainSource, isNot(contains('firstPresentedFrame')));

    for (final stylePath in [
      'android/app/src/main/res/values/styles.xml',
      'android/app/src/main/res/values-night/styles.xml',
    ]) {
      final source = File(stylePath).readAsStringSync();
      expect(source, isNot(contains('?android:colorBackground')));
      expect(source, contains('@color/launch_background'));
      expect(source, contains('@drawable/launch_background'));
      expect(source, contains('#FFFFFF'));
    }
    for (final launchPath in [
      'android/app/src/main/res/drawable/launch_background.xml',
      'android/app/src/main/res/drawable-v21/launch_background.xml',
    ]) {
      expect(
        File(launchPath).readAsStringSync(),
        contains('@drawable/ic_launcher_foreground'),
        reason:
            'Cold engine startup must show the static brand, not blank white.',
      );
    }
    for (final stylePath in [
      'android/app/src/main/res/values-v31/styles.xml',
      'android/app/src/main/res/values-night-v31/styles.xml',
    ]) {
      final source = File(stylePath).readAsStringSync();
      expect(
        source,
        contains('android:windowSplashScreenAnimationDuration">0'),
        reason: 'Android must not insert a second native icon fade.',
      );
      expect(
        source,
        contains(
          'android:windowSplashScreenAnimatedIcon">'
          '@drawable/ic_launcher_foreground',
        ),
      );
    }
    final iosLaunch = File(
      'ios/Runner/Base.lproj/LaunchScreen.storyboard',
    ).readAsStringSync();
    expect(iosLaunch, contains('red="1" green="1" blue="1"'));
    expect(iosLaunch, isNot(contains('green="0.1803921569"')));
    expect(iosLaunch, isNot(contains('LaunchImage')));
    expect(
      Directory('ios/Runner/Assets.xcassets/LaunchImage.imageset').existsSync(),
      isFalse,
    );

    final routerSource =
        File('lib/core/router/app_router.dart').readAsStringSync();
    expect(routerSource, isNot(contains('AssalamAnimationScreen')));
    expect(
      File('lib/features/onboarding/screens/assalam_animation_screen.dart')
          .existsSync(),
      isFalse,
    );
  });

  test('adaptive launcher foreground is high-resolution and transparent',
      () async {
    final masterBytes =
        File('assets/icon/app_icon_foreground.png').readAsBytesSync();
    final masterCodec = await ui.instantiateImageCodec(masterBytes);
    final masterFrame = await masterCodec.getNextFrame();
    final master = masterFrame.image;
    expect(master.width, 1024);
    expect(master.height, 1024);
    final rgba = await master.toByteData(format: ui.ImageByteFormat.rawRgba);
    expect(rgba, isNotNull);
    expect(
      rgba!.getUint8(3),
      0,
      reason: 'The adaptive foreground must have a transparent corner.',
    );
    master.dispose();
    masterCodec.dispose();
  });

  test('website-matched launcher uses a dedicated adaptive foreground',
      () async {
    final launcher = File('assets/icon/app_icon.png');
    expect(launcher.existsSync(), isTrue);
    expect(File('assets/icon/app_icon_foreground.png').existsSync(), isTrue);

    final codec = await ui.instantiateImageCodec(launcher.readAsBytesSync());
    final frame = await codec.getNextFrame();
    expect(frame.image.width, 1024);
    expect(frame.image.height, 1024);
    frame.image.dispose();
    codec.dispose();

    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(
      RegExp(
        r'adaptive_icon_foreground:\s*"assets/icon/app_icon_foreground\.png"',
      ).hasMatch(pubspec),
      isTrue,
    );
    expect(pubspec, contains('adaptive_icon_background: "#FFFFFF"'));
  });

  test('native restart bridge remains available but appearance is live',
      () async {
    const channel = MethodChannel('com.silarah.app/app_lifecycle');
    final methods = <String>[];
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      methods.add(call.method);
      return true;
    });
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    expect(AppLifecycleService.supportsInPlaceRestart, isTrue);
    expect(await AppLifecycleService.restartNow(), isTrue);
    expect(methods, ['restartApp']);

    final settings = File(
      'lib/features/home/screens/settings_screen.dart',
    ).readAsStringSync();
    final nativeHost = File(
      'android/app/src/main/kotlin/com/silarah/app/MainActivity.kt',
    ).readAsStringSync();
    expect(settings, isNot(contains("Text('Restart now')")));
    expect(settings, contains('applyMode(mode)'));
    expect(settings, contains('settings_theme_applied'));
    expect(
      File('lib/l10n/app_en.arb').readAsStringSync(),
      contains('Applied instantly'),
    );
    expect(nativeHost, contains('Intent.FLAG_ACTIVITY_CLEAR_TASK'));
    expect(nativeHost, contains('finishAffinity()'));
    expect(nativeHost, contains('setOnExitAnimationListener'));
    expect(nativeHost, contains('splashView.remove()'));
  });
}

double _contrast(Color foreground, Color background) {
  final light = _luminance(foreground);
  final dark = _luminance(background);
  final lighter = light > dark ? light : dark;
  final darker = light > dark ? dark : light;
  return (lighter + .05) / (darker + .05);
}

double _luminance(Color color) {
  double channel(double value) => value <= .04045
      ? value / 12.92
      : math.pow((value + .055) / 1.055, 2.4).toDouble();
  return .2126 * channel(color.r) +
      .7152 * channel(color.g) +
      .0722 * channel(color.b);
}
