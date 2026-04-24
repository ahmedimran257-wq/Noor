// lib/core/cubits/interests/interests_cubit.dart
// ============================================================
// NOOR — Interests Cubit (Step 7 — Complete Lifecycle)
//
// Blueprint lifecycle:
//   send → PENDING
//   accept → ACCEPTED + match created
//   decline → DECLINED
//   withdraw → WITHDRAWN (silent, while PENDING)
//   14 days → EXPIRED (computed on InterestEntry)
//
// sendInterest() is called from discovery_feed_screen when the
// user taps "Send Interest" on a card or from ProfileDetailScreen.
// ============================================================

import 'package:flutter_bloc/flutter_bloc.dart';
import 'interests_state.dart';
import '../../mock/mock_profiles.dart';

class InterestsCubit extends Cubit<InterestsState> {
  InterestsCubit() : super(const InterestsState()) {
    _initMockData();
  }

  // ── Init mock data ────────────────────────────────────────

  void _initMockData() {
    final now = DateTime.now();

    final initialReceived = [
      InterestEntry(
        id:      'r1',
        profile: kMockProfiles[2],
        timeAgo: '2h ago',
        sentAt:  now.subtract(const Duration(hours: 2)),
      ),
      InterestEntry(
        id:      'r2',
        profile: kMockProfiles[4],
        timeAgo: '1d ago',
        sentAt:  now.subtract(const Duration(days: 1)),
      ),
      InterestEntry(
        id:      'r3',
        profile: kMockProfiles[6],
        timeAgo: '3d ago',
        sentAt:  now.subtract(const Duration(days: 3)),
      ),
    ];

    final initialSent = [
      InterestEntry(
        id:      's1',
        profile: kMockProfiles[0],
        timeAgo: 'Yesterday',
        sentAt:  now.subtract(const Duration(days: 1)),
        status:  InterestStatus.pending,
      ),
      InterestEntry(
        id:      's2',
        profile: kMockProfiles[3],
        timeAgo: '2d ago',
        sentAt:  now.subtract(const Duration(days: 2)),
        status:  InterestStatus.pending,
      ),
    ];

    emit(InterestsState(
      received: initialReceived,
      sent:     initialSent,
      matches:  const [],
    ));
  }

  // ── Received actions ──────────────────────────────────────

  /// Accept an incoming interest → creates a match, unlocks chat.
  void acceptInterest(String id) {
    final updated = List<InterestEntry>.from(state.received);
    final idx = updated.indexWhere((e) => e.id == id);
    if (idx == -1) return;

    final accepted = updated[idx].copyWith(status: InterestStatus.accepted);
    updated[idx] = accepted;

    final updatedMatches = List<InterestEntry>.from(state.matches)
      ..add(accepted);

    emit(state.copyWith(received: updated, matches: updatedMatches));
  }

  /// Decline an incoming interest.
  void declineInterest(String id) {
    final updated = List<InterestEntry>.from(state.received);
    final idx = updated.indexWhere((e) => e.id == id);
    if (idx == -1) return;

    updated[idx] = updated[idx].copyWith(status: InterestStatus.declined);
    emit(state.copyWith(received: updated));
  }

  // ── Sent actions ──────────────────────────────────────────

  /// Send an interest from the discovery feed or profile detail.
  /// Adds to the sent list immediately for UI feedback.
  void sendInterest(MockProfile profile) {
    // Prevent duplicate sends to the same profile
    final alreadySent = state.sent.any(
      (e) => e.profile.firstName == profile.firstName,
    );
    if (alreadySent) return;

    final entry = InterestEntry(
      id:      'sent_${DateTime.now().millisecondsSinceEpoch}',
      profile: profile,
      timeAgo: 'Just now',
      sentAt:  DateTime.now(),
      status:  InterestStatus.pending,
    );

    final updated = [entry, ...state.sent];
    emit(state.copyWith(sent: updated));
  }

  /// Withdraw a pending sent interest (silent — no notification to recipient).
  void withdrawInterest(String id) {
    final updated = List<InterestEntry>.from(state.sent);
    final idx = updated.indexWhere((e) => e.id == id);
    if (idx == -1) return;

    // Blueprint: "The user can withdraw a pending interest silently."
    updated[idx] = updated[idx].copyWith(status: InterestStatus.withdrawn);
    emit(state.copyWith(sent: updated));
  }

  // ── Simulation helpers ────────────────────────────────────

  /// Simulate the remote side accepting one of our sent interests.
  /// Used for demo purposes (e.g., a test button or auto-trigger).
  void simulateAcceptance(String sentId) {
    final updated = List<InterestEntry>.from(state.sent);
    final idx = updated.indexWhere((e) => e.id == sentId);
    if (idx == -1) return;

    updated[idx] = updated[idx].copyWith(status: InterestStatus.accepted);
    emit(state.copyWith(sent: updated));
  }

  /// Simulate the remote side declining.
  void simulateDecline(String sentId) {
    final updated = List<InterestEntry>.from(state.sent);
    final idx = updated.indexWhere((e) => e.id == sentId);
    if (idx == -1) return;

    updated[idx] = updated[idx].copyWith(status: InterestStatus.declined);
    emit(state.copyWith(sent: updated));
  }
}
