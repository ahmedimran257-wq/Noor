// lib/core/cubits/discovery/discovery_feed_cubit.dart
// ============================================================
// NOOR — Discovery Feed Cubit (Step 6 — Filter-aware)
//
// Blueprint (Part 8):
//   • Cursor-based pagination — no offset drift, no duplicates
//   • Every 10th profile: "Someone you might connect with"
//   • Free-tier counter
//   • Sector / Deen / Age / Verified / FamilyType filters
//     applied in-memory against the mock pool
//
// Filter persistence: active filter is saved to SharedPreferences
// so it survives app restarts.
// ============================================================

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../mock/mock_profiles.dart';
import 'discovery_feed_state.dart';

class DiscoveryFeedCubit extends Cubit<DiscoveryFeedState> {
  DiscoveryFeedCubit() : super(const DiscoveryFeedState());

  static const _batchSize  = 8;
  static const _kFilterKey = 'discovery_active_filter';

  // Extended mock pool (5 rotations for infinite-scroll demo)
  static final List<MockProfile> _pool = [
    ...kMockProfiles,
    ...kMockProfiles.reversed,
    ...kMockProfiles,
    ...kMockProfiles.reversed,
    ...kMockProfiles,
  ];

  int _cursor = 0;

  // ── Public API ────────────────────────────────────────────

  /// Initial page load — shows skeleton loaders first.
  /// Also restores saved filter from SharedPreferences.
  Future<void> loadInitial() async {
    if (state.status != FeedStatus.initial) return;
    emit(state.copyWith(status: FeedStatus.loading));

    // Restore saved filter
    final savedFilter = await _loadFilterFromPrefs();
    final filter = savedFilter ?? state.activeFilter;

    await Future.delayed(const Duration(milliseconds: 1200));

    _cursor = 0;
    final filtered = _applyFilter(_pool, filter);
    final batch    = _nextBatch(filtered, offset: 0);

    if (!isClosed) {
      emit(state.copyWith(
        status:       batch.isEmpty ? FeedStatus.empty : FeedStatus.loaded,
        profiles:     batch,
        hasMore:      _cursor < filtered.length,
        activeFilter: filter,
      ));
    }
  }

  /// Load next page (append).
  Future<void> loadMore() async {
    if (state.status == FeedStatus.loadingMore) return;
    if (!state.hasMore) return;

    emit(state.copyWith(status: FeedStatus.loadingMore));
    await Future.delayed(const Duration(milliseconds: 1400));

    final filtered = _applyFilter(_pool, state.activeFilter);
    final batch    = _nextBatch(filtered, offset: state.profiles.length);

    if (!isClosed) {
      emit(state.copyWith(
        status:   FeedStatus.loaded,
        profiles: [...state.profiles, ...batch],
        hasMore:  _cursor < filtered.length,
      ));
    }
  }

  /// Apply new filters — resets the feed and reloads from cursor 0.
  Future<void> applyFilter(DiscoveryFilter filter) async {
    emit(state.copyWith(status: FeedStatus.loading, activeFilter: filter));

    // Persist the filter
    await _saveFilterToPrefs(filter);

    await Future.delayed(const Duration(milliseconds: 800));

    _cursor = 0;
    final filtered = _applyFilter(_pool, filter);
    final batch    = _nextBatch(filtered, offset: 0);

    if (!isClosed) {
      emit(state.copyWith(
        status:   batch.isEmpty ? FeedStatus.empty : FeedStatus.loaded,
        profiles: batch,
        hasMore:  _cursor < filtered.length,
      ));
    }
  }

  /// Clear all filters and reload.
  Future<void> clearFilters() => applyFilter(DiscoveryFilter.empty);

  void recordProfileView() {
    if (!isClosed) {
      emit(state.copyWith(profilesViewedToday: state.profilesViewedToday + 1));
    }
  }

  // ── Filter Persistence ────────────────────────────────────

  Future<DiscoveryFilter?> _loadFilterFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw   = prefs.getString(_kFilterKey);
      if (raw == null || raw.isEmpty) return null;

