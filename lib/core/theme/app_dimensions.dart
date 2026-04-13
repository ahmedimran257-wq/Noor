// lib/core/theme/app_dimensions.dart
// ============================================================
// NOOR Design DNA — Spacing, Radius & Layout Constants
// "Premium apps use whitespace as a feature."
// ============================================================

abstract final class AppDimensions {
  // ── Grid & Margins ────────────────────────────────────────

  /// Standard horizontal margin. "The Grid: 24px horizontal margin."
  static const double horizontalMargin = 24.0;

  /// Minimum touch target size (accessibility).
  static const double minTouchTarget = 48.0;

  // ── Corner Radii ──────────────────────────────────────────

  /// For large cards (profile cards, section panels).
  /// "Large Cards: 24px (Soft, modern)."
  static const double radiusCard = 24.0;

  /// For buttons and inputs.
  /// "Buttons/Inputs: 12px (Professional. NO pill-shapes)."
  static const double radiusButton = 12.0;

  /// For small chips and tags.
  static const double radiusChip = 8.0;

  /// For tiny indicators (badges, dots).
  static const double radiusTiny = 4.0;

  // ── Button Dimensions ─────────────────────────────────────

  /// Standard button height. "Height: 56px."
  static const double buttonHeight = 56.0;

  /// Small button height (secondary actions).
  static const double buttonHeightSmall = 44.0;

  // ── Input Dimensions ──────────────────────────────────────

  /// Text field height.
  static const double inputHeight = 56.0;

  // ── Icon Sizes ────────────────────────────────────────────

  static const double iconSizeSmall  = 16.0;
  static const double iconSizeMedium = 20.0;
  static const double iconSizeLarge  = 24.0;
  static const double iconSizeXLarge = 32.0;

  // ── Border Widths ─────────────────────────────────────────

  /// Standard card border. "1px border of rgba(255,255,255,0.1)."
  static const double borderThin = 1.0;

  /// Input focus border. "2px Champagne Gold."
  static const double borderFocus = 2.0;

  // ── Spacing Scale (8pt grid) ──────────────────────────────

  static const double space2  = 2.0;
  static const double space4  = 4.0;
  static const double space6  = 6.0;
  static const double space8  = 8.0;
  static const double space10 = 10.0;
  static const double space12 = 12.0;
  static const double space14 = 14.0;
  static const double space16 = 16.0;
  static const double space20 = 20.0;
  static const double space24 = 24.0;
  static const double space28 = 28.0;
  static const double space32 = 32.0;
  static const double space40 = 40.0;
  static const double space48 = 48.0;
  static const double space56 = 56.0;
  static const double space64 = 64.0;
  static const double space80 = 80.0;

  // ── Discovery Card ────────────────────────────────────────

  /// Card aspect ratio: 3:4 portrait.
  static const double cardAspectRatio = 3 / 4;

  // ── Animation Durations ───────────────────────────────────

  /// "The Reveal" — elements entering the screen (300–500ms).
  static const Duration durationReveal = Duration(milliseconds: 350);

  /// "The Transition" — state changes, chip color (200–300ms).
  static const Duration durationTransition = Duration(milliseconds: 250);

  /// "The Tactile Pop" — micro-interactions (600–800ms).
  static const Duration durationTactile = Duration(milliseconds: 700);

  /// Button press scale animation (100ms).
  static const Duration durationButtonPress = Duration(milliseconds: 100);

  /// Page transition "Unfolding" (350ms).
  static const Duration durationPageTransition = Duration(milliseconds: 350);

  /// Shimmer sweep duration.
  static const Duration durationShimmer = Duration(milliseconds: 1500);

  // ── Interest Ceremony Timeline ────────────────────────────

  static const Duration ceremonyCooldown     = Duration(milliseconds: 2100);
  static const Duration ceremonyRingExpand   = Duration(milliseconds: 400);
  static const Duration ceremonyRingFade     = Duration(milliseconds: 300);
  static const Duration ceremonyParticles    = Duration(milliseconds: 400);
  static const Duration ceremonyCheckmark    = Duration(milliseconds: 300);
  static const Duration ceremonyTextFade     = Duration(milliseconds: 300);
  static const Duration ceremonyOverlayFade  = Duration(milliseconds: 300);
}
