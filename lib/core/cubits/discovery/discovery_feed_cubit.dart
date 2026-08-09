// SILARAH — Discovery Feed Cubit (Step 6 — Filter-aware)
//
//   • Cursor-based pagination — no offset drift, no duplicates
//   • Every 10th profile: "Someone you might connect with"
//   • Free-tier counter
//   • Sect / Deen / Age / Verified / FamilyType filters applied by Supabase
//
// Filter persistence: active filter is saved to SharedPreferences
// so it survives app restarts.
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/discovery_profile.dart';
import '../../services/supabase_service.dart';
import '../../services/profile_write_service.dart';
import '../../services/location_service.dart';
import '../../services/profile_photo_service.dart';
import '../../services/connectivity_service.dart';
import '../../models/onboarding_data.dart';
import '../../utils/silarah_compute.dart';
import 'discovery_feed_state.dart';

class _ProfileViewQuota {
  const _ProfileViewQuota({
    required this.viewsToday,
    required this.dailyLimit,
  });

  final int viewsToday;
  final int dailyLimit;
}

class DiscoveryFeedCubit extends Cubit<DiscoveryFeedState> {
  DiscoveryFeedCubit() : super(const DiscoveryFeedState());

  static const _batchSize = 8;
  static const _kFilterKey = 'discovery_active_filter';

  double? _backendCursorScore;
  String? _backendCursorId;
  bool _discoveryLocationPrepared = false;
  int _requestVersion = 0;
  String? _readyViewerId;
  DateTime? _viewerReadyAt;
  String? _loadedRevisionToken;
  String? _pendingRevisionToken;
  DateTime? _lastRevisionCheckAt;
  static const _viewerReadinessFreshness = Duration(minutes: 10);
  static const _revisionCheckFreshness = Duration(seconds: 90);

  // Public API
  Future<OnboardingData?> _getViewerProfile() async {
    try {
      if (SupabaseService.isInitialized) {
        final dbData = await ProfileWriteService.loadProfile();
        if (dbData != null) return dbData;
      }
    } catch (e) {
      debugPrint('DiscoveryFeedCubit: Error loading viewer profile: $e');
    }
    return null;
  }

  /// Initial page load — shows skeleton loaders first.
  /// Restores saved filters locally; browse quota always comes from Supabase.
  Future<void> loadInitial({bool force = false}) async {
    if (!force && state.status != FeedStatus.initial) return;
    final requestVersion = _nextRequestVersion();
    emit(state.copyWith(
      status:
          state.profiles.isEmpty ? FeedStatus.loading : FeedStatus.refreshing,
      clearFailure: true,
    ));

    // Local filter restoration and the viewer projection are independent.
    // Starting them together avoids putting device I/O behind a database read.
    final initialData = await Future.wait<dynamic>([
      _getViewerProfile(),
      _loadFilterFromPrefs(),
    ]);
    if (!_isCurrentRequest(requestVersion)) return;
    final viewerProfile = initialData[0] as OnboardingData?;
    final savedFilter = initialData[1] as DiscoveryFilter?;
    DiscoveryFilter filter = savedFilter ?? state.activeFilter;

    if (savedFilter == null && viewerProfile != null) {
      filter = DiscoveryFilter(
        ageMin: viewerProfile.preferredAgeMin,
        ageMax: viewerProfile.preferredAgeMax,
        sect: viewerProfile.preferredSect != null &&
                viewerProfile.preferredSect != 'Any'
            ? viewerProfile.preferredSect
            : null,
        deenLevel: viewerProfile.preferredDeenLevel != null &&
                viewerProfile.preferredDeenLevel != 'Any'
            ? viewerProfile.preferredDeenLevel
            : null,
        diasporaMode:
            viewerProfile.locationPreference == LocationPreference.diaspora,
        distanceLabel:
            viewerProfile.locationPreference == LocationPreference.sameCity
                ? 'Same City'
                : (viewerProfile.locationPreference ==
                        LocationPreference.sameCountry
                    ? 'Same Country'
                    : 'Anywhere'),
      );
    }

    try {
      filter = await _enforceLocationFilterAccess(filter);
      if (!_isCurrentRequest(requestVersion)) return;
      await _saveFilterToPrefs(filter);
      if (!_isCurrentRequest(requestVersion)) return;
      final currentUserId = await SupabaseService.currentUserIdOrRefresh();
      if (currentUserId == null) {
        throw StateError('Please sign in to view discovery profiles.');
      }

      // These three server reads are independent. Keeping them concurrent cuts
      // cold-start latency without adding requests, and readiness remains
      // cached for pagination and subsequent filter changes.
      final pendingRevision = _pendingRevisionToken;
      final prerequisites = await Future.wait<dynamic>([
        pendingRevision != null
            ? Future<String?>.value(pendingRevision)
            : _readDiscoveryRevisionToken(filter),
        _loadServerViewQuota(),
        _assertViewerDiscoveryReady(currentUserId),
      ]);
      final revisionAtStart = prerequisites[0] as String?;
      final quota = prerequisites[1] as _ProfileViewQuota;
      _pendingRevisionToken = null;
      _lastRevisionCheckAt = DateTime.now();
      if (!_isCurrentRequest(requestVersion)) return;
      _resetCursors();
      final profiles =
          await _getPool(filter: filter, requestVersion: requestVersion);
      if (!_isCurrentRequest(requestVersion)) return;
      final batch = _toFeedProfiles(profiles, offset: 0);
      if (!isClosed) {
        if (revisionAtStart != null) {
          _loadedRevisionToken = revisionAtStart;
        }
        emit(state.copyWith(
          status: batch.isEmpty ? FeedStatus.empty : FeedStatus.loaded,
          profiles: batch,
          hasMore: profiles.length == _batchSize,
          activeFilter: filter,
          profilesViewedToday: quota.viewsToday,
          dailyLimit: quota.dailyLimit,
          clearFailure: true,
        ));
      }
    } catch (e) {
      if (_isCurrentRequest(requestVersion)) await _emitDiscoveryError(e);
    }
  }

