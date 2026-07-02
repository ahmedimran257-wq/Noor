// lib/core/cubits/notification_prefs/notification_prefs_cubit.dart
// ============================================================
// MITHAQ — Notification Preferences Cubit (Supabase production flow)
//
// Each toggle maps directly to a column in the notification_prefs
// DB table. In real mode: upserts to Supabase on every toggle.
//
// Firebase Cloud Messaging (FCM) integration notes:
//   - On app start: FCM token obtained via FirebaseMessaging.instance.getToken()
//   - On login:    FCM token saved to user_fcm_tokens table in Supabase
//   - On delete:   FCM token row deleted from user_fcm_tokens (ghost push prevention)
//   - On refresh:  FirebaseMessaging.instance.onTokenRefresh saves new token to DB
// ============================================================

import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../services/supabase_service.dart';
import 'notification_prefs_state.dart';

class NotificationPrefsCubit extends Cubit<NotificationPrefsState> {
  NotificationPrefsCubit() : super(const NotificationPrefsState());

  bool get _isRealMode => SupabaseService.isInitialized;
  Timer? _persistDebounce;
  int _persistVersion = 0;

  // ── Load prefs from DB on login ───────────────────────────

  /// Load notification preferences from Supabase for the current user.
  Future<void> loadPrefs() async {
    if (!_isRealMode) return;

    final userId = SupabaseService.currentUserId;
    if (userId == null) return;

    try {
      final row = await SupabaseService.client
          .from('notification_prefs')
          .select(
            'new_interest, interest_accepted, new_message, profile_approved, '
            'interest_expiring, inactive_nudge, boost_available, '
            'quiet_start, quiet_end',
          )
          .eq('user_id', userId)
          .maybeSingle();

      if (row != null && !isClosed) {
        emit(NotificationPrefsState(
          newInterest: (row['new_interest'] as bool?) ?? true,
          interestAccepted: (row['interest_accepted'] as bool?) ?? true,
          newMessage: (row['new_message'] as bool?) ?? true,
          profileApproved: (row['profile_approved'] as bool?) ?? true,
          interestExpiring: (row['interest_expiring'] as bool?) ?? true,
          inactiveNudge: (row['inactive_nudge'] as bool?) ?? true,
          boostAvailable: (row['boost_available'] as bool?) ?? true,
          quietStartHour: _timeToHour(row['quiet_start'] as String?),
          quietEndHour: _timeToHour(row['quiet_end'] as String?),
        ));
      }
    } catch (e) {
      debugPrint('[NotificationPrefsCubit] Error loading prefs: $e');
    }
  }

  // ── Toggle methods — one per DB column ────────────────────

  void toggleNewInterest(bool value) {
    emit(state.copyWith(newInterest: value));
    _schedulePersist();
  }

  void toggleInterestAccepted(bool value) {
    emit(state.copyWith(interestAccepted: value));
    _schedulePersist();
  }

  void toggleNewMessage(bool value) {
    emit(state.copyWith(newMessage: value));
    _schedulePersist();
  }

  void toggleProfileApproved(bool value) {
    emit(state.copyWith(profileApproved: value));
    _schedulePersist();
  }

  void toggleInterestExpiring(bool value) {
    emit(state.copyWith(interestExpiring: value));
    _schedulePersist();
  }

  void toggleInactiveNudge(bool value) {
    emit(state.copyWith(inactiveNudge: value));
    _schedulePersist();
  }

  void toggleBoostAvailable(bool value) {
    emit(state.copyWith(boostAvailable: value));
    _schedulePersist();
  }

  // ── Quiet hours ───────────────────────────────────────────

  void setQuietHours({required int startHour, required int endHour}) {
    emit(state.copyWith(
      quietStartHour: startHour,
      quietEndHour: endHour,
    ));
    _schedulePersist();
  }

  // ── Reset all to defaults ─────────────────────────────────

  void resetToDefaults() {
    emit(const NotificationPrefsState());
    _schedulePersist();
  }

  // ── Persistence helper ────────────────────────────────────

  void _schedulePersist() {
    final version = ++_persistVersion;
    _persistDebounce?.cancel();
    // Race fix: rapid toggles are debounced and versioned so an older async
    // upsert cannot overwrite the latest in-memory preference state.
    _persistDebounce = Timer(const Duration(milliseconds: 300), () {
      unawaited(_persist(version, state));
    });
  }

  Future<void> _persist(
    int version,
    NotificationPrefsState snapshot,
  ) async {
    if (!_isRealMode) return;
    if (version != _persistVersion) return;

    final userId = SupabaseService.currentUserId;
    if (userId == null) return;
    if (version != _persistVersion) return;

    try {
      await SupabaseService.client.from('notification_prefs').upsert({
        'user_id': userId,
        'new_interest': snapshot.newInterest,
        'interest_accepted': snapshot.interestAccepted,
        'new_message': snapshot.newMessage,
        'profile_approved': snapshot.profileApproved,
        'interest_expiring': snapshot.interestExpiring,
        'inactive_nudge': snapshot.inactiveNudge,
        'boost_available': snapshot.boostAvailable,
        'quiet_start':
            '${snapshot.quietStartHour.toString().padLeft(2, '0')}:00',
        'quiet_end': '${snapshot.quietEndHour.toString().padLeft(2, '0')}:00',
      }, onConflict: 'user_id');
    } catch (e) {
      debugPrint('[NotificationPrefsCubit] Error persisting prefs: $e');
    }
  }

  // ── Helpers ───────────────────────────────────────────────

  /// Parse a time string like "23:00:00" → 23
  int _timeToHour(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return 23;
    final parts = timeStr.split(':');
    return int.tryParse(parts[0]) ?? 23;
  }

  @override
  Future<void> close() {
    _persistDebounce?.cancel();
    return super.close();
  }
}
