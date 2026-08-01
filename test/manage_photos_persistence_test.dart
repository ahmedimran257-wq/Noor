import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final screen = File(
    'lib/features/onboarding/screens/photo_upload_screen.dart',
  ).readAsStringSync();
  final service = File(
    'lib/core/services/profile_photo_service.dart',
  ).readAsStringSync();
  final edge = File(
    'supabase/functions/get-signed-url/index.ts',
  ).readAsStringSync();
  final profileWriter = File(
    'lib/core/services/profile_write_service.dart',
  ).readAsStringSync().replaceAll('\r\n', '\n');

  test('manage photos restores persisted server slots after restart', () {
    expect(screen, contains('getMyPhotoSlots()'));
    expect(screen, contains('_bytes[0] != null || _remoteUrls[0] != null'));
    expect(screen, contains('remoteUrl: _remoteUrls[index]'));
    expect(screen, contains('CachedNetworkImage('));
    expect(screen, contains('maxWidthDiskCache: 640'));
    expect(service, contains("'purpose': 'read_profile_gallery'"));
    expect(service, isNot(contains('profiles!inner')));
    expect(edge, contains('get_authorized_photo_gallery_paths'));
  });

  test('photo manager preserves explicit indexes instead of compacting gaps',
      () {
    expect(screen, contains('final localSlots = <int, String>{}'));
    expect(screen, contains('localSlots[i] = _paths[i]!'));
    expect(screen, contains('syncPhotoSlots('));
    expect(service, contains("'order_index': orderIndex"));
  });

  test('onboarding photo step has one owner for privacy persistence', () {
    expect(service, contains("'set_my_photo_privacy'"));
    expect(
        screen, contains('await ProfilePhotoService.instance.syncPhotoSlots('));
    expect(
      profileWriter,
      contains(
        'case OnboardingFlow.photoUploadStep:\n'
        '        // ProfilePhotoService owns this step transactionally:',
      ),
    );
    expect(
      profileWriter,
      isNot(
        contains(
          "case OnboardingFlow.photoUploadStep:\n"
          "        return _compactMap({\n"
          "          'photo_privacy'",
        ),
      ),
    );
  });

  test('save cannot fail silently and exposes progress and retry states', () {
    expect(screen, contains('onCtaDisabledTap: _explainDisabledSave'));
    expect(screen, contains("_showSaveRequirement('Add a main photo"));
    expect(screen, contains('isCtaLoading: isLoading || _uploading'));
    expect(screen, contains('_existingLoadError'));
    expect(screen, contains('_PhotoOperationPanel'));
    expect(screen, contains('onProgress: _handleSyncProgress'));
    expect(screen, contains('await cubit.syncPhotoPrivacy(_privacy)'));
    expect(
      screen,
      isNot(contains('final saved = await cubit.updateProfile(data)')),
    );
    expect(screen, isNot(contains('Fallback: use raw bytes')));
    expect(service, contains('PhotoSyncStage.transferring'));
    expect(service, contains('PhotoSyncStage.publishing'));
  });

  test('remote deletion and replacement cleanup are ownership scoped', () {
    expect(service, contains("'purpose': 'delete_profile_photo'"));
    expect(edge, contains('deleteOwnProfilePhoto(userId, order_index)'));
    expect(edge, contains('"request_profile_photo_deletion"'));
    expect(edge, contains('p_user_id: userId'));
    expect(
        edge, contains('!existingPhoto && (existingCount ?? 0) >= MAX_PHOTOS'));
  });
}
