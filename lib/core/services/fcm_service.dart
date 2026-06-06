// lib/core/services/fcm_service.dart
// ============================================================
// NOOR — Firebase Cloud Messaging Service
//
// Handles FCM token lifecycle:
//   - Request notification permissions
//   - Obtain and save FCM registration token to Supabase
//   - Listen for token refresh events
//   - Delete token on logout / account deletion
//
// Replaces the OneSignal integration with a free, unlimited
// alternative using Firebase Cloud Messaging.
// ============================================================

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'supabase_service.dart';

class FcmService {
  FcmService._();
  static final instance = FcmService._();

  FirebaseMessaging get _messaging => FirebaseMessaging.instance;
  StreamSubscription<String>? _tokenRefreshSub;

  /// Device ID — persisted across sessions so the same device
  /// always overwrites its own token row (via UPSERT).
  String? _deviceId;

  /// Initialize FCM: request permissions, get token, and save it.
  /// Call this in main() after Firebase.initializeApp().
  Future<void> initialize() async {
    // Request notification permissions (iOS requires explicit permission)
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('[FcmService] ⚠️ Notification permissions denied by user.');
      return;
    }

    debugPrint('[FcmService] ✅ Notification permissions: ${settings.authorizationStatus}');

    // Get or create a stable device ID
    _deviceId = await _getOrCreateDeviceId();

    // Get the current FCM token
    final token = await _messaging.getToken();
    if (token != null) {
      debugPrint('[FcmService] FCM token obtained (${token.substring(0, 20)}...)');
      await _saveTokenToSupabase(token);
    }

    // Listen for token refresh (Firebase rotates tokens periodically)
    _tokenRefreshSub = _messaging.onTokenRefresh.listen((newToken) async {
      debugPrint('[FcmService] 🔄 FCM token refreshed.');
      await _saveTokenToSupabase(newToken);
    });

    // Handle notification taps when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Handle notification that launched the app from terminated state
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }
  }

  /// Save (upsert) the FCM token to the user_fcm_tokens table in Supabase.
  /// This is only meaningful when a user is logged in.
  Future<void> _saveTokenToSupabase(String token) async {
    if (!SupabaseService.isInitialized) {
      debugPrint('[FcmService] Supabase not initialized — skipping token save.');
      return;
    }

    final session = SupabaseService.client.auth.currentSession;
    if (session == null) {
      debugPrint('[FcmService] No active session — token will be saved on login.');
      return;
    }

    final userId = session.user.id;
    final platform = defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';

    try {
      await SupabaseService.client.from('user_fcm_tokens').upsert({
        'user_id':   userId,
        'device_id': _deviceId,
        'fcm_token': token,
        'platform':  platform,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id,device_id');

      debugPrint('[FcmService] ✅ FCM token saved to Supabase for user $userId');
    } catch (e) {
      debugPrint('[FcmService] ❌ Failed to save FCM token: $e');
    }
  }

  /// Called after successful authentication to ensure the token
  /// is linked to the authenticated user.
  Future<void> onUserLogin() async {
    final token = await _messaging.getToken();
    if (token != null) {
      await _saveTokenToSupabase(token);
    }
  }

  /// Called on logout or account deletion.
  /// Deletes the FCM token row to prevent ghost push notifications.
  Future<void> onUserLogout() async {
    if (!SupabaseService.isInitialized || _deviceId == null) return;

    final session = SupabaseService.client.auth.currentSession;
    if (session == null) return;

    try {
      await SupabaseService.client
          .from('user_fcm_tokens')
          .delete()
          .eq('user_id', session.user.id)
          .eq('device_id', _deviceId!);

      debugPrint('[FcmService] ✅ FCM token deleted from Supabase.');
    } catch (e) {
      debugPrint('[FcmService] ❌ Failed to delete FCM token: $e');
    }
  }

  /// Get or create a persistent device ID stored in SharedPreferences.
  Future<String> _getOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    var deviceId = prefs.getString('noor_device_id');
    if (deviceId == null) {
      deviceId = const Uuid().v4();
      await prefs.setString('noor_device_id', deviceId);
    }
    return deviceId;
  }

  Function(String path)? _onNotificationTap;
  String? _pendingNotificationPath;

  set onNotificationTap(Function(String path)? callback) {
    _onNotificationTap = callback;
    if (callback != null && _pendingNotificationPath != null) {
      callback(_pendingNotificationPath!);
      _pendingNotificationPath = null;
    }
  }

  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('[FcmService] Notification tapped: ${message.data}');
    final type = message.data['type'] as String?;
    String? path;

    if (type == 'interest_received') {
      path = '/home?tab=1';
    } else if (type == 'new_message') {
      final matchId = message.data['match_id'] as String?;
      if (matchId != null) {
        path = '/chat/$matchId';
      }
    } else if (type == 'interest_accepted') {
      path = '/home?tab=1';
    }

    if (path != null) {
      if (_onNotificationTap != null) {
        _onNotificationTap!(path);
      } else {
        _pendingNotificationPath = path;
      }
    }
  }

  /// Dispose resources.
  void dispose() {
    _tokenRefreshSub?.cancel();
  }
}
