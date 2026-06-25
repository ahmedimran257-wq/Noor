// lib/core/services/selfie_verification_service.dart
// ============================================================
// MITHAQ — Selfie Verification Service
//
// Automated selfie verification using Google ML Kit Face Detection.
// No third-party KYC provider. No paid APIs. No manual review.
//
// Flow:
//   1. Generate a random challenge (smile, turn left/right, look up/down)
//   2. User captures a camera-only selfie
//   3. ML Kit validates: exactly 1 face, face size, eyes visible
//   4. ML Kit validates: challenge condition met (Euler angles / smile)
//   5. On success → upload photo + call Supabase RPC
//
// Challenge thresholds (from Google ML Kit documentation):
//   Turn Left:   headEulerAngleY < -15
//   Turn Right:  headEulerAngleY > 15
//   Look Up:     headEulerAngleX < -10
//   Look Down:   headEulerAngleX > 10
//   Smile:       smilingProbability > 0.5
// ============================================================

import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;
import 'supabase_service.dart';

// ── Challenge enum ────────────────────────────────────────────

enum VerificationChallenge {
  smile,
  turnLeft,
  turnRight,
  lookUp,
  lookDown;

  /// Human-readable instruction for the UI.
  String get instruction {
    switch (this) {
      case VerificationChallenge.smile:
        return 'Please Smile';
      case VerificationChallenge.turnLeft:
        return 'Turn Your Head Left';
      case VerificationChallenge.turnRight:
        return 'Turn Your Head Right';
      case VerificationChallenge.lookUp:
        return 'Look Up';
      case VerificationChallenge.lookDown:
        return 'Look Down';
    }
  }

  /// Icon data name for the UI illustration.
  String get iconHint {
    switch (this) {
      case VerificationChallenge.smile:
        return 'sentiment_satisfied_alt';
      case VerificationChallenge.turnLeft:
        return 'turn_slight_left';
      case VerificationChallenge.turnRight:
        return 'turn_slight_right';
      case VerificationChallenge.lookUp:
        return 'arrow_upward';
      case VerificationChallenge.lookDown:
        return 'arrow_downward';
    }
  }

  /// Database value.
  String get dbValue {
    switch (this) {
      case VerificationChallenge.smile:
        return 'smile';
      case VerificationChallenge.turnLeft:
        return 'turn_left';
      case VerificationChallenge.turnRight:
        return 'turn_right';
      case VerificationChallenge.lookUp:
        return 'look_up';
      case VerificationChallenge.lookDown:
        return 'look_down';
    }
  }
}

// ── Validation result ─────────────────────────────────────────

enum FaceValidationError {
  noFace,
  multipleFaces,
  faceTooSmall,
  eyesNotVisible,
  challengeFailed,
}

class ValidationResult {
  const ValidationResult.success()
      : error = null,
        isValid = true;
  const ValidationResult.failure(this.error) : isValid = false;

  final bool isValid;
  final FaceValidationError? error;

  String get errorMessage {
    switch (error) {
      case FaceValidationError.noFace:
        return 'No face detected. Please position your face clearly in the frame.';
      case FaceValidationError.multipleFaces:
        return 'Multiple faces detected. Please ensure only your face is in the frame.';
      case FaceValidationError.faceTooSmall:
        return 'Your face is too far from the camera. Please move closer.';
      case FaceValidationError.eyesNotVisible:
        return 'Your eyes are not clearly visible. Please remove any obstruction.';
      case FaceValidationError.challengeFailed:
        return 'Challenge not detected. Please try again and follow the instruction.';
      case null:
        return '';
    }
  }
}

// ── Service ───────────────────────────────────────────────────

class SelfieVerificationService {
  SelfieVerificationService._();
  static final instance = SelfieVerificationService._();

  static final _random = Random();

  /// Generate a random challenge.
  VerificationChallenge generateChallenge() {
    const values = VerificationChallenge.values;
    return values[_random.nextInt(values.length)];
  }

