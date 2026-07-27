// lib/core/services/connectivity_service.dart
// ============================================================
// SILARAH — Connectivity Service
// Verifies that the configured backend is reachable instead of trusting a
// network-interface or DNS-only signal. This keeps backend outages and captive
// portals from being mistaken for a signed-out user.
//
// Usage:
//   final service = ConnectivityService();
//   service.connectivityStream.listen((isOnline) { ... });
//   final online = await service.checkNow();
//   service.dispose(); // when done
//
// ============================================================

import 'dart:async';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:silarah/core/config/app_config.dart';
import 'package:silarah/core/services/supabase_service.dart';

enum BackendConnectionQuality { unknown, good, poor, offline }

class ConnectivityService with WidgetsBindingObserver {
  ConnectivityService._({
    this.checkInterval = const Duration(minutes: 5),
  }) {
    _startMonitoring();
  }

  /// Singleton instance — call [initialize] in main() before use.
  static ConnectivityService? _instance;
  static ConnectivityService get instance {
    assert(_instance != null,
        'ConnectivityService.initialize() must be called first');
    return _instance!;
  }

  /// Create the singleton. Safe to call multiple times (idempotent).
  static ConnectivityService initialize({
    Duration checkInterval = const Duration(minutes: 5),
  }) {
    _instance ??= ConnectivityService._(checkInterval: checkInterval);
    return _instance!;
  }

  final Duration checkInterval;

  final _controller = StreamController<bool>.broadcast();
  Timer? _timer;
  Future<bool>? _checkInFlight;
  bool _lastKnownState = true;
  BackendConnectionQuality _lastQuality = BackendConnectionQuality.unknown;
  Duration? _lastLatency;
  bool _isForeground = true;
  DateTime? _lastCheckedAt;

  static const _offlineRetryInterval = Duration(seconds: 30);
  static const _resumeFreshness = Duration(seconds: 30);

  /// Stream of connectivity changes (true = online, false = offline).
  Stream<bool> get connectivityStream => _controller.stream;

  /// Whether the device was online at last check.
  bool get isOnline => _lastKnownState;

  /// Quality is based on the same authenticated-backend health request used
  /// for reachability. It adds no network calls and avoids platform-specific
  /// radio permissions that would not work consistently on Wi-Fi.
  BackendConnectionQuality get quality => _lastQuality;
  Duration? get lastLatency => _lastLatency;

  /// Immediately check connectivity and return result.
  Future<bool> checkNow() {
    final activeCheck = _checkInFlight;
    if (activeCheck != null) return activeCheck;

    final check = _performCheck();
    _checkInFlight = check;
    return check.whenComplete(() {
      if (identical(_checkInFlight, check)) _checkInFlight = null;
    });
  }

  Future<bool> _performCheck() async {
    HttpClient? client;
    final stopwatch = Stopwatch()..start();
    try {
      Uri endpoint = Uri.https('1.1.1.1', '/cdn-cgi/trace');
      if (SupabaseService.isInitialized) {
        final uri = Uri.tryParse(AppConfig.supabaseUrl);
        if (uri != null && uri.host.isNotEmpty) {
          endpoint = uri.replace(path: '/auth/v1/health', query: null);
        }
      }

      client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
      final request = await client.getUrl(endpoint).timeout(
            const Duration(seconds: 4),
          );
      request.followRedirects = false;
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close().timeout(
            const Duration(seconds: 4),
          );
      await response.drain<void>();
      final online = response.statusCode >= 200 && response.statusCode < 500;
      stopwatch.stop();
      _lastLatency = stopwatch.elapsed;
      _lastQuality = !online
          ? BackendConnectionQuality.offline
          : stopwatch.elapsed > const Duration(milliseconds: 1100)
              ? BackendConnectionQuality.poor
              : BackendConnectionQuality.good;
      _updateState(online);
      return online;
    } on SocketException catch (_) {
      _lastLatency = null;
      _lastQuality = BackendConnectionQuality.offline;
      _updateState(false);
      return false;
    } on TimeoutException catch (_) {
      _lastLatency = null;
      _lastQuality = BackendConnectionQuality.offline;
      _updateState(false);
      return false;
    } catch (e) {
      debugPrint('ConnectivityService: unexpected error: $e');
      _lastLatency = null;
      _lastQuality = BackendConnectionQuality.offline;
      _updateState(false);
      return false;
    } finally {
      _lastCheckedAt = DateTime.now();
      client?.close(force: true);
      _scheduleNextCheck();
    }
  }

  void _startMonitoring() {
    // Avoid starting background polling timers in unit/widget tests
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return;
    }
    WidgetsBinding.instance.addObserver(this);
    unawaited(checkNow());
  }

  void _scheduleNextCheck() {
    _timer?.cancel();
    if (!_isForeground || _controller.isClosed) return;
    // Healthy connections need only a low-frequency backend health check.
    // Offline devices retry sooner so the startup recovery screen remains
    // responsive without continuously billing the backend while online.
    _timer = Timer(
      _lastKnownState ? checkInterval : _offlineRetryInterval,
      () => unawaited(checkNow()),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isForeground = state == AppLifecycleState.resumed;
    if (!_isForeground) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    final lastCheck = _lastCheckedAt;
    if (lastCheck == null ||
        DateTime.now().difference(lastCheck) >= _resumeFreshness) {
      unawaited(checkNow());
    } else {
      _scheduleNextCheck();
    }
  }

  void _updateState(bool online) {
    if (online != _lastKnownState) {
      _lastKnownState = online;
      if (!_controller.isClosed) {
        _controller.add(online);
      }
    }
  }

  /// Stop polling and close the stream.
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _controller.close();
    if (identical(_instance, this)) _instance = null;
  }
}
