// lib/core/cubits/interests/interests_cubit.dart
// ============================================================
// NOOR — Interests Cubit (Items 17, 18, 19)
//
// Blueprint lifecycle:
//   send → PENDING  (gated by daily limit — Item 17)
//   accept → ACCEPTED + match created
//   decline → DECLINED
//   withdraw → WITHDRAWN (silent, while PENDING) — Item 19
//   14 days → EXPIRED (computed on InterestEntry — Item 18)
//
// sendInterest() returns bool: true on success, false on limit hit.
// ============================================================

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'interests_state.dart';
import '../../mock/mock_profiles.dart';

class InterestsCubit extends Cubit<InterestsState> {
  InterestsCubit() : super(const InterestsState()) {
    _initMockData();
  }

  static const _keyInterestsSentToday = 'interests_sent_today';
  static const _keyInterestsResetDate = 'interests_reset_date';

  // ── Init mock data ────────────────────────────────────────

  void _initMockData() {
    // Guard against an undersized mock list
    if (kMockProfiles.length < 7) return;

    final now = DateTime.now();

    final initialReceived = [
      InterestEntry(
        id:        'r1',
        profile:   kMockProfiles[2],
        timeAgo:   '2h ago',
        sentAt:    now.subtract(const Duration(hours: 2)),
        createdAt: now.subtract(const Duration(hours: 2)),
      ),
      InterestEntry(
        id:        'r2',
        profile:   kMockProfiles[4],
        timeAgo:   '1d ago',
        sentAt:    now.subtract(const Duration(days: 1)),
        createdAt: now.subtract(const Duration(days: 9)),   // expires in 5 days
      ),
      InterestEntry(
        id:        'r3',
        profile:   kMockProfiles[6],
        timeAgo:   '3d ago',
        sentAt:    now.subtract(const Duration(days: 3)),
        createdAt: now.subtract(const Duration(days: 11)),  // expires in ~3 days
      ),
    ];

    final initialSent = [
      InterestEntry(
        id:        's1',
        profile:   kMockProfiles[0],
        timeAgo:   'Yesterday',
        sentAt:    now.subtract(const Duration(days: 1)),
        createdAt: now.subtract(const Duration(days: 1)),
        status:    InterestStatus.pending,
      ),
      InterestEntry(
        id:        's2',
        profile:   kMockProfiles[3],
        timeAgo:   '2d ago',
        sentAt:    now.subtract(const Duration(days: 2)),
        createdAt: now.subtract(const Duration(days: 12)),  // expires in ~2 days
        status:    InterestStatus.pending,
      ),
    ];

    emit(InterestsState(
      received:           initialReceived,
      sent:               initialSent,
      matches:            const [],
      interestsSentToday: 2,
      dailyLimit:         3,   // default: free male
      lastResetDate:      now,
    ));
  }

  // ── Daily Limit (Item 17) ─────────────────────────────────

  /// Call once gender + subscription status are known.
  ///
  /// Blueprint:
  ///   female              → unlimited (no banner shown)
  ///   male, no sub        → 3 per day
  ///   male, subscribed    → 20 per day
  ///
  /// We use 9999 as sentinel for "unlimited" so the math in
  /// isDailyLimitReached / remainingToday still works without
  /// special-casing it everywhere.
  void setDailyLimitForGender({
    required String gender,
    required bool   isSubscribed,
  }) {
    final int limit;
    if (gender == 'female') {
      limit = 9999; // unlimited — blueprint: women send interests free
    } else if (isSubscribed) {
      limit = 20;
    } else {
      limit = 3;
    }
    emit(state.copyWith(dailyLimit: limit));
  }

  /// Convenience alias kept for backward compat.
  void setDailyLimit(int limit) {
    emit(state.copyWith(dailyLimit: limit));
  }

  /// Restore saved counter from SharedPreferences on app launch.
  Future<void> loadSavedCounter() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _dateOnly(DateTime.now());

    final savedDateStr = prefs.getString(_keyInterestsResetDate);
    final savedCount   = prefs.getInt(_keyInterestsSentToday) ?? 0;

    if (savedDateStr != null) {
      final savedDate = DateTime.tryParse(savedDateStr);
      if (savedDate != null && _dateOnly(savedDate) == today) {
        // Same day — restore count
        emit(state.copyWith(
          interestsSentToday: savedCount,
          lastResetDate:      savedDate,
        ));
        return;
      }
    }

    // New day — reset
    await _resetCounter(prefs);
  }

  Future<void> _resetCounter(SharedPreferences prefs) async {
    final now = DateTime.now();
    await prefs.setInt(_keyInterestsSentToday, 0);
    await prefs.setString(_keyInterestsResetDate, now.toIso8601String());
    emit(state.copyWith(
      interestsSentToday: 0,
      lastResetDate:      now,
    ));
  }

  DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

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
  /// Returns true on success, false if daily limit reached.
  /// Item 17: enforces daily limit and persists count.
  Future<bool> sendInterest(MockProfile profile) async {
    // Check reset first
    final today = _dateOnly(DateTime.now());
    if (state.lastResetDate == null ||
        _dateOnly(state.lastResetDate!) != today) {
      final prefs = await SharedPreferences.getInstance();
      await _resetCounter(prefs);
    }

    // Enforce daily limit
    if (state.isDailyLimitReached) {
      emit(state.copyWith(limitError: true));
      return false;
    }

    // Prevent duplicate sends to the same profile
    final alreadySent = state.sent.any(
      (e) => e.profile.id == profile.id &&
             e.effectiveStatus == InterestStatus.pending,
    );
    if (alreadySent) return true; // silent no-op, already sent

    final now   = DateTime.now();
    final entry = InterestEntry(
      id:        'sent_${now.millisecondsSinceEpoch}',
      profile:   profile,
      timeAgo:   'Just now',
      sentAt:    now,
      createdAt: now,
      status:    InterestStatus.pending,
    );

    final updated        = [entry, ...state.sent];
    final newSentToday   = state.interestsSentToday + 1;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyInterestsSentToday, newSentToday);
    await prefs.setString(_keyInterestsResetDate, now.toIso8601String());

    emit(state.copyWith(
      sent:               updated,
      interestsSentToday: newSentToday,
      clearLimitError:    true,
    ));
    return true;
  }

  /// Clear the limit error flag after showing SnackBar.
  void clearLimitError() {
    emit(state.copyWith(clearLimitError: true));
  }

  /// Withdraw a pending sent interest (silent — no notification to recipient).
  /// Item 19: blueprint: "The user can withdraw a pending interest silently."
  void withdrawInterest(String id) {
    final updated = List<InterestEntry>.from(state.sent);
    final idx = updated.indexWhere((e) => e.id == id);
    if (idx == -1) return;

    updated[idx] = updated[idx].copyWith(status: InterestStatus.withdrawn);
    emit(state.copyWith(sent: updated));
  }

  // ── Simulation helpers ────────────────────────────────────

  /// Simulate the remote side accepting one of our sent interests.
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
