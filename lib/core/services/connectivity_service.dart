// lib/core/services/connectivity_service.dart
// ============================================================
// MITHAQ — Connectivity Service
// Lightweight connectivity checker using dart:io.
// No extra dependency needed — uses InternetAddress.lookup().
//
// Usage:
//   final service = ConnectivityService();
//   service.connectivityStream.listen((isOnline) { ... });
//   final online = await service.checkNow();
//   service.dispose(); // when done
//
// Step 12: Replace with connectivity_plus for better platform
// support if needed.
// ============================================================

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:mithaq/core/config/app_config.dart';
import 'package:mithaq/core/services/supabase_service.dart';

class ConnectivityService {
  ConnectivityService._({
    this.checkInterval = const Duration(seconds: 30),
  }) {
    _startPolling();
  }

  /// Singleton instance — call [initialize] in main() before use.
  static ConnectivityService? _instance;
  static ConnectivityService get instance {
    assert(_instance != null, 'ConnectivityService.initialize() must be called first');
    return _instance!;
  }

  /// Create the singleton. Safe to call multiple times (idempotent).
  static ConnectivityService initialize({
    Duration checkInterval = const Duration(seconds: 30),
  }) {
    _instance ??= ConnectivityService._(checkInterval: checkInterval);
    return _instance!;
  }

  final Duration checkInterval;

  final _controller = StreamController<bool>.broadcast();
  Timer? _timer;
  bool _lastKnownState = true;

  /// Stream of connectivity changes (true = online, false = offline).
  Stream<bool> get connectivityStream => _controller.stream;

  /// Whether the device was online at last check.
  bool get isOnline => _lastKnownState;

  /// Immediately check connectivity and return result.
  Future<bool> checkNow() async {
    try {
      String host = 'one.one.one.one';
      if (SupabaseService.isInitialized) {
        final uri = Uri.tryParse(AppConfig.supabaseUrl);
        if (uri != null && uri.host.isNotEmpty) {
          host = uri.host;
        }
      }

      final result = await InternetAddress.lookup(host)
          .timeout(const Duration(seconds: 5));
      final online = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      _updateState(online);
      return online;
    } on SocketException catch (_) {
      _updateState(false);
      return false;
    } on TimeoutException catch (_) {
      _updateState(false);
      return false;
    } catch (e) {
      debugPrint('ConnectivityService: unexpected error: $e');
      _updateState(false);
      return false;
    }
  }

  void _startPolling() {
    // Avoid starting background polling timers in unit/widget tests
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return;
    }
    // Initial check
    checkNow();
    // Periodic checks
    _timer = Timer.periodic(checkInterval, (_) => checkNow());
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
    _timer?.cancel();
    _controller.close();
  }
}
