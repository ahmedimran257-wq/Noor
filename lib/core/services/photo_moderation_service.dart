import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:nsfw_detect/nsfw_detect.dart';
import 'package:path_provider/path_provider.dart';

enum PhotoModerationDecision { safe, pendingReview, unsafe, scanFailed }

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
  bool get canUpload =>
      decision == PhotoModerationDecision.safe ||
      decision == PhotoModerationDecision.pendingReview;

  Map<String, dynamic> toValidationPayload() => {
        'status': decision.name,
        'is_nsfw': decision == PhotoModerationDecision.unsafe,
        'requires_review': decision == PhotoModerationDecision.pendingReview,
        'confidence': confidence,
        'category': category,
        'threshold': threshold,
      };
}

typedef PhotoScanCallback = Future<ScanResult> Function(String path);
typedef FaceCheckCallback = Future<FaceProminenceResult> Function(String path);

/// Runs privacy-preserving NSFW classification entirely on the user's device.
class PhotoModerationService {
  PhotoModerationService({
    PhotoScanCallback? scanner,
    FaceCheckCallback? faceChecker,
  })  : _scanner = scanner ?? _scanNormalizedFile,
        _faceChecker = faceChecker ?? _checkFaceProminence;

  static final PhotoModerationService instance = PhotoModerationService();
  static Future<void>? _classifierReady;

  static Future<void> warmUp() => _ensureClassifierReady();

  // The bundled Falconsai model is binary (safe/nsfw). Keep collection low so
  // moderate NSFW evidence is visible, then apply product policy separately.
  static const double scannerCollectionThreshold = 0.01;
  static const double hardNsfwRejectThreshold = 0.88;
  static const double softNsfwReviewThreshold = 0.75;
  static const double neutralPortraitPassThreshold = 0.30;
  static const double prominentFaceRatioThreshold = 0.12;
  static const double confidenceThreshold = hardNsfwRejectThreshold;
  static const String _localModelId = 'mithaq_falconsai_nsfw';
  static const String _localModelAssetPath =
      'assets/models/falconsai_nsfw.tflite';
  static const String _localModelFileName = 'falconsai_nsfw.tflite';
  static const int _localModelBytes = 88008416;
  static const double _explicitBodySkinRatioThreshold = 0.45;
  static const double _explicitTorsoSkinRatioThreshold = 0.45;
  static const double _explicitPelvisSkinRatioThreshold = 0.12;
  final PhotoScanCallback _scanner;
  final FaceCheckCallback _faceChecker;

