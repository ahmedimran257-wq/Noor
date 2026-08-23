import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:silarah/core/cubits/chat/chat_state.dart';

void main() {
  final migration = File(
    'supabase/migrations/244_private_moderation_chat_state.sql',
  ).readAsStringSync();

  test('other participant moderation is private and chat becomes read-only',
      () {
    expect(migration, contains("'member_unavailable_read_only'"));
    expect(migration, contains("'Silarah member'"));
    expect(migration, contains('v_access.reason <> \'allowed\''));
    expect(migration, contains('private.assert_active_member(NEW.receiver_id'));
    expect(migration, isNot(contains("'User was banned'")));
  });

  test('unavailable conversation exposes only a neutral preview', () {
    const conversation = Conversation(
      id: 'match-id',
      matchName: 'Silarah member',
      matchLastInitial: '',
      messages: [],
      isMatchClosed: true,
      memberUnavailable: true,
    );
    expect(
      conversation.lastMessagePreview,
      'This profile is unavailable right now.',
    );
    expect(conversation.displayName, 'Silarah member');
  });
}
