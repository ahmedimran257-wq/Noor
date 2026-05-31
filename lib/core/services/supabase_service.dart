// lib/core/services/supabase_service.dart
// ============================================================
// NOOR — Supabase Service
// Provides singleton Supabase client throughout the app.
// ============================================================

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
      throw StateError('SupabaseService not initialized. Call initialize() first.');
    }
    return _client!;
  }

  /// Whether Supabase has been initialized.
  static bool get isInitialized => _isInitialized;

  /// Current user ID if authenticated, null otherwise.
  static String? get currentUserId => _client?.auth.currentUser?.id;

  /// Initialize Supabase with credentials from AppConfig.
  /// Call this before runApp() in main.dart.
  static Future<void> initialize() async {
    if (_isInitialized) return;

    const url = AppConfig.supabaseUrl;
    const anonKey = AppConfig.supabaseAnonKey;

    // Check if credentials are placeholder values
    if (url.contains('YOUR_PROJECT') || anonKey.contains('YOUR_')) {
      // Not configured yet - stay in mock mode
      _isInitialized = false;
      return;
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
}