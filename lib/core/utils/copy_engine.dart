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

class CopyEngine {
  CopyEngine._();

  /// Resolves creator relation default and handles backend mapping.
  // TODO (backend): wire to profileCreatorRelation from Supabase profiles table.
  static String _getRelation(String? creatorRelation) => creatorRelation ?? 'self';

  // ── Islamic practice questions ──────────────────────────────

  /// Returns the correct hijab / dress question for the screen context.
  static String hijabQuestion(String? creatorRelation, String? gender) {
    if (gender == 'male') return 'Does he observe Islamic dress / beard?';
    switch (_getRelation(creatorRelation)) {
      case 'parent':
        return 'Does your daughter observe hijab?';
      case 'sibling':
        return 'Does your sister observe hijab?';
      case 'guardian':
        return 'Does your ward observe hijab?';
      default:
        return 'Do you observe hijab?';
    }
  }

  /// Returns the correct beard question for the screen context.
  static String beardQuestion(String? creatorRelation) {
    switch (_getRelation(creatorRelation)) {
      case 'parent':
        return 'Does your son have a beard?';
      case 'sibling':
        return 'Does your brother have a beard?';
      case 'guardian':
        return 'Does your ward have a beard?';
      default:
        return 'Do you have a beard?';
    }
  }

  /// Returns the correct five-times prayer question for the screen context.
  static String prayerQuestion(String? creatorRelation) {
    switch (_getRelation(creatorRelation)) {
      case 'parent':
      case 'guardian':
        return 'Does your child pray five times daily?';
      case 'sibling':
        return 'Does your sibling pray five times daily?';
      default:
        return 'Do you pray five times daily?';
    }
  }

  // ── Bio prompts ─────────────────────────────────────────────

  /// Returns the correct bio prompt for the screen context.
  static String bioPrompt(String? creatorRelation) {
    switch (_getRelation(creatorRelation)) {
      case 'parent':
        return 'Describe your child with honesty and dignity.';
      case 'sibling':
        return 'Describe your sibling with honesty and dignity.';
      case 'guardian':
        return 'Describe your ward with honesty and dignity.';
      default:
        return 'Describe yourself with honesty and dignity.';
    }
  }

  // ── Identity labels ─────────────────────────────────────────

  /// Returns the correct community / biradari field label.
  static String communityQuestion(String? creatorRelation) {
    switch (_getRelation(creatorRelation)) {
      case 'parent':
      case 'guardian':
        return 'Their community / biradari';
      case 'sibling':
        return 'Your family community / biradari';
      default:
        return 'Your community / biradari';
    }
  }
}
