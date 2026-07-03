import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mithaq/core/services/photo_moderation_service.dart';
import 'package:nsfw_detect/nsfw_detect.dart';

ScanResult resultFor({
  required ScanStatus status,
  required NsfwCategory category,
  required double confidence,
}) =>
    resultWithLabels(
      status: status,
      labels: [NsfwLabel(category: category, confidence: confidence)],
    );

ScanResult resultWithLabels({
  required ScanStatus status,
  required List<NsfwLabel> labels,
}) =>
    ScanResult(
      item: MediaItem.empty(),
      status: status,
      labels: labels,
      scannedAt: DateTime(2026, 7, 3),
      confidenceThreshold: PhotoModerationService.scannerCollectionThreshold,
    );

PhotoModerationService serviceFor({
  required ScanResult scan,
  FaceProminenceResult face = const FaceProminenceResult(
    hasFace: true,
    faceCount: 1,
    faceRatio: 0.12,
  ),
}) =>
    PhotoModerationService(
      scanner: (_) async => scan,
      faceChecker: (_) async => face,
    );

void main() {
  group('PhotoModerationService', () {
    test('normal clear face portrait passes', () async {
      final file = await _writeSyntheticPhoto(_SyntheticPhoto.casual);
      addTearDown(() => file.deleteSync());

      final result = await serviceFor(
        scan: resultFor(
          status: ScanStatus.completed,
          category: NsfwCategory.safe,
          confidence: 0.99,
        ),
      ).scanFile(file.path);

      expect(result.decision, PhotoModerationDecision.safe);
      expect(result.canUpload, isTrue);
    });

    test('hijab/normal modest portrait passes', () async {
      final file = await _writeSyntheticPhoto(_SyntheticPhoto.hijab);
      addTearDown(() => file.deleteSync());

      final result = await serviceFor(
        scan: resultFor(
          status: ScanStatus.completed,
          category: NsfwCategory.safe,
          confidence: 0.98,
        ),
      ).scanFile(file.path);

      expect(result.decision, PhotoModerationDecision.safe);
    });

    test('saree and visible arms do not falsely reject', () async {
      for (final type in [_SyntheticPhoto.saree, _SyntheticPhoto.sleeveless]) {
        final file = await _writeSyntheticPhoto(type);
        addTearDown(() => file.deleteSync());

        final result = await serviceFor(
          scan: resultFor(
            status: ScanStatus.completed,
            category: NsfwCategory.safe,
            confidence: 0.97,
          ),
        ).scanFile(file.path);

        expect(result.decision, PhotoModerationDecision.safe);
      }
    });

    test('full-body bikini is rejected when body-dominant exposure is detected',
        () async {
      final file = await _writeSyntheticPhoto(_SyntheticPhoto.swimwear);
      addTearDown(() => file.deleteSync());

      final result = await serviceFor(
        scan: resultFor(
          status: ScanStatus.completed,
          category: NsfwCategory.safe,
          confidence: 0.93,
        ),
        face: const FaceProminenceResult(
          hasFace: true,
          faceCount: 1,
          faceRatio: 0.03,
        ),
      ).scanFile(file.path);

      expect(
        result.decision,
        anyOf(
          PhotoModerationDecision.unsafe,
          PhotoModerationDecision.pendingReview,
        ),
      );
      expect(result.decision, PhotoModerationDecision.unsafe);
      expect(result.category, 'explicit_content');
    });

    test('nude photo is rejected', () async {
      final file = await _writeSyntheticPhoto(_SyntheticPhoto.nude);
      addTearDown(() => file.deleteSync());

      final result = await serviceFor(
        scan: resultFor(
          status: ScanStatus.completed,
          category: NsfwCategory.nudity,
          confidence: 0.90,
        ),
      ).scanFile(file.path);

      expect(result.decision, PhotoModerationDecision.unsafe);
      expect(result.category, 'explicit_content');
    });

    test('no-face image is rejected', () async {
      final file = await _writeSyntheticPhoto(_SyntheticPhoto.casual);
      addTearDown(() => file.deleteSync());

      final result = await serviceFor(
        scan: resultFor(
          status: ScanStatus.completed,
          category: NsfwCategory.safe,
          confidence: 0.99,
        ),
        face: FaceProminenceResult.noFace(),
      ).scanFile(file.path);

      expect(result.decision, PhotoModerationDecision.unsafe);
      expect(result.category, 'no_face');
    });

    test('small-face body-dominant image is rejected or held for review',
        () async {
      final file = await _writeSyntheticPhoto(_SyntheticPhoto.casual);
      addTearDown(() => file.deleteSync());

      final result = await serviceFor(
        scan: resultFor(
          status: ScanStatus.completed,
          category: NsfwCategory.safe,
          confidence: 0.99,
        ),
        face: const FaceProminenceResult(
          hasFace: true,
          faceCount: 1,
          faceRatio: 0.03,
        ),
      ).scanFile(file.path);

      expect(
        result.decision,
        anyOf(
          PhotoModerationDecision.unsafe,
          PhotoModerationDecision.pendingReview,
        ),
      );
    });

    test('borderline binary NSFW score is uploadable but pending review',
        () async {
      final file = await _writeSyntheticPhoto(_SyntheticPhoto.casual);
      addTearDown(() => file.deleteSync());

      final result = await serviceFor(
        scan: resultFor(
          status: ScanStatus.completed,
          category: NsfwCategory.nudity,
          confidence: 0.62,
        ),
      ).scanFile(file.path);

      expect(result.decision, PhotoModerationDecision.pendingReview);
      expect(result.canUpload, isTrue);
      expect(result.isSafe, isFalse);
    });

    test('failed classifier result fails closed', () {
      final result = PhotoModerationService.evaluate(resultFor(
        status: ScanStatus.failed,
        category: NsfwCategory.unknown,
        confidence: 0,
      ));

      expect(result.decision, PhotoModerationDecision.scanFailed);
      expect(result.canUpload, isFalse);
    });
  });
}

