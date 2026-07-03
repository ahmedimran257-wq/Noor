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
      scannedAt: DateTime(2026, 6, 22),
      confidenceThreshold: PhotoModerationService.confidenceThreshold,
    );

void main() {
  group('PhotoModerationService', () {
    test('allows a completed safe classification', () {
      final result = PhotoModerationService.evaluate(resultFor(
        status: ScanStatus.completed,
        category: NsfwCategory.safe,
        confidence: 0.99,
      ));

      expect(result.decision, PhotoModerationDecision.safe);
      expect(result.isSafe, isTrue);
    });

    test('does not reject low-confidence nudity signal', () {
      final result = PhotoModerationService.evaluate(resultFor(
        status: ScanStatus.completed,
        category: NsfwCategory.nudity,
        confidence: 0.5,
      ));

      expect(result.decision, PhotoModerationDecision.safe);
    });

    test('rejects high-confidence explicit content', () {
      final result = PhotoModerationService.evaluate(resultFor(
        status: ScanStatus.completed,
        category: NsfwCategory.nudity,
        confidence: 0.96,
      ));

      expect(result.decision, PhotoModerationDecision.unsafe);
      expect(result.toValidationPayload()['is_nsfw'], isTrue);
    });

    test('allows suggestive signal when neutral/safe score is high', () {
      final result = PhotoModerationService.evaluate(resultWithLabels(
        status: ScanStatus.completed,
        labels: const [
          NsfwLabel(category: NsfwCategory.suggestive, confidence: 0.88),
          NsfwLabel(category: NsfwCategory.safe, confidence: 0.62),
        ],
      ));

      expect(result.decision, PhotoModerationDecision.safe);
    });

    test('neutral photo skips face prominence layer', () async {
      final file = await _writeSyntheticPhoto(_SyntheticPhoto.casual);
      addTearDown(() => file.deleteSync());
      var faceChecked = false;
      final service = PhotoModerationService(
        scanner: (_) async => resultWithLabels(
          status: ScanStatus.completed,
          labels: const [
            NsfwLabel(category: NsfwCategory.safe, confidence: 0.70),
            NsfwLabel(category: NsfwCategory.suggestive, confidence: 0.94),
          ],
        ),
        faceChecker: (_) async {
          faceChecked = true;
          return FaceProminenceResult.noFace();
        },
      );

      final result = await service.scanFile(file.path);

      expect(result.decision, PhotoModerationDecision.safe);
      expect(faceChecked, isFalse);
    });

    test('rejects high-suggestive photo when no face is detected', () async {
      final file = await _writeSyntheticPhoto(_SyntheticPhoto.swimwear);
      addTearDown(() => file.deleteSync());
      final service = PhotoModerationService(
        scanner: (_) async => resultWithLabels(
          status: ScanStatus.completed,
          labels: const [
            NsfwLabel(category: NsfwCategory.suggestive, confidence: 0.93),
            NsfwLabel(category: NsfwCategory.safe, confidence: 0.10),
          ],
        ),
        faceChecker: (_) async => FaceProminenceResult.noFace(),
      );

      final result = await service.scanFile(file.path);

      expect(result.decision, PhotoModerationDecision.unsafe);
      expect(result.category, 'no_face');
    });

    test('rejects high-suggestive body-dominant photo with tiny face',
        () async {
      final file = await _writeSyntheticPhoto(_SyntheticPhoto.swimwear);
      addTearDown(() => file.deleteSync());
      final service = PhotoModerationService(
        scanner: (_) async => resultWithLabels(
          status: ScanStatus.completed,
          labels: const [
            NsfwLabel(category: NsfwCategory.suggestive, confidence: 0.93),
            NsfwLabel(category: NsfwCategory.safe, confidence: 0.10),
          ],
        ),
        faceChecker: (_) async => const FaceProminenceResult(
          hasFace: true,
          faceCount: 1,
          faceRatio: 0.04,
        ),
      );

      final result = await service.scanFile(file.path);

      expect(result.decision, PhotoModerationDecision.unsafe);
      expect(result.category, 'explicit_content');
    });

    test('allows high-suggestive cultural photo with prominent face', () async {
      final file = await _writeSyntheticPhoto(_SyntheticPhoto.saree);
      addTearDown(() => file.deleteSync());
      final service = PhotoModerationService(
        scanner: (_) async => resultWithLabels(
          status: ScanStatus.completed,
          labels: const [
            NsfwLabel(category: NsfwCategory.suggestive, confidence: 0.93),
            NsfwLabel(category: NsfwCategory.safe, confidence: 0.10),
          ],
        ),
        faceChecker: (_) async => const FaceProminenceResult(
          hasFace: true,
          faceCount: 1,
          faceRatio: 0.12,
        ),
      );

      final result = await service.scanFile(file.path);

      expect(result.decision, PhotoModerationDecision.safe);
    });

    test('fails closed when native classification does not complete', () {
      final result = PhotoModerationService.evaluate(resultFor(
        status: ScanStatus.failed,
        category: NsfwCategory.unknown,
        confidence: 0,
      ));

      expect(result.decision, PhotoModerationDecision.scanFailed);
      expect(result.isSafe, isFalse);
    });

    test('allows western casual clothing when classifier reports safe',
        () async {
      final file = await _writeSyntheticPhoto(_SyntheticPhoto.casual);
      addTearDown(() => file.deleteSync());
      final service = PhotoModerationService(
        scanner: (_) async => resultFor(
          status: ScanStatus.completed,
          category: NsfwCategory.safe,
          confidence: 0.99,
        ),
      );

      final result = await service.scanFile(file.path);

      expect(result.decision, PhotoModerationDecision.safe);
    });

    test('allows saree-style visible midriff when classifier reports safe',
        () async {
      final file = await _writeSyntheticPhoto(_SyntheticPhoto.saree);
      addTearDown(() => file.deleteSync());
      final service = PhotoModerationService(
        scanner: (_) async => resultFor(
          status: ScanStatus.completed,
          category: NsfwCategory.safe,
          confidence: 0.99,
        ),
      );

      final result = await service.scanFile(file.path);

      expect(result.decision, PhotoModerationDecision.safe);
    });

    test('allows sleeveless top when classifier reports safe', () async {
      final file = await _writeSyntheticPhoto(_SyntheticPhoto.sleeveless);
      addTearDown(() => file.deleteSync());
      final service = PhotoModerationService(
        scanner: (_) async => resultFor(
          status: ScanStatus.completed,
          category: NsfwCategory.safe,
          confidence: 0.99,
        ),
      );

      final result = await service.scanFile(file.path);

      expect(result.decision, PhotoModerationDecision.safe);
    });

    test('rejects swimwear/full-body exposure even when classifier is safe',
        () async {
      final file = await _writeSyntheticPhoto(_SyntheticPhoto.swimwear);
      addTearDown(() => file.deleteSync());
      final service = PhotoModerationService(
        scanner: (_) async => resultFor(
          status: ScanStatus.completed,
          category: NsfwCategory.safe,
          confidence: 0.99,
        ),
      );

      final result = await service.scanFile(file.path);

      expect(result.decision, PhotoModerationDecision.unsafe);
      expect(result.category, 'explicit_content');
    });

    test('rejects nude full-body exposure even when classifier is neutral',
        () async {
      final file = await _writeSyntheticPhoto(_SyntheticPhoto.nude);
      addTearDown(() => file.deleteSync());
      final service = PhotoModerationService(
        scanner: (_) async => resultFor(
          status: ScanStatus.completed,
          category: NsfwCategory.safe,
          confidence: 0.99,
        ),
      );

      final result = await service.scanFile(file.path);

      expect(result.decision, PhotoModerationDecision.unsafe);
      expect(result.category, 'explicit_content');
    });

    test('rejects swimwear when classifier reports high-confidence nudity',
        () async {
      final file = await _writeSyntheticPhoto(_SyntheticPhoto.swimwear);
      addTearDown(() => file.deleteSync());
      final service = PhotoModerationService(
        scanner: (_) async => resultFor(
          status: ScanStatus.completed,
          category: NsfwCategory.nudity,
          confidence: 0.86,
        ),
      );

      final result = await service.scanFile(file.path);

      expect(result.decision, PhotoModerationDecision.unsafe);
      expect(result.category, 'explicit_content');
    });
  });
}

