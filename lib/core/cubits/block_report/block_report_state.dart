// lib/core/cubits/block_report/block_report_state.dart
// ============================================================
// NOOR — Block / Report State
//
// Blueprint (Part 9):
//   - Blocking is silent. The blocked person is not notified.
//   - Report reasons are predefined (8 categories).
//   - 3 unique reports → auto-suspension trigger (DB-side).
//   - Reporting immediately hides profile from reporter.
// ============================================================

import 'package:equatable/equatable.dart';

// ── Report Reasons — exact blueprint values ──────────────────

enum ReportReason {
  fakeProfile(
    key:    'fake_profile',
    label:  'Fake Profile',
    detail: 'This profile appears to be fake or impersonating someone',
  ),
  inappropriatePhotos(
    key:    'inappropriate_photos',
    label:  'Inappropriate Photos',
    detail: 'Photos contain inappropriate or offensive content',
  ),
  harassment(
    key:    'harassment',
    label:  'Harassment',
    detail: 'This user is sending harassing or abusive messages',
  ),
  scam(
    key:    'scam',
    label:  'Scam',
    detail: 'This user appears to be running a scam or asking for money',
  ),
  underage(
    key:    'underage',
    label:  'Underage',
    detail: 'This user appears to be under 18',
  ),
  alreadyMarried(
    key:    'already_married',
    label:  'Already Married',
    detail: 'This user is already married and misrepresenting themselves',
  ),
  offensiveBio(
    key:    'offensive_bio',
    label:  'Offensive Bio',
    detail: 'Bio contains offensive or inappropriate language',
  ),
  other(
    key:    'other',
    label:  'Other',
    detail: 'Other reason',
  );

  const ReportReason({
    required this.key,
    required this.label,
    required this.detail,
  });

  final String key;
  final String label;
  final String detail;
}

// ── Data models ───────────────────────────────────────────────

class BlockedUser extends Equatable {
  final String userId;
  final String name;
  final String lastInitial;
  final DateTime blockedAt;

  const BlockedUser({
    required this.userId,
    required this.name,
    required this.lastInitial,
    required this.blockedAt,
  });

  @override
  List<Object?> get props => [userId, name, lastInitial, blockedAt];
}

class ReportEntry extends Equatable {
  final String       reportId;
  final String       reportedUserId;
  final String       reportedName;
  final ReportReason reason;
  final String?      description;
  final DateTime     submittedAt;

  const ReportEntry({
    required this.reportId,
    required this.reportedUserId,
    required this.reportedName,
    required this.reason,
    this.description,
    required this.submittedAt,
  });

  @override
  List<Object?> get props =>
      [reportId, reportedUserId, reason, submittedAt];
}

// ── State ─────────────────────────────────────────────────────

class BlockReportState extends Equatable {
  final List<BlockedUser>  blockedUsers;
  final List<ReportEntry>  reportHistory;
  /// Profile IDs hidden from the reporter's UI (local, pending backend)
  final Set<String>        hiddenProfileIds;
  final bool               isSubmitting;
  final String?            successMessage;
  final String?            error;

  const BlockReportState({
    this.blockedUsers    = const [],
    this.reportHistory   = const [],
    this.hiddenProfileIds = const {},
    this.isSubmitting    = false,
    this.successMessage  = null,
    this.error           = null,
  });

  bool isBlocked(String userId) =>
      blockedUsers.any((b) => b.userId == userId);

  bool isHidden(String profileId) =>
      hiddenProfileIds.contains(profileId);

  BlockReportState copyWith({
    List<BlockedUser>?  blockedUsers,
    List<ReportEntry>?  reportHistory,
    Set<String>?        hiddenProfileIds,
    bool?               isSubmitting,
    String?             successMessage,
    String?             error,
    bool                clearSuccess = false,
    bool                clearError   = false,
  }) {
    return BlockReportState(
      blockedUsers:     blockedUsers     ?? this.blockedUsers,
      reportHistory:    reportHistory    ?? this.reportHistory,
      hiddenProfileIds: hiddenProfileIds ?? this.hiddenProfileIds,
      isSubmitting:     isSubmitting     ?? this.isSubmitting,
      successMessage:   clearSuccess ? null : (successMessage ?? this.successMessage),
      error:            clearError   ? null : (error          ?? this.error),
    );
  }

  @override
  List<Object?> get props => [
        blockedUsers, reportHistory, hiddenProfileIds,
        isSubmitting, successMessage, error,
      ];
}
