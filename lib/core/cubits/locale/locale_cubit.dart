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

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final code  = prefs.getString(_kKey) ?? 'en';
    if (!isClosed) emit(Locale(code));
  }

  Future<void> setLocale(Locale locale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kKey, locale.languageCode);
    if (!isClosed) emit(locale);
  }
}
