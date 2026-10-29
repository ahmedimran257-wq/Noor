import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _migration280() => File(
      'supabase/migrations/280_security_audit_hardening.sql',
    ).readAsStringSync();

String _functionBody(String migration, String name) {
  final start = migration.indexOf('FUNCTION public.$name(');
  expect(start, isNonNegative, reason: '$name must be redefined');
  final end = migration.indexOf(r'$function$;', start);
  return migration.substring(start, end);
}

void main() {
  test('server-only functions lose the default member grants', () {
    final migration = _migration280();

    expect(
      migration,
      contains('REVOKE EXECUTE ON FUNCTION %s FROM PUBLIC, anon, authenticated'),
    );
    for (final function in [
      'claim_transactional_email',
      'compute_reporter_trust_score',
      'checkout_notifications',
      'consume_upload_reservation',
      'request_profile_photo_deletion',
      'is_disposable_email_domain',
    ]) {
      expect(migration, contains("'$function'"));
    }
  });

  test('every function a migration grants only to service_role is revoked '
      'from signed-in members', () {
    final grant = RegExp(
      r'GRANT EXECUTE ON FUNCTION (?:public\.)?([a-z_0-9]+)\([^)]*\)\s+TO\s+service_role\s*;',
      caseSensitive: false,
    );
    final memberRevoke = RegExp(
      r'REVOKE[^;]*FUNCTION (?:public\.)?([a-z_0-9]+)\([^;]*FROM[^;]*authenticated',
      caseSensitive: false,
    );
    final dropped = RegExp(
      r'DROP FUNCTION IF EXISTS (?:public\.)?([a-z_0-9]+)\(',
      caseSensitive: false,
    );
    final serviceOnly = <String>{};
    final revoked = <String>{};
    final retired = <String>{};
    final migrations = Directory('supabase/migrations')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.sql'));
    for (final file in migrations) {
      final sql = file.readAsStringSync();
      serviceOnly.addAll(grant.allMatches(sql).map((m) => m.group(1)!));
      revoked.addAll(memberRevoke.allMatches(sql).map((m) => m.group(1)!));
      retired.addAll(dropped.allMatches(sql).map((m) => m.group(1)!));
    }

    final audit = _migration280();
    final missing = serviceOnly
        .where(
          (name) =>
              !retired.contains(name) &&
              !revoked.contains(name) &&
              !audit.contains("'$name'"),
        )
        .toList();
    // Supabase grants EXECUTE to anon and authenticated on creation; a
    // REVOKE ... FROM PUBLIC alone leaves members able to call the function.
    expect(missing, isEmpty);
  });

  test('photo checks bind the viewer to the signed-in caller', () {
    final migration = _migration280();

    final canViewPhoto = _functionBody(migration, 'can_view_photo');
    expect(canViewPhoto, contains('p_viewer IS DISTINCT FROM auth.uid()'));
    expect(canViewPhoto, contains("<> 'service_role'"));

    final realtimeTopic =
        _functionBody(migration, 'can_access_chat_realtime_topic');
    expect(realtimeTopic, contains('p_user_id = auth.uid()'));
  });

  test('a block ends photo access and photo requests in both directions', () {
    final migration = _migration280();

    final paths = _functionBody(migration, 'get_authorized_photo_paths');
    expect(paths, contains("auth.role() = 'service_role'"));
    expect(paths, contains('FROM public.blocks pair_block'));
    expect(
      paths,
      contains(
        'pair_block.blocker_id = owner.user_id AND pair_block.blocked_id = p_viewer_user_id',
      ),
    );

    final request = _functionBody(migration, 'request_photo_access');
    expect(request, contains('b.blocker_id = v_owner AND b.blocked_id = v_requester'));
    expect(
      'This profile is not accepting photo access requests.'
          .allMatches(request)
          .length,
      3,
    );
  });
}