enum _SyntheticPhoto { casual, hijab, saree, sleeveless, swimwear, nude }

Future<File> _writeSyntheticPhoto(_SyntheticPhoto type) async {
  final file = File(
    '${Directory.systemTemp.path}/mithaq_moderation_${type.name}_${DateTime.now().microsecondsSinceEpoch}.jpg',
  );
  await file.writeAsBytes(_syntheticPhotoBytes(type));
  return file;
}

Uint8List _syntheticPhotoBytes(_SyntheticPhoto type) {
  final canvas = img.Image(width: 220, height: 360);
  img.fill(canvas, color: img.ColorRgb8(245, 245, 245));

  final skin = img.ColorRgb8(198, 132, 92);
  final darkFabric = img.ColorRgb8(26, 32, 42);
  final blueFabric = img.ColorRgb8(34, 74, 130);
  final goldFabric = img.ColorRgb8(196, 142, 48);
  final redFabric = img.ColorRgb8(180, 42, 72);

  img.fillRect(canvas, x1: 92, y1: 32, x2: 128, y2: 70, color: skin);

  switch (type) {
    case _SyntheticPhoto.casual:
      img.fillRect(canvas, x1: 64, y1: 78, x2: 156, y2: 315, color: darkFabric);
    case _SyntheticPhoto.hijab:
      img.fillCircle(canvas, x: 110, y: 52, radius: 28, color: darkFabric);
      img.fillRect(canvas, x1: 64, y1: 78, x2: 156, y2: 315, color: darkFabric);
      img.fillRect(canvas, x1: 96, y1: 38, x2: 124, y2: 68, color: skin);
    case _SyntheticPhoto.saree:
      img.fillRect(canvas, x1: 60, y1: 80, x2: 160, y2: 125, color: goldFabric);
      img.fillRect(canvas, x1: 62, y1: 125, x2: 158, y2: 168, color: skin);
      img.fillRect(canvas,
          x1: 58, y1: 168, x2: 162, y2: 320, color: blueFabric);
      img.fillRect(canvas, x1: 44, y1: 90, x2: 70, y2: 300, color: blueFabric);
    case _SyntheticPhoto.sleeveless:
      img.fillRect(canvas, x1: 44, y1: 80, x2: 64, y2: 250, color: skin);
      img.fillRect(canvas, x1: 156, y1: 80, x2: 176, y2: 250, color: skin);
      img.fillRect(canvas, x1: 66, y1: 82, x2: 154, y2: 315, color: darkFabric);
    case _SyntheticPhoto.swimwear:
      img.fillRect(canvas, x1: 72, y1: 78, x2: 148, y2: 315, color: skin);
      img.fillRect(canvas, x1: 70, y1: 105, x2: 150, y2: 137, color: redFabric);
      img.fillRect(canvas, x1: 74, y1: 218, x2: 146, y2: 252, color: redFabric);
    case _SyntheticPhoto.nude:
      img.fillRect(canvas, x1: 72, y1: 78, x2: 148, y2: 315, color: skin);
  }

  return Uint8List.fromList(img.encodeJpg(canvas, quality: 95));
}
