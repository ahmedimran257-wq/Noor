import 'chat_state.dart';

ChatMessage? oldestPersistedChatMessage(List<ChatMessage> messages) =>
    messages.where((m) => !m.id.startsWith('local_')).firstOrNull;

List<ChatMessage> mergeChatMessagesById(
  List<ChatMessage> current,
  List<ChatMessage> incoming,
) {
  final byId = <String, ChatMessage>{
    for (final message in current) message.id: message
  };
  for (final message in incoming) {
    byId[message.id] = message;
  }
  return byId.values.toList()
    ..sort((a, b) {
      final byTime = a.sentAt.compareTo(b.sentAt);
      return byTime != 0 ? byTime : a.id.compareTo(b.id);
    });
}

/// A latest-page recovery must not join disconnected history segments: the
/// older-page cursor would then skip the gap forever. Reset to the latest
/// bounded window when it no longer overlaps the saved server messages.
({List<ChatMessage> messages, bool olderExhausted}) reconcileChatMessagePage({
  required List<ChatMessage> current,
  required List<ChatMessage> incoming,
  required bool older,
  required bool wasExhausted,
  required int pageSize,
  String? lastFetchedMessageId,
}) {
  final incomingIds = incoming.map((m) => m.id).toSet();
  // Only a previous authoritative page proves continuity. A freshly received
  // live event or inbox preview can overlap the latest page despite an older gap.
  final overlaps = lastFetchedMessageId != null &&
      incomingIds.contains(lastFetchedMessageId);
  final reset = !older && (incoming.length < pageSize || !overlaps);
  final base = reset
      ? current.where((m) => m.id.startsWith('local_')).toList()
      : current;
  return (
    messages: mergeChatMessagesById(base, incoming),
    olderExhausted: incoming.length < pageSize || (!reset && wasExhausted),
  );
}
