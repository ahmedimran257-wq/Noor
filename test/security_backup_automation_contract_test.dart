import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('profile projection views use isolated invoker-safe contracts', () {
    final advisorFix = File(
      'supabase/migrations/183_resolve_security_advisor_findings.sql',
    ).readAsStringSync();
    final isolation = File(
      'supabase/migrations/184_isolate_private_view_helpers.sql',
    ).readAsStringSync();
    final guardianContract = File(
      'supabase/migrations/185_preserve_guardian_projection_contract.sql',
    ).readAsStringSync();

    expect(advisorFix, contains('unexpected_spatial_ref_sys_ownership'));
    expect(advisorFix, contains('security_invoker = true'));
    expect(isolation, contains('create schema if not exists api_private'));
    expect(isolation, contains('drop function if exists public.'));
    expect(isolation, isNot(contains('grant select on public.profiles')));
    expect(guardianContract, contains('last_name_initial text'));
    expect(guardianContract, contains('visibility text'));
  });

  test('backup tooling creates restorable ignored checksummed artifacts', () {
    final ignore = File('.gitignore').readAsStringSync();
    final backup = File('tool/backup_supabase.ps1').readAsStringSync();
    final scheduler = File(
      'tool/register_supabase_backup_task.ps1',
    ).readAsStringSync();

    expect(ignore, contains('/supabase/backups/'));
    expect(backup, contains("'--format=custom'"));
    expect(backup, contains("'--role=postgres'"));
    expect(backup, contains("'--schema=public'"));
    expect(backup, contains("'--schema=private'"));
    expect(backup, contains("'--schema=api_private'"));
    expect(backup, contains('Get-ArchiveTableRows'));
    expect(backup, contains('format_version = 2'));
    expect(backup, contains('Get-FileHash'));
    expect(backup, contains('manifest.json'));
    expect(backup, contains('previousEnvironment'));
    expect(scheduler, contains('New-ScheduledTaskTrigger -Weekly'));
    expect(scheduler, contains('-StartWhenAvailable'));
  });

  test('staging workflow uses disposable accounts and covers full lifecycle',
      () {
    final workflow = File(
      '.github/workflows/staging-conversation-lifecycle.yml',
    ).readAsStringSync();
    final lifecycle = File(
      'tool/staging_conversation_lifecycle.mjs',
    ).readAsStringSync();

    expect(workflow, contains('cron: "17 3 * * 1"'));
    expect(workflow, contains('environment: staging'));
    expect(workflow, isNot(contains('STAGING_FEMALE_EMAIL')));
    expect(workflow, isNot(contains('STAGING_MALE_PASSWORD')));
    expect(
      lifecycle,
      contains('Refusing to run lifecycle automation against production'),
    );
    expect(lifecycle, contains('admin/users'));
    expect(lifecycle, contains('subscription_required'));
    expect(lifecycle, contains('get_prior_match_context'));
    expect(lifecycle, contains('submit_user_report'));
    expect(lifecycle, contains('report_chat_message'));
    expect(lifecycle, contains('block_member'));
    expect(lifecycle, contains('complete disposable two-account'));
  });
}
