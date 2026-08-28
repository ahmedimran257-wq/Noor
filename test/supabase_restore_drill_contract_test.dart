import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String script;

  setUpAll(() {
    script = File('tool/restore_supabase_backup_drill.ps1').readAsStringSync();
  });

  test('restore drill is staging-only and dry-run by default', () {
    expect(script, contains("[switch]\$Execute"));
    expect(script, contains('Restore drills are forbidden against production'));
    expect(script, contains('Dry run passed'));
    expect(script, contains('manifest.project_ref'));
    expect(script, contains('db.\$StagingProjectRef.supabase.co'));
    expect(script, contains('pooler\\.supabase\\.com'));
    expect(script, contains('previousLinkedRef'));
    expect(script,
        contains('Could not restore the previous Supabase project link'));
  });

  test('app data is restored without managed platform dependencies', () {
    expect(script, contains("'TABLE DATA'"));
    expect(script, contains("'CHECK CONSTRAINT'"));
    expect(script, contains("name -eq 'spatial_ref_sys'"));
    expect(script, contains('CREATE EXTENSION postgis WITH SCHEMA public'));
    expect(script, contains('manifest.table_rows'));
    expect(script, contains('app.dump'));
    expect(script, isNot(contains('Restored public-table row counts')));
  });

  test('ephemeral restore is validated and always deleted', () {
    expect(script, contains('silarah_restore_drill_'));
    expect(script, contains('Restored row count mismatch'));
    expect(script, contains('pg_terminate_backend'));
    expect(script, contains('DROP DATABASE'));
    expect(script, contains(r'$cleanupArmed = $true'));
    expect(script, contains('finally'));
  });

  test('database creation and deletion are separate psql commands', () {
    expect(script, isNot(contains('SET ROLE postgres; CREATE DATABASE')));
    expect(script, isNot(contains('SET ROLE postgres; DROP DATABASE')));
    expect(script, contains('Invoke-PsqlStatements'));
    expect(script, contains("'SET ROLE postgres',"));
  });
}
