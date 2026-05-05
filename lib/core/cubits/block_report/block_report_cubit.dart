// lib/core/cubits/block_report/block_report_cubit.dart
// ============================================================
// NOOR — Block / Report Cubit (Step 10 — Mock)
//
// Blueprint (Part 9):
//   "Blocking is silent. The blocked person is not notified.
//    They cannot find the blocker in search, their interests
//    disappear, and the chat is removed from both sides."
//
//   "A report button is accessible from every profile (three-dot
//    menu) and from within every conversation. Reporting immediately
//    hides that profile from the reporter."
//
// Persistence: blocked users and report history are persisted
// to SharedPreferences as JSON so they survive app restarts.
//
// Step 12: replace SharedPreferences with Supabase writes:
//   - blockUser: INSERT INTO blocks (blocker_id, blocked_id)
//   - reportUser: INSERT INTO reports (reporter_id, reported_user_id, ...)
//   - unblockUser: DELETE FROM blocks WHERE blocker_id=... AND blocked_id=...
// ============================================================

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'block_report_state.dart';

class BlockReportCubit extends Cubit<BlockReportState> {
  BlockReportCubit() : super(const BlockReportState()) {
    _loadFromPrefs();
  }

  static const _kBlockedUsers    = 'blocked_users_json';
  static const _kReportHistory   = 'report_history_json';
  static const _kHiddenProfiles  = 'hidden_profile_ids';

  // ── Persistence — Load ────────────────────────────────────

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load blocked users
      final blockedJson = prefs.getStringList(_kBlockedUsers) ?? [];
      final blockedUsers = blockedJson.map((s) {
        try {
          final j = jsonDecode(s) as Map<String, dynamic>;
          return BlockedUser(
            userId:      j['userId'] as String,
            name:        j['name'] as String,
            lastInitial: j['lastInitial'] as String,
            blockedAt:   DateTime.parse(j['blockedAt'] as String),
          );
        } catch (_) {
          return null;
        }
      }).whereType<BlockedUser>().toList();

      // Load report history
      final reportJson = prefs.getStringList(_kReportHistory) ?? [];
      final reportHistory = reportJson.map((s) {
        try {
          final j = jsonDecode(s) as Map<String, dynamic>;
          return ReportEntry(
            reportId:       j['reportId'] as String,
            reportedUserId: j['reportedUserId'] as String,
            reportedName:   j['reportedName'] as String,
            reason:         ReportReason.values.firstWhere(
              (r) => r.key == j['reasonKey'],
              orElse: () => ReportReason.other,
            ),
            description:    j['description'] as String?,
            submittedAt:    DateTime.parse(j['submittedAt'] as String),
          );
        } catch (_) {
          return null;
        }
      }).whereType<ReportEntry>().toList();

      // Load hidden profile IDs
      final hiddenList = prefs.getStringList(_kHiddenProfiles) ?? [];
      final hiddenIds  = hiddenList.toSet();

      if (!isClosed) {
        emit(state.copyWith(
          blockedUsers:     blockedUsers,
          reportHistory:    reportHistory,
          hiddenProfileIds: hiddenIds,
        ));
      }
    } catch (e) {
      debugPrint('BlockReportCubit: failed to load from prefs: $e');
    }
  }

  // ── Persistence — Save ────────────────────────────────────

  Future<void> _saveToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Save blocked users
      final blockedJson = state.blockedUsers.map((b) => jsonEncode({
        'userId':      b.userId,
        'name':        b.name,
        'lastInitial': b.lastInitial,
        'blockedAt':   b.blockedAt.toIso8601String(),
      })).toList();
      await prefs.setStringList(_kBlockedUsers, blockedJson);

      // Save report history
      final reportJson = state.reportHistory.map((r) => jsonEncode({
        'reportId':       r.reportId,
        'reportedUserId': r.reportedUserId,
        'reportedName':   r.reportedName,
        'reasonKey':      r.reason.key,
        'description':    r.description,
        'submittedAt':    r.submittedAt.toIso8601String(),
      })).toList();
      await prefs.setStringList(_kReportHistory, reportJson);

      // Save hidden profile IDs
      await prefs.setStringList(
        _kHiddenProfiles,
        state.hiddenProfileIds.toList(),
      );
    } catch (e) {
      debugPrint('BlockReportCubit: failed to save to prefs: $e');
    }
  }

  // ── Block ─────────────────────────────────────────────────

  /// Silently block a user.
  /// Blueprint: "The blocked person is not notified."
  Future<void> blockUser({
    required String userId,
    required String name,
    required String lastInitial,
  }) async {
    if (state.isBlocked(userId)) return;

    emit(state.copyWith(isSubmitting: true));

    // Mock: simulate network
    await Future.delayed(const Duration(milliseconds: 600));

    if (isClosed) return;

    final blocked = BlockedUser(
      userId:    userId,
      name:      name,
      lastInitial: lastInitial,
      blockedAt: DateTime.now(),
    );

    final updatedBlocks  = [blocked, ...state.blockedUsers];
    final updatedHidden  = {...state.hiddenProfileIds, userId};

    emit(state.copyWith(
      isSubmitting:     false,
      blockedUsers:     updatedBlocks,
      hiddenProfileIds: updatedHidden,
      successMessage:   'User blocked. They can no longer contact you.',
    ));

    await _saveToPrefs();
  }

  /// Unblock a previously blocked user.
  Future<void> unblockUser(String userId) async {
    emit(state.copyWith(isSubmitting: true));

    await Future.delayed(const Duration(milliseconds: 500));

    if (isClosed) return;

    final updatedBlocks = state.blockedUsers
        .where((b) => b.userId != userId)
        .toList();
    final updatedHidden = {...state.hiddenProfileIds}..remove(userId);

    emit(state.copyWith(
      isSubmitting:     false,
      blockedUsers:     updatedBlocks,
      hiddenProfileIds: updatedHidden,
    ));

    await _saveToPrefs();
  }

  // ── Report ────────────────────────────────────────────────

  /// Report a user with a predefined reason.
  /// Blueprint: "Reporting immediately hides that profile from the reporter."
  Future<void> reportUser({
    required String       reportedUserId,
    required String       reportedName,
    required ReportReason reason,
    String?               description,
  }) async {
    emit(state.copyWith(isSubmitting: true, clearError: true));

    await Future.delayed(const Duration(milliseconds: 800));

    if (isClosed) return;

    final entry = ReportEntry(
      reportId:       'r_${DateTime.now().millisecondsSinceEpoch}',
      reportedUserId: reportedUserId,
      reportedName:   reportedName,
      reason:         reason,
      description:    description,
      submittedAt:    DateTime.now(),
    );

    // Blueprint: "immediately hides that profile from the reporter"
    final updatedHidden = {...state.hiddenProfileIds, reportedUserId};

    emit(state.copyWith(
      isSubmitting:     false,
      reportHistory:    [entry, ...state.reportHistory],
      hiddenProfileIds: updatedHidden,
      successMessage:   'Report submitted. JazakAllah for keeping the community safe.',
    ));

    await _saveToPrefs();
  }

  void clearMessages() {
    emit(state.copyWith(clearSuccess: true, clearError: true));
  }
}
