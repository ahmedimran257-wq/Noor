import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    'supabase/migrations/182_rematch_cycles_and_private_chat_deletion.sql',
  ).readAsStringSync();
  final visibilityMigration = File(
    'supabase/migrations/187_visible_relationship_states_in_discovery.sql',
  ).readAsStringSync();

  test('respectful closures permit a safe new match cycle after cooldown', () {
    expect(migration, contains("interval '7 days'"));
    expect(migration, contains('uq_active_match_pair'));
    expect(migration, contains("status IN ('closed','expired')"));
    expect(migration, contains("status IN ('active','blocked','reported')"));
    expect(migration, contains('get_prior_match_context'));
    expect(migration, contains('discovery_rematch_cooldown_token'));
    expect(migration, contains("RAISE EXCEPTION 'rematch_cooldown'"));
    expect(visibilityMigration, contains("'rematch_cooldown'"));
    expect(visibilityMigration, contains('rematch_available_at'));
    expect(
      visibilityMigration,
      contains("rematch_guard.status IN ('active','blocked','reported')"),
    );
  });

  test('pending interests and respectful cooldowns stay visible', () {
    expect(visibilityMigration, contains("i.status = 'accepted'"));
    expect(
      visibilityMigration,
      isNot(contains("i.status IN ('pending', 'accepted')")),
    );
    expect(visibilityMigration, contains("'pending_sent'"));
    expect(visibilityMigration, contains("'pending_received'"));
    expect(
        visibilityMigration, contains("latest.ended_at + interval '7 days'"));
  });

  test('blocked and reported pairs can never rematch', () {
    expect(migration, contains('FROM public.blocks b'));
    expect(migration, contains('FROM public.reports r'));
    expect(migration, contains("m.status IN ('blocked','reported')"));
    expect(migration, contains("RAISE EXCEPTION 'profile_unavailable'"));
    expect(visibilityMigration, contains('FROM public.blocks b'));
    expect(visibilityMigration, contains('FROM public.reports r'));
  });

  test('chat deletion is participant-private and evidence preserving', () {
    expect(migration, contains('hidden_by_a_at'));
    expect(migration, contains('hidden_by_b_at'));
    expect(migration, contains('hide_chat_conversation'));
    expect(migration, contains('end_match_before_deleting_chat'));
    expect(migration, contains('deleted_by_a = true'));
    expect(migration, contains('deleted_by_b = true'));
    expect(migration, isNot(contains('DELETE FROM public.messages')));
    expect(migration, isNot(contains('DELETE FROM public.matches')));
  });

  test('both chat surfaces expose an honest delete action', () {
    final cubit =
        File('lib/core/cubits/chat/chat_cubit.dart').readAsStringSync();
    final list = File(
      'lib/features/home/screens/chat_list_screen.dart',
    ).readAsStringSync();
    final chat = File(
      'lib/features/home/screens/chat_screen.dart',
    ).readAsStringSync();

    expect(cubit, contains("'hide_chat_conversation'"));
    expect(list, contains('Delete chat'));
    expect(chat, contains('Delete chat'));
    expect(list, contains('only from your inbox'));
    expect(chat, contains('only from your inbox'));
  });

  test('discovery discloses prior-match history before another interest', () {
    final cubit = File(
      'lib/core/cubits/discovery/discovery_feed_cubit.dart',
    ).readAsStringSync();
    final card = File(
      'lib/core/widgets/cards/silarah_profile_card.dart',
    ).readAsStringSync();
    final detail = File(
      'lib/features/home/screens/profile_detail_screen.dart',
    ).readAsStringSync();

    expect(cubit, contains("'get_prior_match_context'"));
    expect(card, contains('previousMatchLabel'));
    expect(card, contains('interestActionLabel'));
    expect(detail, contains('Previously matched on'));
    expect(detail, contains('rematchCooldownDays'));
  });
}
