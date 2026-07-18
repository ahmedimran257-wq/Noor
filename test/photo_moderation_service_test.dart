import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:silarah/core/services/photo_moderation_service.dart';

PhotoModerationService serviceFor({
  bool hasHuman = true,
  NsfwScores scores = const NsfwScores(
    nsfw: 0.01,
    safe: 0.98,
  ),
  Object? scanError,
}) {
  return PhotoModerationService(
    humanPresenceScanner: (_) async => hasHuman,
    nsfwScanner: (_) async {
      if (scanError != null) throw scanError;
      return scores;
    },
  );
}

void main() {
  group('PhotoModerationService compact NSFW + ML Kit policy', () {
    test('human photo with low nudity score is approved', () async {
      final file = await _writeSyntheticPhoto();
      addTearDown(() => file.deleteSync());

      final result = await serviceFor(
        scores: const NsfwScores(
          nsfw: 0.03,
          safe: 0.95,
        ),
      ).scanFile(file.path);

      expect(result.decision, PhotoModerationDecision.approved);
      expect(result.category, 'safe_image');
      expect(result.canUpload, isTrue);
    });

    test('niqab, traditional dress, and group photos have no separate gate',
        () async {
      final file = await _writeSyntheticPhoto();
      addTearDown(() => file.deleteSync());

      for (final nudity in [0.01, 0.20, 0.84]) {
        final result = await serviceFor(
          scores: NsfwScores(
            nsfw: nudity,
            safe: 0.10,
          ),
        ).scanFile(file.path);
        expect(result.decision, PhotoModerationDecision.approved);
      }
    });

    test('an image without a detected human is rejected before NSFW', () async {
      final file = await _writeSyntheticPhoto();
      addTearDown(() => file.deleteSync());
      var classifierCalled = false;
      final service = PhotoModerationService(
        humanPresenceScanner: (_) async => false,
        nsfwScanner: (_) async {
          classifierCalled = true;
          return const NsfwScores(nsfw: 0, safe: 1);
        },
      );

      final result = await service.scanFile(file.path);

      expect(result.decision, PhotoModerationDecision.rejected);
      expect(result.category, 'no_person_detected');
      expect(result.canUpload, isFalse);
      expect(classifierCalled, isFalse);
    });

    test('0.85 is approved and only a score above 0.85 is flagged', () {
      final atThreshold = PhotoModerationService.evaluateScores(
        const NsfwScores(nsfw: 0.85, safe: 0.15),
      );
      final overThreshold = PhotoModerationService.evaluateScores(
        const NsfwScores(nsfw: 0.851, safe: 0.149),
      );

      expect(atThreshold.decision, PhotoModerationDecision.approved);
      expect(overThreshold.decision, PhotoModerationDecision.flagged);
      expect(overThreshold.category, 'explicit_content');
      expect(overThreshold.canUpload, isTrue);
    });

    test('low safe confidence cannot reject a non-explicit human photo', () {
      final result = PhotoModerationService.evaluateScores(
        const NsfwScores(nsfw: 0.20, safe: 0.10),
      );

      expect(result.decision, PhotoModerationDecision.approved);
      expect(result.category, 'safe_image');
    });

    test('validation payload carries NSFW scores and policy version', () {
      final result = PhotoModerationService.evaluateScores(
        const NsfwScores(nsfw: 0.92, safe: 0.08),
      );
      final payload = result.toValidationPayload();

      expect(payload['policy_version'], 3);
      expect(payload['nsfw_confidence'], 0.92);
      expect(payload['safe_confidence'], 0.08);
      expect(payload['is_nsfw'], isTrue);
      expect(payload['requires_review'], isTrue);
    });

    test('classifier failures fail closed', () async {
      final file = await _writeSyntheticPhoto();
      addTearDown(() => file.deleteSync());

      final result = await serviceFor(
        scanError: StateError('interpreter unavailable'),
      ).scanFile(file.path);

      expect(result.decision, PhotoModerationDecision.scanFailed);
      expect(result.category, 'scan_failed');
      expect(result.canUpload, isFalse);
    });

    test('missing or corrupted tiny files are rejected before native ML',
        () async {
      final file = File(
        '${Directory.systemTemp.path}/silarah_corrupt_${DateTime.now().microsecondsSinceEpoch}.jpg',
      )..writeAsBytesSync(const [1, 2, 3, 4]);
      addTearDown(() => file.deleteSync());

      final result = await serviceFor().scanFile(file.path);

      expect(result.decision, PhotoModerationDecision.rejected);
      expect(result.category, 'invalid_image');
    });

    test('bundled mobile model matches the verified conversion contract', () {
      final model = File(PhotoModerationService.modelAssetPath);

      expect(model.existsSync(), isTrue);
      expect(model.lengthSync(), PhotoModerationService.modelBytes);
      expect(
        sha256.convert(model.readAsBytesSync()).toString(),
        PhotoModerationService.modelSha256,
      );
      expect(
        PhotoModerationService.modelSource,
        'bhky/opennsfw2',
      );
      expect(PhotoModerationService.modelSha256, hasLength(64));
    });

    test('compact verified model is materialized and file-backed', () {
      final source = File(
        'lib/core/services/photo_moderation_service.dart',
      ).readAsStringSync();

      expect(source, contains('Interpreter.fromFile('));
      expect(source, contains('_materializeModelFile('));
      expect(source, contains('sha256.convert(bytes)'));
      expect(source, contains('build_compact_nsfw_model.py'));
      expect(source, contains('[1, 224, 224, 3]'));
      expect(source, isNot(contains('Interpreter.fromAsset(')));
    });
  });
}

Future<File> _writeSyntheticPhoto() async {
  final file = File(
    '${Directory.systemTemp.path}/silarah_nsfw_${DateTime.now().microsecondsSinceEpoch}.jpg',
  );
  await file.writeAsBytes(_syntheticPhotoBytes());
  return file;
}

Uint8List _syntheticPhotoBytes() {
  final canvas = img.Image(width: 220, height: 360);
  img.fill(canvas, color: img.ColorRgb8(245, 245, 245));
  img.fillCircle(
    canvas,
    x: 110,
    y: 58,
    radius: 28,
    color: img.ColorRgb8(198, 132, 92),
  );
  img.fillRect(
    canvas,
    x1: 64,
    y1: 88,
    x2: 156,
    y2: 320,
    color: img.ColorRgb8(26, 32, 42),
  );
  return Uint8List.fromList(img.encodeJpg(canvas, quality: 95));
}
