import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:silarah/core/services/otp_request_coalescer.dart';

void main() {
  test('parallel OTP submissions share one provider request', () async {
    final gate = OtpRequestCoalescer();
    final providerResponse = Completer<void>();
    var providerCalls = 0;

    Future<void> request() {
      providerCalls++;
      return providerResponse.future;
    }

    final keyboardSubmit = gate.run(request);
    final buttonTap = gate.run(request);

    expect(providerCalls, 1);
    expect(identical(keyboardSubmit, buttonTap), isTrue);

    providerResponse.complete();
    await Future.wait([keyboardSubmit, buttonTap]);
    await Future<void>.delayed(Duration.zero);

    await gate.run(() async => providerCalls++);
    expect(providerCalls, 2);
  });

  test('a failed request releases the gate for a real retry', () async {
    final gate = OtpRequestCoalescer();
    var providerCalls = 0;

    await expectLater(
      gate.run(() async {
        providerCalls++;
        throw StateError('SMTP unavailable');
      }),
      throwsStateError,
    );
    await Future<void>.delayed(Duration.zero);

    await gate.run(() async => providerCalls++);
    expect(providerCalls, 2);
  });
}
