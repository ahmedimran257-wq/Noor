import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:silarah/core/cubits/chat/chat_state.dart';

void main() {
  test('chat badge totals authoritative per-conversation unread counts', () {
    const state = ChatState(
      conversations: [
        Conversation(
          id: 'match-a',
          matchName: 'Amina',
          matchLastInitial: 'K',
          messages: [],
          unreadCount: 2,
        ),
        Conversation(
          id: 'match-b',
          matchName: 'Sara',
          matchLastInitial: 'M',
          messages: [],
          unreadCount: 1,
        ),
      ],
    );

    expect(state.totalUnread, 3);
  });

  test('incoming messages update the badge without depending on FCM', () {
    final chat =
        File('lib/core/cubits/chat/chat_cubit.dart').readAsStringSync();
    final nav = File(
      'lib/features/home/widgets/silarah_bottom_nav.dart',
    ).readAsStringSync();
    final main = File('lib/main.dart').readAsStringSync();

    expect(chat, contains(".channel('chat_inbox:\$me')"));
    expect(chat, contains('event: PostgresChangeEvent.insert'));
    expect(chat, contains("column: 'receiver_id'"));
    expect(chat, contains('_handleInboxMessageInsert(payload, me)'));
    expect(chat, contains('incrementUnread: !isOpen'));
    expect(chat, contains('_requestInboxReload()'));
    expect(chat, contains('_disposeInboxRealtime()'));

    expect(nav, contains('selector: (state) => state.totalUnread'));
    expect(nav, contains('2 => chatUnread'));

    // Notification Realtime and foreground FCM remain independent recovery
    // signals, but duplicate signals are coalesced into one reconciliation.
    expect(main, contains("if (item.type == 'new_message')"));
    expect(main, contains('_notificationRefreshSubscription'));
    expect(main, contains('_chatCubit.scheduleInboxReconciliation()'));
    expect(
      RegExp(r'_chatCubit\.scheduleInboxReconciliation\(\)')
          .allMatches(main)
          .length,
      2,
    );
  });
}
