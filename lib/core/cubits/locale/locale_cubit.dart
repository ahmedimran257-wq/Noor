import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/supabase_service.dart';

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
    await syncToServer();
  }

  /// Keeps server-generated notification copy aligned with the language the
  /// member selected in the app. Local language selection remains usable when
  /// offline and is reconciled on the next authenticated session.
  Future<bool> syncToServer({String? countryCode}) async {
    if (!SupabaseService.isInitialized ||
        SupabaseService.client.auth.currentSession == null) {
      return false;
    }
    try {
      final normalizedCountry = countryCode?.trim().toUpperCase();
      final fields = <String, dynamic>{
        'preferred_language': state.languageCode,
      };
      // Silarah is currently India-only. Keep server-side quiet hours and
      // notification scheduling in the member's launch-market timezone.
      // When more countries are enabled this value should come from the
      // selected launch market instead of a device offset.
      if (normalizedCountry == 'IN' || normalizedCountry == 'IND') {
        fields['timezone'] = 'Asia/Kolkata';
      }
      await SupabaseService.client.rpc(
        'patch_my_user',
        params: {
          'p_fields': fields,
        },
      );
      return true;
    } catch (error) {
      debugPrint('[LocaleCubit] Server language sync deferred: $error');
      return false;
    }
  }
}
