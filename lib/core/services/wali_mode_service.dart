// lib/core/services/wali_mode_service.dart
// ============================================================
// NOOR — Wali (Guardian) Mode Service
//
// Fixes Audit Finding 3.1 (Critical):
//   Provides guardian link flow, mirrored chat access, realtime
//   message subscription, and guardian dashboard for full in-app
//   chat mirroring (Active Realtime Guardian).
//
// The guardian gets their own login to the app with a dedicated
// dashboard showing all active chats their ward is engaged in.
// Messages appear live via Supabase Realtime.
// ============================================================

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

/// Manages Wali (Guardian) mode operations.
///
/// Supports two modes:
/// - **Passive**: Guardian sees read-only chat transcripts in real-time
/// - **Active**: Guardian can also send messages and approve matches
///
/// The guardian has their own unique login and sees a dashboard of
/// all active chats their ward is engaged in, with live message
/// updates via Supabase Realtime.
class WaliModeService {
  WaliModeService._();
  static final instance = WaliModeService._();

  SupabaseClient get _supabase {
    if (!SupabaseService.isInitialized) {
      throw StateError('Supabase is not initialized. Ensure SupabaseService.initialize() is called first.');
    }
    return SupabaseService.client;
  }

  // ── Realtime ────────────────────────────────────────────────
  RealtimeChannel? _realtimeChannel;
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();

  /// Stream of new messages arriving in mirrored chats.
  /// Each event is the raw message payload from Supabase Realtime.
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;

  /// Whether the Realtime channel is currently connected.
  bool get isRealtimeConnected => _realtimeChannel != null;

  /// Activates guardian mode by linking the current user as a guardian
  /// to a ward's profile.
  ///
  /// The caller must be authenticated as the guardian.
  /// [wardProfileId] is the profile UUID of the person being guarded.
  /// [guardianPhone] is the phone number to verify against the stored
  /// encrypted guardian phone.
  ///
  /// Returns a map with activation status and mode.
  Future<Map<String, dynamic>> activateGuardian({
    required String wardProfileId,
    required String guardianPhone,
  }) async {
    try {
      final response = await _supabase.rpc(
        'activate_guardian',
        params: {
          'p_ward_profile_id': wardProfileId,
          'p_guardian_phone': guardianPhone,
        },
      );

      final result = response as Map<String, dynamic>;
      debugPrint('[WaliModeService] Guardian activated: $result');
      return result;
    } catch (e) {
      debugPrint('[WaliModeService] Activation error: $e');
      rethrow;
    }
  }

  // ── Dashboard ───────────────────────────────────────────────

  /// Fetches the full guardian dashboard data via the
  /// `get_guardian_dashboard()` RPC.
  ///
  /// Returns a list of active conversations the guardian can see,
  /// including ward name, other party details, last message,
  /// unread count, and match approval status.
  Future<List<GuardianDashboardItem>> getDashboard() async {
    try {
      final response = await _supabase.rpc('get_guardian_dashboard');
      final rows = response as List<dynamic>;

      return rows.map((row) {
        final r = row as Map<String, dynamic>;
        return GuardianDashboardItem(
          wardName: r['ward_name'] as String? ?? 'Unknown',
          wardProfileId: r['ward_profile_id'] as String,
          wardUserId: r['ward_user_id'] as String,
          matchId: r['match_id'] as String,
          otherPartyName: r['other_party_name'] as String? ?? 'Unknown',
          otherPartyPhoto: r['other_party_photo'] as String?,
          lastMessage: r['last_message'] as String?,
          lastMessageAt: r['last_message_at'] != null
              ? DateTime.parse(r['last_message_at'] as String)
              : null,
          unreadCount: (r['unread_count'] as num?)?.toInt() ?? 0,
          guardianMode: r['guardian_mode'] as String,
          matchStatus: r['match_status'] as String,
          guardianApproved: r['guardian_approved'] as bool?,
          matchCreatedAt: r['match_created_at'] != null
              ? DateTime.parse(r['match_created_at'] as String)
              : null,
        );
      }).toList();
    } catch (e) {
      debugPrint('[WaliModeService] Dashboard fetch error: $e');
      return [];
    }
  }