  /// Run ML Kit face detection on [imageBytes] and validate:
  ///   1. Exactly one face
  ///   2. Face occupies ≥ 20% of image
  ///   3. Both eyes visible
  ///   4. Challenge condition met
  Future<ValidationResult> validateSelfie(
    Uint8List imageBytes,
    VerificationChallenge challenge,
  ) async {
    if (!SupabaseService.isInitialized) {
      // Mock/development mode: bypass native FaceDetector to prevent desktop/emulator hangs
      await Future.delayed(const Duration(milliseconds: 1500));
      return const ValidationResult.success();
    }

    File? tempFile;
    try {
      // Write bytes to temp file for ML Kit
      final tempDir = await getTemporaryDirectory();
      tempFile = File(
        '${tempDir.path}/mithaq_verif_${DateTime.now().millisecondsSinceEpoch}.webp',
      );
      await tempFile.writeAsBytes(imageBytes);

      final inputImage = InputImage.fromFilePath(tempFile.path);
      final detector = FaceDetector(
        options: FaceDetectorOptions(
          enableClassification: true, // smile probability, eye open probability
          enableLandmarks: true, // eye positions
          enableContours: false,
          enableTracking: false,
          performanceMode: FaceDetectorMode.accurate,
        ),
      );

      final faces = await detector
          .processImage(inputImage)
          .timeout(const Duration(seconds: 10));
      await detector.close();

      // ── Validation checks ────────────────────────────────

      // 1. Exactly one face
      if (faces.isEmpty) {
        return const ValidationResult.failure(FaceValidationError.noFace);
      }
      if (faces.length > 1) {
        return const ValidationResult.failure(
            FaceValidationError.multipleFaces);
      }

      final face = faces.first;

      // 2. Face occupies ≥ 20% of image
      // Decode the actual image dimensions from the bytes.
      final codec = await ui.instantiateImageCodec(imageBytes);
      final frameInfo = await codec.getNextFrame();
      final imageWidth = frameInfo.image.width;
      final imageHeight = frameInfo.image.height;
      final imageArea = imageWidth * imageHeight;

      final faceArea = face.boundingBox.width * face.boundingBox.height;
      final faceRatio = faceArea / imageArea;

      if (faceRatio < 0.20) {
        return const ValidationResult.failure(FaceValidationError.faceTooSmall);
      }

      // 3. Eyes visible
      final leftEyeOpen = face.leftEyeOpenProbability ?? 0.0;
      final rightEyeOpen = face.rightEyeOpenProbability ?? 0.0;
      if (leftEyeOpen < 0.3 || rightEyeOpen < 0.3) {
        // Exception: for look_down, eyes may appear partially closed
        if (challenge != VerificationChallenge.lookDown) {
          return const ValidationResult.failure(
              FaceValidationError.eyesNotVisible);
        }
      }

      // 4. Challenge validation
      if (!_validateChallenge(face, challenge)) {
        return const ValidationResult.failure(
            FaceValidationError.challengeFailed);
      }

      return const ValidationResult.success();
    } catch (e) {
      debugPrint('SelfieVerificationService: ML Kit error: $e');
      // On ML Kit failure, fail gracefully with a generic error
      return const ValidationResult.failure(FaceValidationError.noFace);
    } finally {
      // Clean up temp file
      if (tempFile != null && await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }
    }
  }

  /// Validate the specific challenge condition using ML Kit face data.
  bool _validateChallenge(Face face, VerificationChallenge challenge) {
    switch (challenge) {
      case VerificationChallenge.smile:
        return (face.smilingProbability ?? 0.0) > 0.5;

      case VerificationChallenge.turnLeft:
        // headEulerAngleY: negative = face turned to the subject's left
        return (face.headEulerAngleY ?? 0.0) < -15.0;

      case VerificationChallenge.turnRight:
        // headEulerAngleY: positive = face turned to the subject's right
        return (face.headEulerAngleY ?? 0.0) > 15.0;

      case VerificationChallenge.lookUp:
        // headEulerAngleX: negative = face tilted up
        return (face.headEulerAngleX ?? 0.0) < -10.0;

      case VerificationChallenge.lookDown:
        // headEulerAngleX: positive = face tilted down
        return (face.headEulerAngleX ?? 0.0) > 10.0;
    }
  }

