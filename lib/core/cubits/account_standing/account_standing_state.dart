import 'package:equatable/equatable.dart';

enum AccountStandingKind {
  unavailable,
  active,
  paused,
  suspended,
  banned,
  deactivated,
}

class AccountStandingState extends Equatable {
  const AccountStandingState({
    this.kind = AccountStandingKind.unavailable,
    this.hasPublishedPhoto = false,
    this.loading = false,
    this.updating = false,
    this.errorMessage,
  });

  final AccountStandingKind kind;
  final bool hasPublishedPhoto;
  final bool loading;
  final bool updating;
  final String? errorMessage;

  bool get showsPersistentNotice => switch (kind) {
        AccountStandingKind.paused ||
        AccountStandingKind.suspended ||
        AccountStandingKind.banned ||
        AccountStandingKind.deactivated =>
          true,
        _ => false,
      };

  bool get isRestricted => switch (kind) {
        AccountStandingKind.suspended ||
        AccountStandingKind.banned ||
        AccountStandingKind.deactivated =>
          true,
        _ => false,
      };

  AccountStandingState copyWith({
    AccountStandingKind? kind,
    bool? hasPublishedPhoto,
    bool? loading,
    bool? updating,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AccountStandingState(
      kind: kind ?? this.kind,
      hasPublishedPhoto: hasPublishedPhoto ?? this.hasPublishedPhoto,
      loading: loading ?? this.loading,
      updating: updating ?? this.updating,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        kind,
        hasPublishedPhoto,
        loading,
        updating,
        errorMessage,
      ];
}