  /// Gets all mirrored chats for the current guardian user.
  ///
  /// Returns a list of match conversations the guardian has access to,
  /// including the ward's name and the other party's name.
  Future<List<GuardianMirroredChat>> getMirroredChats() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('Not authenticated');

      final response = await _supabase
          .from('guardian_chat_mirrors')
          .select('''
            id,
            match_id,
            ward_id,
            mode,
            matches!inner (
              id,
              user_a,
              user_b,
              status,
              last_message_at,
              created_at
            )
          ''')
          .eq('guardian_id', userId)
          .order('created_at', ascending: false);

      final mirrors = response as List<dynamic>;

      final chats = <GuardianMirroredChat>[];

      for (final mirror in mirrors) {
        final match = mirror['matches'] as Map<String, dynamic>;

        // Determine who the ward is talking to
        final otherUserId = match['user_a'] == mirror['ward_id']
            ? match['user_b'] as String
            : match['user_a'] as String;

        // Fetch names
        final wardProfile = await _supabase
            .from('profiles')
            .select('first_name')
            .eq('user_id', mirror['ward_id'])
            .single();

        final otherProfile = await _supabase
            .from('profiles')
            .select('first_name')
            .eq('user_id', otherUserId)
            .single();

        chats.add(GuardianMirroredChat(
          mirrorId: mirror['id'] as String,
          matchId: mirror['match_id'] as String,
          wardId: mirror['ward_id'] as String,
          wardName: wardProfile['first_name'] as String? ?? 'Unknown',
          otherPartyId: otherUserId,
          otherPartyName: otherProfile['first_name'] as String? ?? 'Unknown',
          mode: mirror['mode'] as String,
          matchStatus: match['status'] as String,
          lastMessageAt: match['last_message_at'] != null
              ? DateTime.parse(match['last_message_at'] as String)
              : null,
        ));
      }

      return chats;
    } catch (e) {
      debugPrint('[WaliModeService] Error fetching mirrored chats: $e');
      return [];
    }
  }

  // ── Realtime Subscription ───────────────────────────────────

  /// Subscribes to Supabase Realtime for live message updates
  /// in all mirrored chats.
  ///
  /// Messages are filtered by RLS — the guardian only receives
  /// messages for matches they're mirrored on.
  ///
  /// Call [disposeRealtime] when the guardian logs out or leaves
  /// the dashboard.
  void subscribeToMirroredChats({
    required Function(Map<String, dynamic>) onNewMessage,
  }) {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      debugPrint('[WaliModeService] Cannot subscribe: not authenticated');
      return;
    }

    // Unsubscribe from any existing channel
    disposeRealtime();

    _realtimeChannel = _supabase
        .channel('guardian_messages_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            final newRecord = payload.newRecord;
            debugPrint('[WaliModeService] Realtime message: ${newRecord['match_id']}');
            _messageController.add(newRecord);
            onNewMessage(newRecord);
          },
        )
        .subscribe((status, [error]) {
          debugPrint('[WaliModeService] Realtime status: $status');
        });

    debugPrint('[WaliModeService] ✅ Realtime subscription active for guardian $userId');
  }

  /// Marks the guardian's last-seen timestamp for a specific ward,
  /// resetting the unread count on the dashboard.
  Future<void> markChatAsSeen({required String wardUserId}) async {
    try {
      await _supabase.rpc(
        'update_guardian_last_seen',
        params: {'p_ward_id': wardUserId},
      );
    } catch (e) {
      debugPrint('[WaliModeService] Mark seen error: $e');
    }
  }

  /// Sends a message as the guardian in an active-mode mirrored chat.
  ///
  /// The message is sent with [sender_id] set to the ward's user ID
  /// (the guardian sends "as" the ward). A notification is sent to
  /// the ward informing them.
  Future<void> sendMessageAsGuardian({
    required String matchId,
    required String wardId,
    required String receiverId,
    required String content,
  }) async {
    try {
      await _supabase.from('messages').insert({
        'match_id': matchId,
        'sender_id': wardId,     // Sent as the ward
        'receiver_id': receiverId,
        'content': content,
      });

      debugPrint('[WaliModeService] Message sent as guardian for ward $wardId');
    } catch (e) {
      debugPrint('[WaliModeService] Send message error: $e');
      rethrow;
    }
  }

  /// Approves a match as an active guardian.
  ///
  /// Only applicable when [guardian_mode] is 'active'.
  /// Match must have guardian approval before messaging begins.
  Future<void> approveMatch(String matchId) async {
    try {
      await _supabase.rpc(
        'guardian_approve_match',
        params: {'p_match_id': matchId},
      );
      debugPrint('[WaliModeService] Match $matchId approved by guardian');
    } catch (e) {
      debugPrint('[WaliModeService] Approve match error: $e');
      rethrow;
    }
  }

  /// Checks if the current user is a guardian for anyone.
  Future<bool> isGuardian() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      final response = await _supabase
          .from('profiles')
          .select('id')
          .eq('guardian_user_id', userId)
          .limit(1);

      return (response as List).isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Gets the guardian info for the current user's profile.
  ///
  /// Returns null if no guardian is set.
  Future<GuardianInfo?> getMyGuardianInfo() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return null;

      final response = await _supabase
          .from('profiles')
          .select('guardian_name, guardian_relationship, guardian_mode, guardian_user_id')
          .eq('user_id', userId)
          .single();

      if (response['guardian_mode'] == 'none' || response['guardian_name'] == null) {
        return null;
      }

      return GuardianInfo(
        name: response['guardian_name'] as String,
        relationship: response['guardian_relationship'] as String?,
        mode: response['guardian_mode'] as String,
        isLinked: response['guardian_user_id'] != null,
      );
    } catch (e) {
      debugPrint('[WaliModeService] Error fetching guardian info: $e');
      return null;
    }
  }

  /// Disposes the Realtime subscription.
  /// Call when guardian logs out or leaves the dashboard.
  void disposeRealtime() {
    if (_realtimeChannel != null) {
      _supabase.removeChannel(_realtimeChannel!);
      _realtimeChannel = null;
      debugPrint('[WaliModeService] Realtime subscription disposed');
    }
  }

  /// Full dispose — call on app shutdown.
  void dispose() {
    disposeRealtime();
    _messageController.close();
  }
}