enum _SyntheticPhoto { casual, saree, sleeveless, swimwear, nude }

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

  img.fillRect(
    canvas,
    x1: 92,
    y1: 32,
    x2: 128,
    y2: 70,
    color: skin,
  );

  switch (type) {
    case _SyntheticPhoto.casual:
      img.fillRect(
        canvas,
        x1: 64,
        y1: 78,
        x2: 156,
        y2: 315,
        color: darkFabric,
      );
    case _SyntheticPhoto.saree:
      img.fillRect(
        canvas,
        x1: 60,
        y1: 80,
        x2: 160,
        y2: 125,
        color: goldFabric,
      );
      img.fillRect(
        canvas,
        x1: 62,
        y1: 125,
        x2: 158,
        y2: 168,
        color: skin,
      );
      img.fillRect(
        canvas,
        x1: 58,
        y1: 168,
        x2: 162,
        y2: 320,
        color: blueFabric,
      );
      img.fillRect(
        canvas,
        x1: 44,
        y1: 90,
        x2: 70,
        y2: 300,
        color: blueFabric,
      );
    case _SyntheticPhoto.sleeveless:
      img.fillRect(
        canvas,
        x1: 44,
        y1: 80,
        x2: 64,
        y2: 250,
        color: skin,
      );
      img.fillRect(
        canvas,
        x1: 156,
        y1: 80,
        x2: 176,
        y2: 250,
        color: skin,
      );
      img.fillRect(
        canvas,
        x1: 66,
        y1: 82,
        x2: 154,
        y2: 315,
        color: darkFabric,
      );
    case _SyntheticPhoto.swimwear:
      img.fillRect(
        canvas,
        x1: 72,
        y1: 78,
        x2: 148,
        y2: 315,
        color: skin,
      );
      img.fillRect(
        canvas,
        x1: 70,
        y1: 105,
        x2: 150,
        y2: 137,
        color: redFabric,
      );
      img.fillRect(
        canvas,
        x1: 74,
        y1: 218,
        x2: 146,
        y2: 252,
        color: redFabric,
      );
    case _SyntheticPhoto.nude:
      img.fillRect(
        canvas,
        x1: 72,
        y1: 78,
        x2: 148,
        y2: 315,
        color: skin,
      );
  }

  return Uint8List.fromList(img.encodeJpg(canvas, quality: 95));
}
