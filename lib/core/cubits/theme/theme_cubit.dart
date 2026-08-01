import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Owns the active visual identity and persists it locally. Theme selection is
/// deliberately device-scoped: it applies before authentication and never
/// causes a profile write or network request.
class ThemeSelectionState {
  const ThemeSelectionState({
    required this.activeMode,
  });

  final SilarahThemeMode activeMode;
  SilarahThemeMode get selectedMode => activeMode;
}

class ThemeCubit extends Cubit<ThemeSelectionState> {
  ThemeCubit({SilarahThemeMode? initialMode})
      : super(ThemeSelectionState(
          activeMode: initialMode ?? SilarahThemeMode.blackWhite,
        )) {
    _applySystemIdentity(state.activeMode);
    _ready = initialMode == null ? _load() : Future<void>.value();
  }

  static const preferenceKey = 'silarah_theme_mode';
  late final Future<void> _ready;

  Future<void> get ready => _ready;

  Future<void> _load() async {
    final preferences = await SharedPreferences.getInstance();
    final mode = SilarahThemeMode.fromStorage(
      preferences.getString(preferenceKey),
    );
    if (preferences.getString(preferenceKey) != mode.storageValue) {
      await preferences.setString(preferenceKey, mode.storageValue);
    }
    if (isClosed) return;
    _applySystemIdentity(mode);
    emit(ThemeSelectionState(activeMode: mode));
  }

  /// Applies and persists a complete identity in the current frame.
  Future<void> applyMode(SilarahThemeMode mode) async {
    await _ready;
    if (isClosed || mode == state.activeMode) return;
    _applySystemIdentity(mode);
    emit(ThemeSelectionState(activeMode: mode));
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(preferenceKey, mode.storageValue);
  }

  static void _applySystemIdentity(SilarahThemeMode mode) {
    AppColors.activate(mode);
    final iconBrightness = mode.isDark ? Brightness.light : Brightness.dark;
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: iconBrightness,
        statusBarBrightness: mode.isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: AppColors.obsidianNight,
        systemNavigationBarIconBrightness: iconBrightness,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarContrastEnforced: false,
      ),
    );
  }
}
