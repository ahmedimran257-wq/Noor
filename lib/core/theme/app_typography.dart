// lib/core/theme/app_typography.dart
// ============================================================
// MITHAQ Design DNA — Typography System
//
// DUAL FONT-PAIRING STRATEGY (high-end magazine / editorial feel):
//
//   Heading Font: Playfair Display (Serif)
//     Vibe: Prestigious, timeless, elegant.
//     Usage: Screen titles, user names, wordmark tagline, bios (Italic).
//     Weight: Semi-Bold (600) or Bold (700).
//
//   Body Font: Inter (Geometric Sans-Serif)
//     Vibe: Modern, clean, professional.
//     Usage: Bios, labels, settings, chat messages.
//     Weight: Regular (400) for body, Medium (500) for labels.
//
// This contrast between serif headings and sans-serif body creates
// the "private gallery" editorial DNA that separates MITHAQ from
// generic apps.
// ============================================================

import 'package:flutter/material.dart';
import 'app_colors.dart';

abstract final class AppTypography {
  // ── Font Family Constants ─────────────────────────────────
  static const String _heading = 'PlayfairDisplay';
  static const String _body    = 'Inter';

  // ── Titles (Playfair Display — Serif) ─────────────────────

  /// Screen Title — Playfair Display 28px Bold, 0.5px spacing, Pearl White
  static const TextStyle screenTitle = TextStyle(
        fontFamily: _heading,
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
        color: AppColors.pearlWhite,
        height: 1.2,
      );

  /// User Name — Playfair Display 24px SemiBold, 0.2px spacing, Pearl White
  static const TextStyle userName = TextStyle(
        fontFamily: _heading,
        fontSize: 24,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        color: AppColors.pearlWhite,
        height: 1.25,
      );

  /// Bio — Playfair Display 17px Italic, Pearl White, wide line-height
  /// "Displayed in italic — these are the person's own words."
  static const TextStyle bio = TextStyle(
        fontFamily: _heading,
        fontSize: 17,
        fontWeight: FontWeight.w400,
        fontStyle: FontStyle.italic,
        color: AppColors.pearlWhite,
        height: 1.6, // "wide line-height to feel like a handwritten letter"
        letterSpacing: 0.1,
      );

  /// Tagline — "Begin with bismillah" — Playfair Display 16px Italic
  static const TextStyle tagline = TextStyle(
        fontFamily: _heading,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        fontStyle: FontStyle.italic,
        color: AppColors.slateMist,
        height: 1.4,
      );

  /// MITHAQ wordmark in the header — Inter 22px ExtraBold, Gold
  /// (Wordmark stays geometric sans-serif for brand identity)
  static const TextStyle wordmark = TextStyle(
        fontFamily: _body,
        fontSize: 22,
        fontWeight: FontWeight.w800,
        letterSpacing: 2.0,
        color: AppColors.champagneGold,
      );

  // ── Body Font: Inter ──────────────────────────────────────

  /// Section Label — Inter 11px Medium, 1.5px UPPER tracking, Slate Mist
  static const TextStyle sectionLabel = TextStyle(
        fontFamily: _body,
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 1.5,
        color: AppColors.slateMist,
        height: 1.2,
      );

  /// Body Text — Inter 15px Regular, 0px spacing, Pearl White
  static const TextStyle body = TextStyle(
        fontFamily: _body,
        fontSize: 15,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        color: AppColors.pearlWhite,
        height: 1.5,
      );

  /// Body muted — same as body but Slate Mist
  static const TextStyle bodyMuted = TextStyle(
        fontFamily: _body,
        fontSize: 15,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        color: AppColors.slateMist,
        height: 1.5,
      );

  /// Body Medium — Inter 15px Medium (for labels that need weight)
  static const TextStyle bodyMedium = TextStyle(
        fontFamily: _body,
        fontSize: 15,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
        color: AppColors.pearlWhite,
        height: 1.5,
      );

  /// Caption — Inter 13px Regular, Slate Mist
  static const TextStyle caption = TextStyle(
        fontFamily: _body,
        fontSize: 13,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        color: AppColors.slateMist,
        height: 1.4,
      );

  /// Caption Medium — Inter 13px Medium
  static const TextStyle captionMedium = TextStyle(
        fontFamily: _body,
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: AppColors.pearlWhite,
        height: 1.4,
      );

  /// Location text on discovery card — Inter 14px Regular
  static TextStyle get cardLocation => TextStyle(
        fontFamily: _body,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.pearlWhite.withValues(alpha: 0.85),
        height: 1.3,
      );

  /// Chip label — Inter 12px Medium
  static const TextStyle chipLabel = TextStyle(
        fontFamily: _body,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.2,
        color: AppColors.pearlWhite,
      );

  /// Button label — Inter 16px SemiBold
  static const TextStyle button = TextStyle(
        fontFamily: _body,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        color: AppColors.obsidianNight,    // Dark text on gold button
        height: 1,
      );

  /// Secondary button label — same but gold text
  static const TextStyle buttonSecondary = TextStyle(
        fontFamily: _body,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        color: AppColors.champagneGold,
        height: 1,
      );

  /// Ghost button label
  static const TextStyle buttonGhost = TextStyle(
        fontFamily: _body,
        fontSize: 16,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.2,
        color: AppColors.pearlWhite,
        height: 1,
      );

  /// Input label (floating) — Inter 13px Regular, Slate Mist
  static const TextStyle inputLabel = TextStyle(
        fontFamily: _body,
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: AppColors.slateMist,
      );

  /// Input text — Inter 15px Regular, Pearl White
  static const TextStyle inputText = TextStyle(
        fontFamily: _body,
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: AppColors.pearlWhite,
        height: 1.4,
      );

  /// Chat message text
  static const TextStyle chatMessage = TextStyle(
        fontFamily: _body,
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: AppColors.pearlWhite,
        height: 1.45,
      );

  /// Timestamp in chat (hidden by default)
  static const TextStyle chatTimestamp = TextStyle(
        fontFamily: _body,
        fontSize: 11,
        fontWeight: FontWeight.w400,
        color: AppColors.slateMist,
      );

  /// Unread count badge
  static const TextStyle badge = TextStyle(
        fontFamily: _body,
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

  /// Builds a Material TextTheme mapped to MITHAQ's type scale.
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
