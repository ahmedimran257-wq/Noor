// lib/core/cubits/notification_prefs/notification_prefs_cubit.dart
// ============================================================
// NOOR — Notification Preferences Cubit (Step 10 — Mock)
//
// Each toggle maps directly to a column in the notification_prefs
// DB table. Step 12: replace emit() with Supabase UPSERT:
//
//   await _supabase.from('notification_prefs').upsert({
//     'user_id':         userId,
//     'new_interest':    newState.newInterest,
//     ... etc
//   });
//
// OneSignal integration notes (blueprint Part 11):
//   - On app start: OneSignal.initialize(appId)
//   - On login:    OneSignal.login(supabaseUserId)
//   - On delete:   OneSignal.logout()  ← CRITICAL (ghost push prevention)
// ============================================================

import 'package:flutter_bloc/flutter_bloc.dart';
import 'notification_prefs_state.dart';

class NotificationPrefsCubit extends Cubit<NotificationPrefsState> {
  NotificationPrefsCubit() : super(const NotificationPrefsState());

  // ── Toggle methods — one per DB column ────────────────────

  void toggleNewInterest(bool value) =>
      emit(state.copyWith(newInterest: value));

  void toggleInterestAccepted(bool value) =>
      emit(state.copyWith(interestAccepted: value));

  void toggleNewMessage(bool value) =>
      emit(state.copyWith(newMessage: value));

  void toggleProfileApproved(bool value) =>
      emit(state.copyWith(profileApproved: value));

  void toggleInterestExpiring(bool value) =>
      emit(state.copyWith(interestExpiring: value));

  void toggleInactiveNudge(bool value) =>
      emit(state.copyWith(inactiveNudge: value));

  void toggleBoostAvailable(bool value) =>
      emit(state.copyWith(boostAvailable: value));

  // ── Quiet hours ───────────────────────────────────────────

  void setQuietHours({required int startHour, required int endHour}) =>
      emit(state.copyWith(
        quietStartHour: startHour,
        quietEndHour:   endHour,
      ));

  // ── Reset all to defaults ─────────────────────────────────

  void resetToDefaults() => emit(const NotificationPrefsState());
}
