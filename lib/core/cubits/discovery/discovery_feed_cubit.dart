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
// ============================================================

import 'package:flutter_bloc/flutter_bloc.dart';
import '../../mock/mock_profiles.dart';
import 'discovery_feed_state.dart';

class DiscoveryFeedCubit extends Cubit<DiscoveryFeedState> {
  DiscoveryFeedCubit() : super(const DiscoveryFeedState());

  static const _batchSize = 8;

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
  Future<void> loadInitial() async {
    if (state.status != FeedStatus.initial) return;
    emit(state.copyWith(status: FeedStatus.loading));
    await Future.delayed(const Duration(milliseconds: 1200));

    _cursor = 0;
    final filtered = _applyFilter(_pool, state.activeFilter);
    final batch    = _nextBatch(filtered, offset: 0);

    if (!isClosed) {
      emit(state.copyWith(
        status:   batch.isEmpty ? FeedStatus.empty : FeedStatus.loaded,
        profiles: batch,
        hasMore:  _cursor < filtered.length,
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
