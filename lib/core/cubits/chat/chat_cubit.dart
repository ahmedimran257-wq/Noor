// lib/core/cubits/chat/chat_cubit.dart
// ============================================================
// NOOR — Chat Cubit (Step 8 — Mock)
//
// Blueprint architecture (Phase 1 mock):
//   • openConversation() — creates or retrieves a conversation
//   • sendMessage() — appends with status 'queued' then 'sent'
//   • markRead() — zeroes unread count
//   • toggleTimestamp() — tap-to-reveal per message
//   • simulateReply() — fake incoming reply for UX demo
//   • closeMatch() — respectful closure (mock, no backend call)
//
// Real implementation wires Supabase Realtime Broadcast
// (channel: 'match:{match_id}') and sqflite offline queue.
// ============================================================

import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'chat_state.dart';

class ChatCubit extends Cubit<ChatState> {
  ChatCubit() : super(const ChatState()) {
    _initMockConversations();
  }

  int _msgCounter = 0;

  // ── Mock data ────────────────────────────────────────────

  void _initMockConversations() {
    final now = DateTime.now();

    final conversations = [
      // Conversation with unread messages
      Conversation(
        id:               'c1',
        matchName:        'Fatima',
        matchLastInitial: 'A',
        unreadCount:      2,
        messages: [
          ChatMessage(
            id:     'm1',
            text:   'Assalamu Alaikum! Mashallah your profile is very impressive.',
            sentAt: now.subtract(const Duration(hours: 3)),
            isMe:   false,
            status: MessageStatus.delivered,
          ),
          ChatMessage(
            id:     'm2',
            text:   'Wa alaikum assalam! JazakAllah khair, that is very kind of you.',
            sentAt: now.subtract(const Duration(hours: 2, minutes: 48)),
            isMe:   true,
            status: MessageStatus.read,
          ),
          ChatMessage(
            id:     'm3',
            text:   'I noticed we share a love of reading. What are you reading currently?',
            sentAt: now.subtract(const Duration(minutes: 22)),
            isMe:   false,
            status: MessageStatus.delivered,
          ),
          ChatMessage(
            id:     'm4',
            text:   'Currently finishing "The Alchemist." Have you read it?',
            sentAt: now.subtract(const Duration(minutes: 10)),
            isMe:   false,
            status: MessageStatus.delivered,
          ),
        ],
      ),

      // Read conversation
      Conversation(
        id:               'c2',
        matchName:        'Zainab',
        matchLastInitial: 'H',
        unreadCount:      0,
        messages: [
          ChatMessage(
            id:     'm5',
            text:   'Assalamu Alaikum. I came across your profile and was genuinely impressed.',
            sentAt: now.subtract(const Duration(days: 1, hours: 2)),
            isMe:   true,
            status: MessageStatus.read,
          ),
          ChatMessage(
            id:     'm6',
            text:   'Wa alaikum assalam! Thank you, I appreciate that. What drew you to medicine?',
            sentAt: now.subtract(const Duration(days: 1, hours: 1)),
            isMe:   false,
            status: MessageStatus.read,
          ),
          ChatMessage(
            id:     'm7',
            text:   'It is a noble calling. InshAllah we can talk more.',
            sentAt: now.subtract(const Duration(days: 1)),
            isMe:   true,
            status: MessageStatus.read,
          ),
        ],
      ),
    ];

    emit(state.copyWith(conversations: conversations));
  }

  // ── Public API ────────────────────────────────────────────

  /// Open or create a conversation with a match by name.
  /// Returns the conversation ID.
  String openOrCreateConversation(String matchName, String lastInitial) {
    final existing = state.conversations.where(
      (c) => c.matchName == matchName,
    );
    if (existing.isNotEmpty) return existing.first.id;

    final newConv = Conversation(
      id:               'c_${DateTime.now().millisecondsSinceEpoch}',
      matchName:        matchName,
      matchLastInitial: lastInitial,
      messages:         const [],
      unreadCount:      0,
    );

    emit(state.copyWith(
      conversations: [newConv, ...state.conversations],
    ));
    return newConv.id;
  }

