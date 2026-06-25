// lib/core/cubits/discovery/discovery_feed_cubit.dart
// ============================================================
// MITHAQ — Discovery Feed Cubit (Step 6 — Filter-aware)
//
// Blueprint (Part 8):
//   • Cursor-based pagination — no offset drift, no duplicates
//   • Every 10th profile: "Someone you might connect with"
//   • Free-tier counter
//   • Sect / Deen / Age / Verified / FamilyType filters applied by Supabase
//
// Filter persistence: active filter is saved to SharedPreferences
// so it survives app restarts.
// ============================================================

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../mock/mock_profiles.dart';
import '../../services/supabase_service.dart';
import '../../services/profile_write_service.dart';
import '../../services/location_service.dart';
import '../../models/onboarding_data.dart';
import '../../utils/mithaq_compute.dart';
import 'discovery_feed_state.dart';

class DiscoveryFeedCubit extends Cubit<DiscoveryFeedState> {
  DiscoveryFeedCubit() : super(const DiscoveryFeedState());

  static const _batchSize = 8;
  static const _kFilterKey = 'discovery_active_filter';
  static const _kViewCountKey = 'discovery_views_today';
  static const _kViewResetKey = 'discovery_views_reset_date';

  double? _backendCursorScore;
  String? _backendCursorId;
  bool _discoveryLocationPrepared = false;

  // ── Public API ────────────────────────────────────────────

  Future<OnboardingData?> _getViewerProfile() async {
    try {
      if (SupabaseService.isInitialized) {
        final dbData = await ProfileWriteService.loadProfile();
        if (dbData != null) return dbData;
      }
      final prefs = await SharedPreferences.getInstance();
      final rawJson = prefs.getString('onboarding_data_cache');
      if (rawJson != null && rawJson.isNotEmpty) {
        final mapped = jsonDecode(rawJson) as Map<String, dynamic>;
        return OnboardingData.fromJson(mapped);
      }
    } catch (e) {
      debugPrint('DiscoveryFeedCubit: Error loading viewer profile: $e');
    }
    return null;
  }

  /// Initial page load — shows skeleton loaders first.
  /// Also restores saved filter and browse counter from SharedPreferences.
  Future<void> loadInitial({bool force = false}) async {
    if (!force && state.status != FeedStatus.initial) return;
    emit(state.copyWith(status: FeedStatus.loading));

    final viewerProfile = await _getViewerProfile();

    // Restore saved filter
    final savedFilter = await _loadFilterFromPrefs();
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

    // G5: Restore persisted browse counter (daily reset)
    final restoredViews = await _restoreBrowseCounter();

    try {
      _resetCursors();
      final profiles = await _getPool(filter: filter);
      final batch = _toFeedProfiles(profiles, offset: 0);
      if (!isClosed) {
        emit(state.copyWith(
          status: batch.isEmpty ? FeedStatus.empty : FeedStatus.loaded,
          profiles: batch,
          hasMore: profiles.length == _batchSize,
          activeFilter: filter,
          profilesViewedToday: restoredViews,
        ));
      }
    } catch (e) {
      _emitDiscoveryError(e);
    }
  }

  /// Load next page (append).
  Future<void> loadMore() async {
    if (state.status == FeedStatus.loadingMore) return;
    if (!state.hasMore) return;

    emit(state.copyWith(status: FeedStatus.loadingMore));
    try {
      final profiles = await _getPool(filter: state.activeFilter);
      final batch = _toFeedProfiles(
        profiles,
        offset: state.profiles.length,
      );
      if (!isClosed) {
        emit(state.copyWith(
          status: FeedStatus.loaded,
          profiles: [...state.profiles, ...batch],
          hasMore: profiles.length == _batchSize,
        ));
      }
    } catch (e) {
      _emitDiscoveryError(e, keepProfiles: true);
    }
  }

  /// Apply new filters — resets the feed and reloads from cursor 0.
  Future<void> applyFilter(DiscoveryFilter filter) async {
    emit(state.copyWith(status: FeedStatus.loading, activeFilter: filter));

    // Persist the filter
    await _saveFilterToPrefs(filter);

    try {
      _resetCursors();
      final profiles = await _getPool(filter: filter);
      final batch = _toFeedProfiles(profiles, offset: 0);
      if (!isClosed) {
        emit(state.copyWith(
          status: batch.isEmpty ? FeedStatus.empty : FeedStatus.loaded,
          profiles: batch,
          hasMore: profiles.length == _batchSize,
        ));
      }
    } catch (e) {
      _emitDiscoveryError(e);
    }
  }

  /// Clear all filters and reload.
  Future<void> clearFilters() => applyFilter(DiscoveryFilter.empty);

  void recordProfileView() {
    if (!isClosed) {
      final newCount = state.profilesViewedToday + 1;
      emit(state.copyWith(profilesViewedToday: newCount));
      _persistBrowseCounter(newCount);
    }
  }

  // ── G5: Browse Counter Persistence ──────────────────────────

  Future<int> _restoreBrowseCounter() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedDate = prefs.getString(_kViewResetKey);
      if (savedDate == null) return 0;

