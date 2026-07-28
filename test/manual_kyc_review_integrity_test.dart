import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final root = Directory.current.path;

  String source(String relative) =>
      File('$root${Platform.pathSeparator}$relative').readAsStringSync();

  test('global KYC is manual and client scores cannot approve', () {
    final edge = source('supabase/functions/process-kyc/index.ts');
    final service = source('lib/core/services/kyc_verification_service.dart');

    expect(edge, contains('submit_manual_kyc_for_review'));
    expect(edge, contains('status: "pending_review"'));
    expect(edge, isNot(contains('kyc_verified: true')));
    expect(service, isNot(contains('_manualReviewThreshold')));
    expect(service, contains('reviewer hint'));
  });

  test('server approval requires all five evidence checks', () {
    final migration =
        source('supabase/migrations/136_manual_global_kyc_review.sql');

    for (final check in [
      'p_document_readable',
      'p_name_match',
      'p_dob_match',
      'p_face_match',
      'p_document_unexpired',
    ]) {
      expect(migration, contains(check));
    }
    expect(migration, contains('Complete all five evidence checks'));
    expect(
        migration, contains("kyc_assurance_level = 'manual_document_review'"));
    expect(migration, contains("p.kyc_method = 'on_device'"));
  });

  test('admin gets short-lived private evidence and focused decisions', () {
    final operations = source('admin/src/lib/operations.ts');
    final page = source('admin/src/app/(staff)/kyc/page.tsx');

    expect(operations, contains('.createSignedUrls(paths, 60 * 5)'));
    expect(operations, contains('signedByPath.get(row.selfie_path)'));
    expect(operations, contains('signedByPath.get(row.id_path)'));
    expect(page, contains('Device hints — not a decision'));
    expect(page, contains('Approval checklist'));
    expect(page, contains('Request resubmission'));
    expect(page, contains('Confirm rejection'));
  });

  test('raw KYC evidence has automatic deletion and durable digests', () {
    final purge = source('supabase/functions/purge-kyc-documents/index.ts');
    final migration =
        source('supabase/migrations/136_manual_global_kyc_review.sql');

    expect(purge, contains('.remove(paths)'));
    expect(purge, contains('SHA-256'));
    expect(purge, contains('documents_purged_at'));
    expect(migration, contains("now() + interval '30 days'"));
    expect(migration, contains('purge_kyc_documents_daily'));
  });
}
