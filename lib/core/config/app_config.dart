// lib/core/config/app_config.dart
// ============================================================
// Mithaq — App Configuration
// Real credentials — wired to live Supabase project.
// ============================================================

abstract final class AppConfig {
  // ── Supabase ───────────────────────────────────────────────
  static const String supabaseUrl = 'https://jukpscfxzwttgtxvrbmj.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp1a3BzY2Z4end0dGd0eHZyYm1qIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE0MDQxMDcsImV4cCI6MjA5Njk4MDEwN30.P-mn2v2_NYHg2g5twxCg_RMNG6wQwooQ2U1C6lvqCy0';

  // ── RevenueCat ─────────────────────────────────────────────
  static const String revenueCatAndroidKey = 'goog_mtcvFiHMUfRbYuvlPXICQWjySJl';
  static const String revenueCatIosKey =
      ''; // TODO: Add iOS key from RevenueCat Dashboard

  // ── App Versioning ────────────────────────────────────────
  static const String appVersion = '1.0.0';
  static const String tosVersion = '1.0';
  static const String privacyVersion = '1.0';
}
