// lib/core/config/app_config.dart
// ============================================================
// NOOR — App Configuration
// Placeholder constants for Phase 4 demo.
// Replace with real values before going live with Supabase.
// ============================================================

abstract final class AppConfig {
  // ── Supabase ───────────────────────────────────────────────
  // Replace with your project's URL & anon key from:
  // Supabase Dashboard → Settings → API
  static const String supabaseUrl  = 'https://YOUR_PROJECT.supabase.co';
  static const String supabaseAnonKey = 'YOUR_ANON_KEY';

  // ── Mock Auth ─────────────────────────────────────────────
  // Step 4 uses a mock OTP flow.
  // Any 6-digit code is accepted as valid.
  static const String mockOtpCode = '000000';

  // ── App Versioning ────────────────────────────────────────
  static const String appVersion   = '1.0.0';
  static const String tosVersion   = '1.0';
  static const String privacyVersion = '1.0';
}