  /// Checks a tiny server revision and reloads only when discovery-relevant
  /// catalog or relationship state changed. Repeated tab taps and short
  /// background/resume cycles therefore do not re-query or re-sign the feed.
  Future<void> refreshIfChanged({bool forceCheck = false}) async {
    if (state.status == FeedStatus.initial) {
      await loadInitial();
      return;
    }
    if (state.status == FeedStatus.loading ||
        state.status == FeedStatus.refreshing ||
        state.status == FeedStatus.loadingMore) {
      return;
    }

    final checkedAt = _lastRevisionCheckAt;
    if (!forceCheck &&
        checkedAt != null &&
        DateTime.now().difference(checkedAt) < _revisionCheckFreshness) {
      return;
    }

    _lastRevisionCheckAt = DateTime.now();
    final serverToken = await _readDiscoveryRevisionToken(state.activeFilter);
    if (serverToken == null || isClosed) return;
    if (_loadedRevisionToken == serverToken) {
      if (state.status == FeedStatus.error) {
        await loadInitial(force: true);
      } else if (state.failureKind != null) {
        emit(state.copyWith(clearFailure: true));
      }
      return;
    }

    final loadedToken = _loadedRevisionToken;
    if (loadedToken != null &&
        state.profiles.isNotEmpty &&
        _catalogRevisionOf(loadedToken) == _catalogRevisionOf(serverToken)) {
      await _refreshRelationshipContext(serverToken);
      return;
    }

    _pendingRevisionToken = serverToken;
    await loadInitial(force: true);
  }

  String _catalogRevisionOf(String token) => token.split(':member=').first;

  /// Load next page (append).
  Future<void> loadMore() async {
    if (state.status == FeedStatus.loadingMore) return;
    if (!state.hasMore) return;

    final requestVersion = _nextRequestVersion();
    final baseProfiles = state.profiles;
    final filter = state.activeFilter;
    emit(state.copyWith(status: FeedStatus.loadingMore));
    try {
      final profiles =
          await _getPool(filter: filter, requestVersion: requestVersion);
      if (!_isCurrentRequest(requestVersion)) return;
      final batch = _toFeedProfiles(
        profiles,
        offset: baseProfiles.length,
      );
      if (!isClosed) {
        emit(state.copyWith(
          status: FeedStatus.loaded,
          profiles: [...baseProfiles, ...batch],
          hasMore: profiles.length == _batchSize,
          clearFailure: true,
        ));
      }
    } catch (e) {
      if (_isCurrentRequest(requestVersion)) {
        await _emitDiscoveryError(e, keepProfiles: true);
      }
    }
  }

