import 'package:nsfw_detect/nsfw_detect.dart';

enum PhotoModerationDecision { safe, unsafe, scanFailed }

class PhotoModerationResult {
  const PhotoModerationResult({
    required this.decision,
    required this.confidence,
    required this.category,
    required this.threshold,
    this.error,
  });

  final PhotoModerationDecision decision;
  final double confidence;
  final String category;
  final double threshold;
  final String? error;

  bool get isSafe => decision == PhotoModerationDecision.safe;

  Map<String, dynamic> toValidationPayload() => {
        'status': decision.name,
        'is_nsfw': decision == PhotoModerationDecision.unsafe,
        'confidence': confidence,
        'category': category,
        'threshold': threshold,
      };
}

typedef PhotoScanCallback = Future<ScanResult> Function(String path);

/// Runs privacy-preserving NSFW classification entirely on the user's device.
/// The OpenNSFW2 model is supplied by the MIT-licensed `nsfw_detect` package.
class PhotoModerationService {
  PhotoModerationService({PhotoScanCallback? scanner})
      : _scanner = scanner ??
            ((path) => NsfwDetector.instance.scanFile(
                  path,
                  confidenceThreshold: confidenceThreshold,
                ));

  static final PhotoModerationService instance = PhotoModerationService();

  // A lower threshold is deliberate: profile photos favor false positives
  // over exposing users to explicit content. Tune from production review data.
  static const double confidenceThreshold = 0.5;

  final PhotoScanCallback _scanner;

  Future<PhotoModerationResult> scanFile(String path) async {
    try {
      return evaluate(await _scanner(path));
    } catch (error) {
      return PhotoModerationResult(
        decision: PhotoModerationDecision.scanFailed,
        confidence: 0,
        category: NsfwCategory.unknown.name,
        threshold: confidenceThreshold,
        error: error.toString(),
      );
    }
  }

  static PhotoModerationResult evaluate(ScanResult result) {
    if (result.status != ScanStatus.completed) {
      return PhotoModerationResult(
        decision: PhotoModerationDecision.scanFailed,
        confidence: result.topConfidence,
        category: result.topCategory.name,
        threshold: confidenceThreshold,
        error: result.errorMessage,
      );
    }

    return PhotoModerationResult(
      decision: result.isNsfw
          ? PhotoModerationDecision.unsafe
          : PhotoModerationDecision.safe,
      confidence: result.topConfidence,
      category: result.topCategory.name,
      threshold: confidenceThreshold,
    );
  }
}
