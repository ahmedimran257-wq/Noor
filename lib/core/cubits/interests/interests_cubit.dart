// lib/core/cubits/interests/interests_cubit.dart
// ============================================================
// NOOR — Interests Cubit (Mock)
// Manages the mock data state for the Interests Lifecycle.
// ============================================================

import 'package:flutter_bloc/flutter_bloc.dart';
import 'interests_state.dart';
import '../../mock/mock_profiles.dart';

class InterestsCubit extends Cubit<InterestsState> {
  InterestsCubit() : super(const InterestsState()) {
    _initMockData();
  }

  void _initMockData() {
    // Populate with some initial mock data
    final initialReceived = [
      InterestEntry(id: 'r1', profile: kMockProfiles[2], timeAgo: '2h ago'),
      InterestEntry(id: 'r2', profile: kMockProfiles[4], timeAgo: '1d ago'),
      InterestEntry(id: 'r3', profile: kMockProfiles[6], timeAgo: '3d ago'),
    ];

    final initialSent = [
      InterestEntry(id: 's1', profile: kMockProfiles[0], timeAgo: 'Yesterday'),
      InterestEntry(id: 's2', profile: kMockProfiles[3], timeAgo: '2d ago'),
    ];

    emit(InterestsState(received: initialReceived, sent: initialSent, matches: const []));
  }

  // ── Actions ──────────────────────────────────────────────────

  void acceptInterest(String id) {
    final updatedReceived = List<InterestEntry>.from(state.received);
    final index = updatedReceived.indexWhere((e) => e.id == id);
    if (index == -1) return;

    final acceptedEntry = updatedReceived[index].copyWith(status: InterestStatus.accepted);
    updatedReceived[index] = acceptedEntry;

    final updatedMatches = List<InterestEntry>.from(state.matches)..add(acceptedEntry);

    emit(state.copyWith(received: updatedReceived, matches: updatedMatches));
  }

  void sendInterest(MockProfile profile) {
    final newEntry = InterestEntry(
      id: 's_${DateTime.now().millisecondsSinceEpoch}',
      profile: profile,
      timeAgo: 'Just now',
      status: InterestStatus.pending,
    );

    final updatedSent = List<InterestEntry>.from(state.sent);
    updatedSent.insert(0, newEntry);

    emit(state.copyWith(sent: updatedSent));
  }

  void declineInterest(String id) {
    final updatedReceived = List<InterestEntry>.from(state.received);
    final index = updatedReceived.indexWhere((e) => e.id == id);
    if (index == -1) return;

    updatedReceived[index] = updatedReceived[index].copyWith(status: InterestStatus.declined);

    emit(state.copyWith(received: updatedReceived));
  }

  void withdrawInterest(String id) {
    final updatedSent = List<InterestEntry>.from(state.sent);
    final index = updatedSent.indexWhere((e) => e.id == id);
    if (index == -1) return;

    updatedSent[index] = updatedSent[index].copyWith(status: InterestStatus.withdrawn);

    emit(state.copyWith(sent: updatedSent));
  }
}
