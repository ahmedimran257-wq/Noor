// lib/core/cubits/chat/chat_cubit.dart
// ============================================================
// MITHAQ — Chat Cubit (Supabase production flow)
// ============================================================

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/supabase_service.dart';
import '../../services/translation_service.dart';
import '../../utils/content_filter.dart';
import '../../utils/mithaq_compute.dart';
import 'chat_state.dart';

class ChatCubit extends Cubit<ChatState> {
  ChatCubit() : super(const ChatState()) {
    unawaited(loadConversations());
  }

  int _msgCounter = 0;
  RealtimeChannel? _messagesSubscription;
  RealtimeChannel? _matchesSubscription;
  int _loadVersion = 0;
  String? _realtimeUserId;

  bool get _isRealMode => SupabaseService.isInitialized;

  // ── DB Loading & Realtime ─────────────────────────────────

  Future<void> loadConversations() async {
    final loadVersion = ++_loadVersion;
    if (!_isRealMode) {
      emit(state.copyWith(conversations: const [], isLoading: false));
      return;
    }

    emit(state.copyWith(isLoading: true));
    try {
      final me = SupabaseService.currentUserId;
      if (me == null) {
        if (_isCurrentLoad(loadVersion)) {
          emit(state.copyWith(isLoading: false));
        }
        return;
      }

      // Fetch user's messaging_suspended_until
      final userRow = await SupabaseService.client
          .from('users')
          .select('messaging_suspended_until')
          .eq('id', me)
          .maybeSingle();

      DateTime? suspendedUntil;
      if (userRow != null && userRow['messaging_suspended_until'] != null) {
        suspendedUntil =
            DateTime.tryParse(userRow['messaging_suspended_until'] as String)
                ?.toLocal();
      }
      if (!_isCurrentLoad(loadVersion)) return;

      // Fetch matches where current user is participant
      final matches = await SupabaseService.client
          .from('matches')
          .select('id, user_a, user_b, status, closure_reason')
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

        final matchName = profile != null
            ? (profile['first_name'] as String? ?? 'User')
            : 'User';
        final lastName =
            profile != null ? (profile['last_name'] as String? ?? '') : '';
        final matchLastInitial = lastName.isNotEmpty ? lastName[0] : '';

        // Fetch messages for this match
        final messagesData = await SupabaseService.client
            .from('messages')
            .select('id, sender_id, content, created_at, read_at, translations')
            .eq('match_id', matchId)
            .order('created_at', ascending: true);

        final parseResult = await compute(
          parseMessagesInBackground,
          MessagesParseInput(messagesData: messagesData, myUserId: me),
        );
        final chatMessages = parseResult.chatMessages;
        final unreadCount = parseResult.unreadCount;

        loaded.add(Conversation(
          id: matchId,
          matchName: matchName,
          matchLastInitial: matchLastInitial,
          messages: chatMessages,
          unreadCount: unreadCount,
          matchId: matchId,
          otherUserId: otherUserId,
          isMatchClosed: status == 'closed' ||
              status == 'expired' ||
              status == 'blocked' ||
              status == 'reported',
          closureMessage: closureReason,
        ));
      }

      if (!_isCurrentLoad(loadVersion)) return;
      emit(state.copyWith(
        conversations: _mergeLoadedConversations(state.conversations, loaded),
        isLoading: false,
        messagingSuspendedUntil: suspendedUntil,
      ));
      _setupRealtime();
    } catch (e) {
      debugPrint('ChatCubit: Error loading conversations: $e');
      if (_isCurrentLoad(loadVersion)) emit(state.copyWith(isLoading: false));
    }
  }

  void _setupRealtime() {
    final me = SupabaseService.currentUserId;
    if (me == null) return;
    if (_realtimeUserId == me &&
        _messagesSubscription != null &&
        _matchesSubscription != null) {
      return;
    }

    _disposeRealtime();
    _realtimeUserId = me;

    // Subscribe to new incoming messages/updates where I am the receiver
    _messagesSubscription = SupabaseService.client
        .channel('chat_messages')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'receiver_id',
            value: me,
          ),
          callback: (payload) {
            final event = payload.eventType;
            final newRecord = payload.newRecord;
            if (event == PostgresChangeEvent.insert) {
              final matchId = newRecord['match_id'] as String?;
              final senderId = newRecord['sender_id'] as String?;
              final content = newRecord['content'] as String? ?? '';
              final msgId = newRecord['id'] as String?;
              final createdAtStr = newRecord['created_at'] as String?;

              if (matchId != null &&
                  senderId != null &&
                  msgId != null &&
                  createdAtStr != null) {
                if (senderId != me) {
                  final sentAt = DateTime.tryParse(createdAtStr)?.toLocal() ??
                      DateTime.now();
                  final chatMessage = ChatMessage(
                    id: msgId,
                    text: content,
                    sentAt: sentAt,
                    isMe: false,
                    status: MessageStatus.delivered,
                  );
                  _appendIncomingMessage(matchId, chatMessage);
                }
              }
            } else if (event == PostgresChangeEvent.update) {
              final matchId = newRecord['match_id'] as String?;
              final msgId = newRecord['id'] as String?;
              final readAt = newRecord['read_at'];
              if (matchId != null && msgId != null && readAt != null) {
                _updateMessageStatus(matchId, msgId, MessageStatus.read);
              }
            } else {
              unawaited(loadConversations());
            }
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
            unawaited(loadConversations());
          },
        )
        .subscribe();
  }

  void _disposeRealtime() {
    _messagesSubscription?.unsubscribe();
    _matchesSubscription?.unsubscribe();
    _messagesSubscription = null;
    _matchesSubscription = null;
    _realtimeUserId = null;
  }

  @override
  Future<void> close() {
    _disposeRealtime();
    return super.close();
  }

  // ── Public API ────────────────────────────────────────────

  Future<String> openOrCreateConversation(
      String otherUserId, String matchName, String lastInitial) async {
    final existing = state.conversations.where((c) {
      if (c.otherUserId != null && c.otherUserId == otherUserId) {
        return true;
      }
      if (c.otherUserId == null &&
          c.matchName.toLowerCase() == matchName.toLowerCase()) {
        return true;
      }
      return false;
    });
    if (existing.isNotEmpty) return existing.first.id;

    if (_isRealMode) {
      // In real mode, matches are created via accepted interests, not manually.
      // 1. Try reloading conversations first in case the realtime sync didn't complete yet
      await loadConversations().timeout(const Duration(seconds: 5));
      final existingAfterLoad = state.conversations.where((c) {
        if (c.otherUserId != null && c.otherUserId == otherUserId) {
          return true;
        }
        if (c.otherUserId == null &&
            c.matchName.toLowerCase() == matchName.toLowerCase()) {
          return true;
        }
        return false;
      });
      if (existingAfterLoad.isNotEmpty) return existingAfterLoad.first.id;

      // 2. Fetch matches from database directly
      final me = SupabaseService.currentUserId;
      if (me != null) {
        try {
          final matchRow = await SupabaseService.client
              .from('matches')
              .select('id')
              .or('and(user_a.eq.$me,user_b.eq.$otherUserId),and(user_a.eq.$otherUserId,user_b.eq.$me)')
              .maybeSingle()
              .timeout(const Duration(seconds: 5));

          if (matchRow != null) {
            // Reload conversations so state holds this conversation
            await loadConversations().timeout(const Duration(seconds: 5));
            return matchRow['id'] as String;
          }
        } catch (e) {
          debugPrint(
              'ChatCubit: Error finding match by otherUserId in real mode: $e');
        }
      }
      return '';
    }

    return '';
  }

  Future<void> sendMessage(String conversationId, String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    if (state.isSuspended) return;

    final conv =
        state.conversations.where((c) => c.id == conversationId).firstOrNull;
    if (conv?.isMatchClosed == true) return;

    final validationError = ContentFilter.validate(trimmed);
    final hasViolation = validationError != null;
    final isUrl = trimmed.contains(RegExp(r'(https?://|www\.)\S+'));

    if (hasViolation) {
      final currentViolations =
          (state.violationCounts[conversationId] ?? 0) + 1;
      final updatedViolations = Map<String, int>.from(state.violationCounts)
        ..[conversationId] = currentViolations;

      DateTime? suspendedUntil;
      if (currentViolations >= 3) {
        suspendedUntil = DateTime.now().add(const Duration(hours: 24));
        if (_isRealMode) {
          try {
            final me = SupabaseService.currentUserId;
            if (me != null) {
              await SupabaseService.client.from('users').update({
                'messaging_suspended_until':
                    suspendedUntil.toUtc().toIso8601String()
              }).eq('id', me);
            }
          } catch (e) {
            debugPrint('ChatCubit: Error suspending user: $e');
          }
        }
      }

      emit(state.copyWith(
        violationCounts: updatedViolations,
        messagingSuspendedUntil:
            suspendedUntil ?? state.messagingSuspendedUntil,
      ));

      if (isUrl) {
        _msgCounter++;
        final tempMsgId = 'msg_$_msgCounter';
        final failedMsg = ChatMessage(
          id: tempMsgId,
          text: '[link blocked - safety violation]',
          sentAt: DateTime.now(),
          isMe: true,
          status: MessageStatus.failed,
        );
        _appendMessage(conversationId, failedMsg);
        return;
      }
    }

    final filtered = ContentFilter.redact(trimmed);
    if (!_isRealMode) return;

    _msgCounter++;
    final tempMsgId = 'msg_$_msgCounter';
    final sent = ChatMessage(
      id: tempMsgId,
      text: filtered,
      sentAt: DateTime.now(),
      isMe: true,
      status: MessageStatus.queued,
    );

    _appendMessage(conversationId, sent);

    final me = SupabaseService.currentUserId;
    if (me == null) return;

    final receiverId = conv?.otherUserId;
    if (receiverId == null) {
      debugPrint(
          'ChatCubit: Error sending message: otherUserId not cached on conversation');
      _updateMessageStatus(conversationId, tempMsgId, MessageStatus.failed);
      return;
    }

    try {
      final insertedData = await SupabaseService.client
          .from('messages')
          .insert({
            'match_id': conversationId,
            'sender_id': me,
            'receiver_id': receiverId,
            'content': filtered,
          })
          .select('id, created_at')
          .single()
          .timeout(const Duration(seconds: 10));

      final realMsgId = insertedData['id'] as String;
      final createdAtStr = insertedData['created_at'] as String;
      final sentAt =
          DateTime.tryParse(createdAtStr)?.toLocal() ?? DateTime.now();

      _updateLocalMessageDetails(
          conversationId, tempMsgId, realMsgId, sentAt, MessageStatus.sent);
    } catch (e) {
      debugPrint('ChatCubit: Error sending message: $e');
      _updateMessageStatus(conversationId, tempMsgId, MessageStatus.failed);
    }
  }

  Future<void> markRead(String conversationId) async {
    final exists = state.conversations.any((c) => c.id == conversationId);
    if (!exists) return;

    final me = SupabaseService.currentUserId;
    if (!_isRealMode || me == null) return;

    try {
      await SupabaseService.client
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
    if (!_isRealMode) return;

    _msgCounter++;
    final closureMsg = ChatMessage(
      id: 'msg_$_msgCounter',
      text: message,
      sentAt: DateTime.now(),
      isMe: true,
      status: MessageStatus.sent,
    );

    final updated = state.conversations.map((c) {
      if (c.id != conversationId) return c;
      return c.copyWith(
        messages: [...c.messages, closureMsg],
        isMatchClosed: true,
        closureMessage: message,
      );
    }).toList();
    emit(state.copyWith(conversations: updated));

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
      await SupabaseService.client.from('matches').update({
        'status': 'closed',
        'closed_by': me,
        'closed_at': DateTime.now().toIso8601String(),
        'closure_reason': message,
      }).eq('id', conversationId);

      await loadConversations();
    } catch (e) {
      debugPrint('ChatCubit: Error closing match: $e');
    }
  }

  // ── Internal helpers ──────────────────────────────────────

  void _appendMessage(String convId, ChatMessage msg) {
    final updated = state.conversations.map((c) {
      if (c.id != convId) return c;
      return c.copyWith(messages: _mergeMessagesById(c.messages, [msg]));
    }).toList();
    emit(state.copyWith(conversations: updated));
  }

  bool _isCurrentLoad(int loadVersion) =>
      !isClosed && loadVersion == _loadVersion;

  List<Conversation> _mergeLoadedConversations(
    List<Conversation> current,
    List<Conversation> loaded,
  ) {
    final currentById = {for (final c in current) c.id: c};
    final loadedIds = loaded.map((c) => c.id).toSet();
    final merged = <Conversation>[
      for (final fresh in loaded)
        _mergeConversation(currentById[fresh.id], fresh),
      // Keep optimistic local conversations that the backend load does not yet
      // know about instead of letting a stale load delete them.
      for (final existing in current)
        if (!loadedIds.contains(existing.id)) existing,
    ];
    return merged;
  }

  Conversation _mergeConversation(Conversation? current, Conversation loaded) {
    if (current == null) return loaded;
    return loaded.copyWith(
      messages: _mergeMessagesById(current.messages, loaded.messages),
      unreadCount: loaded.unreadCount,
      isMatchClosed: loaded.isMatchClosed,
      closureMessage: loaded.closureMessage,
    );
  }

  List<ChatMessage> _mergeMessagesById(
    List<ChatMessage> current,
    List<ChatMessage> incoming,
  ) {
    final byId = <String, ChatMessage>{for (final m in current) m.id: m};
    for (final message in incoming) {
      byId[message.id] = message;
    }
    final merged = byId.values.toList()
      ..sort((a, b) => a.sentAt.compareTo(b.sentAt));
    return merged;
  }

  void _updateMessageStatus(String convId, String msgId, MessageStatus status) {
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

  void _updateLocalMessageDetails(String convId, String tempMsgId,
      String realMsgId, DateTime sentAt, MessageStatus status) {
    if (isClosed) return;
    final updated = state.conversations.map((c) {
      if (c.id != convId) return c;
      final msgs = c.messages.map((m) {
        if (m.id != tempMsgId) return m;
        return ChatMessage(
          id: realMsgId,
          text: m.text,
          sentAt: sentAt,
          isMe: m.isMe,
          status: status,
          sentByGuardian: m.sentByGuardian,
          translations: m.translations,
          isTimestampVisible: m.isTimestampVisible,
        );
      }).toList();
      return c.copyWith(messages: msgs);
    }).toList();
    emit(state.copyWith(conversations: updated));
  }

  void _appendIncomingMessage(String convId, ChatMessage msg) {
    if (isClosed) return;
    final updated = state.conversations.map((c) {
      if (c.id != convId) return c;
      final alreadyPresent = c.messages.any((m) => m.id == msg.id);
      return c.copyWith(
        messages: _mergeMessagesById(c.messages, [msg]),
        unreadCount: alreadyPresent ? c.unreadCount : c.unreadCount + 1,
      );
    }).toList();
    emit(state.copyWith(conversations: updated));
  }

  // ── Translation ────────────────────────────────────────────

  Future<void> translateMessage(
      String conversationId, String messageId, String targetLang) async {
    final convIndex =
        state.conversations.indexWhere((c) => c.id == conversationId);
    if (convIndex == -1) return;

    final conv = state.conversations[convIndex];
    final msgIndex = conv.messages.indexWhere((m) => m.id == messageId);
    if (msgIndex == -1) return;

    final msg = conv.messages[msgIndex];

    // Check if translation is already present locally
    if (msg.translations.containsKey(targetLang)) {
      return;
    }

    if (!_isRealMode) return;

    try {
      // Fetch message translations from Supabase to check if cached in DB
      final response = await SupabaseService.client
          .from('messages')
          .select('translations')
          .eq('id', messageId)
          .single();

      final dbTranslations =
          Map<String, dynamic>.from(response['translations'] ?? {});

      if (dbTranslations.containsKey(targetLang)) {
        _updateMessageTranslations(conversationId, messageId, dbTranslations);
        return;
      }

      // Call the Translation Service to translate content
      final translated = await TranslationService.instance.translate(
        text: msg.text,
        targetLang: targetLang,
      );

      if (translated != null) {
        dbTranslations[targetLang] = translated;
        await SupabaseService.client
            .from('messages')
            .update({'translations': dbTranslations}).eq('id', messageId);

        _updateMessageTranslations(conversationId, messageId, dbTranslations);
      }
    } catch (e) {
      debugPrint('ChatCubit: Error translating message in DB: $e');
    }
  }

  void _updateMessageTranslations(
      String convId, String msgId, Map<String, dynamic> translations) {
    if (isClosed) return;
    final updated = state.conversations.map((c) {
      if (c.id != convId) return c;
      final msgs = c.messages.map((m) {
        if (m.id != msgId) return m;
        return m.copyWith(translations: Map<String, String>.from(translations));
      }).toList();
      return c.copyWith(messages: msgs);
    }).toList();
    emit(state.copyWith(conversations: updated));
  }
}
