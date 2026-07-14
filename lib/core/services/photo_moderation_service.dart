import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:nsfw_detect/nsfw_detect.dart';
import 'package:path_provider/path_provider.dart';

enum PhotoModerationDecision { approved, flagged, rejected, scanFailed }

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

  bool get isSafe => decision == PhotoModerationDecision.approved;
  bool get canUpload =>
      decision == PhotoModerationDecision.approved ||
      decision == PhotoModerationDecision.flagged;

  Map<String, dynamic> toValidationPayload() => {
        'status': decision.name,
        'is_nsfw': decision == PhotoModerationDecision.flagged,
        'requires_review': decision == PhotoModerationDecision.flagged,
        'confidence': confidence,
        'category': category,
        'threshold': threshold,
      };
}

typedef PhotoScanCallback = Future<ScanResult> Function(String path);

/// Runs privacy-preserving explicit-content classification on-device.
///
/// Profile-photo moderation deliberately performs no face, eye, prominence,
/// pose, or group-size analysis. Identity and liveness checks belong only to
/// the separate badge-verification flow.
class PhotoModerationService {
  PhotoModerationService({PhotoScanCallback? scanner})
      : _scanner = scanner ?? _scanNormalizedFile;

  static final PhotoModerationService instance = PhotoModerationService();
  static Future<void>? _classifierReady;

  static Future<void> warmUp() => _ensureClassifierReady();

  // The bundled Falconsai model is binary (safe/nsfw). Keep collection low so
  // moderate NSFW evidence is visible, then apply product policy separately.
  static const double scannerCollectionThreshold = 0.01;
  static const double explicitContentFlagThreshold = 0.85;
  static const double hardNsfwRejectThreshold = explicitContentFlagThreshold;
  static const double neutralContentPassThreshold = 0.30;
  static const double confidenceThreshold = hardNsfwRejectThreshold;
  static const String _localModelId = 'silarah_falconsai_nsfw';
  static const String _localModelAssetPath =
      'assets/models/falconsai_nsfw.tflite';
  static const String _localModelFileName = 'falconsai_nsfw.tflite';
  static const int _localModelBytes = 88008416;
  final PhotoScanCallback _scanner;

  Future<PhotoModerationResult> scanFile(String path) async {
    try {
      if (!await _isRealImage(path)) {
        return const PhotoModerationResult(
          decision: PhotoModerationDecision.rejected,
          confidence: 1,
          category: 'invalid_image',
          threshold: 0,
        );
      }

      final scan = await _scanner(path);
      return evaluate(scan);
    } catch (error) {
      debugPrint('[PhotoModerationService] scan failed: $error');
      return PhotoModerationResult(
        decision: PhotoModerationDecision.scanFailed,
        confidence: 0,
        category: NsfwCategory.unknown.name,
        threshold: scannerCollectionThreshold,
        error: error.toString(),
      );
    }
  }

  static Future<bool> _isRealImage(String path) async {
    final file = File(path);
    if (!await file.exists() || await file.length() < 128) return false;

    try {
      final decoded = img.decodeImage(await file.readAsBytes());
      if (decoded == null || decoded.width < 32 || decoded.height < 32) {
        return false;
      }

      final sample = img.copyResize(
        img.bakeOrientation(decoded),
        width: 32,
        height: 32,
        interpolation: img.Interpolation.average,
      );
      var minLuma = 255.0;
      var maxLuma = 0.0;
      final colorBuckets = <int>{};
      for (final pixel in sample) {
        final r = pixel.r.toDouble();
        final g = pixel.g.toDouble();
        final b = pixel.b.toDouble();
        final luma = (0.299 * r) + (0.587 * g) + (0.114 * b);
        minLuma = math.min(minLuma, luma);
        maxLuma = math.max(maxLuma, luma);
        colorBuckets.add(
          ((r ~/ 16) << 8) | ((g ~/ 16) << 4) | (b ~/ 16),
        );
      }

      // A decoded but essentially uniform frame is a blank capture, not a
      // usable photograph. This check is content-agnostic and never examines
      // faces, clothing, or the number of people present.
      return maxLuma - minLuma >= 4 && colorBuckets.length >= 4;
    } catch (_) {
      return false;
    }
  }

  static Future<ScanResult> _scanNormalizedFile(String path) async {
    await _ensureClassifierReady();
    final bytes = await File(path).readAsBytes();
    final classifierInputs = _classifierInputs(bytes);
    if (classifierInputs.isNotEmpty) {
      final scans = <ScanResult>[];
      for (final input in classifierInputs) {
        final scan = await NsfwDetector.instance.scanBytes(
          input,
          modelId: _localModelId,
          confidenceThreshold: scannerCollectionThreshold,
        );
        if (scan.status != ScanStatus.completed) return scan;
        scans.add(scan);
      }
      return _aggregateCropScans(scans);
    }

    return NsfwDetector.instance.scanFile(
      path,
      modelId: _localModelId,
      confidenceThreshold: scannerCollectionThreshold,
    );
  }

