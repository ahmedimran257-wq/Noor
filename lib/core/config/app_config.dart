// lib/core/config/app_config.dart
// ============================================================
// NOOR — App Configuration
// Real credentials — wired to live Supabase project.
// ============================================================

abstract final class AppConfig {
  // ── Supabase ───────────────────────────────────────────────
  static const String supabaseUrl  = 'https://wmkoeahcqfbigglhsxaa.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Indta29lYWhjcWZiaWdnbGhzeGFhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU5MTkyNjgsImV4cCI6MjA5MTQ5NTI2OH0.aTZHHcLsrOv5m0xtA8Xlb9G7M7JNs_1YiST49C6PlP8';

  // ── RevenueCat ─────────────────────────────────────────────
  static const String revenueCatAndroidKey = 'goog_mtcvFiHMUfRbYuvlPXICQWjySJl';
  static const String revenueCatIosKey     = ''; // TODO: Add iOS key from RevenueCat Dashboard

  // ── Mock Auth ─────────────────────────────────────────────
  // Step 4 uses a mock OTP flow.
  // Any 6-digit code is accepted as valid.
  static const String mockOtpCode = '000000';

  // ── Google Places ──────────────────────────────────────────
  // Replace with your Google Places API key from:
  // Google Cloud Console → APIs & Services → Credentials
  // Enable: Places API (New) + Geocoding API
  // Free tier: 28,500 requests/month
  static const String googlePlacesApiKey = 'YOUR_GOOGLE_PLACES_API_KEY';

  // ── App Versioning ────────────────────────────────────────
  static const String appVersion   = '1.0.0';
  static const String tosVersion   = '1.0';
  static const String privacyVersion = '1.0';
}
