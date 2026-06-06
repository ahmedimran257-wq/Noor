// lib/core/utils/copy_engine.dart
// ============================================================
// NOOR — Copy Engine
// Returns the correct UI copy string based on who is creating
// the profile (self / parent / sibling / guardian).
//
// Usage:
//   final relation = cubit.currentData.profileCreatorRelation;
//   Text(CopyEngine.hijabQuestion(relation, 'female'))
// ============================================================

import 'package:noor/l10n/generated/app_localizations.dart';

class CopyEngine {
  CopyEngine._();

  /// Resolves creator relation default and handles backend mapping.
  // TODO (backend): wire to profileCreatorRelation from Supabase profiles table.
  static String _getRelation(String? creatorRelation) => creatorRelation ?? 'self';

  // ── Islamic practice questions ──────────────────────────────

  /// Returns the correct hijab / dress question for the screen context.
  static String hijabQuestion(AppLocalizations l10n, String? creatorRelation, String? gender) {
    if (gender == 'male') {
      return l10n.localeName == 'ar' ? 'هل يلتزم بالزي الإسلامي / اللحية؟' : 'Does he observe Islamic dress / beard?';
    }
    switch (_getRelation(creatorRelation)) {
      case 'parent':
        return l10n.copy_hijab_parent;
      case 'sibling':
        return l10n.copy_hijab_sibling;
      case 'guardian':
        return l10n.localeName == 'ar' ? 'هل ترتدي من ترعاها الحجاب؟' : 'Does your ward observe hijab?';
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
        return l10n.localeName == 'ar' ? 'هل لمن ترعاه لحية؟' : 'Does your ward have a beard?';
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

  // ── Bio prompts ─────────────────────────────────────────────

  /// Returns the correct bio prompt for the screen context.
  static String bioPrompt(AppLocalizations l10n, String? creatorRelation) {
    switch (_getRelation(creatorRelation)) {
      case 'parent':
        return l10n.localeName == 'ar' ? 'صِف طفلك بصدق وكرامة.' : 'Describe your child with honesty and dignity.';
      case 'sibling':
        return l10n.localeName == 'ar' ? 'صِف شقيقك/شقيقتك بصدق وكرامة.' : 'Describe your sibling with honesty and dignity.';
      case 'guardian':
        return l10n.localeName == 'ar' ? 'صِف من ترعاه بصدق وكرامة.' : 'Describe your ward with honesty and dignity.';
      default:
        return l10n.onboarding_hint_bio;
    }
  }

  // ── Identity labels ─────────────────────────────────────────

  /// Returns the correct community / biradari field label.
  static String communityQuestion(AppLocalizations l10n, String? creatorRelation) {
    switch (_getRelation(creatorRelation)) {
      case 'parent':
      case 'guardian':
        return l10n.onboarding_label_community_parent;
      case 'sibling':
        return l10n.localeName == 'ar' ? 'مجتمع عائلتك / بيرادري' : 'Your family community / biradari';
      default:
        return l10n.onboarding_label_community;
    }
  }
}
