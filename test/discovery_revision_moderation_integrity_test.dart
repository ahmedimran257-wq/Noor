import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String source(String path) => File(path).readAsStringSync();

  test('optional preferences never suppress an otherwise eligible profile', () {
    final migration = source(
      'supabase/migrations/178_discovery_revision_and_moderation_integrity.sql',
    );

    expect(
      migration,
      contains(
          'LEFT JOIN public.profile_preferences prefs ON prefs.profile_id = p.id'),
    );
    expect(migration, contains('trg_ensure_profile_preferences_row'));
    expect(migration, contains("ph.order_index = 0"));
    expect(migration, contains("ph.status = 'active'"));
    expect(migration, contains('FROM public.live_discovery_pool candidate'));
  });

  test('resume refresh is revision-gated and relationship-aware', () {
    final migration = source(
      'supabase/migrations/178_discovery_revision_and_moderation_integrity.sql',
    );
    final cubit = source('lib/core/cubits/discovery/discovery_feed_cubit.dart');
    final home = source('lib/features/home/home_screen.dart');

    expect(migration, contains('private.discovery_catalog_revision'));
    expect(migration, contains('private.discovery_member_revisions'));
    expect(migration, contains('trg_discovery_revision_matches'));
    expect(migration, contains('trg_discovery_revision_blocks'));
    expect(cubit, contains('Future<void> refreshIfChanged'));
    expect(cubit, contains('_loadedRevisionToken == serverToken'));
    expect(home, contains('refreshIfChanged()'));
    expect(home, isNot(contains('loadInitial(force: true);')));
  });

  test('reports and blocks preserve evidence behind checked boundaries', () {
    final migration = source(
      'supabase/migrations/178_discovery_revision_and_moderation_integrity.sql',
    );
    final blockCubit =
        source('lib/core/cubits/block_report/block_report_cubit.dart');

    expect(migration, contains("SET status = 'blocked'"));
    expect(migration, isNot(contains('DELETE FROM public.matches')));
    expect(migration, contains("SET status = 'reported'"));
    expect(
        migration, contains('REVOKE INSERT, UPDATE, DELETE ON public.blocks'));
    expect(blockCubit, contains("rpc('block_member'"));
    expect(blockCubit, contains("'unblock_member'"));
  });

  test('admin decisions and staging transition are operational, not labels',
      () {
    final migration = source(
      'supabase/migrations/178_discovery_revision_and_moderation_integrity.sql',
    );
    final admin = source('admin/src/app/(staff)/moderation/page.tsx');
    final workflow = source(
      '.github/workflows/staging-conversation-lifecycle.yml',
    );
    final staging = source('tool/staging_conversation_lifecycle.mjs');

    expect(
        migration, contains("suspended_reason = 'moderation_report_actioned'"));
    expect(migration, contains("now() + interval '7 days'"));
    expect(admin, contains('Discovery eligibility'));
    expect(admin, contains('Restrict messaging 7 days'));
    expect(admin, contains('Suspend profile'));
    expect(workflow, contains('workflow_dispatch'));
    expect(staging,
        contains('Refusing to run lifecycle automation against production'));
    expect(staging, contains('subscription_required'));
    expect(staging, contains('read_only'));
  });
}
