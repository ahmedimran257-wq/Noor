// lib/core/cubits/chat/chat_cubit.dart
// ============================================================
// SILARAH — Chat Cubit (RPC-backed production flow)
// ============================================================

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/supabase_service.dart';
import '../../services/translation_service.dart';
import 'chat_state.dart';

class ChatCubit extends Cubit<ChatState> {
  ChatCubit() : super(const ChatState());

  static const int _messagePageSize = 30;

  int _msgCounter = 0;
  int _loadVersion = 0;
  bool _inboxLoadInFlight = false;
  DateTime? _lastInboxLoadedAt;
  static const _inboxFreshness = Duration(minutes: 2);
  final Set<String> _messageLoadsInFlight = {};
  final Set<String> _exhaustedMessagePages = {};

  static const Duration _typingRefreshInterval = Duration(milliseconds: 1400);
  static const Duration _localTypingIdleTimeout = Duration(milliseconds: 2200);
  static const Duration _remoteTypingExpiry = Duration(milliseconds: 4200);

  RealtimeChannel? _activeChatSubscription;
  String? _realtimeUserId;
  String? _activeConversationId;
  String? _loadedUserId;
  Timer? _localTypingIdleTimer;
  Timer? _remoteTypingExpiryTimer;
  DateTime? _lastTypingBroadcastAt;
  bool _localTypingActive = false;

  bool get _isRealMode => SupabaseService.isInitialized;

