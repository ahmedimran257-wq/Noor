// SILARAH — Copy Engine
// Returns the correct UI copy string based on who is creating
// the profile (self / parent / sibling / guardian).
//
// Usage:
//   final relation = cubit.currentData.profileCreatorRelation;
//   Text(CopyEngine.hijabQuestion(relation, 'female'))
import 'package:silarah/l10n/generated/app_localizations.dart';

class CopyEngine {
  CopyEngine._();

  /// Resolves creator relation default and handles backend mapping.
  static String _getRelation(String? creatorRelation) =>
      creatorRelation ?? 'self';

  // Islamic practice questions
  /// Returns the correct hijab / dress question for the screen context.
  static String hijabQuestion(
      AppLocalizations l10n, String? creatorRelation, String? gender) {
    if (gender == 'male') {
      return beardQuestion(l10n, creatorRelation);
    }
    switch (_getRelation(creatorRelation)) {
      case 'parent':
        return l10n.copy_hijab_parent;
      case 'sibling':
        return l10n.copy_hijab_sibling;
      case 'guardian':
        return l10n.copy_hijab_parent;
      default:
        return l10n.copy_hijab_self;
    }
  }

  /// Returns the correct beard question for the screen context.
  static String beardQuestion(AppLocalizations l10n, String? creatorRelation) {
    switch (_getRelation(creatorRelation)) {
      case 'parent':
        return l10n.copy_beard_parent;
      case 'sibling':
        return l10n.copy_beard_sibling;
      case 'guardian':
        return l10n.copy_beard_parent;
      default:
        return l10n.copy_beard_self;
    }
  }

  /// Returns the correct five-times prayer question for the screen context.
  static String prayerQuestion(AppLocalizations l10n, String? creatorRelation) {
    switch (_getRelation(creatorRelation)) {
      case 'parent':
      case 'guardian':
        return l10n.copy_prayer_parent;
      case 'sibling':
        return l10n.copy_prayer_sibling;
      default:
        return l10n.copy_prayer_self;
    }
  }

  // Bio prompts
  /// Returns the correct bio prompt for the screen context.
  static String bioPrompt(AppLocalizations l10n, String? creatorRelation) {
    switch (_getRelation(creatorRelation)) {
      case 'parent':
      case 'sibling':
      case 'guardian':
        return l10n.onboarding_hint_bio;
      default:
        return l10n.onboarding_hint_bio;
    }
  }

  // Identity labels
  /// Returns the correct community / biradari field label.
  static String communityQuestion(
      AppLocalizations l10n, String? creatorRelation) {
    switch (_getRelation(creatorRelation)) {
      case 'parent':
      case 'guardian':
        return l10n.onboarding_label_community_parent;
      case 'sibling':
        return l10n.onboarding_label_community_parent;
      default:
        return l10n.onboarding_label_community;
    }
  }
}
