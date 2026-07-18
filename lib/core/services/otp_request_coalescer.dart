import 'dart:async';

/// Ensures one authentication email request is active at a time.
///
/// A keyboard submission and a button tap can be delivered in the same frame.
/// Both callers receive the same future, while only the first callback reaches
/// Supabase. The gate opens again after success or failure.
class OtpRequestCoalescer {
  Future<void>? _inFlight;

  Future<void> run(Future<void> Function() request) {
    final current = _inFlight;
    if (current != null) return current;

    final operation = Future<void>.sync(request);
    _inFlight = operation;
    unawaited(
      operation.then<void>(
        (_) => _release(operation),
        onError: (Object _, StackTrace __) => _release(operation),
      ),
    );
    return operation;
  }

  void _release(Future<void> operation) {
    if (identical(_inFlight, operation)) _inFlight = null;
  }
}