  void clear() {
    _nextRequestVersion();
    _resetCursors();
    _discoveryLocationPrepared = false;
    _readyViewerId = null;
    _viewerReadyAt = null;
    _loadedRevisionToken = null;
    _pendingRevisionToken = null;
    _lastRevisionCheckAt = null;
    if (!isClosed) emit(const DiscoveryFeedState());
  }

  /// Apply new filters — resets the feed and reloads from cursor 0.
  Future<void> applyFilter(DiscoveryFilter filter) async {
    final requestVersion = _nextRequestVersion();
    final previousFilter = state.activeFilter;
    try {
      final effectiveFilter = await _enforceLocationFilterAccess(filter);
      if (!_isCurrentRequest(requestVersion)) return;
      emit(state.copyWith(
        status:
            state.profiles.isEmpty ? FeedStatus.loading : FeedStatus.refreshing,
        activeFilter: effectiveFilter,
        clearFailure: true,
      ));

      // Persist only the server-authorized filter. This prevents an expired
      // Premium scope from breaking discovery on every subsequent launch.
      await _saveFilterToPrefs(effectiveFilter);
      if (!_isCurrentRequest(requestVersion)) return;

      final revisionAtStart =
          await _readDiscoveryRevisionToken(effectiveFilter);
      _lastRevisionCheckAt = DateTime.now();
      if (!_isCurrentRequest(requestVersion)) return;
      _resetCursors();
      final profiles = await _getPool(
        filter: effectiveFilter,
        requestVersion: requestVersion,
      );
      if (!_isCurrentRequest(requestVersion)) return;
      final batch = _toFeedProfiles(profiles, offset: 0);
      if (!isClosed) {
        if (revisionAtStart != null) {
          _loadedRevisionToken = revisionAtStart;
        }
        emit(state.copyWith(
          status: batch.isEmpty ? FeedStatus.empty : FeedStatus.loaded,
          profiles: batch,
          hasMore: profiles.length == _batchSize,
          clearFailure: true,
        ));
      }
    } catch (e) {
      if (_isCurrentRequest(requestVersion)) {
        await _saveFilterToPrefs(previousFilter);
        await _emitDiscoveryError(e, fallbackFilter: previousFilter);
      }
    }
  }

  /// Clear all filters and reload.
  Future<void> clearFilters() => applyFilter(DiscoveryFilter.empty);

  Future<bool> recordProfileView(String viewedUserId) async {
    if (!SupabaseService.isInitialized || viewedUserId.isEmpty) {
      return false;
    }
    final currentUserId = await SupabaseService.currentUserIdOrRefresh();
    if (currentUserId == null) return false;

    try {
      final response = await SupabaseService.client.rpc(
        'record_profile_view',
        params: {
          'p_viewed_user_id': viewedUserId,
          'p_notify_owner': false,
        },
      );
      final rows = response as List<dynamic>;
      final row = rows.isNotEmpty
          ? Map<String, dynamic>.from(rows.first as Map)
          : <String, dynamic>{};
      final allowed = row['allowed'] == true;
      if (!isClosed) {
        emit(state.copyWith(
          profilesViewedToday: (row['views_today'] as num?)?.toInt() ??
              state.profilesViewedToday,
          dailyLimit: (row['daily_limit'] as num?)?.toInt() ?? state.dailyLimit,
        ));
      }
      return allowed;
    } catch (e) {
      debugPrint('DiscoveryFeedCubit: failed to record profile view: $e');
      return false;
    }
  }

  Future<_ProfileViewQuota> _loadServerViewQuota() async {
    if (!SupabaseService.isInitialized) {
      throw StateError('Discovery quota requires an authenticated session.');
    }
    final currentUserId = await SupabaseService.currentUserIdOrRefresh();
    if (currentUserId == null) {
      throw StateError('Discovery quota requires an authenticated session.');
    }

    try {
      final response =
          await SupabaseService.client.rpc('get_profile_view_quota');
      final rows = response as List<dynamic>;
      if (rows.isEmpty) {
        throw StateError('Profile view quota response was empty.');
      }
      final row = Map<String, dynamic>.from(rows.first as Map);
      final viewsToday = (row['views_today'] as num?)?.toInt();
      final dailyLimit = (row['daily_limit'] as num?)?.toInt();
      if (viewsToday == null || dailyLimit == null) {
        throw StateError('Profile view quota response was incomplete.');
      }
      return _ProfileViewQuota(
        viewsToday: viewsToday,
        dailyLimit: dailyLimit,
      );
    } catch (e) {
      debugPrint('DiscoveryFeedCubit: failed to load profile view quota: $e');
      throw StateError('Unable to verify your daily discovery limit.');
    }
  }

