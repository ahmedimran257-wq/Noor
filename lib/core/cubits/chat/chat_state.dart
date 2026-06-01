// lib/core/cubits/chat/chat_state.dart
// ============================================================
// NOOR — Chat State
//
// Blueprint (Part 8, Conversations):
//   • Conversations list sorted by newest message
//   • Unread count per conversation
//   • Messages: sent (gold-tinted right) / received (surface left)
//   • Message status: queued | sent | delivered | read
//   • Timestamps hidden by default; revealed on tap
//   • Respectful closure: isMatchClosed + closureMessage per conversation
// ============================================================

import 'package:equatable/equatable.dart';

// ── Message status ─────────────────────────────────────────────

enum MessageStatus { queued, sent, delivered, read }

// ── Message ───────────────────────────────────────────────────

class ChatMessage extends Equatable {
  const ChatMessage({
    required this.id,
    required this.text,
    required this.sentAt,
    required this.isMe,
    this.status = MessageStatus.sent,
    this.isTimestampVisible = false,
    this.sentByGuardian = false,
  });

  final String         id;
  final String         text;
  final DateTime       sentAt;
  final bool           isMe;      // true = sent by current user
  final MessageStatus  status;
  final bool           isTimestampVisible;
  final bool           sentByGuardian; // §3.2: true when guardian sent this message

  ChatMessage copyWith({
    MessageStatus? status,
    bool?          isTimestampVisible,
  }) {
    return ChatMessage(
      id:                  id,
      text:                text,
      sentAt:              sentAt,
      isMe:                isMe,
      status:              status ?? this.status,
      isTimestampVisible:  isTimestampVisible ?? this.isTimestampVisible,
      sentByGuardian:      sentByGuardian,
    );
  }

  @override
  List<Object?> get props =>
      [id, text, sentAt, isMe, status, isTimestampVisible, sentByGuardian];
}

// ── Conversation ──────────────────────────────────────────────

class Conversation extends Equatable {
  const Conversation({
    required this.id,
    required this.matchName,
    required this.matchLastInitial,
    required this.messages,
    this.unreadCount = 0,
    this.matchId,
    this.isMatchClosed = false,
    this.closureMessage,
  });

  final String           id;
  final String           matchName;       // First name only
  final String           matchLastInitial;
  final List<ChatMessage> messages;
  final int              unreadCount;
  final String?          matchId;
  final bool             isMatchClosed;   // true when respectful closure sent
  final String?          closureMessage;  // the pre-written closing message

  ChatMessage? get lastMessage =>
      messages.isEmpty ? null : messages.last;

  String get lastMessagePreview {
    final m = lastMessage;
    if (m == null) return 'Say Assalamu Alaikum!';
    return m.text.length > 50 ? '${m.text.substring(0, 50)}…' : m.text;
  }

  String get lastMessageTime {
    final m = lastMessage;
    if (m == null) return '';
    final diff = DateTime.now().difference(m.sentAt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  Conversation copyWith({
    List<ChatMessage>? messages,
    int?               unreadCount,
    bool?              isMatchClosed,
    String?            closureMessage,
  }) {
    return Conversation(
      id:                id,
      matchName:         matchName,
      matchLastInitial:  matchLastInitial,
      messages:          messages       ?? this.messages,
      unreadCount:       unreadCount    ?? this.unreadCount,
      matchId:           matchId,
      isMatchClosed:     isMatchClosed  ?? this.isMatchClosed,
      closureMessage:    closureMessage ?? this.closureMessage,
    );
  }

  @override
  List<Object?> get props =>
      [id, matchName, matchLastInitial, messages, unreadCount, isMatchClosed, closureMessage];
}

// ── Chat State ────────────────────────────────────────────────

class ChatState extends Equatable {
  const ChatState({
    this.conversations = const [],
    this.isLoading     = false,
  });

  final List<Conversation> conversations;
  final bool               isLoading;

  int get totalUnread =>
      conversations.fold(0, (sum, c) => sum + c.unreadCount);

  /// Sorted: newest message first
  List<Conversation> get sortedConversations {
    final sorted = List<Conversation>.from(conversations);
    sorted.sort((a, b) {
      final aTime = a.lastMessage?.sentAt ?? DateTime(0);
      final bTime = b.lastMessage?.sentAt ?? DateTime(0);
      return bTime.compareTo(aTime);
    });
    return sorted;
  }

  ChatState copyWith({
    List<Conversation>? conversations,
    bool?              isLoading,
  }) {
    return ChatState(
      conversations: conversations ?? this.conversations,
      isLoading:     isLoading     ?? this.isLoading,
    );
  }

  @override
  List<Object?> get props => [conversations, isLoading];
}
