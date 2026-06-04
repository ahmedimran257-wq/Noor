// lib/core/cubits/notification_prefs/notification_prefs_cubit.dart
// ============================================================
// NOOR — Notification Preferences Cubit (Real Supabase + Mock)
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
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../services/supabase_service.dart';
import 'notification_prefs_state.dart';

class NotificationPrefsCubit extends Cubit<NotificationPrefsState> {
  NotificationPrefsCubit() : super(const NotificationPrefsState());

  bool get _isRealMode => SupabaseService.isInitialized;

  // ── Load prefs from DB on login ───────────────────────────

  /// Load notification preferences from Supabase for the current user.
  Future<void> loadPrefs() async {
    if (!_isRealMode) return;

    final userId = SupabaseService.currentUserId;
    if (userId == null) return;

    try {
      final row = await SupabaseService.client
          .from('notification_prefs')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (row != null && !isClosed) {
        emit(NotificationPrefsState(
          newInterest:      (row['new_interest'] as bool?) ?? true,
          interestAccepted: (row['interest_accepted'] as bool?) ?? true,
          newMessage:       (row['new_message'] as bool?) ?? true,
          profileApproved:  (row['profile_approved'] as bool?) ?? true,
          interestExpiring: (row['interest_expiring'] as bool?) ?? true,
          inactiveNudge:    (row['inactive_nudge'] as bool?) ?? true,
          boostAvailable:   (row['boost_available'] as bool?) ?? true,
          quietStartHour:   _timeToHour(row['quiet_start'] as String?),
          quietEndHour:     _timeToHour(row['quiet_end'] as String?),
        ));
      }
    } catch (e) {
      debugPrint('[NotificationPrefsCubit] Error loading prefs: $e');
    }
  }

  // ── Toggle methods — one per DB column ────────────────────

  void toggleNewInterest(bool value) {
    emit(state.copyWith(newInterest: value));
    _persist();
  }

  void toggleInterestAccepted(bool value) {
    emit(state.copyWith(interestAccepted: value));
    _persist();
  }

  void toggleNewMessage(bool value) {
    emit(state.copyWith(newMessage: value));
    _persist();
  }

  void toggleProfileApproved(bool value) {
    emit(state.copyWith(profileApproved: value));
    _persist();
  }

  void toggleInterestExpiring(bool value) {
    emit(state.copyWith(interestExpiring: value));
    _persist();
  }

  void toggleInactiveNudge(bool value) {
    emit(state.copyWith(inactiveNudge: value));
    _persist();
  }

  void toggleBoostAvailable(bool value) {
    emit(state.copyWith(boostAvailable: value));
    _persist();
  }

  // ── Quiet hours ───────────────────────────────────────────

  void setQuietHours({required int startHour, required int endHour}) {
    emit(state.copyWith(
      quietStartHour: startHour,
      quietEndHour:   endHour,
    ));
    _persist();
  }

  // ── Reset all to defaults ─────────────────────────────────

  void resetToDefaults() {
    emit(const NotificationPrefsState());
    _persist();
  }

  // ── Persistence helper ────────────────────────────────────

  Future<void> _persist() async {
    if (!_isRealMode) return;

    final userId = SupabaseService.currentUserId;
    if (userId == null) return;

    try {
      await SupabaseService.client
          .from('notification_prefs')
          .upsert({
            'user_id':            userId,
            'new_interest':       state.newInterest,
            'interest_accepted':  state.interestAccepted,
            'new_message':        state.newMessage,
            'profile_approved':   state.profileApproved,
            'interest_expiring':  state.interestExpiring,
            'inactive_nudge':     state.inactiveNudge,
            'boost_available':    state.boostAvailable,
            'quiet_start':        '${state.quietStartHour.toString().padLeft(2, '0')}:00',
            'quiet_end':          '${state.quietEndHour.toString().padLeft(2, '0')}:00',
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
}
