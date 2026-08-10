import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    'supabase/migrations/170_restore_instant_photo_publishing.sql',
  ).readAsStringSync();
  final validator = File(
    'supabase/functions/validate-photo-upload/index.ts',
  ).readAsStringSync();
  final photoService = File(
    'lib/core/services/profile_photo_service.dart',
  ).readAsStringSync();
  final uploadScreen = File(
    'lib/features/onboarding/screens/photo_upload_screen.dart',
  ).readAsStringSync();
  final settings = File(
    'lib/features/home/screens/settings_screen.dart',
  ).readAsStringSync();
  final dispatch = File(
    'supabase/functions/dispatch-notifications/index.ts',
  ).readAsStringSync();
  final adminModeration = File(
    'admin/src/app/(staff)/moderation/page.tsx',
  ).readAsStringSync();

  test('safe uploads publish immediately and every upload enters moderation',
      () {
    expect(
      migration,
      contains("CASE WHEN v_flagged THEN 'pending_review' ELSE 'active' END"),
    );
    expect(migration, contains('NOT v_flagged,\n    NOT v_flagged,'));
    expect(
      migration,
      contains('INSERT INTO public.photo_moderation_queue('),
    );
    expect(migration, contains("'unreviewed_upload'"));
    expect(migration, contains("'explicit_content'"));
    expect(
      migration,
      contains(
        "CASE WHEN v_flagged THEN 'pending_review'::text ELSE 'active'::text END",
      ),
    );
    expect(validator, contains('finalized.action === "active"'));
    expect(
      photoService,
      contains("action != 'active' && action != 'pending_review'"),
    );
  });

  test('onboarding publishes eligible primary photos without obsolete gates',
      () {
    expect(
      migration,
      contains(
        'DROP TRIGGER IF EXISTS trg_enforce_marriage_timeline '
        'ON public.profiles',
      ),
    );
    expect(
        migration,
        contains('CREATE OR REPLACE FUNCTION '
            'public.complete_onboarding_profile()'));
    expect(migration, contains("WHEN v_has_primary THEN 'visible'"));
    expect(migration, contains("'profile_live'"));
    expect(migration, contains("'Your profile is now live!'"));
    expect(
      uploadScreen,
      contains('Safe photos are live and remain subject to moderation'),
    );
  });

  test('later moderator rejection removes the photo and pauses a primary', () {
    expect(
      migration,
      contains("SET moderation_status = 'rejected'"),
    );
    expect(migration, contains("status = 'rejected'"));
    expect(migration, contains("WHEN v_photo.order_index = 0"));
    expect(migration, contains("ELSE 'paused'"));
    expect(migration, contains("'photo_rejected'"));
    expect(migration, contains("'moderation_rejected'"));
  });

  test('visibility and notification paths accept a published pending review',
      () {
    expect(
      settings,
      isNot(contains(".eq('moderation_status', 'approved')")),
    );
    expect(dispatch, contains('.eq("status", "active")'));
    expect(
      dispatch,
      isNot(contains('.eq("moderation_status", "approved")')),
    );
    expect(dispatch, contains('deep_link: "silarah://discover"'));
    expect(dispatch, isNot(contains('deep_link: "/home?tab=0"')));
    expect(
      migration,
      contains("'photo_approved', 'photo_rejected'"),
    );
    expect(migration, contains('coalesce(np.profile_live, true)'));
    expect(migration, contains("'silarah://profile'"));
    expect(migration, isNot(contains("'/home?tab=3'")));
  });

  test('admin presents low-score photos as routine review work', () {
    expect(adminModeration, contains('Photo moderation review'));
    expect(adminModeration, contains('Routine review'));
    expect(
      adminModeration,
      contains('Every uploaded profile photo remains available'),
    );
    expect(adminModeration, contains('Routine photo reviews'));
    expect(adminModeration, contains('No photos pending moderation.'));
    expect(adminModeration, isNot(contains('Invalid queue item')));
    expect(adminModeration, isNot(contains('Flagged photo review')));
  });
}
