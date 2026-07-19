import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:silarah/core/cubits/theme/theme_cubit.dart';
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
