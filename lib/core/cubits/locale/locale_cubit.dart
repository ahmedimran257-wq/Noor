import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SupportedLanguage {
  const SupportedLanguage({
    required this.code,
    required this.nativeName,
    required this.englishName,
    this.isRtl = false,
  });

  final String code;
  final String nativeName;
  final String englishName;
  final bool isRtl;
}

class LocaleCubit extends Cubit<Locale> {
  LocaleCubit() : super(const Locale('en')) {
    _load();
  }

  static const _kKey = 'app_locale';

  /// Single source of truth for generated translations and the settings UI.
  static const supportedLanguages = <SupportedLanguage>[
    SupportedLanguage(
      code: 'en',
      nativeName: 'English',
      englishName: 'English',
    ),
    SupportedLanguage(
      code: 'ar',
      nativeName: 'العربية',
      englishName: 'Arabic',
      isRtl: true,
    ),
    SupportedLanguage(
      code: 'ur',
      nativeName: 'اردو',
      englishName: 'Urdu',
      isRtl: true,
    ),
    SupportedLanguage(
      code: 'hi',
      nativeName: 'हिन्दी',
      englishName: 'Hindi',
    ),
    SupportedLanguage(
      code: 'bn',
      nativeName: 'বাংলা',
      englishName: 'Bengali',
    ),
    SupportedLanguage(
      code: 'id',
      nativeName: 'Bahasa Indonesia',
      englishName: 'Indonesian',
    ),
    SupportedLanguage(
      code: 'ms',
      nativeName: 'Bahasa Melayu',
      englishName: 'Malay',
    ),
    SupportedLanguage(
      code: 'tr',
      nativeName: 'Türkçe',
      englishName: 'Turkish',
    ),
    SupportedLanguage(
      code: 'fr',
      nativeName: 'Français',
      englishName: 'French',
    ),
    SupportedLanguage(
      code: 'de',
      nativeName: 'Deutsch',
      englishName: 'German',
    ),
  ];

  static const supportedLanguageCodes = {
    'en',
    'ar',
    'ur',
    'hi',
    'bn',
    'id',
    'ms',
    'tr',
    'fr',
    'de',
  };

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kKey);

    if (saved != null && supportedLanguageCodes.contains(saved)) {
      if (!isClosed) emit(Locale(saved));
      return;
    }

    final deviceCode =
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    final code =
        supportedLanguageCodes.contains(deviceCode) ? deviceCode : 'en';
    await prefs.setString(_kKey, code);
    if (!isClosed) emit(Locale(code));
  }

  Future<void> setLocale(Locale locale) async {
    final code = supportedLanguageCodes.contains(locale.languageCode)
        ? locale.languageCode
        : 'en';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kKey, code);
    if (!isClosed) emit(Locale(code));
  }
}
