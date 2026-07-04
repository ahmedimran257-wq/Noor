// lib/core/cubits/block_report/block_report_cubit.dart
// ============================================================
// MITHAQ - Block / Report Cubit (Supabase production flow)
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
// Real mode:
//   - blockUser:   INSERT INTO blocks (blocker_id, blocked_id)
//                  DB trigger sever_ties_on_block() auto-removes matches/interests
//   - unblockUser: DELETE FROM blocks
//   - reportUser:  INSERT INTO reports (reporter_id, reported_user_id, reason, description)
//                  DB trigger check_report_threshold() auto-suspends after 3 unique reports
//
// ============================================================

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../services/supabase_service.dart';
import 'block_report_state.dart';

class BlockReportCubit extends Cubit<BlockReportState> {
  BlockReportCubit() : super(const BlockReportState()) {
    _loadInitial();
  }

  bool get _isRealMode => SupabaseService.isInitialized;

  // Initial load

  Future<void> _loadInitial() async {
    if (_isRealMode) {
      await _loadFromDb();
    }
  }

  /// Load blocks from Supabase
  Future<void> _loadFromDb() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) {
      return;
    }

    try {
      // Load blocked users
      final blockedRows = await SupabaseService.client
          .from('blocks')
          .select('blocked_id, created_at')
          .eq('blocker_id', userId);

      final blockedUsers = <BlockedUser>[];
      final hiddenIds = <String>{};

      for (final row in (blockedRows as List<dynamic>)) {
        final blockedId = row['blocked_id'] as String;
        hiddenIds.add(blockedId);

        // Try to get the blocked user's name from profiles
        String name = 'User';
        String lastInitial = '';
        try {
          final profile = await SupabaseService.client
              .from('profiles')
              .select('first_name, last_name')
              .eq('user_id', blockedId)
              .maybeSingle();
          if (profile != null) {
            name = (profile['first_name'] as String?) ?? 'User';
            final lastName = (profile['last_name'] as String?) ?? '';
            lastInitial = lastName.isNotEmpty ? lastName[0] : '';
          }
        } catch (_) {}

        blockedUsers.add(BlockedUser(
          userId: blockedId,
          name: name,
          lastInitial: lastInitial,
          blockedAt:
              DateTime.tryParse(row['created_at'] as String) ?? DateTime.now(),
        ));
      }

      // Load report history
      final reportRows = await SupabaseService.client
          .from('reports')
          .select('id, reported_user_id, reason, description, created_at')
          .eq('reporter_id', userId)
          .order('created_at', ascending: false);

      final reportHistory = <ReportEntry>[];
      for (final row in (reportRows as List<dynamic>)) {
        final reportedUserId = row['reported_user_id'] as String;
        hiddenIds.add(reportedUserId);

        // Get reported user name
        String reportedName = 'User';
        try {
          final profile = await SupabaseService.client
              .from('profiles')
              .select('first_name')
              .eq('user_id', reportedUserId)
              .maybeSingle();
          if (profile != null) {
            reportedName = (profile['first_name'] as String?) ?? 'User';
          }
        } catch (_) {}

        reportHistory.add(ReportEntry(
          reportId: row['id'] as String,
          reportedUserId: reportedUserId,
          reportedName: reportedName,
          reason: ReportReason.values.firstWhere(
            (r) => r.key == (row['reason'] as String),
            orElse: () => ReportReason.other,
          ),
          description: row['description'] as String?,
          submittedAt:
              DateTime.tryParse(row['created_at'] as String) ?? DateTime.now(),
        ));
      }

      if (!isClosed) {
        emit(state.copyWith(
          blockedUsers: blockedUsers,
          reportHistory: reportHistory,
          hiddenProfileIds: hiddenIds,
        ));
      }
    } catch (e) {
      debugPrint('[BlockReportCubit] Error loading from DB: $e');
    }
  }

  // Block

  /// Silently block a user.
  /// Blueprint: "The blocked person is not notified."
  Future<void> blockUser({
    required String userId,
    required String name,
    required String lastInitial,
  }) async {
    if (state.isBlocked(userId)) return;
    if (!_isRealMode) return;

    emit(state.copyWith(isSubmitting: true));
    final activeUserId = SupabaseService.currentUserId;
    if (activeUserId == null) {
      emit(state.copyWith(isSubmitting: false));
      return;
    }

    if (_isRealMode) {
      // Real mode: INSERT INTO blocks
      final myId = activeUserId;
      try {
        await SupabaseService.client.from('blocks').insert({
          'blocker_id': myId,
          'blocked_id': userId,
        });
        // DB trigger sever_ties_on_block() automatically:
        //   - Deletes matches between blocker and blocked
        //   - Deletes interests between the pair
      } catch (e) {
        debugPrint('[BlockReportCubit] Error blocking user: $e');
        emit(state.copyWith(isSubmitting: false));
        return;
      }
    }

    if (isClosed) return;

    final blocked = BlockedUser(
      userId: userId,
      name: name,
      lastInitial: lastInitial,
      blockedAt: DateTime.now(),
    );

    final updatedBlocks = [blocked, ...state.blockedUsers];
    final updatedHidden = {...state.hiddenProfileIds, userId};

    emit(state.copyWith(
      isSubmitting: false,
      blockedUsers: updatedBlocks,
      hiddenProfileIds: updatedHidden,
      successMessage: 'User blocked. They can no longer contact you.',
    ));
  }

  /// Unblock a previously blocked user.
  Future<void> unblockUser(String userId) async {
    if (!_isRealMode) return;

    emit(state.copyWith(isSubmitting: true));
    final activeUserId = SupabaseService.currentUserId;
    if (activeUserId == null) {
      emit(state.copyWith(isSubmitting: false));
      return;
    }

    if (_isRealMode) {
      final myId = activeUserId;
      try {
        await SupabaseService.client
            .from('blocks')
            .delete()
            .eq('blocker_id', myId)
            .eq('blocked_id', userId);
      } catch (e) {
        debugPrint('[BlockReportCubit] Error unblocking user: $e');
        emit(state.copyWith(isSubmitting: false));
        return;
      }
    }

    if (isClosed) return;

    final updatedBlocks =
        state.blockedUsers.where((b) => b.userId != userId).toList();
    final updatedHidden = {...state.hiddenProfileIds}..remove(userId);

    emit(state.copyWith(
      isSubmitting: false,
      blockedUsers: updatedBlocks,
      hiddenProfileIds: updatedHidden,
    ));
  }

  // Report

  /// Report a user with a predefined reason.
  /// Blueprint: "Reporting immediately hides that profile from the reporter."
  Future<void> reportUser({
    required String reportedUserId,
    required String reportedName,
    required ReportReason reason,
    String? description,
  }) async {
    if (!_isRealMode) return;

    emit(state.copyWith(isSubmitting: true, clearError: true));
    final activeUserId = SupabaseService.currentUserId;
    if (activeUserId == null) {
      emit(state.copyWith(isSubmitting: false));
      return;
    }

    String? reportId;

    if (_isRealMode) {
      final myId = activeUserId;
      try {
        final result = await SupabaseService.client
            .from('reports')
            .insert({
              'reporter_id': myId,
              'reported_user_id': reportedUserId,
              'reason': reason.key,
              'description': description,
            })
            .select('id')
            .single();
        reportId = result['id'] as String;
        // DB trigger check_report_threshold() auto-suspends after 3 unique reports
      } catch (e) {
        debugPrint('[BlockReportCubit] Error reporting user: $e');
        emit(state.copyWith(isSubmitting: false));
        return;
      }
    }

    if (isClosed) return;

    final entry = ReportEntry(
      reportId: reportId!,
      reportedUserId: reportedUserId,
      reportedName: reportedName,
      reason: reason,
      description: description,
      submittedAt: DateTime.now(),
    );

    // Blueprint: "immediately hides that profile from the reporter"
    final updatedHidden = {...state.hiddenProfileIds, reportedUserId};

    emit(state.copyWith(
      isSubmitting: false,
      reportHistory: [entry, ...state.reportHistory],
      hiddenProfileIds: updatedHidden,
      successMessage:
          'Report submitted. JazakAllah for keeping the community safe.',
    ));
  }

  void clearMessages() {
    emit(state.copyWith(clearSuccess: true, clearError: true));
  }
}
