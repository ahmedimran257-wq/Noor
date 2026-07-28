import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import 'supabase_service.dart';

enum PassiveFaceValidationError {
  noFace,
  multipleFaces,
  faceTooSmall,
  poorLighting,
  sunglasses,
  spoofSuspected,
}

class PassiveFaceValidationResult {
  const PassiveFaceValidationResult.success()
      : isValid = true,
        error = null;
  const PassiveFaceValidationResult.failure(this.error) : isValid = false;

  final bool isValid;
  final PassiveFaceValidationError? error;

  String get errorMessage => switch (error) {
        PassiveFaceValidationError.multipleFaces =>
          'Only one face should be visible',
        PassiveFaceValidationError.sunglasses => 'Remove sunglasses',
        PassiveFaceValidationError.faceTooSmall =>
          'Move closer and keep your face inside the guide',
        PassiveFaceValidationError.noFace =>
          'Keep your face centered inside the guide',
        PassiveFaceValidationError.poorLighting ||
        PassiveFaceValidationError.spoofSuspected =>
          'Move to better lighting',
        null => '',
      };
}

class SelfieVerificationService {
  SelfieVerificationService._();
  static final instance = SelfieVerificationService._();

  Future<PassiveFaceValidationResult> validatePassiveSelfie(
    Uint8List imageBytes,
  ) async {
    File? tempFile;
    FaceDetector? detector;
    try {
      final decodedSource = img.decodeImage(imageBytes);
      if (decodedSource == null) {
        return const PassiveFaceValidationResult.failure(
          PassiveFaceValidationError.poorLighting,
        );
      }
      final decoded = img.bakeOrientation(decodedSource);

      final tempDir = await getTemporaryDirectory();
      tempFile = File(
        '${tempDir.path}/silarah_passive_face_${DateTime.now().microsecondsSinceEpoch}.jpg',
      );
      await tempFile.writeAsBytes(imageBytes, flush: true);

      detector = FaceDetector(
        options: FaceDetectorOptions(
          enableClassification: true,
          enableLandmarks: true,
          performanceMode: FaceDetectorMode.accurate,
        ),
      );
      final faces = await detector
          .processImage(InputImage.fromFilePath(tempFile.path))
          .timeout(const Duration(seconds: 8));

      if (faces.isEmpty) {
        return const PassiveFaceValidationResult.failure(
          PassiveFaceValidationError.noFace,
        );
      }
      if (faces.length != 1) {
        return const PassiveFaceValidationResult.failure(
          PassiveFaceValidationError.multipleFaces,
        );
      }

      final face = faces.single;
      final imageArea = decoded.width * decoded.height;
      final faceArea = face.boundingBox.width * face.boundingBox.height;
      if (imageArea <= 0 || faceArea / imageArea < 0.30) {
        return const PassiveFaceValidationResult.failure(
          PassiveFaceValidationError.faceTooSmall,
        );
      }

      final left = face.boundingBox.left.round().clamp(0, decoded.width - 1);
      final top = face.boundingBox.top.round().clamp(0, decoded.height - 1);
      final right =
          face.boundingBox.right.round().clamp(left + 1, decoded.width);
      final bottom =
          face.boundingBox.bottom.round().clamp(top + 1, decoded.height);
      final faceCrop = img.copyCrop(
        decoded,
        x: left,
        y: top,
        width: right - left,
        height: bottom - top,
      );
      final imageQuality = _analyseTextureAndLighting(faceCrop);
      if (!imageQuality.lightingOk) {
        return const PassiveFaceValidationResult.failure(
          PassiveFaceValidationError.poorLighting,
        );
      }
      if (!imageQuality.textureOk) {
        return const PassiveFaceValidationResult.failure(
          PassiveFaceValidationError.spoofSuspected,
        );
      }

      final leftEye = face.leftEyeOpenProbability;
      final rightEye = face.rightEyeOpenProbability;
      if (leftEye == null ||
          rightEye == null ||
          leftEye <= 0.7 ||
          rightEye <= 0.7) {
        return const PassiveFaceValidationResult.failure(
          PassiveFaceValidationError.sunglasses,
        );
      }

      return const PassiveFaceValidationResult.success();
    } catch (error) {
      debugPrint('SelfieVerificationService passive validation failed: $error');
      return const PassiveFaceValidationResult.failure(
        PassiveFaceValidationError.poorLighting,
      );
    } finally {
      await detector?.close();
      if (tempFile != null && await tempFile.exists()) {
        await tempFile.delete().catchError((_) => tempFile!);
      }
    }
  }