// ── Data Models ───────────────────────────────────────────────

/// Dashboard item returned by [WaliModeService.getDashboard].
class GuardianDashboardItem {
  const GuardianDashboardItem({
    required this.wardName,
    required this.wardProfileId,
    required this.wardUserId,
    required this.matchId,
    required this.otherPartyName,
    this.otherPartyPhoto,
    this.lastMessage,
    this.lastMessageAt,
    required this.unreadCount,
    required this.guardianMode,
    required this.matchStatus,
    this.guardianApproved,
    this.matchCreatedAt,
  });

  final String wardName;
  final String wardProfileId;
  final String wardUserId;
  final String matchId;
  final String otherPartyName;
  final String? otherPartyPhoto;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final String guardianMode;   // 'passive' or 'active'
  final String matchStatus;
  final bool? guardianApproved;
  final DateTime? matchCreatedAt;

  bool get canSendMessages => guardianMode == 'active' && matchStatus == 'active';
  bool get needsApproval => guardianMode == 'active' && guardianApproved != true;
  bool get hasUnread => unreadCount > 0;
}

/// Represents a mirrored chat visible to a guardian.
class GuardianMirroredChat {
  const GuardianMirroredChat({
    required this.mirrorId,
    required this.matchId,
    required this.wardId,
    required this.wardName,
    required this.otherPartyId,
    required this.otherPartyName,
    required this.mode,
    required this.matchStatus,
    this.lastMessageAt,
  });

  final String mirrorId;
  final String matchId;
  final String wardId;
  final String wardName;
  final String otherPartyId;
  final String otherPartyName;
  final String mode;  // 'passive' or 'active'
  final String matchStatus;
  final DateTime? lastMessageAt;

  bool get canSendMessages => mode == 'active' && matchStatus == 'active';
}

/// Guardian information for a user's profile.
class GuardianInfo {
  const GuardianInfo({
    required this.name,
    this.relationship,
    required this.mode,
    required this.isLinked,
  });

  final String name;
  final String? relationship;
  final String mode;  // 'passive' or 'active'

  /// Whether the guardian has created their own account and linked it.
  final bool isLinked;
}
