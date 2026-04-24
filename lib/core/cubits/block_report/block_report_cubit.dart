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
// Step 12: replace in-memory lists with Supabase writes:
//   - blockUser: INSERT INTO blocks (blocker_id, blocked_id)
//   - reportUser: INSERT INTO reports (reporter_id, reported_user_id, ...)
//   - unblockUser: DELETE FROM blocks WHERE blocker_id=... AND blocked_id=...
// ============================================================

import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'block_report_state.dart';

class BlockReportCubit extends Cubit<BlockReportState> {
  BlockReportCubit() : super(const BlockReportState());

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
  }

  void clearMessages() {
    emit(state.copyWith(clearSuccess: true, clearError: true));
  }
}
