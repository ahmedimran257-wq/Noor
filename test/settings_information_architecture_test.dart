import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('settings and profile information architecture', () {
    late String settings;
    late String profile;

    setUpAll(() {
      settings = File(
        'lib/features/home/screens/settings_screen.dart',
      ).readAsStringSync();
      profile = File(
        'lib/features/home/screens/my_profile_screen.dart',
      ).readAsStringSync();
    });

    test('removes legacy verification and placeholder settings actions', () {
      expect(settings, isNot(contains('settings_label_selfieChallenge')));
      expect(settings, isNot(contains('settings_label_rate_snackbar')));
      expect(settings, isNot(contains('_triggerDataExport')));
      expect(settings, isNot(contains("value: '1.0.0 (build 1)'")));
    });

    test('wires live package version and editable quiet hours', () {
      expect(settings, contains('PackageInfo.fromPlatform()'));
      expect(settings, contains('_changeQuietHours(context, prefs)'));
      expect(settings, contains('setQuietHours('));
    });

    test('language picker exposes every generated app locale', () {
      final localeCubit = File(
        'lib/core/cubits/locale/locale_cubit.dart',
      ).readAsStringSync();
      for (final code in [
        'en',
        'ar',
        'ur',
        'hi',
        'bn',
        'id',
        'ms',
        'tr',
        'fr',
        'de'
      ]) {
        expect(localeCubit, contains("code: '$code'"));
      }
      expect(settings, contains('LocaleCubit.supportedLanguages'));
      expect(settings, contains('ListView('));
    });

    test('activity nudge preference controls progressive nudge pushes', () {
      final migration = File(
        'supabase/migrations/116_wire_profile_nudge_preference.sql',
      ).readAsStringSync();
      expect(
        migration,
        contains("p_type IN ('inactive_nudge', 'profile_nudge')"),
      );
      expect(migration, contains('coalesce(np.inactive_nudge, true)'));
    });

    test('separates passive photo verification from legal identity checks', () {
      expect(profile, contains('_VerificationIdentityStatus('));
      expect(profile, contains('AppRoutes.badgeVerification'));
      expect(profile, contains('_TrustCenterCard('));
      expect(profile, contains('AppRoutes.verify'));
      expect(profile, contains('Government ID check'));
      expect(profile, contains('Profile photo check'));
      expect(profile, contains('noreply@mail.silarah.com'));
      expect(profile, contains('Live in discovery'));
    });

    test('keeps account navigation singular and exposes self preview', () {
      expect(profile, contains('_ProfilePrimaryActions('));
      expect(profile, contains('View profile'));
      expect(profile, contains('isOwnProfile: true'));
      expect(profile, isNot(contains("label: 'Help & support'")));
      expect(profile, isNot(contains("title: 'Account controls'")));
      expect(profile, isNot(contains('class _SettingsSection')));
      expect(settings, isNot(contains('settings_label_editProfile')));
      expect(settings, isNot(contains('AppRoutes.editProfile')));
    });

    test('uses profile-live notification language instead of approval copy',
        () {
      expect(settings, contains('Profile goes live'));
      expect(settings, isNot(contains('settings_notify_profileApproved')));
      expect(settings, isNot(contains('toggleProfileApproved')));
      expect(
        profile,
        isNot(contains('No admin approval is required')),
      );
    });

    test('profile actions persist through server-enforced flows', () {
      final views = File(
        'lib/features/home/screens/profile_views_screen.dart',
      ).readAsStringSync();
      final migration = File(
        'supabase/migrations/121_profile_surface_integrity.sql',
      ).readAsStringSync();

      expect(profile, contains("rpc('activate_profile_boost')"));
      expect(profile, contains("'set_profile_pause'"));
      expect(profile, contains('await context.read<AuthCubit>().signOut()'));
      expect(profile, contains('onChanged: _loadBookmarks'));
      expect(profile, isNot(contains("'is_boosted': true")));
      expect(views, contains(".gte("));
      expect(views, contains('final sent = await context'));
      expect(
          migration,
          contains(
              'CREATE OR REPLACE FUNCTION public.activate_profile_boost()'));
      expect(migration, contains('ph.order_index = 0'));
      expect(migration, isNot(contains('waiting for approval')));
    });
  });
}
