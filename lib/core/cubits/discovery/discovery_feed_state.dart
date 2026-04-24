// lib/core/cubits/discovery/discovery_feed_state.dart
// ============================================================
// NOOR — Discovery Feed State (Step 6 update)
// ============================================================

import 'package:equatable/equatable.dart';
import '../../mock/mock_profiles.dart';
import 'discovery_filter.dart';

export 'discovery_filter.dart';

enum FeedStatus { initial, loading, loaded, loadingMore, empty, error }

class FeedProfile extends Equatable {
  const FeedProfile({
    required this.profile,
    this.isWildCard = false,
  });

  final MockProfile profile;
  final bool isWildCard;

  @override
  List<Object?> get props => [profile, isWildCard];
}

class DiscoveryFeedState extends Equatable {
  const DiscoveryFeedState({
    this.status              = FeedStatus.initial,
    this.profiles            = const [],
    this.errorMessage,
    this.hasMore             = true,
    this.profilesViewedToday = 0,
    this.dailyLimit          = 15,
    this.activeFilter        = DiscoveryFilter.empty,
  });

  final FeedStatus          status;
  final List<FeedProfile>   profiles;
  final String?             errorMessage;
  final bool                hasMore;
  final int                 profilesViewedToday;
  final int                 dailyLimit;
  final DiscoveryFilter     activeFilter;

  int  get remainingToday          => (dailyLimit - profilesViewedToday).clamp(0, dailyLimit);
  bool get isFreeTierLimitReached  => profilesViewedToday >= dailyLimit;

  DiscoveryFeedState copyWith({
    FeedStatus?        status,
    List<FeedProfile>? profiles,
    String?            errorMessage,
    bool?              hasMore,
    int?               profilesViewedToday,
    int?               dailyLimit,
    DiscoveryFilter?   activeFilter,
  }) {
    return DiscoveryFeedState(
      status:              status              ?? this.status,
      profiles:            profiles            ?? this.profiles,
      errorMessage:        errorMessage        ?? this.errorMessage,
      hasMore:             hasMore             ?? this.hasMore,
      profilesViewedToday: profilesViewedToday ?? this.profilesViewedToday,
      dailyLimit:          dailyLimit          ?? this.dailyLimit,
      activeFilter:        activeFilter        ?? this.activeFilter,
    );
  }

  @override
  List<Object?> get props => [
    status, profiles, errorMessage, hasMore,
    profilesViewedToday, dailyLimit, activeFilter,
  ];
}