      final saved = DateTime.tryParse(savedDate);
      final today = DateTime.now();
      // Same calendar day → restore count
      if (saved != null &&
          saved.year == today.year &&
          saved.month == today.month &&
          saved.day == today.day) {
        return prefs.getInt(_kViewCountKey) ?? 0;
      }
      // New day → reset
      await prefs.remove(_kViewCountKey);
      await prefs.remove(_kViewResetKey);
      return 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> _persistBrowseCounter(int count) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kViewCountKey, count);
      await prefs.setString(_kViewResetKey, DateTime.now().toIso8601String());
    } catch (_) {
      // Best-effort persistence
    }
  }

  // ── Filter Persistence ────────────────────────────────────

  Future<DiscoveryFilter?> _loadFilterFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kFilterKey);
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
        await prefs.remove(_kFilterKey);
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
      });
      await prefs.setString(_kFilterKey, json);
    } catch (e) {
      debugPrint('DiscoveryFeedCubit: failed to save filter: $e');
    }
  }

  void _resetCursors() {
    _backendCursorScore = null;
    _backendCursorId = null;
  }

  List<FeedProfile> _toFeedProfiles(
    List<MockProfile> profiles, {
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

    return {
      if (maxKm != null) 'max_distance_km': maxKm,
      if (f.distanceLabel == 'Same City') 'same_city': true,
      if (f.distanceLabel == 'Same Country') 'same_country': true,
      if (f.distanceLabel == 'Anywhere') 'anywhere': true,
      if (f.ageMin != null) 'age_min': f.ageMin,
      if (f.ageMax != null) 'age_max': f.ageMax,
      'active_recently': f.activeRecentlyOnly,
      if (f.sect != null && f.sect != 'Any') 'sect': f.sect!.toLowerCase(),
      if (f.deenLevel != null && f.deenLevel != 'Any')
        'deen_level': f.deenLevel!.toLowerCase(),
      'verified_only': f.verifiedOnly,
      if (f.familyType != null && f.familyType != 'Any')
        'family_type': f.familyType!.toLowerCase(),
      if (f.maritalStatus != null && f.maritalStatus != 'Any')
        'marital_status': f.maritalStatus == 'Never Married'
            ? 'no'
            : f.maritalStatus!.toLowerCase(),
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
      if (f.hasChildren != null) 'has_children': f.hasChildren!.toLowerCase(),
    };
  }

  /// Fetches real candidates and their stated compatibility preferences.
  Future<List<MockProfile>> _getPool({DiscoveryFilter? filter}) async {
    if (!SupabaseService.isInitialized) {
      throw StateError('Discovery requires a Supabase connection.');
    }
    final currentUserId = SupabaseService.currentUserId;
    if (currentUserId == null) {
      throw StateError('Please sign in to view discovery profiles.');
    }

    try {
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
      _updateBackendCursor(rows);
      await _attachCompatibilityPreferences(rows);
      final profiles = await compute(parseProfilesInBackground, rows);
      return _signPhotoUrls(profiles);
    } catch (e) {
      debugPrint('DiscoveryFeedCubit: Supabase discovery failed: $e');
      rethrow;
    }
  }

  Future<void> _attachCompatibilityPreferences(
    List<Map<String, dynamic>> rows,
  ) async {
    if (rows.isEmpty) return;
    final profileIds = rows
        .map((row) => row['profile_id'] as String?)
        .whereType<String>()
        .toList();
    if (profileIds.isEmpty) return;

    final response = await SupabaseService.client.rpc(
      'get_discovery_compatibility_preferences',
      params: {'p_profile_ids': profileIds},
    );
    final preferencesByProfile = <String, Map<String, dynamic>>{
      for (final raw in response as List<dynamic>)
        if ((raw as Map)['profile_id'] != null)
          raw['profile_id'] as String: Map<String, dynamic>.from(raw),
    };
    for (final row in rows) {
      final preferences = preferencesByProfile[row['profile_id']];
      if (preferences != null) row.addAll(preferences);
    }
  }

  void _emitDiscoveryError(Object error, {bool keepProfiles = false}) {
    if (isClosed) return;
    emit(state.copyWith(
      status: FeedStatus.error,
      profiles: keepProfiles ? state.profiles : const [],
      hasMore: false,
      errorMessage: error is StateError
          ? error.message
          : 'Unable to load profiles. Please try again.',
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
      default:
        return null;
    }
  }

  Future<List<MockProfile>> _signPhotoUrls(List<MockProfile> profiles) async {
    final signed = <MockProfile>[];
    for (final profile in profiles) {
      final path = profile.photoUrl;
      if (path == null || path.isEmpty || profile.isPhotoPrivate) {
        signed.add(profile);
        continue;
      }

      try {
        final url = await SupabaseService.client.storage
            .from('profile-photos')
            .createSignedUrl(path, 60 * 60);
        signed.add(profile.copyWith(photoUrl: url));
      } catch (e) {
        debugPrint('DiscoveryFeedCubit: failed to sign photo URL: $e');
        signed.add(profile.copyWith(clearPhotoUrl: true));
      }
    }
    return signed;
  }
}
