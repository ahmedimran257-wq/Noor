// lib/core/cubits/chat/chat_cubit.dart
// ============================================================
// NOOR — Chat Cubit (Real Supabase + Mock Fallback)
// ============================================================

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/supabase_service.dart';
import '../../utils/content_filter.dart';
import 'chat_state.dart';

class ChatCubit extends Cubit<ChatState> {
  ChatCubit() : super(const ChatState()) {
    loadConversations();
  }

  int _msgCounter = 0;
  RealtimeChannel? _messagesSubscription;
  RealtimeChannel? _matchesSubscription;

  bool get _isRealMode => SupabaseService.isInitialized;

  // ── DB Loading & Realtime ─────────────────────────────────

  Future<void> loadConversations() async {
    if (!_isRealMode) {
      _initMockConversations();
      return;
    }

    emit(state.copyWith(isLoading: true));
    try {
      final me = SupabaseService.currentUserId;
      if (me == null) {
        _initMockConversations();
        return;
      }

      // Fetch matches where current user is participant
      final matches = await SupabaseService.client
          .from('matches')
          .select()
          .or('user_a.eq.$me,user_b.eq.$me');

      final List<Conversation> loaded = [];

      for (var m in matches) {
        final matchId = m['id'] as String;
        final userA = m['user_a'] as String;
        final userB = m['user_b'] as String;
        final status = m['status'] as String;
        final closureReason = m['closure_reason'] as String?;
        final otherUserId = (userA == me) ? userB : userA;

        // Fetch other user's profile
        final profile = await SupabaseService.client
            .from('profiles')
            .select('first_name, last_name')
            .eq('user_id', otherUserId)
            .maybeSingle();

        final matchName = profile != null ? (profile['first_name'] as String? ?? 'User') : 'User';
        final lastName = profile != null ? (profile['last_name'] as String? ?? '') : '';
        final matchLastInitial = lastName.isNotEmpty ? lastName[0] : '';

        // Fetch messages for this match
        final messagesData = await SupabaseService.client
            .from('messages')
            .select()
            .eq('match_id', matchId)
            .order('created_at', ascending: true);

        final List<ChatMessage> chatMessages = [];
        int unreadCount = 0;

        for (var msg in messagesData) {
          final isMe = msg['sender_id'] == me;
          final readAt = msg['read_at'];
          final isRead = readAt != null;
          if (!isMe && !isRead) {
            unreadCount++;
          }
          chatMessages.add(ChatMessage(
            id: msg['id'] as String,
            text: msg['content'] as String? ?? '',
            sentAt: DateTime.parse(msg['created_at'] as String).toLocal(),
            isMe: isMe,
            status: isRead 
                ? MessageStatus.read 
                : (isMe ? MessageStatus.sent : MessageStatus.delivered),
          ));
        }

        loaded.add(Conversation(
          id: matchId,
          matchName: matchName,
          matchLastInitial: matchLastInitial,
          messages: chatMessages,
          unreadCount: unreadCount,
          matchId: matchId,
          isMatchClosed: status == 'closed' || status == 'expired' || status == 'blocked' || status == 'reported',
          closureMessage: closureReason,
        ));
      }

      emit(state.copyWith(conversations: loaded, isLoading: false));
      _setupRealtime();
    } catch (e) {
      debugPrint('ChatCubit: Error loading conversations: $e');
      _initMockConversations();
    }
  }

