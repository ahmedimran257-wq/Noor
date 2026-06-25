import 'package:flutter_test/flutter_test.dart';
import 'package:mithaq/core/services/photo_moderation_service.dart';
import 'package:nsfw_detect/nsfw_detect.dart';

ScanResult resultFor({
  required ScanStatus status,
  required NsfwCategory category,
  required double confidence,
}) =>
    ScanResult(
      item: MediaItem.empty(),
      status: status,
      labels: [NsfwLabel(category: category, confidence: confidence)],
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

    test('rejects nudity at the conservative upload threshold', () {
      final result = PhotoModerationService.evaluate(resultFor(
        status: ScanStatus.completed,
        category: NsfwCategory.nudity,
        confidence: 0.5,
      ));

      expect(result.decision, PhotoModerationDecision.unsafe);
      expect(result.toValidationPayload()['is_nsfw'], isTrue);
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
  });
}