      final j = jsonDecode(raw) as Map<String, dynamic>;
      return DiscoveryFilter(
        ageMin:             j['ageMin'] as int?,
        ageMax:             j['ageMax'] as int?,
        sect:               j['sect'] as String?,
        deenLevel:          j['deenLevel'] as String?,
        verifiedOnly:       (j['verifiedOnly'] as bool?) ?? false,
        activeRecentlyOnly: (j['activeRecentlyOnly'] as bool?) ?? false,
        maxDistanceKm:      j['maxDistanceKm'] as int?,
        familyType:         j['familyType'] as String?,
        openToDivorced:     (j['openToDivorced'] as bool?) ?? false,
        genderPref:         j['genderPref'] as String?,
        maritalStatus:      j['maritalStatus'] as String?,
        hasChildren:        j['hasChildren'] as String?,
        educationMin:       j['educationMin'] as String?,
        distanceLabel:      j['distanceLabel'] as String?,
        motherTongue:       j['motherTongue'] as String?,
        community:          j['community'] as String?,
        livingExpectation:  j['livingExpectation'] as String?,
        quranMemorization:  j['quranMemorization'] as String?,
        marriageTimeline:   j['marriageTimeline'] as String?,
        willingToRelocate:  j['willingToRelocate'] as String?,
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
        'ageMin':             f.ageMin,
        'ageMax':             f.ageMax,
        'sect':               f.sect,
        'deenLevel':          f.deenLevel,
        'verifiedOnly':       f.verifiedOnly,
        'activeRecentlyOnly': f.activeRecentlyOnly,
        'maxDistanceKm':      f.maxDistanceKm,
        'familyType':         f.familyType,
        'openToDivorced':     f.openToDivorced,
        'genderPref':         f.genderPref,
        'maritalStatus':      f.maritalStatus,
        'hasChildren':        f.hasChildren,
        'educationMin':       f.educationMin,
        'distanceLabel':      f.distanceLabel,
        'motherTongue':       f.motherTongue,
        'community':          f.community,
        'livingExpectation':  f.livingExpectation,
        'quranMemorization':  f.quranMemorization,
        'marriageTimeline':   f.marriageTimeline,
        'willingToRelocate':  f.willingToRelocate,
      });
      await prefs.setString(_kFilterKey, json);
    } catch (e) {
      debugPrint('DiscoveryFeedCubit: failed to save filter: $e');
    }
  }

  // ── Internal helpers ──────────────────────────────────────

  /// Apply filter predicate to the full mock pool.
  List<MockProfile> _applyFilter(List<MockProfile> pool, DiscoveryFilter f) {
    if (!f.isActive) return pool;
    return pool.where((p) {
      if (f.sect != null && f.sect!.isNotEmpty && p.sect != f.sect) return false;
      if (f.deenLevel != null && f.deenLevel!.isNotEmpty && p.deenLevel != f.deenLevel) return false;
      if (f.verifiedOnly && !p.isVerified) return false;
      if (f.ageMin != null && p.age < f.ageMin!) return false;
      if (f.ageMax != null && p.age > f.ageMax!) return false;
      if (f.familyType != null && f.familyType!.isNotEmpty && p.familyType != f.familyType) return false;
      if (!f.openToDivorced && p.maritalStatus != null && p.maritalStatus != 'Never Married') return false;
      // Phase 7 filters
      if (f.quranMemorization != null && f.quranMemorization!.isNotEmpty && p.quranMemorization != f.quranMemorization) return false;
      if (f.marriageTimeline != null && f.marriageTimeline!.isNotEmpty && p.marriageTimeline != f.marriageTimeline) return false;
      if (f.willingToRelocate != null && f.willingToRelocate!.isNotEmpty && p.willingToRelocate != f.willingToRelocate) return false;
      if (f.motherTongue != null && f.motherTongue!.isNotEmpty && p.motherTongue != f.motherTongue) return false;
      if (f.community != null && f.community!.isNotEmpty && p.community != f.community) return false;
      if (f.livingExpectation != null && f.livingExpectation!.isNotEmpty && p.livingExpectation != f.livingExpectation) return false;
      if (f.genderPref != null && f.genderPref!.isNotEmpty && p.gender != f.genderPref) return false;
      if (f.hasChildren != null && f.hasChildren == 'no' && p.hasChildren) return false;
      return true;
    }).toList();
  }

  /// Produce next batch with wild-card injection every 10th profile.
  List<FeedProfile> _nextBatch(List<MockProfile> filtered, {required int offset}) {
    if (_cursor >= filtered.length) return [];

    final end  = (_cursor + _batchSize).clamp(0, filtered.length);
    final list = <FeedProfile>[];

    for (int i = _cursor; i < end; i++) {
      final feedIndex = offset + (i - _cursor);
      final isWild    = feedIndex > 0 && (feedIndex + 1) % 10 == 0;
      list.add(FeedProfile(profile: filtered[i], isWildCard: isWild));
    }
    _cursor = end;
    return list;
  }
}