  /// Classifies the complete frame plus body-focused crops. Resizing a tall
  /// full-body image can otherwise make explicit regions too small for the
  /// NSFW model. This remains classifier-only: it uses no face or skin logic.
  static List<Uint8List> _classifierInputs(Uint8List bytes) {
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return const [];
      final oriented = img.bakeOrientation(decoded);
      final inputs = <img.Image>[
        oriented,
        _fractionalCrop(
          oriented,
          left: 0.10,
          top: 0.08,
          right: 0.90,
          bottom: 0.92,
        ),
        _fractionalCrop(
          oriented,
          left: 0.08,
          top: 0.02,
          right: 0.92,
          bottom: 0.68,
        ),
        _fractionalCrop(
          oriented,
          left: 0.08,
          top: 0.32,
          right: 0.92,
          bottom: 0.98,
        ),
      ];

      return inputs
          .map(_resizeForClassifier)
          .map((image) => Uint8List.fromList(img.encodeJpg(image, quality: 90)))
          .toList(growable: false);
    } catch (error) {
      debugPrint('[PhotoModerationService] crop preparation failed: $error');
      return const [];
    }
  }

  static img.Image _fractionalCrop(
    img.Image source, {
    required double left,
    required double top,
    required double right,
    required double bottom,
  }) {
    final x = (source.width * left).floor().clamp(0, source.width - 1);
    final y = (source.height * top).floor().clamp(0, source.height - 1);
    final width =
        (source.width * (right - left)).round().clamp(1, source.width - x);
    final height =
        (source.height * (bottom - top)).round().clamp(1, source.height - y);
    return img.copyCrop(
      source,
      x: x,
      y: y,
      width: width,
      height: height,
    );
  }

  static img.Image _resizeForClassifier(img.Image image) {
    if (image.width <= 1280 && image.height <= 1280) return image;
    return img.copyResize(
      image,
      width: image.width >= image.height ? 1280 : null,
      height: image.height > image.width ? 1280 : null,
      interpolation: img.Interpolation.average,
    );
  }

  static ScanResult _aggregateCropScans(List<ScanResult> scans) {
    final first = scans.first;
    final scores = scans.map(NsfwScores.fromScan).toList(growable: false);
    final maxExplicit = scores.map((score) => score.nsfw).reduce(math.max);
    final minNeutral = scores.map((score) => score.neutral).reduce(math.min);
    return ScanResult(
      item: first.item,
      status: ScanStatus.completed,
      labels: [
        NsfwLabel(
          category: NsfwCategory.nudity,
          confidence: maxExplicit,
        ),
        NsfwLabel(
          category: NsfwCategory.safe,
          confidence: minNeutral,
        ),
      ],
      scannedAt: DateTime.now(),
      confidenceThreshold: scannerCollectionThreshold,
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
        defaultThreshold: scannerCollectionThreshold,
      ));

      final modelPath = await _installBundledClassifier();
      await NsfwDetector.instance.registerModel(ModelRegistration(
        id: _localModelId,
        displayName: 'Silarah Falconsai NSFW',
        assetPath: modelPath,
        inputSize: 224,
        kind: ModelKind.classifier,
        classLabels: const ['safe', 'nudity'],
        version: '1.0',
        metadata: const {
          'outputSize': 2,
          'framework': 'TFLite',
          'source': 'Falconsai/nsfw_image_detection',
          'license': 'Apache-2.0',
        },
      ));

      // Preload only the app-bundled classifier. Do not call
      // ensureReady(ModelIds.openNsfw2): the plugin's Android default points
      // at a release asset that can 404, which would block safe uploads.
      await NsfwDetector.instance.models.preload(_localModelId);
    }();
  }

  static Future<String> _installBundledClassifier() async {
    final appDir = await getApplicationSupportDirectory();
    final modelDir =
        Directory('${appDir.path}${Platform.pathSeparator}ml_models');
    if (!await modelDir.exists()) {
      await modelDir.create(recursive: true);
    }

    final target =
        File('${modelDir.path}${Platform.pathSeparator}$_localModelFileName');
    if (await target.exists() && await target.length() == _localModelBytes) {
      return target.path;
    }

    // The Falconsai model is bundled in the APK/IPA and copied once into the
    // app sandbox because nsfw_detect intentionally refuses arbitrary external
    // paths for model registration.
    final bytes = await rootBundle.load(_localModelAssetPath);
    await target.writeAsBytes(
      bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      flush: true,
    );
    return target.path;
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

    final scores = NsfwScores.fromScan(result);

    if (scores.nsfw > explicitContentFlagThreshold) {
      return PhotoModerationResult(
        decision: PhotoModerationDecision.flagged,
        confidence: scores.nsfw,
        category: 'explicit_content',
        threshold: explicitContentFlagThreshold,
      );
    }

    if (scores.neutral > neutralContentPassThreshold) {
      return PhotoModerationResult(
        decision: PhotoModerationDecision.approved,
        confidence: scores.neutral,
        category: 'safe_image',
        threshold: neutralContentPassThreshold,
      );
    }

    // Product policy blocks only genuinely explicit content. A low neutral
    // score is not evidence of nudity and commonly occurs with niqab, dark
    // backgrounds, text, and traditional dress.
    return PhotoModerationResult(
      decision: PhotoModerationDecision.approved,
      confidence: scores.neutral,
      category: 'safe_image',
      threshold: neutralContentPassThreshold,
    );
  }
}

@visibleForTesting
class NsfwScores {
  const NsfwScores({
    required this.neutral,
    required this.nsfw,
  });

  factory NsfwScores.fromScan(ScanResult result) {
    final explicitSignal = math.max(
      result.confidenceFor(NsfwCategory.nudity),
      result.confidenceFor(NsfwCategory.explicitNudity),
    );
    return NsfwScores(
      neutral: result.confidenceFor(NsfwCategory.safe),
      nsfw: explicitSignal,
    );
  }

  final double neutral;
  final double nsfw;
}
