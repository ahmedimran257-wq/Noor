// lib/core/cubits/locale/locale_cubit.dart
// ============================================================
// NOOR — Locale Cubit (Feature 16)
// Holds the active Locale and persists to SharedPreferences.
// main.dart reads this to set MaterialApp.locale.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleCubit extends Cubit<Locale> {
  LocaleCubit() : super(const Locale('en')) {
    _load();
  }

  static const _kKey = 'app_locale';

  /// Supported language codes — must match available .arb files.
  /// Only ship locales that have actual translations.
  ///
  /// Phase 2+ expansion (add .arb files first, then uncomment):
  //  'ur', 'ms', 'id', 'tr', 'bn', 'fr', 'hi', 'ta', 'te',
  //  'ml', 'kn', 'mr', 'gu', 'pa', 'fa', 'ps', 'sw', 'so', 'ha', 'de',
  //  'nl', 'sv', 'no', 'ru', 'bs', 'sq', 'az', 'pt', 'es', 'am', 'ku',
  //  'uz', 'tg', 'tk', 'kk', 'ky', 'my', 'th', 'tl', 'jv', 'si', 'ne',
  //  'wo', 'yo', 'af',
  static const _supported = {
    'en', 'ar',
  };

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kKey);

    if (saved != null) {
      // User has previously chosen a locale
      if (!isClosed) emit(Locale(saved));
    } else {
      // First launch: detect device locale, fall back to 'en' if unsupported
      final deviceCode =
          WidgetsBinding.instance.platformDispatcher.locale.languageCode;
      final code = _supported.contains(deviceCode) ? deviceCode : 'en';
      if (!isClosed) emit(Locale(code));
    }
  }

  Future<void> setLocale(Locale locale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kKey, locale.languageCode);
    if (!isClosed) emit(locale);
  }
}
