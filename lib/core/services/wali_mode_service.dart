// SILARAH — Wali (Guardian) Mode Service
//
// Guardian configuration and linked-account operations.
//
// The guardian gets their own login to the app with a dedicated
// dashboard showing all active chats their ward is engaged in.
// Messages appear live via Supabase Realtime.
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'profile_photo_service.dart';
import 'supabase_service.dart';

/// Manages Wali (Guardian) mode operations.
///
/// Supports two modes:
/// - **Passive**: Guardian sees read-only chat transcripts in real-time
/// - **Active**: Guardian can also send messages and approve matches
///
/// A linked guardian can see the guardian dashboard with live message updates.
class WaliModeService {
  WaliModeService._();
  static final instance = WaliModeService._();
  static const pendingInvitationKey = 'pending_guardian_invitation_code';

  SupabaseClient get _supabase {
    if (!SupabaseService.isInitialized) {
      throw StateError(
        'Supabase is not initialized. Ensure SupabaseService.initialize() is called first.',
      );
    }
    return SupabaseService.client;
  }

  // Realtime
  RealtimeChannel? _realtimeChannel;
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();

  /// Stream of new messages arriving in mirrored chats.
  /// Each event is the raw message payload from Supabase Realtime.
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;

  bool _isRealtimeConnected = false;

  /// Whether the Realtime channel is currently connected.
  bool get isRealtimeConnected => _isRealtimeConnected;

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

  Future<Map<String, dynamic>> acceptInvitation(String code) async {
    final normalized = code.trim().toUpperCase();
    if (!RegExp(r'^[A-F0-9]{10}$').hasMatch(normalized)) {
      throw const FormatException('invalid_guardian_invitation_code');
    }
    final response = await _supabase.rpc(
      'accept_my_guardian_invitation',
      params: {'p_code': normalized},
    );
    return Map<String, dynamic>.from(response as Map);
  }

  Future<void> rememberPendingInvitation(String code) async {
    final normalized = code.trim().toUpperCase();
    if (!RegExp(r'^[A-F0-9]{10}$').hasMatch(normalized)) {
      throw const FormatException('invalid_guardian_invitation_code');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(pendingInvitationKey, normalized);
  }

  Future<String?> pendingInvitation() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(pendingInvitationKey)?.trim().toUpperCase();
    return code != null && RegExp(r'^[A-F0-9]{10}$').hasMatch(code)
        ? code
        : null;
  }

