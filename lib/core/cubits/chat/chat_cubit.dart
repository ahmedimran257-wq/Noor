// lib/core/cubits/chat/chat_cubit.dart
// ============================================================
// MITHAQ — Chat Cubit (RPC-backed production flow)
// ============================================================

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/supabase_service.dart';
import '../../services/translation_service.dart';
import 'chat_state.dart';

class ChatCubit extends Cubit<ChatState> {
  ChatCubit() : super(const ChatState()) {
    unawaited(loadConversations());
  }

  static const int _messagePageSize = 50;

  int _msgCounter = 0;
  int _loadVersion = 0;
  final Set<String> _messageLoadsInFlight = {};
  final Set<String> _exhaustedMessagePages = {};

  RealtimeChannel? _incomingMessagesSubscription;
  RealtimeChannel? _sentMessagesSubscription;
  RealtimeChannel? _matchesSubscription;
  String? _realtimeUserId;

  bool get _isRealMode => SupabaseService.isInitialized;

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

      final results = await Future.wait<dynamic>([
        SupabaseService.client
            .from('users')
            .select('messaging_suspended_until')
            .eq('id', me)
            .maybeSingle(),
        SupabaseService.client.rpc(
          'get_chat_inbox',
          params: {'p_limit': 50},
        ),
      ]);

      if (!_isCurrentLoad(loadVersion)) return;

      final userRow = results[0] as Map<String, dynamic>?;
      final inboxRows = _asRows(results[1]);
      final suspendedUntil = _parseDate(userRow?['messaging_suspended_until']);
      final loaded =
          inboxRows.map((row) => _conversationFromInbox(row, me)).toList();

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

  Future<void> loadMessages(
    String conversationId, {
    bool older = false,
  }) async {
    if (!_isRealMode) return;
    if (_messageLoadsInFlight.contains(conversationId)) return;
    if (older && _exhaustedMessagePages.contains(conversationId)) return;

    final conv = _findConversation(conversationId);
    if (conv == null) return;

    _messageLoadsInFlight.add(conversationId);
    try {
      final before = older && conv.messages.isNotEmpty
          ? conv.messages.first.sentAt.toUtc().toIso8601String()
          : null;
      final rows = _asRows(await SupabaseService.client.rpc(
        'get_chat_messages',
        params: {
          'p_match_id': conversationId,
          'p_limit': _messagePageSize,
          if (before != null) 'p_before': before,
        },
      ));

      if (rows.length < _messagePageSize) {
        _exhaustedMessagePages.add(conversationId);
      }

      final me = SupabaseService.currentUserId;
      if (me == null || isClosed) return;

      final messages = rows.map((row) => _messageFromRow(row, me)).toList();
      final updated = state.conversations.map((c) {
        if (c.id != conversationId) return c;
        return c.copyWith(messages: _mergeMessagesById(c.messages, messages));
      }).toList();
      emit(state.copyWith(conversations: updated));
    } catch (e) {
      debugPrint('ChatCubit: Error loading messages: $e');
    } finally {
      _messageLoadsInFlight.remove(conversationId);
    }
  }

  Future<String> openOrCreateConversation(
    String otherUserId,
    String matchName,
    String lastInitial,
  ) async {
    final existing = state.conversations.where((c) {
      if (c.otherUserId != null && c.otherUserId == otherUserId) return true;
      return c.otherUserId == null &&
          c.matchName.toLowerCase() == matchName.toLowerCase();
    });
    if (existing.isNotEmpty) return existing.first.id;

    if (!_isRealMode) return '';
    await loadConversations().timeout(const Duration(seconds: 5));
    final afterLoad =
        state.conversations.where((c) => c.otherUserId == otherUserId);
    return afterLoad.isNotEmpty ? afterLoad.first.id : '';
  }

  Future<void> sendMessage(String conversationId, String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.isSuspended) return;

    final conv = _findConversation(conversationId);
    if (conv == null || conv.isMatchClosed || !_isRealMode) return;

