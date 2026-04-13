// lib/core/cubits/interests/interests_state.dart
// ============================================================
// NOOR — Interests State (Mock)
// Tracks the state of the mock interests lifecycle.
// ============================================================

import 'package:equatable/equatable.dart';
import '../../mock/mock_profiles.dart';

class InterestEntry extends Equatable {
  const InterestEntry({
    required this.id,
    required this.profile,
    required this.timeAgo,
    this.status = InterestStatus.pending,
  });

  final String        id;
  final MockProfile   profile;
  final String        timeAgo;
  final InterestStatus status;

  InterestEntry copyWith({InterestStatus? status, String? timeAgo}) {
    return InterestEntry(
      id:      id,
      profile: profile,
      timeAgo: timeAgo ?? this.timeAgo,
      status:  status ?? this.status,
    );
  }

  @override
  List<Object?> get props => [id, profile, timeAgo, status];
}

enum InterestStatus { pending, accepted, declined, withdrawn }

class InterestsState extends Equatable {
  const InterestsState({
    this.received = const [],
    this.sent     = const [],
    this.matches  = const [],
  });

  final List<InterestEntry> received;
  final List<InterestEntry> sent;
  final List<InterestEntry> matches; // Where status is accepted

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