  Future<void> clearPendingInvitation() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(pendingInvitationKey);
  }

  // Dashboard
  /// Fetches the full guardian dashboard data via the
  /// `get_guardian_dashboard()` RPC.
  ///
  /// Returns a list of active conversations the guardian can see,
  /// including ward name, other party details, last message,
  /// unread count, and match approval status.
  Future<List<GuardianDashboardItem>> getDashboard({
    String? markSeenWardId,
  }) async {
    try {
      final response = await _supabase.rpc(
        'get_guardian_dashboard_v2',
        params: {'p_mark_seen_ward_id': markSeenWardId},
      );
      final rows = response as List<dynamic>;
      final ownerIds = rows
          .map((row) => (row as Map)['other_party_user_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList(growable: false);
      final signedPhotos = await ProfilePhotoService.instance
          .getAuthorizedPhotoUrls(ownerUserIds: ownerIds);

      return rows.map((row) {
        final r = row as Map<String, dynamic>;
        final otherPartyUserId = r['other_party_user_id'] as String;
        return GuardianDashboardItem(
          wardName: _requiredText(r, 'ward_name'),
          wardProfileId: r['ward_profile_id'] as String,
          wardUserId: r['ward_user_id'] as String,
          matchId: r['match_id'] as String,
          otherPartyUserId: otherPartyUserId,
          otherPartyName: _requiredText(r, 'other_party_name'),
          otherPartyPhoto: signedPhotos[otherPartyUserId],
          lastMessage: r['last_message'] as String?,
          lastMessageAt: r['last_message_at'] != null
              ? DateTime.parse(r['last_message_at'] as String)
              : null,
          unreadCount: (r['unread_count'] as num?)?.toInt() ?? 0,
          guardianMode: r['guardian_mode'] as String,
          matchStatus: r['match_status'] as String,
          guardianHasApproved: r['guardian_has_approved'] as bool? ?? false,
          allGuardiansApproved: r['all_guardians_approved'] as bool? ?? false,
          matchCreatedAt: r['match_created_at'] != null
              ? DateTime.parse(r['match_created_at'] as String)
              : null,
        );
      }).toList();
    } catch (e) {
      debugPrint('[WaliModeService] Dashboard fetch error: $e');
      rethrow;
    }
  }

  Future<List<GuardianTranscriptMessage>> getTranscript({
    required String matchId,
    GuardianTranscriptMessage? before,
  }) async {
    final response = await _supabase.rpc(
      'get_guardian_match_messages',
      params: {
        'p_match_id': matchId,
        'p_before_created_at': before?.createdAt.toUtc().toIso8601String(),
        'p_before_id': before?.id,
        'p_limit': 50,
      },
    );
    return (response as List<dynamic>).map((row) {
      final r = Map<String, dynamic>.from(row as Map);
      return GuardianTranscriptMessage(
        id: r['message_id'] as String,
        content: _requiredText(r, 'content'),
        createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
        isFromWard: r['is_from_ward'] as bool? ?? false,
        sentByGuardian: r['sent_by_guardian'] as bool? ?? false,
        deliveryStatus: r['delivery_status']?.toString() ?? 'sent',
      );
    }).toList(growable: false);
  }

  // Realtime Subscription
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
    void Function(bool connected)? onStatusChange,
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
            debugPrint(
                '[WaliModeService] Realtime message: ${newRecord['match_id']}');
            _messageController.add(newRecord);
            onNewMessage(newRecord);
          },
        )
        .subscribe((status, [error]) {
      debugPrint('[WaliModeService] Realtime status: $status');
      final isSubscribed = status == RealtimeSubscribeStatus.subscribed;
      _isRealtimeConnected = isSubscribed;
      if (onStatusChange != null) {
        onStatusChange(isSubscribed);
      }
    });

    debugPrint(
        '[WaliModeService] ✅ Realtime subscription active for guardian $userId');
  }

  /// Sends a message as the guardian in an active-mode mirrored chat.
  ///
  /// The message is sent with [sender_id] set to the ward's user ID
  /// (the guardian sends "as" the ward). A notification is sent to
  /// the ward informing them.
  Future<void> sendMessageAsGuardian({
    required String matchId,
    required String content,
  }) async {
    try {
      await _supabase.rpc('send_guardian_chat_message', params: {
        'p_match_id': matchId,
        'p_content': content,
      });

      debugPrint('[WaliModeService] Guardian message sent for match $matchId');
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
          .from('my_guardian_wards')
          .select('id')
          .eq('guardian_user_id', userId)
          .limit(1);

      return (response as List).isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Saves the ward's guardian settings on the profile row and encrypts the
  /// phone through the existing SECURITY DEFINER RPC. SharedPreferences should
  /// only be used by callers as a UI cache, never as the source of truth.
  Future<GuardianInvitation?> saveMyGuardianSettings({
    required bool enabled,
    required String guardianName,
    required String guardianPhone,
    required String relationship,
    required bool canReply,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Sign in is required to save guardian settings.');
    }

    final response =
        await _supabase.rpc('save_my_guardian_configuration', params: {
      'p_enabled': enabled,
      'p_can_reply': canReply,
      'p_name': guardianName.trim(),
      'p_relationship': _dbRelationship(relationship),
      'p_phone': guardianPhone.trim().isEmpty ? null : guardianPhone.trim(),
    });
    final result = Map<String, dynamic>.from(response as Map);
    return GuardianInvitation.fromResponse(result);
  }

  Future<GuardianInvitation> renewMyGuardianInvitation() async {
    final response = await _supabase.rpc('renew_my_guardian_invitation');
    final invitation = GuardianInvitation.fromResponse(
      Map<String, dynamic>.from(response as Map),
    );
    if (invitation == null) {
      throw StateError('guardian_invitation_unavailable');
    }
    return invitation;
  }

  static String _dbRelationship(String label) {
    switch (label.toLowerCase()) {
      case 'father':
        return 'father';
      case 'mother':
        return 'mother';
      case 'brother':
        return 'brother';
      case 'uncle':
        return 'uncle';
      default:
        return 'other';
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
          .from('my_profile_private')
          .select(
            'guardian_name, guardian_relationship, guardian_mode, '
            'guardian_user_id, guardian_phone_encrypted, '
            'guardian_invitation_expires_at',
          )
          .eq('user_id', userId)
          .single();

      if (response['guardian_mode'] == 'none' ||
          response['guardian_name'] == null) {
        return null;
      }

      return GuardianInfo(
        name: response['guardian_name'] as String,
        relationship: response['guardian_relationship'] as String?,
        mode: response['guardian_mode'] as String,
        isLinked: response['guardian_user_id'] != null,
        hasPhone: response['guardian_phone_encrypted'] != null,
        invitationExpiresAt: response['guardian_invitation_expires_at'] == null
            ? null
            : DateTime.tryParse(
                response['guardian_invitation_expires_at'].toString(),
              )?.toLocal(),
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
      _isRealtimeConnected = false;
      debugPrint('[WaliModeService] Realtime subscription disposed');
    }
  }

  /// Full dispose — call on app shutdown.
  void dispose() {
    disposeRealtime();
    _messageController.close();
  }
}

String _requiredText(Map<String, dynamic> row, String key) {
  final value = row[key]?.toString().trim();
  if (value == null || value.isEmpty) {
    throw StateError('Guardian data is missing required field "$key".');
  }
  return value;
}

// Data Models
/// Dashboard item returned by [WaliModeService.getDashboard].
class GuardianDashboardItem {
  const GuardianDashboardItem({
    required this.wardName,
    required this.wardProfileId,
    required this.wardUserId,
    required this.matchId,
    required this.otherPartyUserId,
    required this.otherPartyName,
    this.otherPartyPhoto,
    this.lastMessage,
    this.lastMessageAt,
    required this.unreadCount,
    required this.guardianMode,
    required this.matchStatus,
    required this.guardianHasApproved,
    required this.allGuardiansApproved,
    this.matchCreatedAt,
  });

  final String wardName;
  final String wardProfileId;
  final String wardUserId;
  final String matchId;
  final String otherPartyUserId;
  final String otherPartyName;
  final String? otherPartyPhoto;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final String guardianMode; // 'passive' or 'active'
  final String matchStatus;
  final bool guardianHasApproved;
  final bool allGuardiansApproved;
  final DateTime? matchCreatedAt;

  bool get canSendMessages =>
      guardianMode == 'active' &&
      matchStatus == 'active' &&
      allGuardiansApproved;
  bool get needsApproval => guardianMode == 'active' && !guardianHasApproved;
  bool get hasUnread => unreadCount > 0;
}

class GuardianTranscriptMessage {
  const GuardianTranscriptMessage({
    required this.id,
    required this.content,
    required this.createdAt,
    required this.isFromWard,
    required this.sentByGuardian,
    required this.deliveryStatus,
  });

  final String id;
  final String content;
  final DateTime createdAt;
  final bool isFromWard;
  final bool sentByGuardian;
  final String deliveryStatus;
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
  final String mode; // 'passive' or 'active'
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
    required this.hasPhone,
    this.invitationExpiresAt,
  });

  final String name;
  final String? relationship;
  final String mode; // 'passive' or 'active'

  /// Whether the guardian has created their own account and linked it.
  final bool isLinked;
  final bool hasPhone;
  final DateTime? invitationExpiresAt;
}

class GuardianInvitation {
  const GuardianInvitation({required this.code, required this.expiresAt});

  final String code;
  final DateTime expiresAt;

  static GuardianInvitation? fromResponse(Map<String, dynamic> response) {
    final code = response['invitation_code']?.toString().trim().toUpperCase();
    final expiresAt = DateTime.tryParse(
      response['invitation_expires_at']?.toString() ?? '',
    )?.toLocal();
    if (code == null || code.isEmpty || expiresAt == null) return null;
    return GuardianInvitation(code: code, expiresAt: expiresAt);
  }
}