    _msgCounter++;
    final tempMsgId = 'local_$_msgCounter';
    final localMsg = ChatMessage(
      id: tempMsgId,
      text: trimmed,
      sentAt: DateTime.now(),
      isMe: true,
      status: MessageStatus.queued,
    );
    _appendMessage(conversationId, localMsg);

    try {
      final rows = _asRows(await SupabaseService.client.rpc(
        'send_chat_message',
        params: {
          'p_match_id': conversationId,
          'p_content': trimmed,
        },
      ));

      final row = rows.isNotEmpty ? rows.first : const <String, dynamic>{};
      final realId = row['message_id']?.toString();
      final createdAt = _parseDate(row['created_at']) ?? DateTime.now();
      if (realId == null) {
        _updateMessageStatus(conversationId, tempMsgId, MessageStatus.failed);
        return;
      }

      _replaceQueuedMessage(
        conversationId,
        tempMsgId,
        ChatMessage(
          id: realId,
          text: trimmed,
          sentAt: createdAt,
          isMe: true,
          status: MessageStatus.sent,
        ),
      );
    } catch (e) {
      debugPrint('ChatCubit: Error sending message: $e');
      _updateMessageStatus(conversationId, tempMsgId, MessageStatus.failed);
      if (_isSafetyBlock(e)) {
        unawaited(loadConversations());
      }
    }
  }

  Future<void> markRead(String conversationId) async {
    if (!_isRealMode || !_conversationExists(conversationId)) return;
    try {
      await SupabaseService.client.rpc(
        'mark_chat_read',
        params: {'p_match_id': conversationId},
      );
      final updated = state.conversations.map((c) {
        if (c.id != conversationId) return c;
        final messages = c.messages.map((m) {
          if (m.isMe) return m;
          return m.copyWith(status: MessageStatus.read);
        }).toList();
        return c.copyWith(messages: messages, unreadCount: 0);
      }).toList();
      emit(state.copyWith(conversations: updated));
    } catch (e) {
      debugPrint('ChatCubit: Error marking read: $e');
    }
  }

  Future<void> reportMessage(
    String conversationId,
    String messageId,
    String reason, {
    String? description,
  }) async {
    if (!_isRealMode || !_conversationExists(conversationId)) return;
    await SupabaseService.client.rpc(
      'report_chat_message',
      params: {
        'p_message_id': messageId,
        'p_reason': reason,
        'p_description': description,
      },
    );
  }

  Future<void> blockUser(String conversationId, {String? reason}) async {
    if (!_isRealMode) return;
    final conv = _findConversation(conversationId);
    final otherUserId = conv?.otherUserId;
    if (conv == null || otherUserId == null) return;

    await SupabaseService.client.rpc(
      'block_chat_user',
      params: {
        'p_user_id': otherUserId,
        'p_reason': reason,
      },
    );

    final updated = state.conversations.map((c) {
      if (c.id != conversationId) return c;
      return c.copyWith(
        isMatchClosed: true,
        closureMessage: 'This member has been blocked.',
      );
    }).toList();
    emit(state.copyWith(conversations: updated));
  }

  Future<void> closeMatch(String conversationId, String message) async {
    if (!_isRealMode) return;

    final me = SupabaseService.currentUserId;
    final conv = _findConversation(conversationId);
    if (me == null || conv == null || conv.isMatchClosed) return;

    try {
      await sendMessage(conversationId, message);
      await SupabaseService.client.from('matches').update({
        'status': 'closed',
        'closed_by': me,
        'closed_at': DateTime.now().toUtc().toIso8601String(),
        'closure_reason': message,
      }).eq('id', conversationId);
      await loadConversations();
    } catch (e) {
      debugPrint('ChatCubit: Error closing match: $e');
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

  Future<void> translateMessage(
    String conversationId,
    String messageId,
    String targetLang,
  ) async {
    final conv = _findConversation(conversationId);
    if (conv == null || !_isRealMode) return;
    final message = conv.messages.where((m) => m.id == messageId).firstOrNull;
    if (message == null || message.translations.containsKey(targetLang)) return;

    try {
      final response = await SupabaseService.client
          .from('messages')
          .select('translations')
          .eq('id', messageId)
          .single();
      final dbTranslations =
          Map<String, dynamic>.from(response['translations'] ?? {});

      if (!dbTranslations.containsKey(targetLang)) {
        final translated = await TranslationService.instance.translate(
          text: message.text,
          targetLang: targetLang,
        );
        if (translated == null) return;
        dbTranslations[targetLang] = translated;
        await SupabaseService.client
            .from('messages')
            .update({'translations': dbTranslations}).eq('id', messageId);
      }
      _updateMessageTranslations(conversationId, messageId, dbTranslations);
    } catch (e) {
      debugPrint('ChatCubit: Error translating message in DB: $e');
    }
  }

  void _setupRealtime() {
    final me = SupabaseService.currentUserId;
    if (me == null) return;
    if (_realtimeUserId == me &&
        _incomingMessagesSubscription != null &&
        _sentMessagesSubscription != null &&
        _matchesSubscription != null) {
      return;
    }

    _disposeRealtime();
    _realtimeUserId = me;

    // Receiver stream handles new messages addressed to this user.
    _incomingMessagesSubscription = SupabaseService.client
        .channel('chat_messages_in_$me')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'receiver_id',
            value: me,
          ),
          callback: (payload) => _handleMessageRealtime(payload, me),
        )
        .subscribe();

    // Sender stream keeps delivered/read receipts current for messages sent by
    // this device or another session owned by the same account.
    _sentMessagesSubscription = SupabaseService.client
        .channel('chat_messages_out_$me')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'sender_id',
            value: me,
          ),
          callback: (payload) => _handleMessageRealtime(payload, me),
        )
        .subscribe();

    _matchesSubscription = SupabaseService.client
        .channel('chat_matches_$me')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'matches',
          callback: (_) => unawaited(loadConversations()),
        )
        .subscribe();
  }

  void _handleMessageRealtime(PostgresChangePayload payload, String me) {
    final record = payload.newRecord;
    final matchId = record['match_id'] as String?;
    if (matchId == null) {
      unawaited(loadConversations());
      return;
    }

    if (payload.eventType == PostgresChangeEvent.insert) {
      _appendMessage(matchId, _messageFromRow(record, me));
      return;
    }

    if (payload.eventType == PostgresChangeEvent.update) {
      final messageId = record['id'] as String?;
      if (messageId == null) return;
      final status = _messageStatusFromRow(record, record['sender_id'] == me);
      _updateMessageStatus(matchId, messageId, status);
      return;
    }

    unawaited(loadConversations());
  }

  void _disposeRealtime() {
    _incomingMessagesSubscription?.unsubscribe();
    _sentMessagesSubscription?.unsubscribe();
    _matchesSubscription?.unsubscribe();
    _incomingMessagesSubscription = null;
    _sentMessagesSubscription = null;
    _matchesSubscription = null;
    _realtimeUserId = null;
  }

  @override
  Future<void> close() {
    _disposeRealtime();
    return super.close();
  }

  Conversation _conversationFromInbox(Map<String, dynamic> row, String me) {
    final lastMessageId = row['last_message_id']?.toString();
    final lastMessage = lastMessageId == null
        ? null
        : ChatMessage(
            id: lastMessageId,
            text: row['last_message_content'] as String? ?? '',
            sentAt:
                _parseDate(row['last_message_created_at']) ?? DateTime.now(),
            isMe: row['last_message_sender_id'] == me,
            status: row['last_message_read_at'] != null
                ? MessageStatus.read
                : (row['last_message_sender_id'] == me
                    ? MessageStatus.sent
                    : MessageStatus.delivered),
          );

    final status = row['match_status'] as String? ?? 'active';
    return Conversation(
      id: row['match_id'].toString(),
      matchName: row['other_first_name'] as String? ?? 'Member',
      matchLastInitial: row['other_last_initial'] as String? ?? '',
      messages: lastMessage == null ? const [] : [lastMessage],
      unreadCount: (row['unread_count'] as num?)?.toInt() ?? 0,
      matchId: row['match_id'].toString(),
      otherUserId: row['other_user_id']?.toString(),
      isMatchClosed: status == 'closed' ||
          status == 'expired' ||
          status == 'blocked' ||
          status == 'reported',
      closureMessage: row['closure_reason'] as String?,
    );
  }

  ChatMessage _messageFromRow(Map<String, dynamic> row, String me) {
    final isMe = row['sender_id'] == me;
    final translationsMap = row['translations'] as Map<dynamic, dynamic>? ?? {};
    return ChatMessage(
      id: row['id'].toString(),
      text: row['content'] as String? ?? '',
      sentAt: _parseDate(row['created_at']) ?? DateTime.now(),
      isMe: isMe,
      status: _messageStatusFromRow(row, isMe),
      sentByGuardian: row['sent_by_guardian'] == true,
      translations: translationsMap.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      ),
    );
  }

  MessageStatus _messageStatusFromRow(Map<String, dynamic> row, bool isMe) {
    if (row['read_at'] != null) return MessageStatus.read;
    if (row['delivered_at'] != null) return MessageStatus.delivered;
    final rawStatus = row['status'] as String?;
    if (rawStatus == 'failed') return MessageStatus.failed;
    if (rawStatus == 'queued') return MessageStatus.queued;
    return isMe ? MessageStatus.sent : MessageStatus.delivered;
  }

  void _appendMessage(String convId, ChatMessage msg) {
    if (isClosed) return;
    final updated = state.conversations.map((c) {
      if (c.id != convId) return c;
      final alreadyPresent = c.messages.any((m) => m.id == msg.id);
      return c.copyWith(
        messages: _mergeMessagesById(c.messages, [msg]),
        unreadCount:
            !msg.isMe && !alreadyPresent ? c.unreadCount + 1 : c.unreadCount,
      );
    }).toList();
    emit(state.copyWith(conversations: updated));
  }

  void _replaceQueuedMessage(
    String convId,
    String tempMsgId,
    ChatMessage realMessage,
  ) {
    if (isClosed) return;
    final updated = state.conversations.map((c) {
      if (c.id != convId) return c;
      final withoutTemp = c.messages
          .where((m) => m.id != tempMsgId && m.id != realMessage.id)
          .toList();
      return c.copyWith(
          messages: _mergeMessagesById(withoutTemp, [realMessage]));
    }).toList();
    emit(state.copyWith(conversations: updated));
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

  void _updateMessageTranslations(
    String convId,
    String msgId,
    Map<String, dynamic> translations,
  ) {
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

  List<Conversation> _mergeLoadedConversations(
    List<Conversation> current,
    List<Conversation> loaded,
  ) {
    final currentById = {for (final c in current) c.id: c};
    final loadedIds = loaded.map((c) => c.id).toSet();
    return [
      for (final fresh in loaded)
        _mergeConversation(currentById[fresh.id], fresh),
      for (final existing in current)
        if (!loadedIds.contains(existing.id)) existing,
    ];
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

  bool _isCurrentLoad(int version) => !isClosed && version == _loadVersion;

  bool _conversationExists(String id) =>
      state.conversations.any((c) => c.id == id);

  Conversation? _findConversation(String id) {
    final matches = state.conversations.where((c) => c.id == id);
    return matches.isEmpty ? null : matches.first;
  }

  List<Map<String, dynamic>> _asRows(dynamic value) {
    if (value is List) {
      return value
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
    }
    if (value is Map) return [Map<String, dynamic>.from(value)];
    return const [];
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value.toLocal();
    return DateTime.tryParse(value.toString())?.toLocal();
  }

  bool _isSafetyBlock(Object error) =>
      error.toString().contains('Message blocked by safety rules');
}
