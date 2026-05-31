// lib/core/theme/app_typography.dart
// ============================================================
// NOOR Design DNA — Typography System
// Single font family: Inter (Geometric Sans-Serif)
//   Vibe: Modern, clean, professional.
//
// Visual hierarchy through WEIGHT CONTRAST, not family contrast:
//   Titles:  Inter Bold/ExtraBold — commanding presence
//   Body:    Inter Regular — clean readability
//   Accent:  Inter Light Italic — elegant bios & taglines
//
// This approach is what Telegram, Signal, and premium apps use.
// Faster load, less memory, consistent rendering across scripts.
// ============================================================

import 'package:flutter/material.dart';
import 'app_colors.dart';

abstract final class AppTypography {
  // ── Titles (Inter Bold / ExtraBold) ───────────────────────

  /// Screen Title — Inter 28px Bold, 0.5px spacing, Pearl White
  static const TextStyle screenTitle = TextStyle(
        fontFamily: 'Inter',
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
        color: AppColors.pearlWhite,
        height: 1.2,
      );

  /// User Name — Inter 24px Bold, 0.2px spacing, Pearl White
  static const TextStyle userName = TextStyle(
        fontFamily: 'Inter',
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
        color: AppColors.pearlWhite,
        height: 1.25,
      );

  /// Bio — Inter 17px Light Italic, Pearl White, wide line-height
  /// "Displayed in light italic — these are the person's own words."
  static const TextStyle bio = TextStyle(
        fontFamily: 'Inter',
        fontSize: 17,
        fontWeight: FontWeight.w300,
        fontStyle: FontStyle.italic,
        color: AppColors.pearlWhite,
        height: 1.6, // "wide line-height to feel like a handwritten letter"
        letterSpacing: 0.1,
      );

  /// Tagline — "Begin with bismillah" — Inter 16px Light Italic
  static const TextStyle tagline = TextStyle(
        fontFamily: 'Inter',
        fontSize: 16,
        fontWeight: FontWeight.w300,
        fontStyle: FontStyle.italic,
        color: AppColors.slateMist,
        height: 1.4,
      );

  /// NOOR wordmark in the header — Inter 22px ExtraBold, Gold
  static const TextStyle wordmark = TextStyle(
        fontFamily: 'Inter',
        fontSize: 22,
        fontWeight: FontWeight.w800,
        letterSpacing: 2.0,
        color: AppColors.champagneGold,
      );

  // ── Body Font: Inter ──────────────────────────────────────

  /// Section Label — Inter 11px Medium, 1.5px UPPER tracking, Slate Mist
  static const TextStyle sectionLabel = TextStyle(
        fontFamily: 'Inter',
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 1.5,
        color: AppColors.slateMist,
        height: 1.2,
      );

  /// Body Text — Inter 15px Regular, 0px spacing, Pearl White
  static const TextStyle body = TextStyle(
        fontFamily: 'Inter',
        fontSize: 15,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        color: AppColors.pearlWhite,
        height: 1.5,
      );

  /// Body muted — same as body but Slate Mist
  static const TextStyle bodyMuted = TextStyle(
        fontFamily: 'Inter',
        fontSize: 15,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        color: AppColors.slateMist,
        height: 1.5,
      );

  /// Body Medium — Inter 15px Medium (for labels that need weight)
  static const TextStyle bodyMedium = TextStyle(
        fontFamily: 'Inter',
        fontSize: 15,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
        color: AppColors.pearlWhite,
        height: 1.5,
      );

  /// Caption — Inter 13px Regular, Slate Mist
  static const TextStyle caption = TextStyle(
        fontFamily: 'Inter',
        fontSize: 13,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        color: AppColors.slateMist,
        height: 1.4,
      );

  /// Caption Medium — Inter 13px Medium
  static const TextStyle captionMedium = TextStyle(
        fontFamily: 'Inter',
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: AppColors.pearlWhite,
        height: 1.4,
      );

  /// Location text on discovery card — Inter 14px Regular
  static TextStyle get cardLocation => TextStyle(
        fontFamily: 'Inter',
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.pearlWhite.withValues(alpha: 0.85),
        height: 1.3,
      );

  /// Chip label — Inter 12px Medium
  static const TextStyle chipLabel = TextStyle(
        fontFamily: 'Inter',
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.2,
        color: AppColors.pearlWhite,
      );

  /// Button label — Inter 16px SemiBold
  static const TextStyle button = TextStyle(
        fontFamily: 'Inter',
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        color: AppColors.obsidianNight,    // Dark text on gold button
        height: 1,
      );

  /// Secondary button label — same but gold text
  static const TextStyle buttonSecondary = TextStyle(
        fontFamily: 'Inter',
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        color: AppColors.champagneGold,
        height: 1,
      );

  /// Ghost button label
  static const TextStyle buttonGhost = TextStyle(
        fontFamily: 'Inter',
        fontSize: 16,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.2,
        color: AppColors.pearlWhite,
        height: 1,
      );

  /// Input label (floating) — Inter 13px Regular, Slate Mist
  static const TextStyle inputLabel = TextStyle(
        fontFamily: 'Inter',
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: AppColors.slateMist,
      );

  /// Input text — Inter 15px Regular, Pearl White
  static const TextStyle inputText = TextStyle(
        fontFamily: 'Inter',
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: AppColors.pearlWhite,
        height: 1.4,
      );

  /// Chat message text
  static const TextStyle chatMessage = TextStyle(
        fontFamily: 'Inter',
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: AppColors.pearlWhite,
        height: 1.45,
      );

  /// Timestamp in chat (hidden by default)
  static const TextStyle chatTimestamp = TextStyle(
        fontFamily: 'Inter',
        fontSize: 11,
        fontWeight: FontWeight.w400,
        color: AppColors.slateMist,
      );

  /// Unread count badge
  static const TextStyle badge = TextStyle(
        fontFamily: 'Inter',
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppColors.obsidianNight,
        height: 1,
      );

  // ── Arabic / Urdu Overrides ───────────────────────────────
  // When locale is ar/ur, switch to a system serif that supports
  // Arabic script. Playfair Display does not support Arabic.

  static TextStyle arabicTitle(double size) => TextStyle(
        fontFamily: 'serif',
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: AppColors.pearlWhite,
        height: 1.4,
      );

  // ── TextTheme Builder ─────────────────────────────────────

  /// Builds a Material TextTheme mapped to NOOR's type scale.
  /// Used in AppTheme.darkTheme
  static TextTheme get textTheme => TextTheme(
        displayLarge:   screenTitle,
        displayMedium:  userName,
        displaySmall:   tagline,
        headlineLarge:  screenTitle,
        headlineMedium: userName,
        headlineSmall:  bio,
        titleLarge:     bodyMedium,
        titleMedium:    body,
        titleSmall:     caption,
        bodyLarge:      body,
        bodyMedium:     bodyMuted,
        bodySmall:      caption,
        labelLarge:     button.copyWith(color: AppColors.pearlWhite),
        labelMedium:    chipLabel,
        labelSmall:     sectionLabel,
      );
}
