import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'face_match_service.dart';
import 'id_ocr_service.dart';
import 'supabase_service.dart';

enum KycVerificationStatus { verified, pendingReview, rejected }

class KycVerificationResult {
  const KycVerificationResult({
    required this.status,
    required this.message,
    this.faceSimilarity,
  });

  final KycVerificationStatus status;
  final String message;
  final double? faceSimilarity;
}

/// Submits global KYC evidence for private human review.
///
/// On-device extraction and comparison are quality hints only. They are never
/// authoritative and cannot approve or reject an identity.
class KycVerificationService {
  KycVerificationService._();
  static final instance = KycVerificationService._();

  static const _bucket = 'kyc-documents';
  Future<KycVerificationResult> verify({
    required File selfie,
    required File idPhoto,
    required String idType,
    required String countryCode,
  }) async {
    if (!SupabaseService.isInitialized ||
        SupabaseService.currentUserId == null) {
      return const KycVerificationResult(
        status: KycVerificationStatus.rejected,
        message: 'Verification is unavailable until you are signed in.',
      );
    }

    DateTime? extractedDob;
    double? faceSimilarity;
    try {
      extractedDob = (await IdOcrService.instance.extract(idPhoto)).dateOfBirth;
    } catch (_) {
      // A human reviewer reads the original document. OCR failure must not
      // become an identity decision.
    }
    try {
      faceSimilarity =
          (await FaceMatchService.instance.compareFaces(selfie, idPhoto))
              .similarity;
    } catch (_) {
      // Face comparison is a reviewer hint, not a submission gate.
    }

    final selfiePath = await _uploadPrivateDocument(selfie, 'kyc_selfie');
    final idPath = await _uploadPrivateDocument(idPhoto, 'kyc_id');
    final response = await SupabaseService.client.functions.invoke(
      'process-kyc',
      body: {
        'user_id': SupabaseService.currentUserId,
        'face_similarity': faceSimilarity,
        'ocr_dob': extractedDob == null ? null : _isoDate(extractedDob),
        'id_type': idType,
        'country_code': countryCode.toUpperCase(),
        'selfie_storage_path': selfiePath,
        'id_photo_storage_path': idPath,
      },
    );
    if (response.status < 200 ||
        response.status >= 300 ||
        response.data is! Map) {
      throw StateError('Unable to process the verification result.');
    }

    final payload = Map<String, dynamic>.from(response.data as Map);
    final status = payload['status'] as String?;
    return KycVerificationResult(
      status: status == 'pending_review'
          ? KycVerificationStatus.pendingReview
          : KycVerificationStatus.rejected,
      message: payload['message'] as String? ??
          'Verification could not be completed.',
      faceSimilarity: faceSimilarity,
    );
  }

  Future<String> _uploadPrivateDocument(File file, String purpose) async {
    final extension = _extension(file.path);
    final signed = await SupabaseService.client.functions.invoke(
      'get-signed-url',
      body: {'purpose': purpose, 'file_extension': extension},
    );
    if (signed.status != 200 || signed.data is! Map) {
      throw StateError('Unable to prepare secure document upload.');
    }
    final payload = Map<String, dynamic>.from(signed.data as Map);
    final path = payload['storage_path'] as String?;
    final token = payload['token'] as String?;
    if (path == null || token == null) {
      throw StateError('Secure document upload response was incomplete.');
    }
    await SupabaseService.client.storage.from(_bucket).uploadBinaryToSignedUrl(
          path,
          token,
          await file.readAsBytes(),
          FileOptions(contentType: _contentType(extension), upsert: false),
        );
    return path;
  }

  String _extension(String path) {
    final dot = path.lastIndexOf('.');
    if (dot < 0 || dot == path.length - 1) return 'jpg';
    final extension = path.substring(dot + 1).toLowerCase();
    return {'jpg', 'jpeg', 'png', 'webp'}.contains(extension)
        ? extension
        : 'jpg';
  }

  String _contentType(String extension) => extension == 'png'
      ? 'image/png'
      : extension == 'webp'
          ? 'image/webp'
          : 'image/jpeg';

  String _isoDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
