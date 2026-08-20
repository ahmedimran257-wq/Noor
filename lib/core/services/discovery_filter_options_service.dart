import 'supabase_service.dart';

class DiscoveryFilterOptions {
  const DiscoveryFilterOptions({
    this.genders = const [],
    this.sects = const [],
    this.deenLevels = const [],
    this.educationRanks = const [],
    this.familyTypes = const [],
    this.maritalStatuses = const [],
    this.motherTongues = const [],
    this.communities = const [],
    this.livingExpectations = const [],
    this.quranMemorizations = const [],
    this.marriageTimelines = const [],
    this.willingToRelocateValues = const [],
  });

  final List<String> genders;
  final List<String> sects;
  final List<String> deenLevels;
  final List<int> educationRanks;
  final List<String> familyTypes;
  final List<String> maritalStatuses;
  final List<String> motherTongues;
  final List<String> communities;
  final List<String> livingExpectations;
  final List<String> quranMemorizations;
  final List<String> marriageTimelines;
  final List<String> willingToRelocateValues;

  static const empty = DiscoveryFilterOptions();
}

class DiscoveryFilterOptionsService {
  const DiscoveryFilterOptionsService._();

  static const _cacheLifetime = Duration(minutes: 10);
  static DiscoveryFilterOptions? _cachedOptions;
  static DateTime? _cachedAt;
  static String? _cachedUserId;
  static Future<DiscoveryFilterOptions>? _inFlight;

  static Future<DiscoveryFilterOptions> load({bool force = false}) async {
    if (!SupabaseService.isInitialized) return DiscoveryFilterOptions.empty;
    final knownUserId = SupabaseService.currentUserId;
    final cachedAt = _cachedAt;
    if (!force &&
        knownUserId != null &&
        knownUserId == _cachedUserId &&
        _cachedOptions != null &&
        cachedAt != null &&
        DateTime.now().difference(cachedAt) < _cacheLifetime) {
      return _cachedOptions!;
    }

    final activeLoad = _inFlight;
    if (!force && activeLoad != null) return activeLoad;

    final userId =
        knownUserId ?? await SupabaseService.currentUserIdOrRefresh();
    if (userId == null) return DiscoveryFilterOptions.empty;

    final request = _fetch(userId);
    _inFlight = request;
    try {
      final options = await request;
      _cachedOptions = options;
      _cachedAt = DateTime.now();
      _cachedUserId = userId;
      return options;
    } finally {
      if (identical(_inFlight, request)) _inFlight = null;
    }
  }

  static Future<DiscoveryFilterOptions> _fetch(String userId) async {
    final response = await SupabaseService.client.rpc(
      'get_india_discovery_filter_facets',
      params: {'p_viewer_id': userId},
    );
    final map = Map<String, dynamic>.from(response as Map);
    return DiscoveryFilterOptions(
      genders: _stringList(map['genders']),
      sects: _stringList(map['sects']),
      deenLevels: _stringList(map['deen_levels']),
      educationRanks: _intList(map['education_ranks']),
      familyTypes: _stringList(map['family_types']),
      maritalStatuses: _stringList(map['marital_statuses']),
      motherTongues: _stringList(map['mother_tongues']),
      communities: _stringList(map['communities']),
      livingExpectations: _stringList(map['living_expectations']),
      quranMemorizations: _stringList(map['quran_memorizations']),
      marriageTimelines: _stringList(map['marriage_timelines']),
      willingToRelocateValues: _stringList(map['willing_to_relocate_values']),
    );
  }

  static List<String> _stringList(Object? value) {
    if (value is! Iterable) return const [];
    final seen = <String>{};
    final result = <String>[];
    for (final item in value) {
      final text = item?.toString().trim();
      if (text == null || text.isEmpty) continue;
      final key = text.toLowerCase();
      if (seen.add(key)) result.add(text);
    }
    result.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return result;
  }

  static List<int> _intList(Object? value) {
    if (value is! Iterable) return const [];
    final result = <int>{};
    for (final item in value) {
      final rank = item is num ? item.toInt() : int.tryParse('$item');
      if (rank != null) result.add(rank);
    }
    final sorted = result.toList()..sort();
    return sorted;
  }
}
