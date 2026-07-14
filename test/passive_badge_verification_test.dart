import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:silarah/core/services/selfie_verification_service.dart';

void main() {
  group('passive badge verification', () {
    late final String screen;
    late final String service;

    setUpAll(() {
      screen = File(
        'lib/features/verification/screens/badge_verification_screen.dart',
      ).readAsStringSync();
      service = File(
        'lib/core/services/selfie_verification_service.dart',
      ).readAsStringSync();
    });

    test('has no pose challenge or manual capture path', () {
      expect(screen, isNot(contains('VerificationChallenge')));
      expect(screen, isNot(contains('headEulerAngle')));
      expect(screen, isNot(contains("Text('Capture'")));
      expect(screen, contains('unawaited(_captureAutomatically())'));
    });

    test('enforces the passive readiness thresholds', () {
      expect(screen, contains('prominence < 0.30'));
      expect(screen, contains('leftEye <= 0.7'));
      expect(screen, contains('rightEye <= 0.7'));
      expect(screen, contains('setState(() => _countdown = 3)'));
    });

    test('runs post-capture anti-spoofing and grants the badge', () {
      expect(service, contains('_analyseTextureAndLighting'));
      expect(service, contains('faces.length != 1'));
      expect(service, contains("'has_verification_badge': true"));
      expect(service, contains("'type': 'badge_earned'"));
      expect(
          service, contains("'verification_challenge': 'passive_face_scan'"));
    });

    test('returns specific recovery reasons', () {
      expect(
        const PassiveFaceValidationResult.failure(
          PassiveFaceValidationError.poorLighting,
        ).errorMessage,
        'Move to better lighting',
      );
      expect(
        const PassiveFaceValidationResult.failure(
          PassiveFaceValidationError.multipleFaces,
        ).errorMessage,
        'Only one face should be visible',
      );
      expect(
        const PassiveFaceValidationResult.failure(
          PassiveFaceValidationError.sunglasses,
        ).errorMessage,
        'Remove sunglasses',
      );
    });
  });
}
