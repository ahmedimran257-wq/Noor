import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every member chat operation survives hardened base-table grants', () {
    final migration = File(
      'supabase/migrations/159_restore_secure_chat_operations.sql',
    ).readAsStringSync();

    for (final function in [
      'get_chat_messages',
      'mark_chat_read',
      'report_chat_message',
      'block_chat_user',
      'close_chat_match',
    ]) {
      expect(migration, contains('FUNCTION public.$function'));
    }
    expect(
      'SECURITY DEFINER'.allMatches(migration).length,
      greaterThanOrEqualTo(5),
    );
    expect(
      migration,
      contains('(m.user_a = v_me OR m.user_b = v_me)'),
    );
    expect(migration, contains('v_msg.receiver_id = v_me'));
  });

  test('chat client uses only the checked RPC surface', () {
    final cubit = File(
      'lib/core/cubits/chat/chat_cubit.dart',
    ).readAsStringSync();

    expect(cubit, contains("'get_chat_inbox'"));
    expect(cubit, contains("'get_chat_messages'"));
    expect(cubit, contains("'send_chat_message'"));
    expect(cubit, contains("'mark_chat_read'"));
    expect(cubit, isNot(contains(".from('messages')")));
    expect(cubit, isNot(contains(".from('matches')")));
  });
}
