// lib/core/config/app_config.dart
// ============================================================
// Silarah - App Configuration
// Values are injected at build time with --dart-define or
// --dart-define-from-file. Never commit live project config here.
// ============================================================

abstract final class AppConfig {
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');

  static const String revenueCatAndroidKey =
      String.fromEnvironment('REVENUECAT_ANDROID_KEY');
  static const String revenueCatIosKey =
      String.fromEnvironment('REVENUECAT_IOS_KEY');
  static const String revenueCatTestKey =
      String.fromEnvironment('REVENUECAT_TEST_KEY');

  static const String appVersion = '1.0.0';
  static const String tosVersion = '1.0';
  static const String privacyVersion = '1.0';
}
