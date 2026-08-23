import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    'supabase/migrations/245_security_advisor_acl_and_postgis_boundary.sql',
  ).readAsStringSync();

  test('anonymous SECURITY DEFINER access is narrowly allowlisted', () {
    expect(migration, contains("n.nspname = 'public'"));
    expect(migration, contains("d.deptype = 'e'"));
    expect(
      migration,
      contains('REVOKE EXECUTE ON FUNCTION %s FROM PUBLIC, anon'),
    );
    expect(migration, contains("'begin_signup_consent_transaction'"));
    expect(migration, contains("'validate_referral_code'"));
  });

  test('managed PostGIS objects are not mutated by app migrations', () {
    expect(migration, contains('managed-extension'));
    expect(migration, isNot(contains('ALTER TABLE public.spatial_ref_sys')));
    expect(migration, isNot(contains('ALTER EXTENSION postgis')));
  });
}
