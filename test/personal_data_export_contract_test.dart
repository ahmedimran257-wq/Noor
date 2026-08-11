import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    'supabase/migrations/207_personal_data_export_and_legal_rights.sql',
  ).readAsStringSync();
  final service = File('lib/core/services/personal_data_export_service.dart')
      .readAsStringSync();
  final settings =
      File('lib/features/home/screens/settings_screen.dart').readAsStringSync();

  test('export RPC is authenticated, bounded and protects third parties', () {
    expect(migration, contains('v_user_id uuid := auth.uid()'));
    expect(migration, contains('export_rate_limited_10_minutes'));
    expect(migration, contains('WHERE r.reporter_id = v_user_id'));
    expect(migration, contains('WHERE mr.reporter_id = v_user_id'));
    expect(migration, contains("'token', '[redacted credential]'"));
    expect(migration, contains("- 'neutral_storage_path'"));
    expect(
        migration, contains('REVOKE ALL ON FUNCTION public.download_my_data'));
    expect(migration,
        contains('GRANT EXECUTE ON FUNCTION public.download_my_data'));
  });

  test('mobile archive contains JSON, accessible photos and privacy warning',
      () {
    expect(service, contains("'silarah-data.json'"));
    expect(service, contains("'profile-photos/photo-"));
    expect(service, contains('ZipEncoder().encode'));
    expect(service, contains('SharePlus.instance.share'));
    expect(service, contains('Store it securely'));
    expect(settings, contains('PersonalDataExportService.instance'));
    expect(settings, contains('settings_privacy_download_label'));
  });

  test('website publishes export and grievance route', () {
    final page = File('site/privacy-rights/index.html').readAsStringSync();
    final sitemap = File('site/sitemap.xml').readAsStringSync();
    expect(page, contains('Download my data'));
    expect(page, contains('acknowledged within 24 hours'));
    expect(page, contains('resolved within 7 days'));
    expect(page, contains('grievance officer is Imran Ahmed'));
    expect(sitemap, contains('https://silarah.com/privacy-rights/'));
  });
}
