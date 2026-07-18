import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:silarah/core/models/discovery_profile.dart';

void main() {
  final migration = File(
    'supabase/migrations/125_complete_photo_privacy_workflow.sql',
  ).readAsStringSync();
  final detail = File(
    'lib/features/home/screens/profile_detail_screen.dart',
  ).readAsStringSync();
  final settings = File(
    'lib/features/home/screens/settings_screen.dart',
  ).readAsStringSync();
  final photoManager = File(
    'lib/features/onboarding/screens/photo_upload_screen.dart',
  ).readAsStringSync();
  final signedUrl = File(
    'supabase/functions/get-signed-url/index.ts',
  ).readAsStringSync();

  test('privacy is represented explicitly and preserves legacy private rows',
      () {
    const requestOnly = DiscoveryProfile(
      id: '00000000-0000-0000-0000-000000000123',
      firstName: 'Amina',
      lastNameInitial: 'K',
      age: 27,
      cityName: 'Hyderabad',
      photoPrivacy: 'request_only',
      isPhotoPrivate: true,
    );
    expect(requestOnly.effectivePhotoPrivacy, 'request_only');

    const legacyPrivate = DiscoveryProfile(
      id: '00000000-0000-0000-0000-000000000124',
      firstName: 'Maryam',
      lastNameInitial: 'S',
      age: 28,
      cityName: 'Delhi',
      isPhotoPrivate: true,
    );
    expect(legacyPrivate.effectivePhotoPrivacy, 'mutual_only');
  });

  test('server owns every authorization decision and workflow mutation', () {
    expect(
        migration, contains('public.can_view_photo(v_viewer, v_profile_id)'));
    expect(migration, contains('m.status = \'active\''));
    expect(migration, contains("p.photo_privacy = 'request_only'"));
    expect(migration, contains('requester_id = v_requester'));
    expect(migration, contains('owner_id = v_owner'));
    expect(migration, contains('AND owner_id = auth.uid()'));
    expect(migration, contains('GRANT EXECUTE ON FUNCTION'));
    expect(migration, contains('photo_access_requests'));
  });

  test('viewer locks the entire gallery until backend access is confirmed', () {
    expect(detail, contains('profile.isPhotoPrivate && !canViewPhotos'));
    expect(detail, isNot(contains('index > 0 && !isMutualMatch')));
    expect(detail, contains('PhotoAccessService.instance.getContext'));
    expect(detail, contains('PhotoAccessService.instance.requestAccess'));
    expect(detail, contains('PhotoAccessService.instance.cancelRequest'));
  });

  test(
      'settings and manage photos cannot overwrite each other with stale state',
      () {
    expect(settings, contains('syncPhotoPrivacy(privacy)'));
    expect(settings, contains('invalidateAllPhotoUrls()'));
    expect(photoManager, contains('getMyPhotoPrivacy()'));
    expect(settings, contains('Manage photo requests'));
  });

  test('private signed URLs expire within five minutes', () {
    expect(signedUrl, contains('const READ_URL_EXPIRES_IN = 300'));
    expect(signedUrl, isNot(contains('const READ_URL_EXPIRES_IN = 3600')));
  });
}