  /// Upload the verification selfie to Supabase Storage and call the RPC.
  /// Returns the verification result from the server.
  Future<Map<String, dynamic>> submitVerification({
    required VerificationChallenge challenge,
    required Uint8List photoBytes,
  }) async {
    if (!SupabaseService.isInitialized) {
      return {'status': 'error', 'message': 'Supabase not initialized'};
    }

    final userId = SupabaseService.currentUserId;
    if (userId == null) {
      return {'status': 'error', 'message': 'Not authenticated'};
    }

    try {
      // Upload the selfie to Supabase Storage
      final storagePath =
          '$userId/verification_${DateTime.now().millisecondsSinceEpoch}.webp';

      await SupabaseService.client.storage
          .from('selfie-verifications')
          .uploadBinary(
            storagePath,
            photoBytes,
            fileOptions: const FileOptions(
              contentType: 'image/webp',
              upsert: true,
            ),
          )
          .timeout(const Duration(seconds: 15));

      // Call the RPC to mark profile as verified
      final response = await SupabaseService.client.rpc(
        'submit_selfie_verification',
        params: {
          'p_challenge': challenge.dbValue,
          'p_photo_path': storagePath,
        },
      ).timeout(const Duration(seconds: 15));

      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      debugPrint('SelfieVerificationService: submit error: $e');
      return {'status': 'error', 'message': e.toString()};
    }
  }

  /// Record a failed attempt (for rate limiting).
  Future<Map<String, dynamic>> recordFailedAttempt() async {
    if (!SupabaseService.isInitialized) {
      return {'status': 'error', 'message': 'Supabase not initialized'};
    }

    try {
      final response = await SupabaseService.client
          .rpc(
            'record_failed_verification_attempt',
          )
          .timeout(const Duration(seconds: 10));
      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      debugPrint('SelfieVerificationService: record attempt error: $e');
      return {'status': 'error', 'message': e.toString()};
    }
  }

  /// Check current verification status from the profile.
  Future<({String status, int attempts, DateTime? verifiedAt})>
      getStatus() async {
    if (!SupabaseService.isInitialized) {
      return (status: 'unverified', attempts: 0, verifiedAt: null);
    }

    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) {
        return (status: 'unverified', attempts: 0, verifiedAt: null);
      }

      final response = await SupabaseService.client
          .from('profiles')
          .select('verification_status, verification_attempts, verified_at')
          .eq('user_id', userId)
          .single()
          .timeout(const Duration(seconds: 10));

      return (
        status: (response['verification_status'] as String?) ?? 'unverified',
        attempts: (response['verification_attempts'] as int?) ?? 0,
        verifiedAt: response['verified_at'] != null
            ? DateTime.tryParse(response['verified_at'] as String)
            : null,
      );
    } catch (e) {
      debugPrint('SelfieVerificationService: getStatus error: $e');
      return (status: 'unverified', attempts: 0, verifiedAt: null);
    }
  }

  // ── Badge Verification (3-pose sequence) ─────────────────────

  /// Generate a sequence of 3 unique random challenges for badge verification.
  List<VerificationChallenge> generateBadgeSequence() {
    final all = VerificationChallenge.values.toList()..shuffle(_random);
    return all.take(3).toList();
  }

  /// Submit the badge verification result to the server.
  /// Writes has_verification_badge = true, badge_earned_at, and
  /// badge_pose_sequence to the profiles table.
  Future<bool> submitBadgeVerification({
    required List<String> poseSequence,
  }) async {
    if (!SupabaseService.isInitialized) return false;
    final userId = SupabaseService.currentUserId;
    if (userId == null) return false;

    try {
      await SupabaseService.client.from('profiles').update({
        'has_verification_badge': true,
        'badge_earned_at': DateTime.now().toUtc().toIso8601String(),
        'badge_pose_sequence': poseSequence,
        'verification_status': 'verified',
        'verification_challenge': 'three_pose_badge',
        'verified_at': DateTime.now().toUtc().toIso8601String(),
        'is_verified': true,
      }).eq('user_id', userId);
      return true;
    } catch (e) {
      debugPrint('SelfieVerificationService: badge submit error: $e');
      return false;
    }
  }

  /// Check if the user already has a verification badge.
  Future<bool> hasBadge() async {
    if (!SupabaseService.isInitialized) return false;
    final userId = SupabaseService.currentUserId;
    if (userId == null) return false;

    try {
      final response = await SupabaseService.client
          .from('profiles')
          .select('has_verification_badge')
          .eq('user_id', userId)
          .single();
      return (response['has_verification_badge'] as bool?) ?? false;
    } catch (_) {
      return false;
    }
  }
}

// ── Badge Verification Result ──────────────────────────────────

class BadgeVerificationResult {
  const BadgeVerificationResult({
    required this.passed,
    required this.poseSequence,
    this.failedAtStep,
  });

  final bool passed;
  final List<String> poseSequence;
  final int? failedAtStep; // which step (0-2) failed, if any
}
