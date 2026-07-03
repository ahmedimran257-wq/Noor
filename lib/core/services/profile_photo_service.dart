import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/onboarding_data.dart';
import 'photo_moderation_service.dart';
import 'supabase_service.dart';

class ProfilePhotoService {
  ProfilePhotoService._();

  static final ProfilePhotoService instance = ProfilePhotoService._();
  static const _bucket = 'profile-photos';

  Future<void> syncLocalPhotos(
    List<String> localPaths, {
    PhotoPrivacy privacy = PhotoPrivacy.publicAll,
  }) async {
    if (!SupabaseService.isInitialized ||
        SupabaseService.currentUserId == null) {
      throw StateError(
        'Profile photo upload is not available without an authenticated backend session.',
      );
    }

    final profileId = await _currentProfileId();
    if (profileId == null) {
      throw StateError('Profile must be saved before uploading photos.');
    }

    await SupabaseService.client
        .from('profiles')
        .update({'photo_privacy': _privacyValue(privacy)}).eq('id', profileId);

    for (var i = 0; i < localPaths.length && i < 4; i++) {
      final file = File(localPaths[i]);
      if (!await file.exists()) continue;

      // Scan again at the upload boundary so stale onboarding state cannot
      // bypass moderation. A failed scan is rejected rather than uploaded.
      final moderation =
          await PhotoModerationService.instance.scanFile(file.path);
      if (!moderation.isSafe) {
        throw StateError(
          moderation.decision == PhotoModerationDecision.unsafe
              ? _moderationMessage(moderation)
              : 'Photo safety validation failed. Please choose another photo.',
        );
      }

      final signed = await SupabaseService.client.functions.invoke(
        'get-signed-url',
        body: {
          'order_index': i,
          'file_extension': 'webp',
        },
      );

      if (signed.status != 200 || signed.data is! Map) {
        throw StateError('Unable to prepare profile photo upload.');
      }

      final payload = Map<String, dynamic>.from(signed.data as Map);
      final storagePath = payload['storage_path'] as String?;
      final token = payload['token'] as String?;
      if (storagePath == null || token == null) {
        throw StateError('Profile photo upload response was incomplete.');
      }

      final bytes = await file.readAsBytes();
      await SupabaseService.client.storage
          .from(_bucket)
          .uploadBinaryToSignedUrl(
            storagePath,
            token,
            bytes,
            const FileOptions(contentType: 'image/webp', upsert: true),
          );

      await _validateUploaded(storagePath, moderation);
    }
  }

  Future<String?> getPrimaryPhotoUrl() async {
    if (!SupabaseService.isInitialized ||
        SupabaseService.currentUserId == null) {
      return null;
    }

    final profileId = await _currentProfileId();
    if (profileId == null) return null;

    final rows = await SupabaseService.client
        .from('photos')
        .select('storage_path')
        .eq('profile_id', profileId)
        .eq('status', 'active')
        .order('order_index')
        .limit(1);

    if (rows.isEmpty) return null;
    final storagePath = rows.first['storage_path'] as String?;
    if (storagePath == null || storagePath.isEmpty) return null;

    return SupabaseService.client.storage
        .from(_bucket)
        .createSignedUrl(storagePath, 60 * 60);
  }

  Future<String?> _currentProfileId() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return null;

    final profile = await SupabaseService.client
        .from('profiles')
        .select('id')
        .eq('user_id', userId)
        .maybeSingle();

    return profile?['id'] as String?;
  }

  Future<void> _validateUploaded(
    String storagePath,
    PhotoModerationResult moderation,
  ) async {
    final response = await SupabaseService.client.functions.invoke(
      'validate-photo-upload',
      body: {
        'storage_path': storagePath,
        'moderation': moderation.toValidationPayload(),
      },
    );
    if (response.status != 200 || response.data is! Map) {
      throw StateError('Photo validation could not be completed.');
    }
    final action = (response.data as Map)['action'] as String?;
    if (action != 'validated') {
      throw StateError('Photo validation did not approve this upload.');
    }
  }

  String _moderationMessage(PhotoModerationResult moderation) {
    if (moderation.category == 'no_face') {
      return "We couldn't detect a face. Please upload a photo clearly showing your face.";
    }
    return 'This photo cannot be accepted. Please upload a clear portrait photo.';
  }

  String _privacyValue(PhotoPrivacy privacy) {
    switch (privacy) {
      case PhotoPrivacy.mutualOnly:
        return 'mutual_only';
      case PhotoPrivacy.requestOnly:
        return 'request_only';
      case PhotoPrivacy.publicAll:
        return 'public';
    }
  }
}
