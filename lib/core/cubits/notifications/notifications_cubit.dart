// lib/core/cubits/notifications/notifications_cubit.dart
// ============================================================
// NOOR — Notifications Cubit (Feature 11)
// Manages a list of mock NotificationItems with unread count.
// markRead(id) / markAllRead().
// ============================================================

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

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
    _loadMock();
  }

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

  void markRead(String id) {
    emit(state.copyWith(
      items: state.items.map((n) => n.id == id ? n.copyWith(isRead: true) : n).toList(),
    ));
  }

  void markAllRead() {
    emit(state.copyWith(
      items: state.items.map((n) => n.copyWith(isRead: true)).toList(),
    ));
  }
}
