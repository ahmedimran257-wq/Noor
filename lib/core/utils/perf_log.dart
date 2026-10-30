// SILARAH — opt-in startup timing marks
//
// Build with --dart-define=SILARAH_PERF_LOG=true to print "[perf]" lines to
// logcat. Without the define, kPerfLog is a compile-time false and every call
// is removed from the release binary.
import 'package:flutter/foundation.dart';

const bool kPerfLog = bool.fromEnvironment('SILARAH_PERF_LOG');

final Stopwatch _sinceStart = Stopwatch()..start();

/// Records [label] with milliseconds since the Dart isolate started.
void perfMark(String label) {
  if (!kPerfLog) return;
  // ignore: avoid_print
  print('[perf] ${_sinceStart.elapsedMilliseconds}ms $label');
}

/// Starts the clock at the very top of main() so marks share one origin.
void perfStart() {
  if (!kPerfLog) return;
  _sinceStart.reset();
  debugPrint('[perf] 0ms main');
}
