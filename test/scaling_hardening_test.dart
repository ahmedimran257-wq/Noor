import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:silarah/features/onboarding/screens/photo_upload_screen.dart';

void main() {
  group('free-tier scaling contracts', () {
    test('profile uploads use the bounded mobile WebP policy', () {
      expect(profilePhotoUploadMinDimension, 720);
      expect(profilePhotoUploadWebpQuality, 74);

      final source = File(
        'lib/features/onboarding/screens/photo_upload_screen.dart',
      ).readAsStringSync();
      expect(source, contains('minWidth: profilePhotoUploadMinDimension'));
      expect(source, contains('quality: profilePhotoUploadWebpQuality'));
      expect(source, contains('keepExif: false'));
    });

    test('signed photo delivery avoids paid image transformations', () {
      final edgeFunction = File(
        'supabase/functions/get-signed-url/index.ts',
      ).readAsStringSync();
      final imageWidget = File(
        'lib/core/widgets/loaders/silarah_blur_image.dart',
      ).readAsStringSync();

      expect(edgeFunction, isNot(contains('transform: {')));
      expect(imageWidget, contains('cacheKey: _stableObjectCacheKey'));
      expect(imageWidget, contains("/storage/v1/object/sign/"));
      expect(imageWidget, contains('maxWidthDiskCache: 720'));
    });

    test('database migration removes fixed work and bounds hot paths', () {
      final migration = File(
        'supabase/migrations/137_free_tier_scaling_hardening.sql',
      ).readAsStringSync();

      expect(
        migration,
        contains("'refresh_recommendations_recent_viewers_10m'"),
      );
      expect(migration,
          contains("replace(v_definition, 'LIMIT 1500', 'LIMIT 300')"));
      expect(migration, contains('trg_wake_notification_dispatch'));
      expect(migration, contains("'dispatch_notifications_fallback_5m'"));
      expect(migration, contains("'*/5 * * * *'"));
      expect(migration, contains('idx_messages_match_created_desc'));
      expect(migration, contains('idx_messages_match_receiver_unread'));
      expect(migration, contains('file_size_limit = 2097152'));
    });

    test('owner and guardian RLS paths use one policy per action', () {
      final migration = File(
        'supabase/migrations/138_consolidate_guardian_rls_policies.sql',
      ).readAsStringSync();

      expect(migration, contains('OR p.guardian_user_id'));
      expect(migration, contains('OR guardian_user_id'));
      expect(
        migration,
        contains('DROP POLICY IF EXISTS profiles_guardian_select'),
      );
      expect(
        migration,
        contains('DROP POLICY IF EXISTS profile_preferences_guardian_select'),
      );
    });

    test('typing presence uses the reduced broadcast cadence', () {
      final source = File(
        'lib/core/cubits/chat/chat_cubit.dart',
      ).readAsStringSync();

      expect(
        source,
        contains('_typingRefreshInterval = Duration(milliseconds: 3000)'),
      );
      expect(
        source,
        contains('_remoteTypingExpiry = Duration(milliseconds: 7000)'),
      );
      expect(source, isNot(contains('Duration(milliseconds: 1400)')));
    });
  });
}
