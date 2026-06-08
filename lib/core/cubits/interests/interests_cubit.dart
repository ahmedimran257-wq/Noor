// lib/core/cubits/interests/interests_cubit.dart
// ============================================================
// NOOR — Interests Cubit (Real Supabase + Mock Fallback)
//
// Blueprint lifecycle:
//   send → PENDING  (gated by daily limit — Item 17)
//   accept → ACCEPTED + match created (DB trigger)
//   decline → DECLINED
//   withdraw → WITHDRAWN (silent, while PENDING) — Item 19
//   14 days → EXPIRED (DB cron job)
//
// Real mode: all operations hit Supabase interests/matches tables.
// Mock mode: in-memory data with simulated delays.
// ============================================================

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'interests_state.dart';
import '../../mock/mock_profiles.dart';
import '../../services/supabase_service.dart';
import '../../utils/content_filter.dart';
import '../../utils/noor_compute.dart';

class InterestsCubit extends Cubit<InterestsState> {
  InterestsCubit() : super(const InterestsState()) {
    _initData();
  }

  static const _keyInterestsSentToday = 'interests_sent_today';
  static const _keyInterestsResetDate = 'interests_reset_date';

  bool get _isRealMode => SupabaseService.isInitialized;

  // ── Init ──────────────────────────────────────────────────

  Future<void> _initData() async {
    if (_isRealMode) {
      await _loadFromDb();
    } else {
      _initMockData();
    }
  }