  ({bool lightingOk, bool textureOk}) _analyseTextureAndLighting(
    img.Image image,
  ) {
    final sampleStep = image.width > 800 ? 4 : 2;
    var luminanceTotal = 0.0;
    var luminanceCount = 0;
    final laplacianValues = <double>[];

    double luminanceAt(int x, int y) {
      final pixel = image.getPixel(x, y);
      return 0.2126 * pixel.r + 0.7152 * pixel.g + 0.0722 * pixel.b;
    }

    for (var y = sampleStep; y < image.height - sampleStep; y += sampleStep) {
      for (var x = sampleStep; x < image.width - sampleStep; x += sampleStep) {
        final center = luminanceAt(x, y);
        luminanceTotal += center;
        luminanceCount++;
        final laplacian = (4 * center) -
            luminanceAt(x - sampleStep, y) -
            luminanceAt(x + sampleStep, y) -
            luminanceAt(x, y - sampleStep) -
            luminanceAt(x, y + sampleStep);
        laplacianValues.add(laplacian);
      }
    }

    if (luminanceCount == 0 || laplacianValues.isEmpty) {
      return (lightingOk: false, textureOk: false);
    }
    final meanLuminance = luminanceTotal / luminanceCount;
    final laplacianMean =
        laplacianValues.reduce((a, b) => a + b) / laplacianValues.length;
    var variance = 0.0;
    for (final value in laplacianValues) {
      final delta = value - laplacianMean;
      variance += delta * delta;
    }
    variance /= laplacianValues.length;

    return (
      lightingOk: meanLuminance >= 45 && meanLuminance <= 225,
      textureOk: variance >= 18,
    );
  }

  Future<bool> submitBadgeVerification() async {
    if (!SupabaseService.isInitialized) return false;
    if (await SupabaseService.currentUserIdOrRefresh() == null) return false;

    try {
      await SupabaseService.client.rpc('submit_my_photo_badge_verification');

      return true;
    } catch (error) {
      debugPrint('Badge verification update failed: $error');
      return false;
    }
  }

  Future<Map<String, dynamic>> recordFailedAttempt() async {
    if (!SupabaseService.isInitialized) return const {'status': 'error'};
    try {
      final response = await SupabaseService.client
          .rpc('record_failed_verification_attempt')
          .timeout(const Duration(seconds: 10));
      return Map<String, dynamic>.from(response as Map);
    } catch (_) {
      return const {'status': 'error'};
    }
  }

  Future<({String status, int attempts, DateTime? verifiedAt})>
      getStatus() async {
    if (!SupabaseService.isInitialized) {
      return (status: 'unverified', attempts: 0, verifiedAt: null);
    }
    final userId = await SupabaseService.currentUserIdOrRefresh();
    if (userId == null) {
      return (status: 'unverified', attempts: 0, verifiedAt: null);
    }
    try {
      final response = await SupabaseService.client
          .from('my_profile_private')
          .select('verification_status, verification_attempts, verified_at')
          .eq('user_id', userId)
          .single();
      return (
        status: response['verification_status']?.toString() ?? 'unverified',
        attempts: (response['verification_attempts'] as num?)?.toInt() ?? 0,
        verifiedAt:
            DateTime.tryParse(response['verified_at']?.toString() ?? ''),
      );
    } catch (_) {
      return (status: 'unverified', attempts: 0, verifiedAt: null);
    }
  }

  Future<bool> hasBadge() async {
    if (!SupabaseService.isInitialized) return false;
    final userId = await SupabaseService.currentUserIdOrRefresh();
    if (userId == null) return false;
    try {
      final response =
          await SupabaseService.client.rpc('get_my_photo_liveness_status');
      return response == true;
    } catch (_) {
      return false;
    }
  }
}