  Future<PhotoModerationResult> scanFile(String path) async {
    try {
      final scan = await _scanner(path);
      if (scan.status != ScanStatus.completed) return evaluate(scan);
      final scores = NsfwScores.fromScan(scan);

      if (scores.nsfw >= hardNsfwRejectThreshold) {
        return PhotoModerationResult(
          decision: PhotoModerationDecision.unsafe,
          confidence: scores.nsfw,
          category: 'explicit_content',
          threshold: hardNsfwRejectThreshold,
        );
      }

      final face = await _faceChecker(path);
      if (!face.hasFace) {
        return const PhotoModerationResult(
          decision: PhotoModerationDecision.unsafe,
          confidence: 1,
          category: 'no_face',
          threshold: 0,
        );
      }

      final needsContextReview = (scores.nsfw >= softNsfwReviewThreshold &&
              scores.neutral < neutralPortraitPassThreshold) ||
          face.faceRatio < prominentFaceRatioThreshold;
      if (needsContextReview) {
        // Skin/exposure heuristics are intentionally scoped to suspicious or
        // body-dominant photos only. Running them on every safe portrait caused
        // false rejections for sarees, sleeveless tops, and cultural dress.
        final exposureResult = await _evaluateExplicitExposurePolicy(path);
        if (exposureResult != null) return exposureResult;

        return PhotoModerationResult(
          decision: PhotoModerationDecision.pendingReview,
          confidence: scores.nsfw,
          category: face.faceRatio < prominentFaceRatioThreshold
              ? 'body_dominant'
              : 'borderline_nsfw',
          threshold: softNsfwReviewThreshold,
        );
      }

      return PhotoModerationResult(
        decision: PhotoModerationDecision.safe,
        confidence: scores.neutral,
        category: 'safe_portrait',
        threshold: softNsfwReviewThreshold,
      );
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

  static Future<PhotoModerationResult?> _evaluateExplicitExposurePolicy(
    String path,
  ) async {
    final file = File(path);
    if (!await file.exists()) return null;

    final exposure = analyzeExplicitExposure(await file.readAsBytes());
    if (!exposure.reject) return null;

    return PhotoModerationResult(
      decision: PhotoModerationDecision.unsafe,
      confidence: exposure.confidence,
      category: 'explicit_content',
      threshold: _explicitBodySkinRatioThreshold,
    );
  }

  static Future<ScanResult> _scanNormalizedFile(String path) async {
    await _ensureClassifierReady();
    final bytes = await File(path).readAsBytes();
    final normalized = _normalizeForClassifier(bytes);
    if (normalized != null) {
      return NsfwDetector.instance.scanBytes(
        normalized,
        modelId: _localModelId,
        confidenceThreshold: scannerCollectionThreshold,
      );
    }

    return NsfwDetector.instance.scanFile(
      path,
      modelId: _localModelId,
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
        displayName: 'Mithaq Falconsai NSFW',
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

  @visibleForTesting
  static ExplicitExposureAnalysis analyzeExplicitExposure(Uint8List bytes) {
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return ExplicitExposureAnalysis.empty();

      final oriented = img.bakeOrientation(decoded);
      final sample = img.copyResize(
        oriented,
        width: oriented.width > oriented.height ? 360 : null,
        height: oriented.height >= oriented.width ? 360 : null,
        interpolation: img.Interpolation.average,
      );

      final body = _measureSkinRatio(
        sample,
        left: 0.18,
        top: 0.22,
        right: 0.82,
        bottom: 0.95,
      );
      final torso = _measureSkinRatio(
        sample,
        left: 0.24,
        top: 0.25,
        right: 0.76,
        bottom: 0.62,
      );
      final pelvis = _measureSkinRatio(
        sample,
        left: 0.25,
        top: 0.58,
        right: 0.75,
        bottom: 0.88,
      );

      return ExplicitExposureAnalysis(
        bodyRatio: body,
        torsoRatio: torso,
        pelvisRatio: pelvis,
      );
    } catch (error) {
      debugPrint('[PhotoModerationService] exposure analysis failed: $error');
      return ExplicitExposureAnalysis.empty();
    }
  }

  static double _measureSkinRatio(
    img.Image image, {
    required double left,
    required double top,
    required double right,
    required double bottom,
  }) {
    final startX = (image.width * left).floor().clamp(0, image.width - 1);
    final endX = (image.width * right).ceil().clamp(startX + 1, image.width);
    final startY = (image.height * top).floor().clamp(0, image.height - 1);
    final endY = (image.height * bottom).ceil().clamp(startY + 1, image.height);

    var skinPixels = 0;
    var sampledPixels = 0;
    const stride = 2;
    for (var y = startY; y < endY; y += stride) {
      for (var x = startX; x < endX; x += stride) {
        sampledPixels++;
        if (_isLikelySkin(image.getPixel(x, y))) {
          skinPixels++;
        }
      }
    }

    if (sampledPixels == 0) return 0;
    return skinPixels / sampledPixels;
  }

  static bool _isLikelySkin(img.Pixel pixel) {
    final r = pixel.r.toDouble();
    final g = pixel.g.toDouble();
    final b = pixel.b.toDouble();
    final maxChannel = math.max(r, math.max(g, b));
    final minChannel = math.min(r, math.min(g, b));
    if (maxChannel < 45 || maxChannel - minChannel < 8) return false;

    final y = (0.299 * r) + (0.587 * g) + (0.114 * b);
    final cb = 128 - (0.168736 * r) - (0.331264 * g) + (0.5 * b);
    final cr = 128 + (0.5 * r) - (0.418688 * g) - (0.081312 * b);
    final saturation =
        maxChannel == 0 ? 0 : (maxChannel - minChannel) / maxChannel;
    final value = maxChannel / 255;

    final warmChrominance = cr >= 132 && cr <= 188 && cb >= 72 && cb <= 145;
    final plausibleBrightness = y >= 38 && value >= 0.18;
    final plausibleSaturation = saturation >= 0.07 && saturation <= 0.82;
    final notPureRedOrYellow = r > b && g >= b * 0.55;

    return warmChrominance &&
        plausibleBrightness &&
        plausibleSaturation &&
        notPureRedOrYellow;
  }

  static Future<FaceProminenceResult> _checkFaceProminence(String path) async {
    File? analysisFile;
    FaceDetector? detector;
    try {
      final bytes = await File(path).readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return FaceProminenceResult.noFace();

      final oriented = img.bakeOrientation(decoded);
      final jpegBytes =
          Uint8List.fromList(img.encodeJpg(oriented, quality: 92));
      final tempDir = await getTemporaryDirectory();
      analysisFile = File(
        '${tempDir.path}${Platform.pathSeparator}mithaq_face_prominence_${DateTime.now().microsecondsSinceEpoch}.jpg',
      );
      await analysisFile.writeAsBytes(jpegBytes, flush: true);

      detector = FaceDetector(
        options: FaceDetectorOptions(
          enableClassification: false,
          enableContours: false,
          enableLandmarks: false,
          enableTracking: false,
          performanceMode: FaceDetectorMode.fast,
        ),
      );
      final faces = await detector
          .processImage(InputImage.fromFilePath(analysisFile.path));
      if (faces.isEmpty) return FaceProminenceResult.noFace();

      final imageArea = math.max(1, oriented.width * oriented.height);
      var maxRatio = 0.0;
      for (final face in faces) {
        final box = face.boundingBox;
        final ratio = (box.width * box.height) / imageArea;
        if (ratio > maxRatio) maxRatio = ratio;
      }

      return FaceProminenceResult(
        hasFace: true,
        faceCount: faces.length,
        faceRatio: maxRatio,
      );
    } catch (error) {
      debugPrint('[PhotoModerationService] face prominence failed: $error');
      return FaceProminenceResult.noFace();
    } finally {
      await detector?.close();
      if (analysisFile != null && await analysisFile.exists()) {
        await analysisFile.delete().catchError((_) => analysisFile!);
      }
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

    final scores = NsfwScores.fromScan(result);

    if (scores.nsfw >= hardNsfwRejectThreshold) {
      return PhotoModerationResult(
        decision: PhotoModerationDecision.unsafe,
        confidence: scores.nsfw,
        category: 'explicit_content',
        threshold: hardNsfwRejectThreshold,
      );
    }

    if (scores.nsfw >= softNsfwReviewThreshold &&
        scores.neutral < neutralPortraitPassThreshold) {
      return PhotoModerationResult(
        decision: PhotoModerationDecision.pendingReview,
        confidence: scores.nsfw,
        category: 'borderline_nsfw',
        threshold: softNsfwReviewThreshold,
      );
    }

    return PhotoModerationResult(
      decision: PhotoModerationDecision.safe,
      confidence: scores.neutral,
      category: 'safe_portrait',
      threshold: softNsfwReviewThreshold,
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
      nsfw: math.max(
        explicitSignal,
        result.confidenceFor(NsfwCategory.suggestive),
      ),
    );
  }

  final double neutral;
  final double nsfw;
}

@visibleForTesting
class FaceProminenceResult {
  const FaceProminenceResult({
    required this.hasFace,
    required this.faceCount,
    required this.faceRatio,
  });

  factory FaceProminenceResult.noFace() => const FaceProminenceResult(
        hasFace: false,
        faceCount: 0,
        faceRatio: 0,
      );

  final bool hasFace;
  final int faceCount;
  final double faceRatio;
}

@visibleForTesting
class ExplicitExposureAnalysis {
  const ExplicitExposureAnalysis({
    required this.bodyRatio,
    required this.torsoRatio,
    required this.pelvisRatio,
  });

  factory ExplicitExposureAnalysis.empty() => const ExplicitExposureAnalysis(
        bodyRatio: 0,
        torsoRatio: 0,
        pelvisRatio: 0,
      );

  final double bodyRatio;
  final double torsoRatio;
  final double pelvisRatio;

  bool get reject =>
      bodyRatio >= PhotoModerationService._explicitBodySkinRatioThreshold &&
      torsoRatio >= PhotoModerationService._explicitTorsoSkinRatioThreshold &&
      pelvisRatio >= PhotoModerationService._explicitPelvisSkinRatioThreshold;

  double get confidence => math
      .min(
        bodyRatio / PhotoModerationService._explicitBodySkinRatioThreshold,
        math.min(
          torsoRatio / PhotoModerationService._explicitTorsoSkinRatioThreshold,
          pelvisRatio /
              PhotoModerationService._explicitPelvisSkinRatioThreshold,
        ),
      )
      .clamp(0, 1);
}
