import 'package:flutter_test/flutter_test.dart';
import 'package:silarah/core/cubits/chat/chat_state.dart';
import 'package:silarah/core/cubits/chat/chat_message_page.dart';

ChatMessage message(int id) => ChatMessage(
      id: '$id',
      text: 'Message $id',
      sentAt: DateTime.utc(2026, 1, 1, 0, id),
      isMe: false,
    );
List<ChatMessage> range(int first, int last) =>
    [for (var i = first; i <= last; i++) message(i)];

void main() {
  test('pagination never sends a temporary local ID to the UUID cursor', () {
    final local = ChatMessage(
      id: 'local_retry',
      text: 'Pending',
      sentAt: DateTime.utc(2025),
      isMe: true,
      status: MessageStatus.failed,
    );
    expect(oldestPersistedChatMessage([local, ...range(10, 20)])?.id, '10');
    expect(oldestPersistedChatMessage([local]), isNull);
  });
  test('catch-up resets a disjoint window and makes the gap pageable', () {
    final page = reconcileChatMessagePage(
      current: range(1, 5),
      incoming: range(16, 45),
      older: false,
      wasExhausted: true,
      pageSize: 30,
    );
    expect(page.messages.map((m) => m.id), range(16, 45).map((m) => m.id));
    expect(page.olderExhausted, false);
    // Fetching before 16 now recovers the missing 6..15 instead of fetching
    // before 1 and incorrectly skipping those messages forever.
    final older = reconcileChatMessagePage(
      current: page.messages,
      incoming: range(1, 15),
      older: true,
      wasExhausted: page.olderExhausted,
      pageSize: 30,
    );
    expect(older.messages.length, 45);
    expect(older.olderExhausted, true);
  });

  test('overlapping recovery keeps contiguous previously loaded history', () {
    final page = reconcileChatMessagePage(
      current: range(1, 50),
      incoming: range(26, 55),
      lastFetchedMessageId: '50',
      older: false,
      wasExhausted: true,
      pageSize: 30,
    );
    expect(page.messages.length, 55);
    expect(page.messages.first.id, '1');
    expect(page.olderExhausted, true);
  });

  test('a complete short latest page removes stale server messages', () {
    final page = reconcileChatMessagePage(
      current: range(1, 10),
      incoming: range(6, 10),
      older: false,
      wasExhausted: false,
      pageSize: 30,
    );
    expect(page.messages.length, 5);
    expect(page.messages.first.id, '6');
    expect(page.olderExhausted, true);
  });

  test('a fresh Realtime event cannot conceal a gap before that event', () {
    final page = reconcileChatMessagePage(
      current: [...range(1, 5), message(50)],
      incoming: range(21, 50),
      older: false,
      wasExhausted: true,
      pageSize: 30,
      lastFetchedMessageId: '5',
    );
    expect(page.messages.length, 30);
    expect(page.messages.first.id, '21');
    expect(page.olderExhausted, false);
  });

  test('reset preserves unsent local bubbles and their operation IDs', () {
    final local = ChatMessage(
      id: 'local_retry',
      operationId: 'retry',
      text: 'Hello',
      sentAt: DateTime.utc(2026, 2),
      isMe: true,
      status: MessageStatus.failed,
    );
    final page = reconcileChatMessagePage(
      current: [...range(1, 5), local],
      incoming: range(16, 45),
      older: false,
      wasExhausted: true,
      pageSize: 30,
    );
    expect(page.messages.length, 31);
    expect(page.messages.last, local);
    expect(page.messages.last.operationId, 'retry');
  });

  test('a full first page remains pageable; an empty latest page is complete',
      () {
    final full = reconcileChatMessagePage(
      current: [],
      incoming: range(1, 30),
      older: false,
      wasExhausted: false,
      pageSize: 30,
    );
    expect(full.olderExhausted, false);
    final empty = reconcileChatMessagePage(
      current: full.messages,
      incoming: [],
      older: false,
      wasExhausted: false,
      pageSize: 30,
    );
    expect(empty.messages, isEmpty);
    expect(empty.olderExhausted, true);
  });
}
