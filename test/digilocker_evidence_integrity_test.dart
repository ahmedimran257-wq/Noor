import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('DigiLocker client uses PKCE and never treats token exchange as proof',
      () {
    final client =
        File('lib/core/services/digilocker_service.dart').readAsStringSync();
    expect(client, contains("'code_challenge': codeChallenge"));
    expect(client, contains("'code_challenge_method': 'S256'"));
    expect(client, contains("'code_verifier': codeVerifier"));
    expect(client, isNot(contains('verifyOptionalAadhaar')));
  });

  test('DigiLocker backend requires profile, document and HMAC evidence', () {
    final backend = File('supabase/functions/digilocker-verify/index.ts')
        .readAsStringSync();
    expect(backend, contains('userDetailsUrl'));
    expect(backend, contains('issuedDocumentsUrl'));
    expect(backend, contains('verifyDigiLockerHmac'));
    expect(backend, contains('extractDocumentIdentity'));
    expect(backend, contains('record_digilocker_verification_result'));
    expect(backend, isNot(contains('kyc_verified: true')));
  });

  test('evidence migration revokes unsupported legacy approvals', () {
    final migration = File(
      'supabase/migrations/135_harden_digilocker_identity_evidence.sql',
    ).readAsStringSync();
    expect(migration, contains("WHERE kyc_method = 'digilocker_optional'"));
    expect(migration, contains('document_integrity_verified'));
    expect(migration, contains('account_name_match'));
    expect(migration, contains('account_dob_match'));
    expect(migration, contains('REVOKE ALL ON TABLE'));
  });

  test('government ID UI never falls back to the liveness status', () {
    final profile = File('lib/features/home/screens/my_profile_screen.dart')
        .readAsStringSync();
    expect(
      profile,
      contains('KycVerificationService.instance.fetchStatus()'),
    );
    expect(
      profile,
      isNot(contains(
        ".select('kyc_verified, verification_status, kyc_assurance_level')",
      )),
    );
  });
}