  /// Load interests, sent interests, and matches from Supabase.
  Future<void> _loadFromDb() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) {
      _initMockData();
      return;
    }

    try {
      final now = DateTime.now();

      // Load received interests (where I am the receiver, pending only)
      final receivedRows = await SupabaseService.client
          .from('interests')
          .select('id, sender_id, note, status, created_at, expires_at')
          .eq('receiver_id', userId)
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      final received = <InterestEntry>[];
      for (final row in (receivedRows as List<dynamic>)) {
        final senderId = row['sender_id'] as String;
        final profile = await _loadProfileForUser(senderId);
        final createdAt = DateTime.tryParse(row['created_at'] as String) ?? now;

        received.add(InterestEntry(
          id:        row['id'] as String,
          profile:   profile,
          timeAgo:   _timeAgoString(createdAt),
          sentAt:    createdAt,
          createdAt: createdAt,
          status:    InterestStatus.pending,
          note:      row['note'] as String?,
        ));
      }

      // Load sent interests (where I am the sender)
      final sentRows = await SupabaseService.client
          .from('interests')
          .select('id, receiver_id, note, status, created_at, expires_at')
          .eq('sender_id', userId)
          .inFilter('status', ['pending', 'accepted', 'declined', 'withdrawn'])
          .order('created_at', ascending: false);

      final sent = <InterestEntry>[];
      for (final row in (sentRows as List<dynamic>)) {
        final receiverId = row['receiver_id'] as String;
        final profile = await _loadProfileForUser(receiverId);
        final createdAt = DateTime.tryParse(row['created_at'] as String) ?? now;
        final statusStr = row['status'] as String;

        sent.add(InterestEntry(
          id:        row['id'] as String,
          profile:   profile,
          timeAgo:   _timeAgoString(createdAt),
          sentAt:    createdAt,
          createdAt: createdAt,
          status:    _parseStatus(statusStr),
          note:      row['note'] as String?,
        ));
      }

      // Load matches
      final matchRows = await SupabaseService.client
          .from('matches')
          .select('id, user_a, user_b, created_at')
          .or('user_a.eq.$userId,user_b.eq.$userId')
          .order('created_at', ascending: false);

      final matches = <InterestEntry>[];
      for (final row in (matchRows as List<dynamic>)) {
        final otherUserId = (row['user_a'] as String) == userId
            ? row['user_b'] as String
            : row['user_a'] as String;
        final profile = await _loadProfileForUser(otherUserId);
        final createdAt = DateTime.tryParse(row['created_at'] as String) ?? now;

        matches.add(InterestEntry(
          id:        row['id'] as String,
          profile:   profile,
          timeAgo:   _timeAgoString(createdAt),
          sentAt:    createdAt,
          createdAt: createdAt,
          status:    InterestStatus.accepted,
        ));
      }

      // Count today's sent interests
      final todayStart = DateTime(now.year, now.month, now.day);
      final todaySent = sent.where((e) =>
        e.sentAt.isAfter(todayStart) &&
        e.status != InterestStatus.withdrawn
      ).length;

      if (!isClosed) {
        emit(InterestsState(
          received:           received,
          sent:               sent,
          matches:            matches,
          interestsSentToday: todaySent,
          dailyLimit:         3,   // default: free male — updated by setDailyLimitForGender
          lastResetDate:      now,
        ));
      }
    } catch (e) {
      debugPrint('[InterestsCubit] Error loading from DB: $e');
      _initMockData();
    }
  }

  /// Load a MockProfile for a given user ID from Supabase
  Future<MockProfile> _loadProfileForUser(String userId) async {
    try {
      final row = await SupabaseService.client
          .from('profiles')
          .select('user_id, first_name, last_name, date_of_birth, gender, city_id, sect, deen_level, photo_privacy, bio')
          .eq('user_id', userId)
          .maybeSingle();

      if (row != null) {
        return compute(parseSingleProfileInBackground, row);
      }
    } catch (e) {
      debugPrint('[InterestsCubit] Error loading profile for $userId: $e');
    }

    return const MockProfile(
      firstName: 'Noor User',
      lastNameInitial: '',
      age: 25,
      cityName: 'Unknown',
      sect: 'SUNNI',
      deenLevel: 'moderate',
      isVerified: false,
      occupation: 'Professional',
      education: 'Graduate',
      bio: '',
    );
  }

  // ── Mock data init (fallback) ─────────────────────────────

  void _initMockData() {
    if (kMockProfiles.isEmpty) return;

    final now = DateTime.now();

    // Safe access with fallback to first profile
    final p0 = kMockProfiles.first;
    final p2 = kMockProfiles.elementAtOrNull(2) ?? p0;
    final p3 = kMockProfiles.elementAtOrNull(3) ?? p0;
    final p4 = kMockProfiles.elementAtOrNull(4) ?? p0;
    final p6 = kMockProfiles.elementAtOrNull(6) ?? p0;

    final initialReceived = [
      InterestEntry(
        id:        'r1',
        profile:   p2,
        timeAgo:   '2h ago',
        sentAt:    now.subtract(const Duration(hours: 2)),
        createdAt: now.subtract(const Duration(hours: 2)),
      ),
      InterestEntry(
        id:        'r2',
        profile:   p4,
        timeAgo:   '1d ago',
        sentAt:    now.subtract(const Duration(days: 1)),
        createdAt: now.subtract(const Duration(days: 9)),
      ),
      InterestEntry(
        id:        'r3',
        profile:   p6,
        timeAgo:   '3d ago',
        sentAt:    now.subtract(const Duration(days: 3)),
        createdAt: now.subtract(const Duration(days: 11)),
      ),
    ];

    final initialSent = [
      InterestEntry(
        id:        's1',
        profile:   p0,
        timeAgo:   'Yesterday',
        sentAt:    now.subtract(const Duration(days: 1)),
        createdAt: now.subtract(const Duration(days: 1)),
        status:    InterestStatus.pending,
      ),
      InterestEntry(
        id:        's2',
        profile:   p3,
        timeAgo:   '2d ago',
        sentAt:    now.subtract(const Duration(days: 2)),
        createdAt: now.subtract(const Duration(days: 12)),
        status:    InterestStatus.pending,
      ),
    ];

    emit(InterestsState(
      received:           initialReceived,
      sent:               initialSent,
      matches:            const [],
      interestsSentToday: 2,
      dailyLimit:         3,
      lastResetDate:      now,
    ));
  }

  // ── Daily Limit (Item 17) ─────────────────────────────────

  void setDailyLimitForGender({
    required String gender,
    required bool   isSubscribed,
  }) {
    final int limit;
    if (gender == 'female') {
      limit = 10;
    } else if (isSubscribed) {
      limit = 20;
    } else {
      limit = 3;
    }
    emit(state.copyWith(dailyLimit: limit));
  }

  void setDailyLimit(int limit) {
    emit(state.copyWith(dailyLimit: limit));
  }

  Future<void> loadSavedCounter() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _dateOnly(DateTime.now());

    final savedDateStr = prefs.getString(_keyInterestsResetDate);
    final savedCount   = prefs.getInt(_keyInterestsSentToday) ?? 0;

    if (savedDateStr != null) {
      final savedDate = DateTime.tryParse(savedDateStr);
      if (savedDate != null && _dateOnly(savedDate) == today) {
        emit(state.copyWith(
          interestsSentToday: savedCount,
          lastResetDate:      savedDate,
        ));
        return;
      }
    }

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

  /// Accept an incoming interest → creates a match (via DB trigger).
  void acceptInterest(String id) async {
    if (_isRealMode) {
      try {
        await SupabaseService.client
            .from('interests')
            .update({'status': 'accepted'})
            .eq('id', id);
        // DB trigger create_match_on_accept() automatically creates the match row
      } catch (e) {
        debugPrint('[InterestsCubit] Error accepting interest: $e');
      }
    }

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
  void declineInterest(String id) async {
    if (_isRealMode) {
      try {
        await SupabaseService.client
            .from('interests')
            .update({'status': 'declined'})
            .eq('id', id);
      } catch (e) {
        debugPrint('[InterestsCubit] Error declining interest: $e');
      }
    }

    final updated = List<InterestEntry>.from(state.received);
    final idx = updated.indexWhere((e) => e.id == id);
    if (idx == -1) return;

    updated[idx] = updated[idx].copyWith(status: InterestStatus.declined);
    emit(state.copyWith(received: updated));
  }

  // ── Sent actions ──────────────────────────────────────────

  /// Send an interest from the discovery feed or profile detail.
  Future<bool> sendInterest(MockProfile profile, {String? note}) async {
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
    if (alreadySent) return true;

    final now   = DateTime.now();
    final filteredNote = note?.isNotEmpty == true ? ContentFilter.redact(note!) : null;

    String? interestId;

    if (_isRealMode) {
      final myId = SupabaseService.currentUserId;
      if (myId != null) {
        try {
          // The profile.id in mock mode is a composite string, but in real mode
          // we need the actual user_id. For profiles loaded from DB, the
          // firstName + lastNameInitial creates a unique key.
          // We'll use the profile name to find the user_id.
          // NOTE: In a fully wired system, profile cards would carry user_id.
          final result = await SupabaseService.client
              .from('interests')
              .insert({
                'sender_id':   myId,
                'receiver_id': profile.id, // This should be a real user UUID
                if (filteredNote != null) 'note': filteredNote,
              })
              .select('id')
              .single();
          interestId = result['id'] as String;
        } catch (e) {
          debugPrint('[InterestsCubit] Error sending interest: $e');
          // If the DB rejects (e.g., daily limit hit by trigger), surface the error
          if (e.toString().contains('Daily interest limit')) {
            emit(state.copyWith(limitError: true));
            return false;
          }
          // For duplicate errors, treat as success
          if (e.toString().contains('already sent')) return true;
        }
      }
    }

    final entry = InterestEntry(
      id:        interestId ?? 'sent_${now.millisecondsSinceEpoch}',
      profile:   profile,
      timeAgo:   'Just now',
      sentAt:    now,
      createdAt: now,
      status:    InterestStatus.pending,
      note:      filteredNote,
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

  void clearLimitError() {
    emit(state.copyWith(clearLimitError: true));
  }

  /// Withdraw a pending sent interest (silent — no notification to recipient).
  void withdrawInterest(String id) async {
    if (_isRealMode) {
      try {
        await SupabaseService.client
            .from('interests')
            .update({'status': 'withdrawn'})
            .eq('id', id);
      } catch (e) {
        debugPrint('[InterestsCubit] Error withdrawing interest: $e');
      }
    }

    final updated = List<InterestEntry>.from(state.sent);
    final idx = updated.indexWhere((e) => e.id == id);
    if (idx == -1) return;

    updated[idx] = updated[idx].copyWith(status: InterestStatus.withdrawn);
    emit(state.copyWith(sent: updated));
  }

  // ── Simulation helpers ────────────────────────────────────

  void simulateAcceptance(String sentId) {
    final updated = List<InterestEntry>.from(state.sent);
    final idx = updated.indexWhere((e) => e.id == sentId);
    if (idx == -1) return;

    updated[idx] = updated[idx].copyWith(status: InterestStatus.accepted);
    emit(state.copyWith(sent: updated));
  }

  void simulateDecline(String sentId) {
    final updated = List<InterestEntry>.from(state.sent);
    final idx = updated.indexWhere((e) => e.id == sentId);
    if (idx == -1) return;

    updated[idx] = updated[idx].copyWith(status: InterestStatus.declined);
    emit(state.copyWith(sent: updated));
  }

  // ── Helpers ───────────────────────────────────────────────

  InterestStatus _parseStatus(String s) {
    switch (s) {
      case 'pending':   return InterestStatus.pending;
      case 'accepted':  return InterestStatus.accepted;
      case 'declined':  return InterestStatus.declined;
      case 'expired':   return InterestStatus.expired;
      case 'withdrawn': return InterestStatus.withdrawn;
      default:          return InterestStatus.pending;
    }
  }

  String _timeAgoString(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays}d ago';
  }
}
