// lib/core/services/fcm_service.dart
// ============================================================
// SILARAH - Firebase Cloud Messaging Service
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
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'supabase_service.dart';
import '../utils/notification_deep_link.dart';

class FcmService {
  FcmService._();
  static final instance = FcmService._();

  FirebaseMessaging get _messaging => FirebaseMessaging.instance;
  Future<void>? _initializeFuture;
  bool _initialized = false;
  bool _pushAvailable = false;
  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _messageOpenedSub;
  StreamSubscription<RemoteMessage>? _foregroundMessageSub;

  /// Device ID - persisted across sessions so the same device
  /// always overwrites its own token row (via UPSERT).
  String? _deviceId;

  /// Initialize FCM: request permissions, get token, and save it.
  /// Call this in main() after Firebase.initializeApp().
  Future<void> initialize() async {
    final existing = _initializeFuture;
    if (existing != null) return existing;

    final future = _initialize().catchError((Object error) {
      _initializeFuture = null;
      throw error;
    });
    _initializeFuture = future;
    return future;
  }

  Future<void> _initialize() async {
    if (!_hasUsableFirebaseConfig()) {
      _pushAvailable = false;
      _initialized = true;
      debugPrint(
        '[FcmService] Firebase config is missing or placeholder; push registration disabled.',
      );
      return;
    }

    // Request notification permissions (iOS requires explicit permission)
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('[FcmService] Notification permissions denied by user.');
      _pushAvailable = false;
      _initialized = true;
      return;
    }

    _pushAvailable = true;

    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    debugPrint(
        '[FcmService] Notification permissions: ${settings.authorizationStatus}');

    // Get or create a stable device ID
    _deviceId = await _getOrCreateDeviceId();

    // Get the current FCM token
    final token = await _messaging.getToken();
    if (token != null) {
      debugPrint(
          '[FcmService] FCM token obtained (${token.substring(0, 20)}...)');
      await _saveTokenToSupabase(token);
    }

    // Listen for token refresh (Firebase rotates tokens periodically)
    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = _messaging.onTokenRefresh.listen((newToken) async {
      debugPrint('[FcmService] FCM token refreshed.');
      await _saveTokenToSupabase(newToken);
    });

    // Handle notification taps when app is in background
    await _messageOpenedSub?.cancel();
    _messageOpenedSub =
        FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Foreground pushes should refresh in-app state immediately. Android does
    // not show system banners for foreground FCM by default, so the app uses
    // Supabase realtime plus this callback for a reliable visible inbox badge.
    await _foregroundMessageSub?.cancel();
    _foregroundMessageSub = FirebaseMessaging.onMessage.listen((message) {
      _onForegroundMessage?.call(message);
    });

    // Handle notification that launched the app from terminated state
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }

    _initialized = true;
  }

  /// Save (upsert) the FCM token to the user_fcm_tokens table in Supabase.
  /// This is only meaningful when a user is logged in.
  Future<void> _saveTokenToSupabase(String token) async {
    if (!SupabaseService.isInitialized) {
      debugPrint(
          '[FcmService] Supabase not initialized - skipping token save.');
      return;
    }

    final session = SupabaseService.client.auth.currentSession;
    if (session == null) {
      debugPrint(
          '[FcmService] No active session - token will be saved on login.');
      return;
    }

    _deviceId ??= await _getOrCreateDeviceId();

    final userId = session.user.id;
    final platform =
        defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';

    try {
      await SupabaseService.client.from('user_fcm_tokens').upsert({
        'user_id': userId,
        'device_id': _deviceId,
        'fcm_token': token,
        'platform': platform,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id,device_id');

      debugPrint('[FcmService] FCM token saved to Supabase for user $userId');
    } catch (e) {
      debugPrint('[FcmService] Failed to save FCM token: $e');
    }
  }

  /// Called after successful authentication to ensure the token
  /// is linked to the authenticated user.
  Future<void> onUserLogin() async {
    if (!_initialized) {
      try {
        await initialize();
      } catch (e) {
        debugPrint('[FcmService] Failed to initialize after login: $e');
        return;
      }
    }

    if (!_pushAvailable) {
      debugPrint('[FcmService] Push unavailable; skipping login token save.');
      return;
    }

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

      debugPrint('[FcmService] FCM token deleted from Supabase.');
    } catch (e) {
      debugPrint('[FcmService] Failed to delete FCM token: $e');
    }
  }

  /// Get or create a persistent device ID stored in SharedPreferences.
  Future<String> _getOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    var deviceId = prefs.getString('silarah_device_id');
    if (deviceId == null) {
      deviceId = const Uuid().v4();
      await prefs.setString('silarah_device_id', deviceId);
    }
    return deviceId;
  }

  bool _hasUsableFirebaseConfig() {
    try {
      final options = Firebase.app().options;
      return !_looksMissingOrPlaceholder(options.projectId) &&
          !_looksMissingOrPlaceholder(options.appId) &&
          !_looksMissingOrPlaceholder(options.messagingSenderId) &&
          !_looksMissingOrPlaceholder(options.apiKey);
    } catch (_) {
      return false;
    }
  }

  bool _looksMissingOrPlaceholder(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) return true;
    final upper = normalized.toUpperCase();
    return upper.startsWith('YOUR_') ||
        upper.contains('PLACEHOLDER') ||
        upper.contains('FIREBASE_');
  }

  Function(String path)? _onNotificationTap;
  void Function(RemoteMessage message)? _onForegroundMessage;
  String? _pendingNotificationPath;

  set onNotificationTap(Function(String path)? callback) {
    _onNotificationTap = callback;
    if (callback != null && _pendingNotificationPath != null) {
      callback(_pendingNotificationPath!);
      _pendingNotificationPath = null;
    }
  }

  set onForegroundMessage(void Function(RemoteMessage message)? callback) {
    _onForegroundMessage = callback;
  }

  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('[FcmService] Notification tapped: ${message.data}');
    final deepLink = message.data['deep_link'] as String?;
    final type = message.data['type'] as String?;
    String? path = notificationPathFromDeepLink(deepLink);

    if (path != null) {
      // Deep links are the server-side source of truth for queued push
      // notifications. Type fallbacks below support older queued rows.
    } else if (type == 'interest_received') {
      path = '/home?tab=1';
    } else if (type == 'new_message') {
      final matchId = message.data['match_id'] as String?;
      if (matchId != null) {
        path = '/chat/$matchId';
      }
    } else if (type == 'interest_accepted' ||
        type == 'match' ||
        type == 'match_accepted') {
      path = '/home?tab=1';
    } else if (type == 'profile_live') {
      path = '/home?tab=3';
    } else if (type == 'profile_nudge') {
      path = '/edit-profile';
    } else if (type == 'admin_announcement') {
      path = '/notifications';
    } else if (type == 'profile_returned_to_review' ||
        type == 'account_restored' ||
        type == 'photo_approved' ||
        type == 'photo_rejected' ||
        type == 'kyc_approved' ||
        type == 'kyc_pending') {
      path = '/home?tab=3';
    } else if (type == 'kyc_rejected') {
      path = '/verify';
    } else if (type == 'account_suspended' || type == 'account_banned') {
      path = '/help-support';
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
    _messageOpenedSub?.cancel();
    _foregroundMessageSub?.cancel();
  }
}
