// lib/core/services/presence_service.dart
// ============================================================
// SILARAH - Presence Service
// Records authenticated app heartbeats for real admin live traffic.
// ============================================================

import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'supabase_service.dart';

class PresenceService {
  PresenceService._();
  static final instance = PresenceService._();

  // Ten minutes aligns with the database's 12-minute online window. The
  // heartbeat updates one indexed row; profile activity is coalesced server
  // side to at most once per hour.
  static const _heartbeatInterval = Duration(minutes: 10);
  static const _duplicateStateWindow = Duration(seconds: 20);

  Timer? _timer;
  bool _inFlight = false;
  String? _activeUserId;
  String? _lastRecordedState;
  DateTime? _lastRecordedAt;

  void start(String userId) {
    if (_activeUserId == userId && _timer != null) return;
    stop();
    _activeUserId = userId;
    unawaited(record(appState: 'foreground'));
    _startHeartbeat();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _activeUserId = null;
    _inFlight = false;
    _lastRecordedState = null;
    _lastRecordedAt = null;
  }

  void handleLifecycle(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        if (_activeUserId != null) {
          unawaited(record(appState: 'foreground'));
          _startHeartbeat();
        }
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _timer?.cancel();
        _timer = null;
        if (_activeUserId != null) {
          unawaited(record(appState: 'background'));
        }
      case AppLifecycleState.inactive:
        // Inactive is often a short system overlay. Avoid a paid write for an
        // event that normally becomes resumed/paused moments later.
        break;
    }
  }

  void _startHeartbeat() {
    _timer?.cancel();
    _timer = Timer.periodic(
      _heartbeatInterval,
      (_) => unawaited(record(appState: 'foreground')),
    );
  }

  Future<void> record({required String appState}) async {
    if (_inFlight || !SupabaseService.isInitialized) return;
    final lastRecordedAt = _lastRecordedAt;
    if (_lastRecordedState == appState &&
        lastRecordedAt != null &&
        DateTime.now().difference(lastRecordedAt) < _duplicateStateWindow) {
      return;
    }
    final userId = await SupabaseService.currentUserIdOrRefresh();
    if (userId == null || (_activeUserId != null && userId != _activeUserId)) {
      return;
    }

    _inFlight = true;
    try {
      await SupabaseService.client.rpc(
        'record_user_presence',
        params: {
          'p_app_state': appState,
          'p_platform': _platform,
        },
      );
      _lastRecordedState = appState;
      _lastRecordedAt = DateTime.now();
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[PresenceService] heartbeat failed: $error');
      }
    } finally {
      _inFlight = false;
    }
  }

  String get _platform {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    if (Platform.isWindows) return 'windows';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isLinux) return 'linux';
    return 'unknown';
  }
}
