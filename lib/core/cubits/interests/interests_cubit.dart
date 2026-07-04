// lib/core/cubits/interests/interests_cubit.dart
// ============================================================
// MITHAQ — Interests Cubit (Supabase production flow)
//
// Blueprint lifecycle:
//   send → PENDING  (gated by daily limit — Item 17)
//   accept → ACCEPTED + match created (DB trigger)
//   decline → DECLINED
//   withdraw → WITHDRAWN (silent, while PENDING) — Item 19
//   14 days → EXPIRED (DB cron job)
//
// Real mode: all operations hit Supabase interests/matches tables.
// Production mode: all operations hit Supabase.
// ============================================================

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'interests_state.dart';
import '../../models/discovery_profile.dart';
import '../../services/supabase_service.dart';
import '../../services/profile_photo_service.dart';
import '../../utils/content_filter.dart';
import '../../utils/mithaq_compute.dart';

class _InterestQuota {
  const _InterestQuota({
    required this.sentToday,
    required this.dailyLimit,
  });

  final int sentToday;
  final int dailyLimit;
}

class InterestsCubit extends Cubit<InterestsState> {
  InterestsCubit() : super(const InterestsState()) {
    _initData();
  }

  // ── Init ──────────────────────────────────────────────────

  Future<void> _initData() async {
    if (SupabaseService.isInitialized) {
      await _loadFromDb();
    } else {
      emit(const InterestsState());
    }
  }