  Future<String?> _readDiscoveryRevisionToken(DiscoveryFilter filter) async {
    if (!SupabaseService.isInitialized) return null;
    final currentUserId = await SupabaseService.currentUserIdOrRefresh();
    if (currentUserId == null) return null;
    try {
      final response = await SupabaseService.client.rpc(
        'get_my_discovery_revision',
        params: {'p_filters': _mapFilterToJson(filter)},
      );
      if (response is! List || response.isEmpty) return null;
      final row = Map<String, dynamic>.from(response.first as Map);
      final token = row['revision_token']?.toString();
      return token == null || token.isEmpty ? null : token;
    } catch (e) {
      // Revision invalidation is an optimization. A temporary failure must not
      // make the primary discovery path unavailable.
      debugPrint('DiscoveryFeedCubit: revision check unavailable: $e');
      return null;
    }
  }

  Future<DiscoveryFilter> _enforceLocationFilterAccess(
    DiscoveryFilter filter,
  ) async {
    if (filter.locationScope == 'global') return filter;
    if (!SupabaseService.isInitialized) {
      throw StateError('Location filters require a Supabase connection.');
    }

    final response = await SupabaseService.client.rpc(
      'get_discovery_filter_access',
    );
    final rows = response as List<dynamic>;
    if (rows.isEmpty) {
      throw StateError('Unable to verify Premium location-filter access.');
    }
    final row = Map<String, dynamic>.from(rows.first as Map);
    if (row['allowed'] == true) return filter;

    return filter.copyWith(
      diasporaMode: false,
      clearDiasporaCountries: true,
      clearBrowseCountries: true,
      clearDistanceLabel: true,
      clearMaxDistance: true,
    );
  }

