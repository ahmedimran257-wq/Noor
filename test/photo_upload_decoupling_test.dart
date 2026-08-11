import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('profile photo moderation is independent from badge verification', () {
    test('upload screen contains no photo-badge capture gate', () {
      final source = File(
        'lib/features/onboarding/screens/photo_upload_screen.dart',
      ).readAsStringSync();

      expect(source, isNot(contains('FaceDetector')));
      expect(source, isNot(contains('_detectFace')));
      expect(source, isNot(contains('_FaceResult')));
      expect(source, isNot(contains('photo_error_no_face_detected')));
      expect(source, isNot(contains('faceResult')));
      expect(source, isNot(contains('proof-of-life')));
    });

    test('moderation service contains only human presence and NSFW gates', () {
      final source = File(
        'lib/core/services/photo_moderation_service.dart',
      ).readAsStringSync();

      expect(source, isNot(contains('google_mlkit_face_detection')));
      expect(source, isNot(contains('FaceDetector')));
      expect(source, isNot(contains('FaceProminence')));
      expect(source, isNot(contains('faceRatio')));
      expect(source, isNot(contains("category: 'no_face'")));
      expect(source, contains('google_mlkit_object_detection'));
      expect(source, contains('explicitContentFlagThreshold = 0.85'));
      expect(source, contains("category: 'no_person_detected'"));
      expect(source, contains("category: 'invalid_image'"));
      expect(source, isNot(contains("category: 'safety_uncertain'")));
      expect(source, isNot(contains('_isRealImage')));
      expect(source, isNot(contains('_classifierInputs')));
      expect(source, isNot(contains('_aggregateCropScans')));
      expect(source, isNot(contains('package:nsfw_detect')));
      expect(source, contains('opennsfw2_float16.tflite'));
      expect(source, contains('Interpreter.fromFile'));
      expect(source, contains('build_compact_nsfw_model.py'));
      expect(source, isNot(contains('Interpreter.fromAsset(')));
      expect(source, isNot(contains('ateq_nsfw.tflite')));
    });

    test('smile and blink guidance remains in badge verification only', () {
      final source = File(
        'lib/features/verification/screens/badge_verification_screen.dart',
      ).readAsStringSync();

      expect(source, contains('FaceDetector'));
      expect(source, contains('leftEyeOpenProbability'));
      expect(source, contains('rightEyeOpenProbability'));
    });

    test('upload helper text states only the explicit-content policy', () {
      final english = File('lib/l10n/app_en.arb').readAsStringSync();

      expect(
        english,
        contains(
          '"photo_banner_text": '
          '"Photos with explicit content are not permitted"',
        ),
      );
      expect(english, isNot(contains('clear photo showing your face')));
    });
  });
}