  void _setupRealtime() {
    final me = SupabaseService.currentUserId;
    if (me == null) return;

    _disposeRealtime();

    // Subscribe to new incoming messages where I am the receiver
    _messagesSubscription = SupabaseService.client
        .channel('chat_messages')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'receiver_id',
            value: me,
          ),
          callback: (payload) {
            loadConversations();
          },
        )
        .subscribe();

    // Subscribe to match status changes / new matches (filtered by RLS)
    _matchesSubscription = SupabaseService.client
        .channel('chat_matches')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'matches',
          callback: (payload) {
            loadConversations();
          },
        )
        .subscribe();
  }

  void _disposeRealtime() {
    _messagesSubscription?.unsubscribe();
    _matchesSubscription?.unsubscribe();
    _messagesSubscription = null;
    _matchesSubscription = null;
  }

  @override
  Future<void> close() {
    _disposeRealtime();
    return super.close();
  }

  // ── Mock data fallback ─────────────────────────────────────

  void _initMockConversations() {
    final now = DateTime.now();

    final conversations = [
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

    emit(state.copyWith(conversations: conversations, isLoading: false));
  }

  // ── Public API ────────────────────────────────────────────

  String openOrCreateConversation(String matchName, String lastInitial) {
    final existing = state.conversations.where(
      (c) => c.matchName == matchName,
    );
    if (existing.isNotEmpty) return existing.first.id;

    if (_isRealMode) {
      // In real mode, matches are created via accepted interests, not manually.
      return '';
    }

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

  Future<void> sendMessage(String conversationId, String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final conv = state.conversations
        .where((c) => c.id == conversationId)
        .firstOrNull;
    if (conv?.isMatchClosed == true) return;

    final filtered = ContentFilter.redact(trimmed);

    _msgCounter++;
    final tempMsgId = 'msg_$_msgCounter';
    final sent  = ChatMessage(
      id:     tempMsgId,
      text:   filtered,
      sentAt: DateTime.now(),
      isMe:   true,
      status: MessageStatus.queued,
    );

    _appendMessage(conversationId, sent);

    if (_isRealMode) {
      final me = SupabaseService.currentUserId;
      if (me == null) return;

      try {
        // Fetch the match pair to determine sender & receiver
        final matchData = await SupabaseService.client
            .from('matches')
            .select('user_a, user_b')
            .eq('id', conversationId)
            .single();

        final userA = matchData['user_a'] as String;
        final userB = matchData['user_b'] as String;
        final receiverId = (userA == me) ? userB : userA;

        await SupabaseService.client.from('messages').insert({
          'match_id': conversationId,
          'sender_id': me,
          'receiver_id': receiverId,
          'content': filtered,
        });

        _updateMessageStatus(conversationId, tempMsgId, MessageStatus.sent);
        await loadConversations();
      } catch (e) {
        debugPrint('ChatCubit: Error sending message: $e');
        // Revert status to queued on error
        _updateMessageStatus(conversationId, tempMsgId, MessageStatus.queued);
      }
    } else {
      // Simulate network delivery in mock mode
      await Future.delayed(const Duration(milliseconds: 400));
      _updateMessageStatus(conversationId, tempMsgId, MessageStatus.sent);

      await Future.delayed(const Duration(milliseconds: 800));
      _updateMessageStatus(conversationId, tempMsgId, MessageStatus.delivered);

      await Future.delayed(const Duration(seconds: 3));
      if (!isClosed) _simulateReply(conversationId);
    }
  }

  void markRead(String conversationId) {
    final exists = state.conversations.any((c) => c.id == conversationId);
    if (!exists) return;

    if (_isRealMode) {
      final me = SupabaseService.currentUserId;
      if (me == null) return;

      try {
        SupabaseService.client
            .from('messages')
            .update({'read_at': DateTime.now().toIso8601String()})
            .eq('match_id', conversationId)
            .eq('receiver_id', me)
            .isFilter('read_at', null);

        final updated = state.conversations.map((c) {
          if (c.id != conversationId) return c;
          return c.copyWith(unreadCount: 0);
        }).toList();
        emit(state.copyWith(conversations: updated));
      } catch (e) {
        debugPrint('ChatCubit: Error marking read: $e');
      }
    } else {
      final updated = state.conversations.map((c) {
        if (c.id != conversationId) return c;
        return c.copyWith(unreadCount: 0);
      }).toList();
      emit(state.copyWith(conversations: updated));
    }
  }

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

  Future<void> closeMatch(String conversationId, String message) async {
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

    if (_isRealMode) {
      final me = SupabaseService.currentUserId;
      if (me == null) return;

      try {
        final matchData = await SupabaseService.client
            .from('matches')
            .select('user_a, user_b')
            .eq('id', conversationId)
            .single();

        final userA = matchData['user_a'] as String;
        final userB = matchData['user_b'] as String;
        final receiverId = (userA == me) ? userB : userA;

        // 1. Insert closure message so other participant sees it
        await SupabaseService.client.from('messages').insert({
          'match_id': conversationId,
          'sender_id': me,
          'receiver_id': receiverId,
          'content': message,
        });

        // 2. Set status to closed in matches
        await SupabaseService.client
            .from('matches')
            .update({
              'status': 'closed',
              'closed_by': me,
              'closed_at': DateTime.now().toIso8601String(),
              'closure_reason': message,
            })
            .eq('id', conversationId);

        await loadConversations();
      } catch (e) {
        debugPrint('ChatCubit: Error closing match: $e');
      }
    }
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
        unreadCount: 0,
      );
    }).toList();
    emit(state.copyWith(conversations: updated));
  }
}
