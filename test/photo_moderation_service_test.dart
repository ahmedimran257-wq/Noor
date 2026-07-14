import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:silarah/core/services/photo_moderation_service.dart';
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

PhotoModerationService serviceFor({required ScanResult scan}) =>
    PhotoModerationService(scanner: (_) async => scan);

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

      expect(result.decision, PhotoModerationDecision.approved);
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

      expect(result.decision, PhotoModerationDecision.approved);
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

        expect(result.decision, PhotoModerationDecision.approved);
      }
    });

    test('body prominence never changes an otherwise safe classifier result',
        () async {
      final file = await _writeSyntheticPhoto(_SyntheticPhoto.swimwear);
      addTearDown(() => file.deleteSync());

      final result = await serviceFor(
        scan: resultFor(
          status: ScanStatus.completed,
          category: NsfwCategory.safe,
          confidence: 0.93,
        ),
      ).scanFile(file.path);

      expect(result.decision, PhotoModerationDecision.approved);
      expect(result.isSafe, isTrue);
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

      expect(result.decision, PhotoModerationDecision.flagged);
      expect(result.category, 'explicit_content');
    });

    test('an image without a detectable face passes when non-explicit',
        () async {
      final file = await _writeSyntheticPhoto(_SyntheticPhoto.casual);
      addTearDown(() => file.deleteSync());

      final result = await serviceFor(
        scan: resultFor(
          status: ScanStatus.completed,
          category: NsfwCategory.safe,
          confidence: 0.99,
        ),
      ).scanFile(file.path);

      expect(result.decision, PhotoModerationDecision.approved);
      expect(result.category, 'safe_image');
    });

    test('small or veiled faces are not evaluated by upload moderation',
        () async {
      final file = await _writeSyntheticPhoto(_SyntheticPhoto.casual);
      addTearDown(() => file.deleteSync());

      final result = await serviceFor(
        scan: resultFor(
          status: ScanStatus.completed,
          category: NsfwCategory.safe,
          confidence: 0.99,
        ),
      ).scanFile(file.path);

      expect(result.decision, PhotoModerationDecision.approved);
    });

    test('low-neutral non-explicit result passes without admin review',
        () async {
      final file = await _writeSyntheticPhoto(_SyntheticPhoto.casual);
      addTearDown(() => file.deleteSync());

      final result = await serviceFor(
        scan: resultWithLabels(
          status: ScanStatus.completed,
          labels: const [
            NsfwLabel(category: NsfwCategory.nudity, confidence: 0.78),
            NsfwLabel(category: NsfwCategory.safe, confidence: 0.24),
          ],
        ),
      ).scanFile(file.path);

      expect(result.decision, PhotoModerationDecision.approved);
      expect(result.category, 'safe_image');
      expect(result.confidence, 0.24);
      expect(result.canUpload, isTrue);
    });

    test('explicit threshold is strict and only values above 0.85 flag', () {
      final atThreshold = PhotoModerationService.evaluate(resultWithLabels(
        status: ScanStatus.completed,
        labels: const [
          NsfwLabel(category: NsfwCategory.nudity, confidence: 0.85),
          NsfwLabel(category: NsfwCategory.safe, confidence: 0.15),
        ],
      ));
      final aboveThreshold = PhotoModerationService.evaluate(resultWithLabels(
        status: ScanStatus.completed,
        labels: const [
          NsfwLabel(category: NsfwCategory.nudity, confidence: 0.851),
          NsfwLabel(category: NsfwCategory.safe, confidence: 0.149),
        ],
      ));

      expect(atThreshold.decision, PhotoModerationDecision.approved);
      expect(atThreshold.category, 'safe_image');
      expect(aboveThreshold.decision, PhotoModerationDecision.flagged);
      expect(aboveThreshold.category, 'explicit_content');
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

    test('corrupted and blank files are rejected before classification',
        () async {
      final corrupt = File(
        '${Directory.systemTemp.path}/silarah_corrupt_${DateTime.now().microsecondsSinceEpoch}.jpg',
      )..writeAsBytesSync(const [1, 2, 3, 4]);
      final blankImage = img.Image(width: 128, height: 128);
      img.fill(blankImage, color: img.ColorRgb8(255, 255, 255));
      final blank = File(
        '${Directory.systemTemp.path}/silarah_blank_${DateTime.now().microsecondsSinceEpoch}.jpg',
      )..writeAsBytesSync(img.encodeJpg(blankImage));
      addTearDown(() {
        corrupt.deleteSync();
        blank.deleteSync();
      });

      final service = serviceFor(
        scan: resultFor(
          status: ScanStatus.completed,
          category: NsfwCategory.safe,
          confidence: 0.99,
        ),
      );
      for (final file in [corrupt, blank]) {
        final result = await service.scanFile(file.path);
        expect(result.decision, PhotoModerationDecision.rejected);
        expect(result.category, 'invalid_image');
      }
    });
  });
}

enum _SyntheticPhoto { casual, hijab, saree, sleeveless, swimwear, nude }

Future<File> _writeSyntheticPhoto(_SyntheticPhoto type) async {
  final file = File(
    '${Directory.systemTemp.path}/silarah_moderation_${type.name}_${DateTime.now().microsecondsSinceEpoch}.jpg',
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
