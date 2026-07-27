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

  tearDown(() => AppColors.activate(SilarahThemeMode.obsidian));

  test('theme modes have stable persistence identities', () {
    expect(
      SilarahThemeMode.values.map((mode) => mode.storageValue).toSet(),
      {'obsidian', 'rose', 'porcelain'},
    );
    expect(
      SilarahThemeMode.fromStorage('unknown'),
      SilarahThemeMode.obsidian,
    );
    expect(
      SilarahThemeMode.fromStorage('emerald'),
      SilarahThemeMode.obsidian,
      reason: 'Removed emerald preferences migrate safely to Obsidian.',
    );
  });

  test('theme selection is persisted without partially mutating the app',
      () async {
    SharedPreferences.setMockInitialValues({});
    final cubit = ThemeCubit();

    await cubit.scheduleForRestart(SilarahThemeMode.rose);
    expect(cubit.state.activeMode, SilarahThemeMode.obsidian);
    expect(cubit.state.pendingMode, SilarahThemeMode.rose);
    expect(cubit.state.requiresRestart, isTrue);
    expect(AppColors.active.mode, SilarahThemeMode.obsidian);
    expect(
      (await SharedPreferences.getInstance())
          .getString(ThemeCubit.preferenceKey),
      'rose',
    );
    await cubit.close();

    final restored = ThemeCubit();
    await restored.ready;
    expect(restored.state.activeMode, SilarahThemeMode.rose);
    expect(restored.state.pendingMode, isNull);
    expect(AppColors.active.mode, SilarahThemeMode.rose);
    await restored.close();
  });

  test('preloaded startup theme applies atomically before first frame',
      () async {
    final cubit = ThemeCubit(initialMode: SilarahThemeMode.porcelain);
    await cubit.ready;
    expect(cubit.state.activeMode, SilarahThemeMode.porcelain);
    expect(AppColors.active.mode, SilarahThemeMode.porcelain);
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
      SilarahPalette.porcelain.background,
      const Color(0xFFFFFFFF),
      reason: 'Porcelain is intentionally a true-white theme.',
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
    }
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

  test('launch sequence is black-first and uses one complete wordmark', () {
    final revealSource = File(
      'lib/core/widgets/silarah_launch_sequence.dart',
    ).readAsStringSync();
    expect(
      Directory('android/app/src/main/res')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('silarah_splash_mark.png')),
      isEmpty,
      reason: 'The native layer must remain obsidian until Flutter reveals.',
    );
    expect(revealSource, contains('Duration(milliseconds: 2400)'));
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
    expect(revealSource, contains('_departureOpacity'));
    expect(revealSource, contains('_ObsidianBloomPainter'));
    expect(revealSource, isNot(contains('silarah_liquid_mark.png')));
    expect(revealSource, isNot(contains("Text(\n          'ilarah'")));
    expect(revealSource, contains('Color(0xFF050507)'));
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
    expect(
      mainSource.indexOf('runApp('),
      lessThan(mainSource.indexOf('Firebase.initializeApp(')),
      reason: 'Core SDK startup must not hold Android\'s static splash.',
    );
    expect(mainSource, contains('binding.deferFirstFrame()'));
    expect(mainSource, isNot(contains('precacheImage(')));
    expect(mainSource, contains('endOfFrame'));
    expect(mainSource, contains('allowFirstFrame()'));
    expect(mainSource, contains('play: _launchMayAnimate'));
    expect(mainSource, contains('firstPresentedFrame'));

    for (final stylePath in [
      'android/app/src/main/res/values/styles.xml',
      'android/app/src/main/res/values-night/styles.xml',
    ]) {
      final source = File(stylePath).readAsStringSync();
      expect(source, isNot(contains('?android:colorBackground')));
      expect(source, contains('@color/launch_background'));
      expect(source, contains('@drawable/launch_background'));
      expect(source, contains('#050507'));
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
          '@android:color/transparent',
        ),
      );
    }
    final iosLaunch = File(
      'ios/Runner/Base.lproj/LaunchScreen.storyboard',
    ).readAsStringSync();
    expect(iosLaunch, isNot(contains('red="1" green="1" blue="1"')));
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
    expect(pubspec, contains('adaptive_icon_background: "#0A0A0D"'));
  });

  test('Restart now invokes the native Android task restart bridge', () async {
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
    expect(settings, contains("Text('Restart now')"));
    expect(settings, contains("'Later'"));
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
