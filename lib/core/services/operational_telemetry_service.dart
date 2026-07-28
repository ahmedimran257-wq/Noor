import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Privacy-safe non-fatal operational telemetry.
///
/// Only stable codes are recorded. Exceptions, message text, search terms,
/// object paths, emails, IDs, and provider payloads must never be passed here.
class OperationalTelemetryService {
  OperationalTelemetryService._();

  static final Map<String, DateTime> _lastRecorded = <String, DateTime>{};
  static const _minimumInterval = Duration(minutes: 10);

  static void record(String component, String code) {
    final normalizedComponent = _normalize(component);
    final normalizedCode = _normalize(code);
    if (normalizedComponent.isEmpty || normalizedCode.isEmpty) return;
    final key = '$normalizedComponent:$normalizedCode';
    final now = DateTime.now();
    final last = _lastRecorded[key];
    if (last != null && now.difference(last) < _minimumInterval) return;
    _lastRecorded[key] = now;

    if (kDebugMode) {
      debugPrint('[OperationalTelemetry] $key');
    }
    unawaited(_recordNonFatal(key));
  }

  static Future<void> _recordNonFatal(String key) async {
    try {
      await FirebaseCrashlytics.instance.recordError(
        StateError(key),
        StackTrace.current,
        reason: key,
        fatal: false,
      );
    } catch (_) {
      // Telemetry must never become a second application failure.
    }
  }

  static String _normalize(String value) {
    final normalized =
        value.trim().toLowerCase().replaceAll(RegExp('[^a-z0-9_:-]'), '_');
    return normalized.length <= 64 ? normalized : normalized.substring(0, 64);
  }
}
