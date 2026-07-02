// lib/core/services/supabase_service.dart
// ============================================================
// MITHAQ — Supabase Service
// Provides singleton Supabase client throughout the app.
// ============================================================

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';

class SupabaseService {
  SupabaseService._();

  static SupabaseClient? _client;
  static bool _isInitialized = false;

  /// Returns the Supabase client instance.
  /// Throws if not initialized - check `isInitialized` first.
  static SupabaseClient get client {
    if (_client == null) {
      throw StateError(
          'SupabaseService not initialized. Call initialize() first.');
    }
    return _client!;
  }

  /// Whether Supabase has been initialized.
  static bool get isInitialized => _isInitialized;

  /// Whether configured credentials are usable for this build.
  static bool get isConfigured => _hasUsableConfig;

  /// Current user ID if authenticated, null otherwise.
  static String? get currentUserId => _client?.auth.currentUser?.id;

  /// Guard production features that cannot run without Supabase.
  ///
  /// Debug/dev screens may choose to show an empty state while a developer is
  /// wiring credentials. Release builds fail closed instead of exposing local
  /// demo or fake behavior.
  static bool requireInitialized(String featureName) {
    if (_isInitialized) return true;
    if (kReleaseMode) {
      throw StateError(
        '$featureName requires Supabase. Release builds must fail closed.',
      );
    }
    debugPrint(
      '[SupabaseService] $featureName skipped because Supabase is not '
      'initialized. This is allowed only in debug/dev builds.',
    );
    return false;
  }

  /// Initialize Supabase with credentials from AppConfig.
  /// Call this before runApp() in main.dart.
  static Future<void> initialize() async {
    if (_isInitialized) return;

    const url = AppConfig.supabaseUrl;
    const anonKey = AppConfig.supabaseAnonKey;

    if (!_hasUsableConfig) {
      throw StateError(
        'Supabase credentials are not configured. Production builds must fail '
        'closed before auth, profile, discovery, chat, or payment flows run.',
      );
    }

    await Supabase.initialize(url: url, anonKey: anonKey);
    _client = Supabase.instance.client;
    _isInitialized = true;
  }

  /// Reset for testing or re-initialization
  static void reset() {
    _client = null;
    _isInitialized = false;
  }

  static bool get _hasUsableConfig {
    const url = AppConfig.supabaseUrl;
    const anonKey = AppConfig.supabaseAnonKey;
    if (_looksPlaceholder(url) || _looksPlaceholder(anonKey)) return false;

    final parsed = Uri.tryParse(url);
    if (parsed == null || !parsed.hasScheme || parsed.host.isEmpty) {
      return false;
    }
    if (kReleaseMode && parsed.scheme != 'https') return false;
    return true;
  }

  static bool _looksPlaceholder(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return true;
    final upper = trimmed.toUpperCase();
    return upper.contains('YOUR_') ||
        upper.contains('YOUR-PROJECT') ||
        upper.contains('PLACEHOLDER') ||
        upper.contains('SUPABASE_URL') ||
        upper.contains('SUPABASE_ANON_KEY');
  }
}
