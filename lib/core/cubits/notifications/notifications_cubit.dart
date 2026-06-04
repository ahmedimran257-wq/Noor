// lib/core/cubits/notifications/notifications_cubit.dart
// ============================================================
// NOOR — Notifications Cubit (Real Supabase + Mock Fallback)
// ============================================================

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/supabase_service.dart';

// ── Model ─────────────────────────────────────────────────────

class NotificationItem extends Equatable {
  const NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.time,
    this.isRead    = false,
    this.profileId,
  });

  final String   id;
  final String   type;       // interest_received | interest_accepted | new_message | profile_tip | boost_ready | profile_approved
  final String   title;
  final String   body;
  final DateTime time;
  final bool     isRead;
  final String?  profileId;

  NotificationItem copyWith({bool? isRead}) =>
      NotificationItem(
        id:        id,
        type:      type,
        title:     title,
        body:      body,
        time:      time,
        isRead:    isRead ?? this.isRead,
        profileId: profileId,
      );

  @override
  List<Object?> get props => [id, type, title, body, time, isRead, profileId];
}

// ── State ─────────────────────────────────────────────────────

class NotificationsState extends Equatable {
  const NotificationsState({
    this.items = const [],
  });

  final List<NotificationItem> items;
  int get unreadCount => items.where((n) => !n.isRead).length;

  NotificationsState copyWith({List<NotificationItem>? items}) =>
      NotificationsState(items: items ?? this.items);

  @override
  List<Object?> get props => [items];
}

// ── Cubit ─────────────────────────────────────────────────────

class NotificationsCubit extends Cubit<NotificationsState> {
  NotificationsCubit() : super(const NotificationsState()) {
    loadNotifications();
  }

  RealtimeChannel? _realtimeSubscription;

  bool get _isRealMode => SupabaseService.isInitialized;

  // ── DB Loading & Realtime ─────────────────────────────────

  Future<void> loadNotifications() async {
    if (!_isRealMode) {
      _loadMock();
      return;
    }

    final me = SupabaseService.currentUserId;
    if (me == null) {
      _loadMock();
      return;
    }

    try {
      final data = await SupabaseService.client
          .from('notifications')
          .select()
          .eq('user_id', me)
          .order('created_at', ascending: false);

      final items = (data as List).map((row) {
        final id = row['id'] as String;
        final type = row['type'] as String? ?? 'general';
        final title = row['title'] as String? ?? '';
        final body = row['body'] as String? ?? '';
        final readAt = row['read_at'];
        final createdAt = DateTime.parse(row['created_at'] as String).toLocal();
        final deepLink = row['deep_link'] as String?;
        
        // Parse profileId from deepLink if it looks like noor://profile/uuid
        String? profileId;
        if (deepLink != null && deepLink.contains('profile/')) {
          profileId = deepLink.split('profile/').last;
        }

        return NotificationItem(
          id: id,
          type: type,
          title: title,
          body: body,
          time: createdAt,
          isRead: readAt != null,
          profileId: profileId,
        );
      }).toList();

      emit(NotificationsState(items: items));
      _setupRealtime();
    } catch (e) {
      debugPrint('NotificationsCubit: Error loading notifications: $e');
      _loadMock();
    }
  }

  void _setupRealtime() {
    final me = SupabaseService.currentUserId;
    if (me == null) return;

    _realtimeSubscription?.unsubscribe();

    _realtimeSubscription = SupabaseService.client
        .channel('public:notifications')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: me,
          ),
          callback: (payload) {
            loadNotifications();
          },
        )
        .subscribe();
  }

  @override
  Future<void> close() {
    _realtimeSubscription?.unsubscribe();
    return super.close();
  }

  // ── Mock data fallback ─────────────────────────────────────

  void _loadMock() {
    final now = DateTime.now();
    emit(NotificationsState(items: [
      NotificationItem(
        id:        'n1',
        type:      'interest_received',
        title:     'New Interest',
        body:      'Fatima A. sent you an interest.',
        time:      now.subtract(const Duration(minutes: 12)),
        isRead:    false,
        profileId: 'fatima_a',
      ),
      NotificationItem(
        id:        'n2',
        type:      'interest_accepted',
        title:     'Interest Accepted',
        body:      'Zainab H. accepted your interest. You can now message her.',
        time:      now.subtract(const Duration(hours: 1)),
        isRead:    false,
        profileId: 'zainab_h',
      ),
      NotificationItem(
        id:        'n3',
        type:      'new_message',
        title:     'New Message',
        body:      'Mariam R. sent you a message.',
        time:      now.subtract(const Duration(hours: 3)),
        isRead:    false,
        profileId: 'mariam_r',
      ),
      NotificationItem(
        id:        'n4',
        type:      'profile_tip',
        title:     'Profile Tip',
        body:      'Adding a bio increases your matches by 3×. Tap to complete.',
        time:      now.subtract(const Duration(hours: 6)),
        isRead:    true,
      ),
      NotificationItem(
        id:        'n5',
        type:      'boost_ready',
        title:     'Boost Ready',
        body:      'Your weekly profile boost is ready. Activate it now.',
        time:      now.subtract(const Duration(days: 1)),
        isRead:    true,
      ),
      NotificationItem(
        id:        'n6',
        type:      'profile_approved',
        title:     'Profile Approved',
        body:      'Your profile has been reviewed and approved. You\'re live!',
        time:      now.subtract(const Duration(days: 2)),
        isRead:    true,
      ),
    ]));
  }

  // ── Public API ────────────────────────────────────────────

  void markRead(String id) {
    // Optimistic UI update
    final updated = state.items.map((n) => n.id == id ? n.copyWith(isRead: true) : n).toList();
    emit(state.copyWith(items: updated));

    if (_isRealMode) {
      try {
        SupabaseService.client
            .from('notifications')
            .update({'read_at': DateTime.now().toIso8601String()})
            .eq('id', id);
      } catch (e) {
        debugPrint('NotificationsCubit: Error marking notification read: $e');
      }
    }
  }

  void markAllRead() {
    // Optimistic UI update
    final updated = state.items.map((n) => n.copyWith(isRead: true)).toList();
    emit(state.copyWith(items: updated));

    if (_isRealMode) {
      final me = SupabaseService.currentUserId;
      if (me == null) return;

      try {
        SupabaseService.client
            .from('notifications')
            .update({'read_at': DateTime.now().toIso8601String()})
            .eq('user_id', me)
            .isFilter('read_at', null);
      } catch (e) {
        debugPrint('NotificationsCubit: Error marking all notifications read: $e');
      }
    }
  }
}
