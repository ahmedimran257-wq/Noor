// SILARAH — Discovery Feed State (Step 6 update)
import 'package:equatable/equatable.dart';
import '../../models/discovery_profile.dart';
import 'discovery_filter.dart';

export 'discovery_filter.dart';

enum FeedStatus {
  initial,
  loading,
  refreshing,
  loaded,
  loadingMore,
  empty,
  error,
}

enum DiscoveryFailureKind {
  offline,
  unavailable,
  profileNotReady,
  authenticationRequired,
}

class FeedProfile extends Equatable {
  const FeedProfile({
    required this.profile,
    this.isWildCard = false,
    this.lastActiveAt,
  });

  final DiscoveryProfile profile;
  final bool isWildCard;
  final DateTime? lastActiveAt;

  /// G1: Human-readable last-active label computed from DateTime.
  String get lastActiveLabel {
    final t = lastActiveAt;
    if (t == null) return '';
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 5) return 'Online now';
    if (diff.inMinutes < 60) return 'Active ${diff.inMinutes}m ago';
    if (diff.inHours < 24) return 'Active ${diff.inHours}h ago';
    if (diff.inDays < 7) return 'Active ${diff.inDays}d ago';
    return 'Active ${diff.inDays ~/ 7}w ago';
  }

  @override
  List<Object?> get props => [profile, isWildCard, lastActiveAt];
}

class DiscoveryFeedState extends Equatable {
  const DiscoveryFeedState({
    this.status = FeedStatus.initial,
    this.profiles = const [],
    this.errorMessage,
    this.failureKind,
    this.hasMore = true,
    this.profilesViewedToday = 0,
    this.dailyLimit = 15,
    this.activeFilter = DiscoveryFilter.empty,
  });

  final FeedStatus status;
  final List<FeedProfile> profiles;
  final String? errorMessage;
  final DiscoveryFailureKind? failureKind;
  final bool hasMore;
  final int profilesViewedToday;
  final int dailyLimit;
  final DiscoveryFilter activeFilter;

  int get remainingToday =>
      (dailyLimit - profilesViewedToday).clamp(0, dailyLimit);
  bool get isFreeTierLimitReached => profilesViewedToday >= dailyLimit;

  DiscoveryFeedState copyWith({
    FeedStatus? status,
    List<FeedProfile>? profiles,
    String? errorMessage,
    DiscoveryFailureKind? failureKind,
    bool clearFailure = false,
    bool? hasMore,
    int? profilesViewedToday,
    int? dailyLimit,
    DiscoveryFilter? activeFilter,
  }) {
    return DiscoveryFeedState(
      status: status ?? this.status,
      profiles: profiles ?? this.profiles,
      errorMessage: clearFailure ? null : errorMessage ?? this.errorMessage,
      failureKind: clearFailure ? null : failureKind ?? this.failureKind,
      hasMore: hasMore ?? this.hasMore,
      profilesViewedToday: profilesViewedToday ?? this.profilesViewedToday,
      dailyLimit: dailyLimit ?? this.dailyLimit,
      activeFilter: activeFilter ?? this.activeFilter,
    );
  }

  @override
  List<Object?> get props => [
        status,
        profiles,
        errorMessage,
        failureKind,
        hasMore,
        profilesViewedToday,
        dailyLimit,
        activeFilter,
      ];
}
