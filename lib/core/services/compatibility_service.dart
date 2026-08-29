import 'supabase_service.dart';

class CompatibilityCriterion {
  const CompatibilityCriterion({
    required this.key,
    required this.matchedCount,
    required this.totalCount,
    required this.status,
  });

  factory CompatibilityCriterion.fromJson(Map<String, dynamic> json) =>
      CompatibilityCriterion(
        key: json['key']?.toString() ?? '',
        matchedCount: (json['matched_count'] as num?)?.toInt() ?? 0,
        totalCount: (json['total_count'] as num?)?.toInt() ?? 0,
        status: json['status']?.toString() ?? 'not_aligned',
      );

  final String key;
  final int matchedCount;
  final int totalCount;
  final String status;
}

class CompatibilityInsight {
  const CompatibilityInsight({
    required this.matchedCount,
    required this.totalCount,
    required this.criteria,
    required this.disclaimer,
  });

  factory CompatibilityInsight.fromJson(Map<String, dynamic> json) {
    final rawCriteria = json['criteria'];
    return CompatibilityInsight(
      matchedCount: (json['matched_count'] as num?)?.toInt() ?? 0,
      totalCount: (json['total_count'] as num?)?.toInt() ?? 0,
      criteria: rawCriteria is List
          ? rawCriteria
              .whereType<Map>()
              .map((item) => CompatibilityCriterion.fromJson(
                    Map<String, dynamic>.from(item),
                  ))
              .toList(growable: false)
          : const [],
      disclaimer: json['disclaimer']?.toString() ?? '',
    );
  }

  final int matchedCount;
  final int totalCount;
  final List<CompatibilityCriterion> criteria;
  final String disclaimer;

  double get fraction => totalCount == 0 ? 0 : matchedCount / totalCount;
}

/// Loads one explainable mutual-preference summary after a Premium member
/// opens a profile. Discovery cards never trigger this RPC.
class CompatibilityService {
  CompatibilityService._();

  static final instance = CompatibilityService._();
  static const _freshness = Duration(minutes: 5);

  String? _cachedUserId;
  final Map<String, ({CompatibilityInsight value, DateTime loadedAt})> _cache =
      {};
  final Map<String, Future<CompatibilityInsight>> _inFlight = {};

  Future<CompatibilityInsight> load(
    String candidateUserId, {
    bool force = false,
  }) async {
    final userId = await SupabaseService.currentUserIdOrRefresh();
    if (!SupabaseService.isInitialized || userId == null) {
      throw StateError('Please sign in again to view compatibility.');
    }
    if (_cachedUserId != userId) {
      _cachedUserId = userId;
      _cache.clear();
      _inFlight.clear();
    }

    final cached = _cache[candidateUserId];
    if (!force &&
        cached != null &&
        DateTime.now().difference(cached.loadedAt) < _freshness) {
      return cached.value;
    }
    final active = _inFlight[candidateUserId];
    if (active != null) return active;

    final request = _loadFromServer(candidateUserId);
    _inFlight[candidateUserId] = request;
    try {
      final value = await request;
      _cache[candidateUserId] = (value: value, loadedAt: DateTime.now());
      return value;
    } finally {
      if (identical(_inFlight[candidateUserId], request)) {
        _inFlight.remove(candidateUserId);
      }
    }
  }

  Future<CompatibilityInsight> _loadFromServer(String candidateUserId) async {
    final raw = await SupabaseService.client.rpc(
      'get_premium_compatibility_insight',
      params: {'p_candidate_user_id': candidateUserId},
    );
    if (raw is! Map) {
      throw StateError('Compatibility details are temporarily unavailable.');
    }
    return CompatibilityInsight.fromJson(Map<String, dynamic>.from(raw));
  }

  void clearCache() {
    _cachedUserId = null;
    _cache.clear();
    _inFlight.clear();
  }
}
