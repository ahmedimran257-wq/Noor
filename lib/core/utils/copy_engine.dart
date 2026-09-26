// SILARAH — Copy Engine
// Returns the correct UI copy string based on who is creating
// the profile (self / parent / sibling / guardian).
//
// Usage:
//   final relation = cubit.currentData.profileCreatorRelation;
//   Text(CopyEngine.hijabQuestion(l10n, relation, 'female'))
import 'package:silarah/l10n/generated/app_localizations.dart';

class CopyEngine {
  CopyEngine._();

  // Islamic practice questions
  /// Returns the correct hijab / dress question for the screen context.
  static String hijabQuestion(
    AppLocalizations l10n,
    String? creatorRelation,
    String? gender,
  ) {
    if (gender == 'male') {
      return beardQuestion(l10n, creatorRelation);
    }
    return switch (creatorRelation) {
      'parent' || 'guardian' => l10n.copy_hijab_parent,
      'sibling' => l10n.copy_hijab_sibling,
      _ => l10n.copy_hijab_self,
    };
  }

  /// Returns the correct beard question for the screen context.
  static String beardQuestion(AppLocalizations l10n, String? creatorRelation) =>
      switch (creatorRelation) {
        'parent' || 'guardian' => l10n.copy_beard_parent,
        'sibling' => l10n.copy_beard_sibling,
        _ => l10n.copy_beard_self,
      };

  /// Returns the correct five-times prayer question for the screen context.
  static String prayerQuestion(
    AppLocalizations l10n,
    String? creatorRelation,
  ) =>
      switch (creatorRelation) {
        'parent' || 'guardian' => l10n.copy_prayer_parent,
        'sibling' => l10n.copy_prayer_sibling,
        _ => l10n.copy_prayer_self,
      };

  // Identity labels
  /// Returns the correct community / biradari field label.
  static String communityQuestion(
    AppLocalizations l10n,
    String? creatorRelation,
  ) =>
      switch (creatorRelation) {
        'parent' ||
        'guardian' ||
        'sibling' =>
          l10n.onboarding_label_community_parent,
        _ => l10n.onboarding_label_community,
      };
}
