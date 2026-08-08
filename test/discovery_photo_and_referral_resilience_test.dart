import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('discovery photo and referral resilience', () {
    late String migration;
    late String discoveryCubit;
    late String photoService;
    late String referralEntry;

    setUpAll(() {
      migration = File(
        'supabase/migrations/174_authorize_live_discovery_photos.sql',
      ).readAsStringSync();
      discoveryCubit = File(
        'lib/core/cubits/discovery/discovery_feed_cubit.dart',
      ).readAsStringSync();
      photoService = File(
        'lib/core/services/profile_photo_service.dart',
      ).readAsStringSync();
      referralEntry = File(
        'lib/features/onboarding/screens/splash_brand_screen.dart',
      ).readAsStringSync();
    });

    test('first discovery page can authorize photos before a view is recorded',
        () {
      expect(migration, contains('FROM public.discovery_pool candidate'));
      expect(migration, contains('candidate.profile_id = owner.id'));
      expect(migration, contains("owner.visibility = 'visible'"));
      expect(migration, contains('public.can_view_photo'));
      expect(migration, contains('FROM public.blocks b'));
      expect(migration, contains("auth.role() = 'service_role'"));
      expect(
        migration,
        contains('FROM PUBLIC, anon, authenticated;'),
      );
    });

    test('feed signs every public profile that reports approved photos', () {
      final signing = discoveryCubit.substring(
        discoveryCubit.indexOf('final publicPhotoOwners = rows'),
      );
      expect(signing, contains("row['photo_count']"));
      expect(signing, contains("privacy != 'mutual_only'"));
      expect(signing, contains('Future.wait<dynamic>'));
      expect(signing, contains("row.remove('photo_url')"));
      expect(photoService, contains('return result;'));
    });

    test('referral submission cannot double-pop or use a disposed sheet', () {
      expect(referralEntry, contains('showModalBottomSheet<bool>'));
      expect(
        referralEntry,
        matches(RegExp(r'onPressed:\s+isSaving\s+\? null')),
      );
      expect(referralEntry, contains('Navigator.pop(sheetContext, true)'));
      expect(
        referralEntry,
        contains('saved != true || !mounted || !context.mounted'),
      );
      expect(referralEntry,
          isNot(contains('.whenComplete(codeController.dispose)')));
    });
  });
}
