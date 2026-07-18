// lib/core/cubits/interests/interests_state.dart
// ============================================================
// SILARAH — Interests State (Items 17 + 18)
//
// Blueprint (Part 8, Interest Lifecycle State Machine):
//   PENDING → ACCEPTED → MATCH_CREATED (chat unlocked)
//   PENDING → DECLINED
//   PENDING → EXPIRED (14 days)
//   PENDING → WITHDRAWN (sender, silent)
//
// Item 17: daily send limit tracking
// Item 18: createdAt + expiresAt on InterestEntry for expiry countdown
// ============================================================

import 'package:equatable/equatable.dart';
import '../../models/discovery_profile.dart';

enum InterestStatus {
  pending,
  accepted,
  declined,
  withdrawn,
  expired, // Auto-set after 14 days
}

class InterestEntry extends Equatable {
  const InterestEntry({
    required this.id,
    required this.profile,
    required this.timeAgo,
    required this.sentAt,
    required this.createdAt, // Item 18: expiry tracking
    this.status = InterestStatus.pending,
    this.note, // D1: optional interest note
  });

  final String id;
  final DiscoveryProfile profile;
  final String timeAgo;
  final DateTime sentAt;
  final DateTime createdAt; // Item 18
  final InterestStatus status;
  final String? note; // D1: personal interest note

  /// Item 18: Interest expires 14 days after creation.
  DateTime get expiresAt => createdAt.add(const Duration(days: 14));

  /// Blueprint: "Pending interests expire after 14 days."
  bool get isExpired =>
      status == InterestStatus.pending &&
      DateTime.now().difference(createdAt).inDays >= 14;

  /// Effective status (accounts for computed expiry)
  InterestStatus get effectiveStatus =>
      isExpired ? InterestStatus.expired : status;

  /// Item 18: Days remaining before expiry. Returns null if not pending.
  int? get daysRemaining {
    if (effectiveStatus != InterestStatus.pending) return null;
    final remaining = expiresAt.difference(DateTime.now());
    return remaining.inDays.clamp(0, 14);
  }

  /// Item 18: Hours remaining (for same-day expiry warning).
  int? get hoursRemaining {
    if (effectiveStatus != InterestStatus.pending) return null;
    final remaining = expiresAt.difference(DateTime.now());
    return remaining.inHours.clamp(0, 336);
  }

  InterestEntry copyWith({
    InterestStatus? status,
    String? timeAgo,
    String? note,
  }) {
    return InterestEntry(
      id: id,
      profile: profile,
      timeAgo: timeAgo ?? this.timeAgo,
      sentAt: sentAt,
      createdAt: createdAt,
      status: status ?? this.status,
      note: note ?? this.note,
    );
  }

  @override
  List<Object?> get props =>
      [id, profile, timeAgo, sentAt, createdAt, status, note];
}

class InterestsState extends Equatable {
  const InterestsState({
    this.received = const [],
    this.sent = const [],
    this.matches = const [],
    this.interestsSentToday = 0,
    this.dailyLimit = 0,
    this.lastResetDate,
    this.quotaResetsAt,
    this.isPremium = false,
    this.limitError = false,
    this.quotaUnavailable = false,
  });

  final List<InterestEntry> received;
  final List<InterestEntry> sent;
  final List<InterestEntry> matches;

  // Item 17: daily limit tracking
  final int interestsSentToday;
  final int dailyLimit;
  final DateTime? lastResetDate;
  final DateTime? quotaResetsAt;
  final bool isPremium;
  final bool limitError; // true only after hitting the daily cap
  final bool quotaUnavailable;

  // ── Computed getters ─────────────────────────────────────

  /// Pending received interests (shown with action buttons)
  List<InterestEntry> get pendingReceived => received
      .where((e) => e.effectiveStatus == InterestStatus.pending)
      .toList();

  /// Responded-to received interests (accepted or declined)
  List<InterestEntry> get respondedReceived => received
      .where((e) =>
          e.effectiveStatus == InterestStatus.accepted ||
          e.effectiveStatus == InterestStatus.declined)
      .toList();

  /// Combined received for display: pending first, then responded
  List<InterestEntry> get displayReceived =>
      [...pendingReceived, ...respondedReceived];

  /// Unread pending received count (for nav badge)
  int get unreadCount => pendingReceived.length;

  /// Item 17: Whether the daily limit has been reached
  bool get isDailyLimitReached =>
      dailyLimit > 0 && interestsSentToday >= dailyLimit;

  /// Item 17: Interests remaining today
  int get remainingToday =>
      (dailyLimit - interestsSentToday).clamp(0, dailyLimit);

  InterestsState copyWith({
    List<InterestEntry>? received,
    List<InterestEntry>? sent,
    List<InterestEntry>? matches,
    int? interestsSentToday,
    int? dailyLimit,
    DateTime? lastResetDate,
    DateTime? quotaResetsAt,
    bool? isPremium,
    bool? limitError,
    bool? quotaUnavailable,
    bool clearLimitError = false,
    bool clearQuotaUnavailable = false,
  }) {
    return InterestsState(
      received: received ?? this.received,
      sent: sent ?? this.sent,
      matches: matches ?? this.matches,
      interestsSentToday: interestsSentToday ?? this.interestsSentToday,
      dailyLimit: dailyLimit ?? this.dailyLimit,
      lastResetDate: lastResetDate ?? this.lastResetDate,
      quotaResetsAt: quotaResetsAt ?? this.quotaResetsAt,
      isPremium: isPremium ?? this.isPremium,
      limitError: clearLimitError ? false : (limitError ?? this.limitError),
      quotaUnavailable: clearQuotaUnavailable
          ? false
          : (quotaUnavailable ?? this.quotaUnavailable),
    );
  }

  @override
  List<Object?> get props => [
        received,
        sent,
        matches,
        interestsSentToday,
        dailyLimit,
        lastResetDate,
        quotaResetsAt,
        isPremium,
        limitError,
        quotaUnavailable,
      ];
}
