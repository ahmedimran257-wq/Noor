// lib/core/cubits/notifications/notifications_cubit.dart
// ============================================================
// MITHAQ - Notifications Cubit
// Production Supabase realtime only.
// ============================================================

import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/supabase_service.dart';

class NotificationItem extends Equatable {
  const NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.time,
    this.isRead = false,
    this.profileId,
  });

  final String id;
  final String type;
  final String title;
  final String body;
  final DateTime time;
  final bool isRead;
  final String? profileId;

  NotificationItem copyWith({bool? isRead}) => NotificationItem(
        id: id,
        type: type,
        title: title,
        body: body,
        time: time,
        isRead: isRead ?? this.isRead,
        profileId: profileId,
      );

  @override
  List<Object?> get props => [id, type, title, body, time, isRead, profileId];
}

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

class NotificationsCubit extends Cubit<NotificationsState> {
  NotificationsCubit() : super(const NotificationsState()) {
    unawaited(loadNotifications());
  }

  RealtimeChannel? _realtimeSubscription;
  String? _realtimeUserId;

  Future<void> loadNotifications() async {
    if (!SupabaseService.isInitialized) {
      emit(const NotificationsState());
      return;
    }

    final me = SupabaseService.currentUserId;
    if (me == null) {
      emit(const NotificationsState());
      return;
    }

    try {
      final data = await SupabaseService.client
          .from('notifications')
          .select('id, type, title, body, read_at, created_at, deep_link')
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
      emit(const NotificationsState());
    }
  }

  void _setupRealtime() {
    final me = SupabaseService.currentUserId;
    if (me == null) return;
    if (_realtimeUserId == me && _realtimeSubscription != null) return;

    _realtimeSubscription?.unsubscribe();
    _realtimeUserId = me;

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
          callback: (_) {
            unawaited(loadNotifications());
          },
        )
        .subscribe();
  }

  Future<void> markRead(String id) async {
    final updated = state.items
        .map((n) => n.id == id ? n.copyWith(isRead: true) : n)
        .toList();
    emit(state.copyWith(items: updated));

    if (!SupabaseService.isInitialized) return;

    try {
      await SupabaseService.client
          .from('notifications')
          .update({'read_at': DateTime.now().toIso8601String()}).eq('id', id);
    } catch (e) {
      debugPrint('NotificationsCubit: Error marking notification read: $e');
    }
  }

  Future<void> markAllRead() async {
    final updated = state.items.map((n) => n.copyWith(isRead: true)).toList();
    emit(state.copyWith(items: updated));

    if (!SupabaseService.isInitialized) return;

    final me = SupabaseService.currentUserId;
    if (me == null) return;

    try {
      await SupabaseService.client
          .from('notifications')
          .update({'read_at': DateTime.now().toIso8601String()})
          .eq('user_id', me)
          .isFilter('read_at', null);
    } catch (e) {
      debugPrint(
          'NotificationsCubit: Error marking all notifications read: $e');
    }
  }

  @override
  Future<void> close() {
    _realtimeSubscription?.unsubscribe();
    _realtimeUserId = null;
    return super.close();
  }
}
