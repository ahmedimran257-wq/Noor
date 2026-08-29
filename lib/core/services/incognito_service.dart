import 'supabase_service.dart';

class IncognitoSetting {
  const IncognitoSetting({
    required this.requested,
    required this.enabled,
    required this.canEnable,
    this.effectiveUntil,
  });

  factory IncognitoSetting.fromJson(Map<String, dynamic> json) =>
      IncognitoSetting(
        requested: json['requested'] == true,
        enabled: json['enabled'] == true,
        canEnable: json['can_enable'] == true,
        effectiveUntil:
            DateTime.tryParse(json['effective_until']?.toString() ?? '')
                ?.toLocal(),
      );

  final bool requested;
  final bool enabled;
  final bool canEnable;
  final DateTime? effectiveUntil;
}

class IncognitoService {
  IncognitoService._();

  static final instance = IncognitoService._();
  static const _freshness = Duration(minutes: 5);

  String? _cachedUserId;
  IncognitoSetting? _cached;
  DateTime? _cachedAt;
  Future<IncognitoSetting>? _loadInFlight;
  Future<void> _writeQueue = Future<void>.value();

  Future<IncognitoSetting> load({bool force = false}) async {
    final userId = await SupabaseService.currentUserIdOrRefresh();
    if (!SupabaseService.isInitialized || userId == null) {
      throw StateError('Please sign in again to load privacy settings.');
    }
    if (_cachedUserId != userId) clearCache();
    final cachedAt = _cachedAt;
    if (!force &&
        _cached != null &&
        cachedAt != null &&
        DateTime.now().difference(cachedAt) < _freshness) {
      return _cached!;
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

  Future<IncognitoSetting> _loadFromServer(String userId) async {
    final raw = await SupabaseService.client.rpc('get_my_incognito_setting');
    final setting = _parse(raw);
    _cachedUserId = userId;
    _cached = setting;
    _cachedAt = DateTime.now();
    return setting;
  }

  Future<IncognitoSetting> setEnabled(bool enabled) {
    final operation = _writeQueue.then((_) async {
      final userId = await SupabaseService.currentUserIdOrRefresh();
      if (!SupabaseService.isInitialized || userId == null) {
        throw StateError('Please sign in again to update privacy settings.');
      }
      final raw = await SupabaseService.client.rpc(
        'set_my_incognito',
        params: {'p_enabled': enabled},
      );
      final setting = _parse(raw);
      _cachedUserId = userId;
      _cached = setting;
      _cachedAt = DateTime.now();
      return setting;
    });
    _writeQueue = operation.then<void>((_) {}, onError: (_, __) {});
    return operation;
  }

  IncognitoSetting _parse(dynamic raw) {
    if (raw is List && raw.isNotEmpty && raw.first is Map) {
      return IncognitoSetting.fromJson(
        Map<String, dynamic>.from(raw.first as Map),
      );
    }
    if (raw is Map) {
      return IncognitoSetting.fromJson(Map<String, dynamic>.from(raw));
    }
    throw StateError('Incognito settings are temporarily unavailable.');
  }

  void clearCache() {
    _cachedUserId = null;
    _cached = null;
    _cachedAt = null;
    _loadInFlight = null;
  }
}
