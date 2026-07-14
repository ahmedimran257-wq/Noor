import 'face_match_service_web.dart'
    if (dart.library.io) 'face_match_service_native.dart' as platform;

enum FaceMatchConfidence { rejected, likelyMatch, highConfidence }

class FaceMatchResult {
  const FaceMatchResult({
    required this.similarity,
    required this.confidence,
  });

  final double similarity;
  final FaceMatchConfidence confidence;

  bool get isLikelyMatch => similarity >= FaceMatchService.likelyMatchThreshold;
}

/// Platform-safe facade for face matching.
///
/// Native builds use the bundled MobileFaceNet model. Browsers fail closed
/// because the native TFLite/ML Kit pipeline is not available on the web.
class FaceMatchService {
  FaceMatchService._();

  static final instance = FaceMatchService._();

  static const double likelyMatchThreshold = 0.65;
  static const double highConfidenceMatchThreshold = 0.80;

  Future<FaceMatchResult> compareFaces(Object selfie, Object idPhoto) async {
    final similarity = await platform.compareFaceImages(selfie, idPhoto);
    final confidence = similarity >= highConfidenceMatchThreshold
        ? FaceMatchConfidence.highConfidence
        : similarity >= likelyMatchThreshold
            ? FaceMatchConfidence.likelyMatch
            : FaceMatchConfidence.rejected;
    return FaceMatchResult(similarity: similarity, confidence: confidence);
  }
}

class FaceMatchException implements Exception {
  const FaceMatchException(this.message);
  final String message;

  @override
  String toString() => message;
}
