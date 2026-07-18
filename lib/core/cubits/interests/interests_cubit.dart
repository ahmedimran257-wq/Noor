// lib/core/cubits/interests/interests_cubit.dart
// ============================================================
// SILARAH — Interests Cubit (Supabase production flow)
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
import '../../utils/silarah_compute.dart';

class _InterestQuota {
  const _InterestQuota({
    required this.sentToday,
    required this.dailyLimit,
    required this.isPremium,
    required this.resetsAt,
  });

  final int sentToday;
  final int dailyLimit;
  final bool isPremium;
  final DateTime resetsAt;
}

class InterestsCubit extends Cubit<InterestsState> {
  InterestsCubit() : super(const InterestsState());

  bool _loadInFlight = false;
  DateTime? _lastLoadedAt;
  String? _loadedUserId;
  static const _freshness = Duration(minutes: 5);
  static const _maxRowsPerSection = 100;

  // ── Init ──────────────────────────────────────────────────

  Future<void> loadData({bool force = false}) async {
    if (!SupabaseService.isInitialized) return;
    final userId = SupabaseService.currentUserId;
    if (userId == null || _loadInFlight) return;
    final lastLoadedAt = _lastLoadedAt;
    if (!force &&
        _loadedUserId == userId &&
        lastLoadedAt != null &&
        DateTime.now().difference(lastLoadedAt) < _freshness) {
      return;
    }
    _loadInFlight = true;
    try {
      await _loadFromDb();
      _loadedUserId = userId;
      _lastLoadedAt = DateTime.now();
    } finally {
      _loadInFlight = false;
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

      // Fetch the three bounded sections and quota concurrently. Profiles and
      // photos are batch-loaded below, avoiding the former 3-5 queries per row.
      final results = await Future.wait<dynamic>([
        SupabaseService.client
            .from('interests')
            .select('id, sender_id, note, status, created_at, expires_at')
            .eq('receiver_id', userId)
            .eq('status', 'pending')
            .order('created_at', ascending: false)
            .limit(_maxRowsPerSection),
        SupabaseService.client
            .from('interests')
            .select('id, receiver_id, note, status, created_at, expires_at')
            .eq('sender_id', userId)
            .inFilter(
                'status', ['pending', 'accepted', 'declined', 'withdrawn'])
            .order('created_at', ascending: false)
            .limit(_maxRowsPerSection),
        SupabaseService.client
            .from('matches')
            .select('id, user_a, user_b, created_at')
            .or('user_a.eq.$userId,user_b.eq.$userId')
            .order('created_at', ascending: false)
            .limit(_maxRowsPerSection),
        _loadServerQuota(),
      ]);

      final receivedRows = results[0] as List<dynamic>;
      final sentRows = results[1] as List<dynamic>;
      final matchRows = results[2] as List<dynamic>;
      final quota = results[3] as _InterestQuota;
      final relatedUserIds = <String>{
        for (final row in receivedRows) row['sender_id'] as String,
        for (final row in sentRows) row['receiver_id'] as String,
        for (final row in matchRows)
          (row['user_a'] as String) == userId
              ? row['user_b'] as String
              : row['user_a'] as String,
      };
      final profilesByUser = await _loadProfilesForUsers(relatedUserIds);

      final received = <InterestEntry>[];
      for (final row in receivedRows) {
        final senderId = row['sender_id'] as String;
        final profile = profilesByUser[senderId];
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

      final sent = <InterestEntry>[];
      for (final row in sentRows) {
        final receiverId = row['receiver_id'] as String;
        final profile = profilesByUser[receiverId];
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

      final matches = <InterestEntry>[];
      for (final row in matchRows) {
        final otherUserId = (row['user_a'] as String) == userId
            ? row['user_b'] as String
            : row['user_a'] as String;
        final profile = profilesByUser[otherUserId];
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

      if (!isClosed) {
        emit(InterestsState(
          received: received,
          sent: sent,
          matches: matches,
          interestsSentToday: quota.sentToday,
          dailyLimit: quota.dailyLimit,
          lastResetDate: now,
          quotaResetsAt: quota.resetsAt,
          isPremium: quota.isPremium,
        ));
      }
    } catch (e) {
      debugPrint('[InterestsCubit] Error loading from DB: $e');
      if (!isClosed) {
        emit(const InterestsState(dailyLimit: 0, quotaUnavailable: true));
      }
    }
  }

  Future<Map<String, DiscoveryProfile>> _loadProfilesForUsers(
    Set<String> userIds,
  ) async {
    if (userIds.isEmpty) return const {};
    final rows = await SupabaseService.client.from('profiles').select('''
      id, user_id, first_name, last_name, date_of_birth, gender, country_code,
      sect, deen_level, photo_privacy, bio, profession, education_level,
      education_rank, family_type, previously_married, children_count,
      mother_tongue, community, living_expectation, quran_memorization,
      religious_education, willing_to_relocate, languages, interests,
      last_active_at, is_verified, cities:cities!city_id(name)
    ''').inFilter('user_id', userIds.toList(growable: false));

    final mappedRows = (rows as List<dynamic>).map((raw) {
      final row = Map<String, dynamic>.from(raw as Map);
      final city = row['cities'];
      if (city is Map) row['city_name'] = city['name'];
      return row;
    }).toList(growable: false);
    final profileIds = mappedRows
        .map((row) => row['id']?.toString())
        .whereType<String>()
        .toList(growable: false);
    final photos = profileIds.isEmpty
        ? const <dynamic>[]
        : await SupabaseService.client
            .from('photos')
            .select('profile_id, blurhash')
            .inFilter('profile_id', profileIds)
            .eq('status', 'active')
            .eq('admin_approved', true)
            .eq('nsfw_cleared', true)
            .order('order_index');
    final photosByProfile = <String, List<Map<String, dynamic>>>{};
    for (final raw in photos) {
      final photo = Map<String, dynamic>.from(raw as Map);
      final profileId = photo['profile_id']?.toString();
      if (profileId != null) {
        photosByProfile.putIfAbsent(profileId, () => []).add(photo);
      }
    }
    final photoOwners = mappedRows
        .where(
            (row) => photosByProfile[row['id']?.toString()]?.isNotEmpty == true)
        .map((row) => row['user_id']?.toString())
        .whereType<String>()
        .toList(growable: false);
    final signedUrls =
        await ProfilePhotoService.instance.getAuthorizedPhotoUrls(
      ownerUserIds: photoOwners,
    );

    final result = <String, DiscoveryProfile>{};
    for (final row in mappedRows) {
      final userId = row['user_id']?.toString();
      if (userId == null) continue;
      final profilePhotos = photosByProfile[row['id']?.toString()] ?? const [];
      row['photo_count'] = profilePhotos.length;
      row['photo_url'] = signedUrls[userId];
      if (profilePhotos.isNotEmpty) {
        row['blurhash'] = profilePhotos.first['blurhash'];
      }
      try {
        result[userId] = mapDbRowToDiscoveryProfile(row);
      } catch (error) {
        debugPrint('[InterestsCubit] Invalid profile $userId: $error');
      }
    }
    return result;
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
    _InterestQuota quota;
    try {
      quota = await _loadServerQuota();
    } catch (_) {
      if (isClosed) return;
      emit(state.copyWith(
        interestsSentToday: 0,
        dailyLimit: 0,
        quotaUnavailable: true,
      ));
      return;
    }
    if (isClosed) return;
    emit(state.copyWith(
      interestsSentToday: quota.sentToday,
      dailyLimit: quota.dailyLimit,
      lastResetDate: DateTime.now(),
      quotaResetsAt: quota.resetsAt,
      isPremium: quota.isPremium,
      clearQuotaUnavailable: true,
    ));
  }

  Future<_InterestQuota> _loadServerQuota() async {
    if (!SupabaseService.isInitialized ||
        SupabaseService.currentUserId == null) {
      throw StateError('Interest quota requires an authenticated session.');
    }
    try {
      final response = await SupabaseService.client.rpc('get_interest_quota');
      final rows = response as List<dynamic>;
      if (rows.isEmpty) {
        throw StateError('Interest quota response was empty.');
      }
      final row = Map<String, dynamic>.from(rows.first as Map);
      final sentToday = (row['sent_today'] as num?)?.toInt();
      final dailyLimit = (row['daily_limit'] as num?)?.toInt();
      final resetsAt = DateTime.tryParse(row['resets_at']?.toString() ?? '');
      final isPremium = row['is_premium'] == true;
      if (sentToday == null || dailyLimit == null || resetsAt == null) {
        throw StateError('Interest quota response was incomplete.');
      }
      return _InterestQuota(
        sentToday: sentToday,
        dailyLimit: dailyLimit,
        isPremium: isPremium,
        resetsAt: resetsAt.toLocal(),
      );
    } catch (e) {
      debugPrint('[InterestsCubit] Error loading server quota: $e');
      throw StateError('Unable to verify your daily interest limit.');
    }
  }

  /// Refreshes the authoritative allowance before opening a composer or note
  /// sheet. [sendInterest] checks again immediately before the insert so this
  /// is a UX optimization, never the security boundary.
  Future<bool> canStartInterest() async {
    try {
      final quota = await _loadServerQuota();
      if (isClosed) return false;
      emit(state.copyWith(
        interestsSentToday: quota.sentToday,
        dailyLimit: quota.dailyLimit,
        quotaResetsAt: quota.resetsAt,
        isPremium: quota.isPremium,
        limitError: quota.sentToday >= quota.dailyLimit,
        clearQuotaUnavailable: true,
      ));
      return quota.sentToday < quota.dailyLimit;
    } catch (_) {
      if (!isClosed) emit(state.copyWith(quotaUnavailable: true));
      return false;
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

    late final _InterestQuota quota;
    try {
      quota = await _loadServerQuota();
    } catch (_) {
      emit(state.copyWith(quotaUnavailable: true));
      return false;
    }
    if (quota.sentToday >= quota.dailyLimit) {
      emit(state.copyWith(
        interestsSentToday: quota.sentToday,
        dailyLimit: quota.dailyLimit,
        quotaResetsAt: quota.resetsAt,
        isPremium: quota.isPremium,
        limitError: true,
        clearQuotaUnavailable: true,
      ));
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
      if (e.toString().contains('interest_quota_exhausted') ||
          e.toString().contains('Daily interest limit')) {
        emit(state.copyWith(
          interestsSentToday: quota.sentToday,
          dailyLimit: quota.dailyLimit,
          quotaResetsAt: quota.resetsAt,
          isPremium: quota.isPremium,
          limitError: true,
          clearQuotaUnavailable: true,
        ));
        return false;
      }
      // For duplicate errors, treat as success because the server already has it.
      if (e.toString().contains('interest_already_exists') ||
          e.toString().contains('already sent')) {
        return true;
      }
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
    late final _InterestQuota updatedQuota;
    try {
      updatedQuota = await _loadServerQuota();
    } catch (_) {
      emit(state.copyWith(
        sent: updated,
        dailyLimit: 0,
        quotaUnavailable: true,
      ));
      return true;
    }

    emit(state.copyWith(
      sent: updated,
      interestsSentToday: updatedQuota.sentToday,
      dailyLimit: updatedQuota.dailyLimit,
      lastResetDate: now,
      quotaResetsAt: updatedQuota.resetsAt,
      isPremium: updatedQuota.isPremium,
      clearLimitError: true,
      clearQuotaUnavailable: true,
    ));
    return true;
  }

  void clearLimitError() {
    emit(state.copyWith(clearLimitError: true));
  }

  void clearQuotaUnavailable() {
    emit(state.copyWith(clearQuotaUnavailable: true));
  }

  void clear() {
    _loadInFlight = false;
    _lastLoadedAt = null;
    _loadedUserId = null;
    if (!isClosed) emit(const InterestsState());
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
