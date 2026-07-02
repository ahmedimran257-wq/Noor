import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
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
      : _scanner = scanner ?? _scanNormalizedFile;

  static final PhotoModerationService instance = PhotoModerationService();
  static Future<void>? _classifierReady;

  static Future<void> warmUp() => _ensureClassifierReady();

  // A lower threshold is deliberate: profile photos favor false positives
  // over exposing users to explicit content. Tune from production review data.
  static const double confidenceThreshold = 0.5;

  final PhotoScanCallback _scanner;

  Future<PhotoModerationResult> scanFile(String path) async {
    try {
      return evaluate(await _scanner(path));
    } catch (error) {
      debugPrint('[PhotoModerationService] scan failed: $error');
      return PhotoModerationResult(
        decision: PhotoModerationDecision.scanFailed,
        confidence: 0,
        category: NsfwCategory.unknown.name,
        threshold: confidenceThreshold,
        error: error.toString(),
      );
    }
  }

  static Future<ScanResult> _scanNormalizedFile(String path) async {
    await _ensureClassifierReady();
    final bytes = await File(path).readAsBytes();
    final normalized = _normalizeForClassifier(bytes);
    if (normalized != null) {
      return NsfwDetector.instance.scanBytes(
        normalized,
        confidenceThreshold: confidenceThreshold,
      );
    }

    return NsfwDetector.instance.scanFile(
      path,
      confidenceThreshold: confidenceThreshold,
    );
  }

  static Future<void> _ensureClassifierReady() {
    final existing = _classifierReady;
    if (existing != null) return existing;

    // First upload after install can arrive before app-start warm-up has
    // finished. Gate every real scan on model readiness so safe photos are not
    // rejected with "model not downloaded" platform failures.
    return _classifierReady = () async {
      await NsfwDetector.instance.init(const NsfwInitOptions(
        preloadModels: [],
        tolerateModelErrors: true,
        enableNativeLogging: kDebugMode,
        defaultThreshold: confidenceThreshold,
      ));
      await NsfwDetector.instance.models.ensureReady(ModelIds.openNsfw2);
    }()
        .catchError((Object error) {
      _classifierReady = null;
      throw error;
    });
  }

  static Uint8List? _normalizeForClassifier(Uint8List bytes) {
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return null;

      final oriented = img.bakeOrientation(decoded);
      final resized = oriented.width > 1280 || oriented.height > 1280
          ? img.copyResize(
              oriented,
              width: oriented.width >= oriented.height ? 1280 : null,
              height: oriented.height > oriented.width ? 1280 : null,
              interpolation: img.Interpolation.average,
            )
          : oriented;

      // NSFW and face engines are most reliable with JPEG/PNG byte streams.
      // Uploaded photos may be WebP, but moderation always uses this JPEG
      // analysis copy so decoder differences cannot reject valid safe photos.
      return Uint8List.fromList(img.encodeJpg(resized, quality: 90));
    } catch (error) {
      debugPrint('[PhotoModerationService] image normalization failed: $error');
      return null;
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
