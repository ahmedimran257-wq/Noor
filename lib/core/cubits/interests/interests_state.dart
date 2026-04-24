// lib/core/cubits/interests/interests_state.dart
// ============================================================
// NOOR — Interests State
//
// Blueprint (Part 8, Interest Lifecycle State Machine):
//   PENDING → ACCEPTED → MATCH_CREATED (chat unlocked)
//   PENDING → DECLINED
//   PENDING → EXPIRED (14 days)
//   PENDING → WITHDRAWN (sender, silent)
// ============================================================

import 'package:equatable/equatable.dart';
import '../../mock/mock_profiles.dart';

enum InterestStatus {
  pending,
  accepted,
  declined,
  withdrawn,
  expired,   // Auto-set after 14 days (simulated)
}

class InterestEntry extends Equatable {
  const InterestEntry({
    required this.id,
    required this.profile,
    required this.timeAgo,
    required this.sentAt,
    this.status = InterestStatus.pending,
  });

  final String         id;
  final MockProfile    profile;
  final String         timeAgo;
  final DateTime       sentAt;
  final InterestStatus status;

  /// Blueprint: "Pending interests expire after 14 days."
  bool get isExpired =>
      status == InterestStatus.pending &&
      DateTime.now().difference(sentAt).inDays >= 14;

  /// Effective status (accounts for computed expiry)
  InterestStatus get effectiveStatus =>
      isExpired ? InterestStatus.expired : status;

  InterestEntry copyWith({
    InterestStatus? status,
    String?         timeAgo,
  }) {
    return InterestEntry(
      id:      id,
      profile: profile,
      timeAgo: timeAgo ?? this.timeAgo,
      sentAt:  sentAt,
      status:  status ?? this.status,
    );
  }

  @override
  List<Object?> get props => [id, profile, timeAgo, sentAt, status];
}

class InterestsState extends Equatable {
  const InterestsState({
    this.received = const [],
    this.sent     = const [],
    this.matches  = const [],
  });

  final List<InterestEntry> received;
  final List<InterestEntry> sent;
  final List<InterestEntry> matches;

  /// Pending received interests (shown with action buttons)
  List<InterestEntry> get pendingReceived =>
      received.where((e) => e.effectiveStatus == InterestStatus.pending).toList();

  /// Responded-to received interests (accepted or declined)
  List<InterestEntry> get respondedReceived =>
      received.where((e) =>
          e.effectiveStatus == InterestStatus.accepted ||
          e.effectiveStatus == InterestStatus.declined).toList();

  /// Combined received for display: pending first, then responded
  List<InterestEntry> get displayReceived =>
      [...pendingReceived, ...respondedReceived];

  /// Unread pending received count (for nav badge)
  int get unreadCount => pendingReceived.length;

  InterestsState copyWith({
    List<InterestEntry>? received,
    List<InterestEntry>? sent,
    List<InterestEntry>? matches,
  }) {
    return InterestsState(
      received: received ?? this.received,
      sent:     sent     ?? this.sent,
      matches:  matches  ?? this.matches,
    );
  }

  @override
  List<Object?> get props => [received, sent, matches];
}