  Future<void> loadConversations({
    bool showLoading = true,
    bool force = false,
  }) async {
    if (_inboxLoadInFlight) return;
    final me = SupabaseService.currentUserId;
    final lastLoadedAt = _lastInboxLoadedAt;
    if (!force &&
        me != null &&
        _loadedUserId == me &&
        lastLoadedAt != null &&
        DateTime.now().difference(lastLoadedAt) < _inboxFreshness) {
      return;
    }
    _inboxLoadInFlight = true;
    final loadVersion = ++_loadVersion;
    if (!_isRealMode) {
      emit(state.copyWith(conversations: const [], isLoading: false));
      _inboxLoadInFlight = false;
      return;
    }

    if (showLoading) {
      emit(state.copyWith(isLoading: true));
    }
    try {
      final me = SupabaseService.currentUserId;
      if (me == null) {
        if (_isCurrentLoad(loadVersion)) {
          clear();
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

      if (!_isCurrentLoad(loadVersion) || SupabaseService.currentUserId != me) {
        return;
      }

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
      _loadedUserId = me;
      _lastInboxLoadedAt = DateTime.now();
    } catch (e) {
      debugPrint('ChatCubit: Error loading conversations: $e');
      if (_isCurrentLoad(loadVersion)) emit(state.copyWith(isLoading: false));
    } finally {
      _inboxLoadInFlight = false;
    }
  }

  Future<void> loadMessages(
    String conversationId, {
    bool older = false,
  }) async {
    if (!_isRealMode) return;
    if (_messageLoadsInFlight.contains(conversationId)) return;
    if (older && _exhaustedMessagePages.contains(conversationId)) return;

    var conv = _findConversation(conversationId);
    if (conv == null) {
      await loadConversations(force: true);
      conv = _findConversation(conversationId);
      if (conv == null) return;
    }
    _subscribeToActiveChat(conversationId);

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
      if (_loadedUserId != null && _loadedUserId != me) return;

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
    await loadConversations(force: true).timeout(const Duration(seconds: 5));
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
        unawaited(loadConversations(force: true));
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

    final conv = _findConversation(conversationId);
    if (conv == null || conv.isMatchClosed) return;

    try {
      await sendMessage(conversationId, message);
      await SupabaseService.client.rpc(
        'close_chat_match',
        params: {
          'p_match_id': conversationId,
          'p_closure_reason': message,
        },
      );
      await loadConversations(force: true);
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

  /// Publishes ephemeral typing presence to the currently open private chat.
  /// Keystrokes and message content are never included in this payload.
  void updateTyping(String conversationId, {required bool isTyping}) {
    if (_activeConversationId != conversationId ||
        _activeChatSubscription == null ||
        SupabaseService.currentUserId == null) {
      return;
    }

    _localTypingIdleTimer?.cancel();
    if (!isTyping) {
      if (_localTypingActive) _sendTypingBroadcast(false);
      return;
    }

    final now = DateTime.now();
    final shouldRefresh = !_localTypingActive ||
        _lastTypingBroadcastAt == null ||
        now.difference(_lastTypingBroadcastAt!) >= _typingRefreshInterval;
    if (shouldRefresh) _sendTypingBroadcast(true);

    _localTypingIdleTimer = Timer(
      _localTypingIdleTimeout,
      () => _sendTypingBroadcast(false),
    );
  }

  void leaveConversation(String conversationId) {
    if (_activeConversationId != conversationId) return;
    _disposeRealtime();
  }

  void clear() {
    _loadVersion++;
    _messageLoadsInFlight.clear();
    _exhaustedMessagePages.clear();
    _loadedUserId = null;
    _lastInboxLoadedAt = null;
    _inboxLoadInFlight = false;
    _disposeRealtime();
    if (!isClosed) emit(const ChatState());
  }

  void _subscribeToActiveChat(String conversationId) {
    final me = SupabaseService.currentUserId;
    if (me == null) return;
    if (_realtimeUserId == me &&
        _activeConversationId == conversationId &&
        _activeChatSubscription != null) {
      return;
    }

    _disposeRealtime();
    _realtimeUserId = me;
    _activeConversationId = conversationId;

    // Scale guard: realtime is scoped to the currently open chat only.
    // Inbox state is refreshed through get_chat_inbox RPC and background
    // notifications, avoiding broad per-user message/match subscriptions.
    _activeChatSubscription = SupabaseService.client
        .channel(
          'chat:$conversationId',
          opts: const RealtimeChannelConfig(private: true, ack: true),
        )
        .onBroadcast(
          event: 'typing',
          callback: (payload) =>
              _handleTypingBroadcast(payload, conversationId, me),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'match_id',
            value: conversationId,
          ),
          callback: (payload) => _handleMessageRealtime(payload, me),
        )
        .subscribe();
  }

  void _sendTypingBroadcast(bool isTyping) {
    final channel = _activeChatSubscription;
    final conversationId = _activeConversationId;
    final me = SupabaseService.currentUserId;
    if (channel == null || conversationId == null || me == null) return;
    if (!isTyping && !_localTypingActive) return;

    _localTypingActive = isTyping;
    _lastTypingBroadcastAt = DateTime.now();
    unawaited(
      channel.sendBroadcastMessage(
        event: 'typing',
        payload: {
          'user_id': me,
          'is_typing': isTyping,
          'sent_at': _lastTypingBroadcastAt!.toUtc().toIso8601String(),
        },
      ).then((response) {
        if (response != ChannelResponse.ok) {
          debugPrint('ChatCubit: typing broadcast was not acknowledged');
        }
      }).catchError((Object error) {
        debugPrint('ChatCubit: typing broadcast failed: $error');
      }),
    );
  }

  void _handleTypingBroadcast(
    Map<String, dynamic> payload,
    String conversationId,
    String me,
  ) {
    // Realtime client versions may expose the broadcast body directly or
    // under `payload`; accepting both keeps presence compatible across SDK
    // upgrades without weakening the participant-only channel policy.
    final eventPayload = payload['payload'] is Map
        ? Map<String, dynamic>.from(payload['payload'] as Map)
        : payload;
    if (eventPayload['user_id'] == me) return;
    final isTyping = eventPayload['is_typing'] == true;
    _remoteTypingExpiryTimer?.cancel();
    _setRemoteTyping(conversationId, isTyping);
    if (isTyping) {
      _remoteTypingExpiryTimer = Timer(
        _remoteTypingExpiry,
        () => _setRemoteTyping(conversationId, false),
      );
    }
  }

  void _setRemoteTyping(String conversationId, bool isTyping) {
    if (isClosed) return;
    final next = Set<String>.from(state.typingConversationIds);
    isTyping ? next.add(conversationId) : next.remove(conversationId);
    if (setEquals(next, state.typingConversationIds)) return;
    emit(state.copyWith(typingConversationIds: next));
  }

  void _handleMessageRealtime(PostgresChangePayload payload, String me) {
    final record = payload.newRecord;
    final matchId = record['match_id'] as String?;
    if (matchId == null) {
      return;
    }

    if (payload.eventType == PostgresChangeEvent.insert) {
      _appendMessage(matchId, _messageFromRow(record, me));
      if (record['receiver_id'] == me) {
        unawaited(markRead(matchId));
      }
      return;
    }

    if (payload.eventType == PostgresChangeEvent.update) {
      final messageId = record['id'] as String?;
      if (messageId == null) return;
      final status = _messageStatusFromRow(record, record['sender_id'] == me);
      _updateMessageStatus(matchId, messageId, status);
      return;
    }

    unawaited(loadMessages(matchId));
  }

  void _disposeRealtime() {
    if (_localTypingActive) _sendTypingBroadcast(false);
    _localTypingIdleTimer?.cancel();
    _remoteTypingExpiryTimer?.cancel();
    _localTypingIdleTimer = null;
    _remoteTypingExpiryTimer = null;
    _localTypingActive = false;
    _lastTypingBroadcastAt = null;
    if (_activeConversationId != null) {
      _setRemoteTyping(_activeConversationId!, false);
    }
    _activeChatSubscription?.unsubscribe();
    _activeChatSubscription = null;
    _realtimeUserId = null;
    _activeConversationId = null;
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
