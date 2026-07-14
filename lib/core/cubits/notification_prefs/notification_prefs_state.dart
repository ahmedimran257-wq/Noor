// lib/core/cubits/notification_prefs/notification_prefs_state.dart
// ============================================================
// SILARAH — Notification Preferences State
//
// Blueprint (Part 11 — notification_prefs table):
//   new_interest, interest_accepted, new_message,
//   profile_live, interest_expiring, inactive_nudge,
//   boost_available + quiet_start / quiet_end (23:00–08:00)
//
// Step 12: replace toggles with Supabase UPSERT on change.
// ============================================================

import 'package:equatable/equatable.dart';

class NotificationPrefsState extends Equatable {
  final bool newInterest;
  final bool interestAccepted;
  final bool newMessage;
  final bool profileLive;
  final bool interestExpiring;
  final bool inactiveNudge;
  final bool boostAvailable;

  /// Quiet hours — 23:00 to 08:00 (database defaults)
  final int quietStartHour; // 23
  final int quietEndHour; // 8

  const NotificationPrefsState({
    this.newInterest = true,
    this.interestAccepted = true,
    this.newMessage = true,
    this.profileLive = true,
    this.interestExpiring = true,
    this.inactiveNudge = true,
    this.boostAvailable = true,
    this.quietStartHour = 23,
    this.quietEndHour = 8,
  });

  NotificationPrefsState copyWith({
    bool? newInterest,
    bool? interestAccepted,
    bool? newMessage,
    bool? profileLive,
    bool? interestExpiring,
    bool? inactiveNudge,
    bool? boostAvailable,
    int? quietStartHour,
    int? quietEndHour,
  }) {
    return NotificationPrefsState(
      newInterest: newInterest ?? this.newInterest,
      interestAccepted: interestAccepted ?? this.interestAccepted,
      newMessage: newMessage ?? this.newMessage,
      profileLive: profileLive ?? this.profileLive,
      interestExpiring: interestExpiring ?? this.interestExpiring,
      inactiveNudge: inactiveNudge ?? this.inactiveNudge,
      boostAvailable: boostAvailable ?? this.boostAvailable,
      quietStartHour: quietStartHour ?? this.quietStartHour,
      quietEndHour: quietEndHour ?? this.quietEndHour,
    );
  }

  @override
  List<Object?> get props => [
        newInterest,
        interestAccepted,
        newMessage,
        profileLive,
        interestExpiring,
        inactiveNudge,
        boostAvailable,
        quietStartHour,
        quietEndHour,
      ];
}