  /// Send a message. Transitions: queued → sent after 400ms.
  Future<void> sendMessage(String conversationId, String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    // Do not allow sending in a closed match
    final conv = state.conversations
        .where((c) => c.id == conversationId)
        .firstOrNull;
    if (conv?.isMatchClosed == true) return;

    _msgCounter++;
    final msgId = 'msg_$_msgCounter';
    final sent  = ChatMessage(
      id:     msgId,
      text:   trimmed,
      sentAt: DateTime.now(),
      isMe:   true,
      status: MessageStatus.queued,
    );

    _appendMessage(conversationId, sent);

    // Simulate network delivery
    await Future.delayed(const Duration(milliseconds: 400));
    _updateMessageStatus(conversationId, msgId, MessageStatus.sent);

    await Future.delayed(const Duration(milliseconds: 800));
    _updateMessageStatus(conversationId, msgId, MessageStatus.delivered);

    // Simulate a reply after a short delay for demo
    await Future.delayed(const Duration(seconds: 3));
    if (!isClosed) _simulateReply(conversationId);
  }

  /// Mark all messages in a conversation as read.
  void markRead(String conversationId) {
    final updated = state.conversations.map((c) {
      if (c.id != conversationId) return c;
      return c.copyWith(unreadCount: 0);
    }).toList();
    emit(state.copyWith(conversations: updated));
  }

  /// Toggle timestamp visibility for a message.
  void toggleTimestamp(String conversationId, String messageId) {
    final updated = state.conversations.map((c) {
      if (c.id != conversationId) return c;
      final msgs = c.messages.map((m) {
        if (m.id != messageId) return m;
        return m.copyWith(isTimestampVisible: !m.isTimestampVisible);
      }).toList();
      return c.copyWith(messages: msgs);
    }).toList();
    emit(state.copyWith(conversations: updated));
  }

  /// Respectfully close a match with a pre-written Islamic message.
  /// Appends the closure message to chat and marks the conversation closed.
  ///
  // TODO (backend): replace with Supabase RPC call:
  // await supabase.rpc('close_match', params: {
  //   'match_id': conversationId,
  //   'user_id': currentUserId,
  //   'message': message,
  // });
  void closeMatch(String conversationId, String message) {
    _msgCounter++;
    final closureMsg = ChatMessage(
      id:     'msg_$_msgCounter',
      text:   message,
      sentAt: DateTime.now(),
      isMe:   true,
      status: MessageStatus.sent,
    );

    final updated = state.conversations.map((c) {
      if (c.id != conversationId) return c;
      return c.copyWith(
        messages:       [...c.messages, closureMsg],
        isMatchClosed:  true,
        closureMessage: message,
      );
    }).toList();
    emit(state.copyWith(conversations: updated));
  }

  // ── Internal helpers ──────────────────────────────────────

  void _appendMessage(String convId, ChatMessage msg) {
    final updated = state.conversations.map((c) {
      if (c.id != convId) return c;
      return c.copyWith(messages: [...c.messages, msg]);
    }).toList();
    emit(state.copyWith(conversations: updated));
  }

  void _updateMessageStatus(
      String convId, String msgId, MessageStatus status) {
    if (isClosed) return;
    final updated = state.conversations.map((c) {
      if (c.id != convId) return c;
      final msgs = c.messages.map((m) {
        if (m.id != msgId) return m;
        return m.copyWith(status: status);
      }).toList();
      return c.copyWith(messages: msgs);
    }).toList();
    emit(state.copyWith(conversations: updated));
  }

  void _simulateReply(String convId) {
    // Do not reply to a closed match
    final conv = state.conversations
        .where((c) => c.id == convId)
        .firstOrNull;
    if (conv == null || conv.isMatchClosed) return;

    final replies = [
      'JazakAllah khair for sharing that, mashAllah.',
      'That is a beautiful perspective, subhanAllah.',
      'I completely agree. InshAllah let us talk more.',
      'Alhamdulillah! I am glad we matched.',
      'I appreciate your honesty, that means a lot.',
    ];
    final reply = replies[_msgCounter % replies.length];

    _msgCounter++;
    final replyMsg = ChatMessage(
      id:     'msg_$_msgCounter',
      text:   reply,
      sentAt: DateTime.now(),
      isMe:   false,
      status: MessageStatus.delivered,
    );

    final updated = state.conversations.map((c) {
      if (c.id != convId) return c;
      return c.copyWith(
        messages:    [...c.messages, replyMsg],
        unreadCount: 0, // Already in the conversation
      );
    }).toList();
    emit(state.copyWith(conversations: updated));
  }
}
