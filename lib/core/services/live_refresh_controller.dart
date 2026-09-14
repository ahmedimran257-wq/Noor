import 'dart:async';
import 'dart:math';

/// Coalesced, single-flight reads for an active live screen. No healthy polling.
/// A failed socket gets a jittered 30–45 second fallback, automatically removed
/// after reconnection. Pausing/disposal cancels scheduled work, never writes.
class LiveRefreshController {
  LiveRefreshController({
    required this.refresh,
    DateTime Function()? now,
    int Function(int)? randomInt,
  })  : _now = now ?? DateTime.now,
        _randomInt = randomInt ?? Random().nextInt;

  final Future<void> Function() refresh;
  final DateTime Function() _now;
  final int Function(int) _randomInt;
  Timer? _refreshTimer;
  Timer? _fallbackTimer;
  bool _active = false;
  bool _connected = false;
  bool _disposed = false;
  bool _inFlight = false;
  bool _pending = false;
  DateTime? _finishedAt;

  void start() {
    if (_disposed || _active) return;
    _active = true;
    _scheduleFallback();
  }

  void stop() {
    _active = false;
    _pending = false;
    _refreshTimer?.cancel();
    _fallbackTimer?.cancel();
    _refreshTimer = null;
    _fallbackTimer = null;
  }

  void setConnected(bool connected) {
    if (_disposed) return;
    final recovered = connected && !_connected;
    _connected = connected;
    if (connected) {
      _fallbackTimer?.cancel();
      _fallbackTimer = null;
      if (recovered) request(); // Read the durable state missed while offline.
    } else {
      _scheduleFallback();
    }
  }

  void request() {
    if (_disposed || !_active) return;
    if (_inFlight) {
      _pending = true;
      return;
    }
    // Do not reset this timer on every event: continuous traffic must not
    // postpone the refresh forever. At most one read runs at a time.
    if (_refreshTimer != null) return;
    final elapsed = _finishedAt == null
        ? 2000
        : _now().difference(_finishedAt!).inMilliseconds;
    final delay = max(400 + _randomInt(600), 2000 - elapsed);
    _refreshTimer = Timer(Duration(milliseconds: delay), () {
      _refreshTimer = null;
      unawaited(_run());
    });
  }

  Future<void> _run() async {
    if (_disposed || !_active) return;
    _inFlight = true;
    try {
      await refresh();
    } catch (_) {
      // The screen owns error presentation. Failed reads are retried only by
      // another signal or the bounded fallback, not a tight exception loop.
    } finally {
      _inFlight = false;
      _finishedAt = _now();
      if (_pending) {
        _pending = false;
        request();
      }
    }
  }

  void _scheduleFallback() {
    if (_disposed || !_active || _connected || _fallbackTimer != null) return;
    _fallbackTimer = Timer(Duration(seconds: 30 + _randomInt(16)), () {
      _fallbackTimer = null;
      request();
      _scheduleFallback();
    });
  }

  void dispose() {
    stop();
    _disposed = true;
  }
}
