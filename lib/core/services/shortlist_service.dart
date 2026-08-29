import 'supabase_service.dart';

enum ShortlistCategory {
  saved('saved'),
  strongMatch('strong_match'),
  discussWithFamily('discuss_with_family'),
  followUp('follow_up');

  const ShortlistCategory(this.serverValue);
  final String serverValue;

  static ShortlistCategory fromServer(String? value) => values.firstWhere(
        (item) => item.serverValue == value,
        orElse: () => ShortlistCategory.saved,
      );
}

class ShortlistDetail {
  const ShortlistDetail({
    required this.savedUserId,
    required this.category,
    this.privateNote,
    this.remindAt,
    this.reminderSentAt,
    this.updatedAt,
  });

  factory ShortlistDetail.fromJson(Map<String, dynamic> json) =>
      ShortlistDetail(
        savedUserId: json['saved_user_id']?.toString() ?? '',
        category: ShortlistCategory.fromServer(json['list_key']?.toString()),
        privateNote: _nullableText(json['private_note']),
        remindAt: _date(json['remind_at']),
        reminderSentAt: _date(json['reminder_sent_at']),
        updatedAt: _date(json['updated_at']),
      );

  final String savedUserId;
  final ShortlistCategory category;
  final String? privateNote;
  final DateTime? remindAt;
  final DateTime? reminderSentAt;
  final DateTime? updatedAt;

  bool get hasPendingReminder =>
      remindAt != null &&
      reminderSentAt == null &&
      remindAt!.isAfter(DateTime.now());
}

class ShortlistService {
  ShortlistService._();

  static final instance = ShortlistService._();
  static const _freshness = Duration(minutes: 5);

  String? _cachedUserId;
  Map<String, ShortlistDetail>? _cached;
  DateTime? _cachedAt;
  Future<Map<String, ShortlistDetail>>? _loadInFlight;
  Future<void> _writeQueue = Future<void>.value();

  Future<Map<String, ShortlistDetail>> load({bool force = false}) async {
    final userId = await SupabaseService.currentUserIdOrRefresh();
    if (!SupabaseService.isInitialized || userId == null) {
      throw StateError('Please sign in again to load your shortlist.');
    }
    if (_cachedUserId != userId) clearCache();
    final cachedAt = _cachedAt;
    if (!force &&
        _cached != null &&
        cachedAt != null &&
        DateTime.now().difference(cachedAt) < _freshness) {
      return Map<String, ShortlistDetail>.from(_cached!);
    }
    final active = _loadInFlight;
    if (active != null && _cachedUserId == userId) return active;
    _cachedUserId = userId;
    final request = _loadFromServer(userId);
    _loadInFlight = request;
    try {
      return await request;
    } finally {
      if (identical(_loadInFlight, request)) _loadInFlight = null;
    }
  }

  Future<Map<String, ShortlistDetail>> _loadFromServer(String userId) async {
    final raw =
        await SupabaseService.client.rpc('get_my_premium_shortlist_details');
    final details = <String, ShortlistDetail>{};
    if (raw is List) {
      for (final item in raw.whereType<Map>()) {
        final mapped = Map<String, dynamic>.from(item);
        final nested = mapped.length == 1
            ? mapped['get_my_premium_shortlist_details']
            : null;
        final detail = ShortlistDetail.fromJson(
          nested is Map ? Map<String, dynamic>.from(nested) : mapped,
        );
        if (detail.savedUserId.isNotEmpty) {
          details[detail.savedUserId] = detail;
        }
      }
    }
    _cachedUserId = userId;
    _cached = details;
    _cachedAt = DateTime.now();
    return Map<String, ShortlistDetail>.from(details);
  }

  Future<ShortlistDetail> save({
    required String savedUserId,
    required ShortlistCategory category,
    String? privateNote,
    DateTime? remindAt,
  }) {
    final operation = _writeQueue.then((_) async {
      final userId = await SupabaseService.currentUserIdOrRefresh();
      if (!SupabaseService.isInitialized || userId == null) {
        throw StateError('Please sign in again to update your shortlist.');
      }
      final raw = await SupabaseService.client.rpc(
        'save_my_premium_shortlist_detail',
        params: {
          'p_saved_user_id': savedUserId,
          'p_list_key': category.serverValue,
          'p_private_note': privateNote,
          'p_remind_at': remindAt?.toUtc().toIso8601String(),
        },
      );
      if (raw is! Map) {
        throw StateError('Your shortlist could not be updated.');
      }
      final detail = ShortlistDetail.fromJson(Map<String, dynamic>.from(raw));
      _cachedUserId = userId;
      _cached = {...?_cached, savedUserId: detail};
      _cachedAt = DateTime.now();
      return detail;
    });
    _writeQueue = operation.then<void>((_) {}, onError: (_, __) {});
    return operation;
  }

  Future<void> clear(String savedUserId) {
    final operation = _writeQueue.then((_) async {
      await SupabaseService.client.rpc(
        'clear_my_premium_shortlist_detail',
        params: {'p_saved_user_id': savedUserId},
      );
      _cached?.remove(savedUserId);
      _cachedAt = DateTime.now();
    });
    _writeQueue = operation.then<void>((_) {}, onError: (_, __) {});
    return operation;
  }

  void clearCache() {
    _cachedUserId = null;
    _cached = null;
    _cachedAt = null;
    _loadInFlight = null;
  }
}

DateTime? _date(dynamic value) {
  final parsed = DateTime.tryParse(value?.toString() ?? '');
  return parsed?.toLocal();
}

String? _nullableText(dynamic value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}