  /// Load interests, sent interests, and matches from Supabase.
  Future<void> _loadFromDb() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) {
      if (!isClosed) emit(const InterestsState());
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
        if (profile == null) continue;
        final createdAt = DateTime.tryParse(row['created_at'] as String) ?? now;

        received.add(InterestEntry(
          id: row['id'] as String,
          profile: profile,
          timeAgo: _timeAgoString(createdAt),
          sentAt: createdAt,
          createdAt: createdAt,
          status: InterestStatus.pending,
          note: row['note'] as String?,
        ));
      }

      // Load sent interests (where I am the sender)
      final sentRows = await SupabaseService.client
          .from('interests')
          .select('id, receiver_id, note, status, created_at, expires_at')
          .eq('sender_id', userId)
          .inFilter('status', [
        'pending',
        'accepted',
        'declined',
        'withdrawn'
      ]).order('created_at', ascending: false);

      final sent = <InterestEntry>[];
      for (final row in (sentRows as List<dynamic>)) {
        final receiverId = row['receiver_id'] as String;
        final profile = await _loadProfileForUser(receiverId);
        if (profile == null) continue;
        final createdAt = DateTime.tryParse(row['created_at'] as String) ?? now;
        final statusStr = row['status'] as String;

        sent.add(InterestEntry(
          id: row['id'] as String,
          profile: profile,
          timeAgo: _timeAgoString(createdAt),
          sentAt: createdAt,
          createdAt: createdAt,
          status: _parseStatus(statusStr),
          note: row['note'] as String?,
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
        if (profile == null) continue;
        final createdAt = DateTime.tryParse(row['created_at'] as String) ?? now;

        matches.add(InterestEntry(
          id: row['id'] as String,
          profile: profile,
          timeAgo: _timeAgoString(createdAt),
          sentAt: createdAt,
          createdAt: createdAt,
          status: InterestStatus.accepted,
        ));
      }

      final quota = await _loadServerQuota();

      if (!isClosed) {
        emit(InterestsState(
          received: received,
          sent: sent,
          matches: matches,
          interestsSentToday: quota.sentToday,
          dailyLimit: quota.dailyLimit,
          lastResetDate: now,
        ));
      }
    } catch (e) {
      debugPrint('[InterestsCubit] Error loading from DB: $e');
      if (!isClosed) emit(const InterestsState());
    }
  }

  /// Load a real profile for a given user ID from Supabase.
  Future<DiscoveryProfile?> _loadProfileForUser(String userId) async {
    try {
      final row = await SupabaseService.client
          .from('profiles')
          .select(
            'user_id, first_name, last_name, date_of_birth, gender, city_id, '
            'country_code, sect, deen_level, photo_privacy, bio, profession, '
            'education_rank, family_type, previously_married, children_count, '
            'mother_tongue, community, living_expectation, quran_memorization, '
            'religious_education, willing_to_relocate, languages, interests, '
            'last_active_at, is_verified',
          )
          .eq('user_id', userId)
          .maybeSingle();

      if (row != null) {
        final mapped = Map<String, dynamic>.from(row);
        final cityId = mapped['city_id'];
        if (cityId != null) {
          final city = await SupabaseService.client
              .from('cities')
              .select('name')
              .eq('id', cityId)
              .maybeSingle();
          mapped['city_name'] = city?['name'];
        }

        final profile = await SupabaseService.client
            .from('profiles')
            .select('id')
            .eq('user_id', userId)
            .maybeSingle();
        final profileId = profile?['id'];
        if (profileId != null) {
          final photos = await SupabaseService.client
              .from('photos')
              .select('storage_path')
              .eq('profile_id', profileId)
              .eq('status', 'active')
              .eq('admin_approved', true)
              .eq('nsfw_cleared', true)
              .order('order_index');
          mapped['photo_count'] = photos.length;
          if (photos.isNotEmpty) {
            mapped['photo_url'] =
                await ProfilePhotoService.instance.getAuthorizedPhotoUrl(
              ownerUserId: userId,
            );
          }
        }

        return compute(parseSingleProfileInBackground, mapped);
      }
    } catch (e) {
      debugPrint('[InterestsCubit] Error loading profile for $userId: $e');
    }

    return null;
  }
  // ── Daily Limit (Item 17) ─────────────────────────────────

  void setDailyLimitForGender({
    required String gender,
    required bool isSubscribed,
  }) {
    refreshQuota();
  }

  void setDailyLimit(int limit) {
    refreshQuota();
  }

  Future<void> refreshQuota() async {
    final quota = await _loadServerQuota();
    if (isClosed) return;
    emit(state.copyWith(
      interestsSentToday: quota.sentToday,
      dailyLimit: quota.dailyLimit,
      lastResetDate: DateTime.now(),
    ));
  }

  Future<_InterestQuota> _loadServerQuota() async {
    if (!SupabaseService.isInitialized ||
        SupabaseService.currentUserId == null) {
      return const _InterestQuota(sentToday: 0, dailyLimit: 3);
    }
    try {
      final response = await SupabaseService.client.rpc('get_interest_quota');
      final rows = response as List<dynamic>;
      final row = rows.isNotEmpty
          ? Map<String, dynamic>.from(rows.first as Map)
          : <String, dynamic>{};
      return _InterestQuota(
        sentToday: (row['sent_today'] as num?)?.toInt() ?? 0,
        dailyLimit: (row['daily_limit'] as num?)?.toInt() ?? 3,
      );
    } catch (e) {
      debugPrint('[InterestsCubit] Error loading server quota: $e');
      return const _InterestQuota(sentToday: 0, dailyLimit: 3);
    }
  }

  // ── Received actions ──────────────────────────────────────

  /// Accept an incoming interest → creates a match (via DB trigger).
  void acceptInterest(String id) async {
    if (!SupabaseService.isInitialized) return;

    if (SupabaseService.isInitialized) {
      try {
        await SupabaseService.client
            .from('interests')
            .update({'status': 'accepted'}).eq('id', id);
        // DB trigger create_match_on_accept() automatically creates the match row
      } catch (e) {
        debugPrint('[InterestsCubit] Error accepting interest: $e');
        return;
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
    if (!SupabaseService.isInitialized) return;

    if (SupabaseService.isInitialized) {
      try {
        await SupabaseService.client
            .from('interests')
            .update({'status': 'declined'}).eq('id', id);
      } catch (e) {
        debugPrint('[InterestsCubit] Error declining interest: $e');
        return;
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
  Future<bool> sendInterest(DiscoveryProfile profile, {String? note}) async {
    if (!SupabaseService.isInitialized) return false;

    final quota = await _loadServerQuota();
    if (quota.sentToday >= quota.dailyLimit) {
      emit(state.copyWith(limitError: true));
      return false;
    }

    // Prevent duplicate sends to the same profile
    final alreadySent = state.sent.any(
      (e) =>
          e.profile.id == profile.id &&
          e.effectiveStatus == InterestStatus.pending,
    );
    if (alreadySent) return true;

    final now = DateTime.now();
    final filteredNote =
        note?.isNotEmpty == true ? ContentFilter.redact(note!) : null;

    String? interestId;

    final myId = SupabaseService.currentUserId;
    if (myId == null) return false;
    try {
      final result = await SupabaseService.client
          .from('interests')
          .insert({
            'sender_id': myId,
            'receiver_id': profile.id,
            if (filteredNote != null) 'note': filteredNote,
          })
          .select('id')
          .single();
      interestId = result['id'] as String;
    } catch (e) {
      debugPrint('[InterestsCubit] Error sending interest: $e');
      // If the DB rejects (e.g., daily limit hit by trigger), surface the error.
      if (e.toString().contains('Daily interest limit')) {
        emit(state.copyWith(limitError: true));
        return false;
      }
      // For duplicate errors, treat as success because the server already has it.
      if (e.toString().contains('already sent')) return true;
      return false;
    }

    if (interestId.isEmpty) return false;

    final entry = InterestEntry(
      id: interestId,
      profile: profile,
      timeAgo: 'Just now',
      sentAt: now,
      createdAt: now,
      status: InterestStatus.pending,
      note: filteredNote,
    );

    final updated = [entry, ...state.sent];
    final updatedQuota = await _loadServerQuota();

    emit(state.copyWith(
      sent: updated,
      interestsSentToday: updatedQuota.sentToday,
      dailyLimit: updatedQuota.dailyLimit,
      lastResetDate: now,
      clearLimitError: true,
    ));
    return true;
  }

  void clearLimitError() {
    emit(state.copyWith(clearLimitError: true));
  }

  /// Withdraw a pending sent interest (silent — no notification to recipient).
  void withdrawInterest(String id) async {
    if (!SupabaseService.isInitialized) return;

    if (SupabaseService.isInitialized) {
      try {
        await SupabaseService.client
            .from('interests')
            .update({'status': 'withdrawn'}).eq('id', id);
      } catch (e) {
        debugPrint('[InterestsCubit] Error withdrawing interest: $e');
        return;
      }
    }

    final updated = List<InterestEntry>.from(state.sent);
    final idx = updated.indexWhere((e) => e.id == id);
    if (idx == -1) return;

    updated[idx] = updated[idx].copyWith(status: InterestStatus.withdrawn);
    emit(state.copyWith(sent: updated));
  }

  // ── Simulation helpers ────────────────────────────────────

  // ── Helpers ───────────────────────────────────────────────

  InterestStatus _parseStatus(String s) {
    switch (s) {
      case 'pending':
        return InterestStatus.pending;
      case 'accepted':
        return InterestStatus.accepted;
      case 'declined':
        return InterestStatus.declined;
      case 'expired':
        return InterestStatus.expired;
      case 'withdrawn':
        return InterestStatus.withdrawn;
      default:
        return InterestStatus.pending;
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