  // Filter Persistence
  Future<DiscoveryFilter?> _loadFilterFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kFilterKey);
      final raw = prefs.getString(_filterKey);
      if (raw == null || raw.isEmpty) return null;

      final j = jsonDecode(raw) as Map<String, dynamic>;
      return DiscoveryFilter(
        ageMin: j['ageMin'] as int?,
        ageMax: j['ageMax'] as int?,
        sect: j['sect'] as String?,
        deenLevel: j['deenLevel'] as String?,
        verifiedOnly: (j['verifiedOnly'] as bool?) ?? false,
        activeRecentlyOnly: (j['activeRecentlyOnly'] as bool?) ?? false,
        maxDistanceKm: j['maxDistanceKm'] as int?,
        familyType: j['familyType'] as String?,
        openToDivorced: (j['openToDivorced'] as bool?) ?? false,
        genderPref: j['genderPref'] as String?,
        maritalStatus: j['maritalStatus'] as String?,
        hasChildren: j['hasChildren'] as String?,
        educationMin: j['educationMin'] as String?,
        distanceLabel: j['distanceLabel'] as String?,
        motherTongue: j['motherTongue'] as String?,
        community: j['community'] as String?,
        livingExpectation: j['livingExpectation'] as String?,
        quranMemorization: j['quranMemorization'] as String?,
        marriageTimeline: j['marriageTimeline'] as String?,
        willingToRelocate: j['willingToRelocate'] as String?,
        diasporaMode: (j['diasporaMode'] as bool?) ?? false,
        diasporaCountries: j['diasporaCountries'] != null
            ? List<String>.from(j['diasporaCountries'] as Iterable)
            : null,
        browseCountries: j['browseCountries'] != null
            ? List<String>.from(j['browseCountries'] as Iterable)
            : null,
      );
    } catch (e) {
      debugPrint('DiscoveryFeedCubit: failed to load filter: $e');
      return null;
    }
  }

  Future<void> _saveFilterToPrefs(DiscoveryFilter f) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!f.isActive) {
        await prefs.remove(_filterKey);
        return;
      }
      final json = jsonEncode({
        'ageMin': f.ageMin,
        'ageMax': f.ageMax,
        'sect': f.sect,
        'deenLevel': f.deenLevel,
        'verifiedOnly': f.verifiedOnly,
        'activeRecentlyOnly': f.activeRecentlyOnly,
        'maxDistanceKm': f.maxDistanceKm,
        'familyType': f.familyType,
        'openToDivorced': f.openToDivorced,
        'genderPref': f.genderPref,
        'maritalStatus': f.maritalStatus,
        'hasChildren': f.hasChildren,
        'educationMin': f.educationMin,
        'distanceLabel': f.distanceLabel,
        'motherTongue': f.motherTongue,
        'community': f.community,
        'livingExpectation': f.livingExpectation,
        'quranMemorization': f.quranMemorization,
        'marriageTimeline': f.marriageTimeline,
        'willingToRelocate': f.willingToRelocate,
        'diasporaMode': f.diasporaMode,
        'diasporaCountries': f.diasporaCountries,
        'browseCountries': f.browseCountries,
      });
      await prefs.setString(_filterKey, json);
    } catch (e) {
      debugPrint('DiscoveryFeedCubit: failed to save filter: $e');
    }
  }

  String get _filterKey {
    final userId = SupabaseService.currentUserId;
    if (userId == null || userId.isEmpty) {
      throw StateError('Authenticated user is required for filter storage.');
    }
    return '${_kFilterKey}_$userId';
  }

  static Future<void> clearPersistedFilters({String? userId}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kFilterKey);
    if (userId != null && userId.isNotEmpty) {
      await prefs.remove('${_kFilterKey}_$userId');
    }
  }

  void _resetCursors() {
    _backendCursorScore = null;
    _backendCursorId = null;
  }

  int _nextRequestVersion() => ++_requestVersion;

  bool _isCurrentRequest(int requestVersion) =>
      !isClosed && requestVersion == _requestVersion;

  List<FeedProfile> _toFeedProfiles(
    List<DiscoveryProfile> profiles, {
    required int offset,
  }) {
    return [
      for (var i = 0; i < profiles.length; i++)
        FeedProfile(
          profile: profiles[i],
          isWildCard: offset + i > 0 && (offset + i + 1) % 10 == 0,
          lastActiveAt: profiles[i].lastActiveAt,
        ),
    ];
  }

  void _updateBackendCursor(List<dynamic> rows) {
    if (rows.isEmpty) return;

    final last = Map<String, dynamic>.from(rows.last as Map);
    final score = (last['rank_score'] as num?)?.toDouble();
    final profileId = last['profile_id'] as String?;
    if (score != null && profileId != null) {
      _backendCursorScore = score;
      _backendCursorId = profileId;
    }
  }

  Map<String, dynamic> _mapFilterToJson(DiscoveryFilter f) {
    final maxKm = f.effectiveMaxDistanceKm;
    final genderPref = _enumToken(f.genderPref);
    final sect = _enumToken(f.sect);
    final deenLevel = _enumToken(f.deenLevel);
    final familyType = _enumToken(f.familyType);
    final maritalStatus = _maritalStatusToken(f.maritalStatus);
    final hasChildren = _enumToken(f.hasChildren);

    return {
      'location_scope': f.locationScope,
      if (maxKm != null) 'max_distance_km': maxKm,
      if (f.distanceLabel == 'Same City') 'same_city': true,
      if (f.distanceLabel == 'Same State' ||
          f.distanceLabel == 'Same State / Region')
        'same_region': true,
      if (f.distanceLabel == 'Same Country') 'same_country': true,
      if (f.distanceLabel == 'Anywhere') 'anywhere': true,
      if (f.browseCountries != null && f.browseCountries!.isNotEmpty)
        'country_codes': f.browseCountries,
      'diaspora_mode': f.diasporaMode,
      if (f.diasporaCountries != null && f.diasporaCountries!.isNotEmpty)
        'diaspora_countries': f.diasporaCountries,
      if (f.ageMin != null) 'age_min': f.ageMin,
      if (f.ageMax != null) 'age_max': f.ageMax,
      'active_recently': f.activeRecentlyOnly,
      if (genderPref != null) 'gender_pref': genderPref,
      if (sect != null) 'sect': sect,
      if (deenLevel != null) 'deen_level': deenLevel,
      'verified_only': f.verifiedOnly,
      if (familyType != null) 'family_type': familyType,
      if (maritalStatus != null) 'marital_status': maritalStatus,
      'open_to_divorced': f.openToDivorced,
      if (_educationRank(f.educationMin) != null)
        'education_min': _educationRank(f.educationMin),
      if (f.motherTongue != null && f.motherTongue != 'Any')
        'mother_tongue': f.motherTongue,
      if (f.community != null && f.community != 'Any') 'community': f.community,
      if (f.livingExpectation != null && f.livingExpectation != 'Any')
        'living_expectation': f.livingExpectation,
      if (f.quranMemorization != null && f.quranMemorization != 'Any')
        'quran_memorization': f.quranMemorization,
      if (f.marriageTimeline != null && f.marriageTimeline != 'Any')
        'marriage_timeline': f.marriageTimeline,
      if (f.willingToRelocate != null && f.willingToRelocate != 'Any')
        'willing_to_relocate': f.willingToRelocate,
      if (hasChildren != null) 'has_children': hasChildren,
    };
  }

  String? _enumToken(String? value) {
    final raw = value?.trim();
    if (raw == null || raw.isEmpty || raw.toLowerCase() == 'any') {
      return null;
    }
    return raw.toLowerCase().replaceAll(RegExp(r'[\s-]+'), '_');
  }

  String? _maritalStatusToken(String? value) {
    final token = _enumToken(value);
    if (token == null) return null;
    return token == 'never_married' ? 'no' : token;
  }

  /// Fetches real candidates and their stated compatibility preferences.
  Future<List<DiscoveryProfile>> _getPool({
    DiscoveryFilter? filter,
    required int requestVersion,
  }) async {
    if (!SupabaseService.isInitialized) {
      throw StateError('Discovery requires a Supabase connection.');
    }
    final currentUserId = await SupabaseService.currentUserIdOrRefresh();
    if (currentUserId == null) {
      throw StateError('Please sign in to view discovery profiles.');
    }

    try {
      final timings = Stopwatch()..start();
      await _assertViewerDiscoveryReady(currentUserId);
      if (!_isCurrentRequest(requestVersion)) return const [];

      final payload =
          filter != null ? _mapFilterToJson(filter) : <String, dynamic>{};
      if (filter?.effectiveMaxDistanceKm != null &&
          !_discoveryLocationPrepared) {
        await LocationService.refreshDiscoveryLocation();
        _discoveryLocationPrepared = true;
      }
      final response = await SupabaseService.client.rpc(
        'get_discovery_feed',
        params: {
          'p_viewer_id': currentUserId,
          'p_cursor_score': _backendCursorScore,
          'p_cursor_id': _backendCursorId,
          'p_page_size': _batchSize,
          'p_filters': payload,
        },
      );

      final rows = (response as List<dynamic>)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
      final feedMs = timings.elapsedMilliseconds;
      // Race fix: stale discovery responses must not advance the shared cursor
      // or overwrite a newer filter/load request.
      if (!_isCurrentRequest(requestVersion)) return const [];
      _updateBackendCursor(rows);
      final publicPhotoOwners = rows
          .where((row) {
            final privacy = row['photo_privacy']?.toString();
            return ((row['photo_count'] as num?)?.toInt() ?? 0) > 0 &&
                privacy != 'mutual_only' &&
                privacy != 'request_only';
          })
          .map((row) => row['user_id']?.toString())
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toList(growable: false);

      // Relationship context and the one batched photo-signing call are
      // independent. Running them together removes a full network round-trip
      // from cold Discovery without increasing request count or egress.
      final enrichment = await Future.wait<dynamic>([
        _attachPriorMatchContext(rows),
        publicPhotoOwners.isEmpty
            ? Future<Map<String, String>>.value(const {})
            : _loadPublicPhotoUrls(publicPhotoOwners),
      ]);
      final signedUrls = enrichment[1] as Map<String, String>;
      for (final row in rows) {
        // Feed rows must never expose private Storage paths as image URLs.
        row.remove('photo_url');
        row.remove('photo_urls');
        final signedUrl = signedUrls[row['user_id']?.toString()];
        if (signedUrl != null && signedUrl.isNotEmpty) {
          row['photo_url'] = signedUrl;
        }
      }
      final contextMs = timings.elapsedMilliseconds - feedMs;
      if (!_isCurrentRequest(requestVersion)) return const [];
      final profiles = await compute(parseProfilesInBackground, rows);
      final parseMs = timings.elapsedMilliseconds - feedMs - contextMs;
      if (!_isCurrentRequest(requestVersion)) return const [];
      if (kDebugMode) {
        debugPrint(
          'DiscoveryFeedCubit: ${profiles.length} profiles in '
          '${timings.elapsedMilliseconds}ms '
          '(feed ${feedMs}ms, parallel enrichment ${contextMs}ms, '
          'parse ${parseMs}ms).',
        );
      }
      return profiles;
    } catch (e) {
      debugPrint('DiscoveryFeedCubit: Supabase discovery failed: $e');
      rethrow;
    }
  }

  Future<void> _assertViewerDiscoveryReady(String currentUserId) async {
    final readyAt = _viewerReadyAt;
    if (_readyViewerId == currentUserId &&
        readyAt != null &&
        DateTime.now().difference(readyAt) < _viewerReadinessFreshness) {
      return;
    }
    final profile = await SupabaseService.client
        .from('my_profile_private')
        .select('id, visibility, onboarding_completed, approved_at')
        .eq('user_id', currentUserId)
        .maybeSingle();

    if (profile == null) {
      throw StateError('Complete your profile before browsing discovery.');
    }

    if (profile['visibility'] != 'visible') {
      throw StateError('Your profile must be visible before discovery.');
    }

    if (profile['onboarding_completed'] != true) {
      throw StateError('Complete your profile before browsing discovery.');
    }

    if (profile['approved_at'] == null) {
      throw StateError(
        'Your primary photo must pass the safety scan before discovery.',
      );
    }

    final profileId = profile['id'] as String?;
    if (profileId == null || profileId.isEmpty) {
      throw StateError('Complete your profile before browsing discovery.');
    }

    final photos = await SupabaseService.client
        .from('photos')
        .select('id')
        .eq('profile_id', profileId)
        .eq('admin_approved', true)
        .eq('nsfw_cleared', true)
        .limit(1);

    if ((photos as List<dynamic>).isEmpty) {
      throw StateError(
        'Add an approved profile photo before browsing discovery.',
      );
    }
    _readyViewerId = currentUserId;
    _viewerReadyAt = DateTime.now();
  }

  /// Adds one bounded card-context projection for candidates already returned
  /// in this page. Relationship history and compatibility preferences share a
  /// single RPC, avoiding both N+1 work and a second enrichment round trip.
  Future<void> _attachPriorMatchContext(
    List<Map<String, dynamic>> rows,
  ) async {
    if (rows.isEmpty) return;
    final candidateIds = rows
        .map((row) => row['user_id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (candidateIds.isEmpty) return;

    final response = await SupabaseService.client.rpc(
      'get_prior_match_context',
      params: {'p_candidate_user_ids': candidateIds},
    );
    final contextByUser = <String, Map<String, dynamic>>{
      for (final raw in response as List<dynamic>)
        if ((raw as Map)['candidate_user_id'] != null)
          raw['candidate_user_id'].toString(): Map<String, dynamic>.from(raw),
    };
    for (final row in rows) {
      final prior = contextByUser[row['user_id']?.toString()];
      if (prior != null) row.addAll(prior);
    }
  }

  Future<Map<String, String>> _loadPublicPhotoUrls(
    List<String> ownerUserIds,
  ) async {
    try {
      return await ProfilePhotoService.instance.getAuthorizedPhotoUrls(
        ownerUserIds: ownerUserIds,
      );
    } catch (error) {
      // Profiles remain browsable with a privacy-safe placeholder while a
      // transient signing service failure recovers.
      debugPrint('DiscoveryFeedCubit: failed to batch sign photo URLs: $error');
      return const {};
    }
  }

  /// Reconciles only relationship metadata for cards already in memory. This
  /// avoids re-running ranking, pagination and photo signing when a match is
  /// opened/closed or a profile is blocked/reported.
  Future<void> _refreshRelationshipContext(String revisionToken) async {
    final currentProfiles = state.profiles;
    if (currentProfiles.isEmpty) {
      _loadedRevisionToken = revisionToken;
      return;
    }

    try {
      final response = await SupabaseService.client.rpc(
        'get_prior_match_context',
        params: {
          'p_candidate_user_ids': currentProfiles
              .map((entry) => entry.profile.id)
              .toSet()
              .toList(growable: false),
        },
      );
      final contextByUser = <String, Map<String, dynamic>>{
        for (final raw in response as List<dynamic>)
          if ((raw as Map)['candidate_user_id'] != null)
            raw['candidate_user_id'].toString(): Map<String, dynamic>.from(raw),
      };
      final updated = <FeedProfile>[];
      for (final entry in currentProfiles) {
        final prior = contextByUser[entry.profile.id];
        // Missing context means this card is no longer safe/visible to this
        // viewer (block, report, suspension or privacy change).
        if (prior == null) continue;
        final previousAt = _optionalTimestamp(prior['previous_match_at']);
        final endedAt = _optionalTimestamp(prior['previous_match_ended_at']);
        final availableAt = _optionalTimestamp(prior['rematch_available_at']);
        updated.add(FeedProfile(
          profile: entry.profile.copyWith(
            previousMatchAt: previousAt,
            previousMatchEndedAt: endedAt,
            priorMatchCount: (prior['prior_match_count'] as num?)?.toInt() ?? 0,
            rematchAvailableAt: availableAt,
            clearPreviousMatchAt: previousAt == null,
            clearPreviousMatchEndedAt: endedAt == null,
            clearRematchAvailableAt: availableAt == null,
          ),
          isWildCard: entry.isWildCard,
          lastActiveAt: entry.lastActiveAt,
        ));
      }
      if (isClosed) return;
      _loadedRevisionToken = revisionToken;
      emit(state.copyWith(
        status: updated.isEmpty ? FeedStatus.empty : FeedStatus.loaded,
        profiles: updated,
        clearFailure: true,
      ));
    } catch (error) {
      // Leave both the existing cards and old token intact so the next check
      // retries safely instead of replacing useful content with an error page.
      debugPrint(
        'DiscoveryFeedCubit: relationship-only refresh unavailable: $error',
      );
    }
  }

  DateTime? _optionalTimestamp(Object? value) {
    if (value is DateTime) return value;
    return value == null ? null : DateTime.tryParse(value.toString());
  }

  Future<void> _emitDiscoveryError(
    Object error, {
    bool keepProfiles = false,
    DiscoveryFilter? fallbackFilter,
  }) async {
    if (isClosed) return;
    final stateError = error is StateError ? error.message : null;
    final normalized = stateError?.toLowerCase() ?? '';
    final profileNotReady = normalized.contains('complete your profile') ||
        normalized.contains('profile must be visible') ||
        normalized.contains('approved profile photo') ||
        normalized.contains('primary photo must pass');
    final authenticationRequired = normalized.contains('sign in') ||
        normalized.contains('authenticated session');

    var isOffline = false;
    if (!profileNotReady &&
        !authenticationRequired &&
        ConnectivityService.isInitialized) {
      await ConnectivityService.instance.checkNow();
      isOffline = !ConnectivityService.instance.hasNetworkInterface;
      if (isClosed) return;
    }

    final kind = profileNotReady
        ? DiscoveryFailureKind.profileNotReady
        : authenticationRequired
            ? DiscoveryFailureKind.authenticationRequired
            : isOffline
                ? DiscoveryFailureKind.offline
                : DiscoveryFailureKind.unavailable;
    final message = switch (kind) {
      DiscoveryFailureKind.offline =>
        'No internet connection. Saved profiles remain available and reconnection is automatic.',
      DiscoveryFailureKind.unavailable =>
        'Profiles are temporarily unavailable. Please try again.',
      DiscoveryFailureKind.profileNotReady =>
        stateError ?? 'Unable to load profiles. Please try again.',
      DiscoveryFailureKind.authenticationRequired =>
        'Please sign in to view discovery profiles.',
    };
    final preserveProfiles = keepProfiles || state.profiles.isNotEmpty;
    emit(state.copyWith(
      status: preserveProfiles ? FeedStatus.loaded : FeedStatus.error,
      profiles: preserveProfiles ? state.profiles : const [],
      hasMore: preserveProfiles ? state.hasMore : false,
      activeFilter: fallbackFilter,
      errorMessage: message,
      failureKind: kind,
    ));
  }

  /// Keeps already loaded cards usable while the device is offline. A later
  /// connectivity transition triggers a normal revision-aware refresh.
  void markOffline() {
    if (isClosed) return;
    final preserveProfiles = state.profiles.isNotEmpty;
    emit(state.copyWith(
      status: preserveProfiles ? FeedStatus.loaded : FeedStatus.error,
      errorMessage:
          'No internet connection. Saved profiles remain available and reconnection is automatic.',
      failureKind: DiscoveryFailureKind.offline,
    ));
  }

  int? _educationRank(String? label) {
    switch (label) {
      case 'Matric':
        return 1;
      case 'Intermediate':
        return 2;
      case "Bachelor's":
        return 3;
      case "Master's":
        return 4;
      case 'PhD':
        return 5;
      case 'Professional Degree':
        return 6;
      case 'Other':
        return 7;
      default:
        return null;
    }
  }
}
