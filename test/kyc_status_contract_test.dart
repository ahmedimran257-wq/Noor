import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String source(String path) => File(path).readAsStringSync();

  test('authoritative KYC status is evidence-backed and user-scoped', () {
    final migration = source(
      'supabase/migrations/145_authoritative_kyc_status_contract.sql',
    );

    expect(migration, contains('private.current_kyc_status'));
    expect(migration, contains('public.get_my_kyc_status'));
    expect(migration, contains('public.kyc_review_submissions'));
    expect(migration, contains('public.identity_verification_evidence'));
    expect(migration, contains("WHEN 'pending' THEN 'pending_review'"));
    expect(migration, contains("WHEN 'resubmit' THEN 'resubmit_required'"));
    expect(migration, contains('WHERE p.user_id = p_user_id'));
    expect(migration, contains('auth.uid()'));
  });

  test('photo verification can never be presented as KYC in admin', () {
    final page = source('admin/src/app/(staff)/users/page.tsx');
    final operations = source('admin/src/lib/operations.ts');

    expect(page, contains('user.kyc_status'));
    expect(
        page,
        isNot(contains(
          '<td><span className="status-pill">{user.verification_status}</span></td>',
        )));
    expect(operations, contains('kyc_status:"not_started"'));
  });

  test('app exposes the complete durable KYC lifecycle', () {
    final service = source('lib/core/services/kyc_verification_service.dart');
    final screen = source(
        'lib/features/verification/screens/kyc_verification_screen.dart');
    final english = source('lib/l10n/app_en.arb');

    for (final state in [
      'notStarted',
      'pendingReview',
      'approved',
      'rejected',
      'resubmitRequired',
      'expired',
    ]) {
      expect(service, contains(state));
      expect(screen, contains('KycVerificationStatus.$state'));
    }
    expect(service, contains("rpc('get_my_kyc_status')"));
    expect(screen, contains('kyc_statusPendingBody'));
    expect(english, contains('You do not need to submit it again.'));
  });
}
