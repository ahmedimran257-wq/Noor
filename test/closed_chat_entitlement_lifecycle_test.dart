import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:silarah/core/cubits/chat/chat_state.dart';

void main() {
  test('a locked inbox never exposes its latest message preview', () {
    final conversation = Conversation(
      id: 'match-1',
      matchName: 'Member',
      matchLastInitial: 'S',
      messages: [
        ChatMessage(
          id: 'message-1',
          text: 'Private message content',
          sentAt: DateTime.utc(2026, 8, 1),
          isMe: false,
          status: MessageStatus.delivered,
        ),
      ],
      unreadCount: 1,
      contentLocked: true,
    );

    expect(conversation.lastMessagePreview, 'Unlock Premium to read messages');
    expect(conversation.unreadCount, 1);
  });

  test('closed-chat access checks entitlement before respectful closure', () {
    final migration = File(
      'supabase/migrations/175_closed_chat_read_entitlement.sql',
    ).readAsStringSync();

    final paywallCheck = migration.indexOf("'subscription_required'::text");
    final readableClosureCheck =
        migration.indexOf("v_status IN ('closed', 'expired')");

    expect(paywallCheck, greaterThan(0));
    expect(readableClosureCheck, greaterThan(paywallCheck));
    expect(migration, contains("v_status IN ('blocked', 'reported')"));
    expect(
        migration,
        contains(
            "SELECT *\n  INTO v_access\n  FROM public.can_open_chat(p_match_id);"));
    expect(migration, contains('WHEN v_content_locked THEN NULL::text'));
  });

  test('client maps closure actor and server content lock metadata', () {
    final cubit =
        File('lib/core/cubits/chat/chat_cubit.dart').readAsStringSync();
    final screen = File(
      'lib/features/home/screens/chat_screen.dart',
    ).readAsStringSync();

    expect(cubit, contains("row['content_locked'] == true"));
    expect(cubit, contains("row['closed_by'] == me"));
    expect(screen, contains("false => '\$name ended this match.'"));
    expect(screen, contains("true => 'You ended this match.'"));
  });

  test('app-owned database functions avoid runtime name ambiguity', () {
    final migration = File(
      'supabase/migrations/176_repair_runtime_function_ambiguities.sql',
    ).readAsStringSync();
    final conflictPolicy = File(
      'supabase/migrations/177_pin_photo_finalizer_column_resolution.sql',
    ).readAsStringSync();

    expect(
      migration,
      contains(
        'ON CONFLICT ON CONSTRAINT '
        'photo_moderation_queue_photo_id_key DO NOTHING',
      ),
    );
    expect(
      migration,
      contains('p_mark_seen_ward_id uuid\n)'),
    );
    expect(
      migration,
      isNot(contains('p_mark_seen_ward_id uuid DEFAULT NULL')),
    );
    expect(
      conflictPolicy,
      contains('WHERE photo_moderation_queue.photo_id = v_replaced.id'),
    );
    expect(conflictPolicy, isNot(contains('plpgsql.variable_conflict')));
  });
}
