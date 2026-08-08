// SILARAH Design DNA — Typography System
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
// the "private gallery" editorial DNA that separates SILARAH from
// generic apps.
import 'package:flutter/material.dart';
import 'app_colors.dart';

abstract final class AppTypography {
  // Font Family Constants
  static const String _heading = 'PlayfairDisplay';
  static const String _body = 'Inter';

  // Titles (Playfair Display — Serif)
  /// Screen Title — Playfair Display 28px Bold, 0.5px spacing, Pearl White
  static TextStyle get screenTitle => TextStyle(
        fontFamily: _heading,
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
        color: AppColors.pearlWhite,
        height: 1.2,
      );

  /// User Name — Playfair Display 24px SemiBold, 0.2px spacing, Pearl White
  static TextStyle get userName => TextStyle(
        fontFamily: _heading,
        fontSize: 24,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        color: AppColors.pearlWhite,
        height: 1.25,
      );

  /// Bio — Playfair Display 17px Italic, Pearl White, wide line-height
  /// "Displayed in italic — these are the person's own words."
  static TextStyle get bio => TextStyle(
        fontFamily: _heading,
        fontSize: 17,
        fontWeight: FontWeight.w400,
        fontStyle: FontStyle.italic,
        color: AppColors.pearlWhite,
        height: 1.6, // "wide line-height to feel like a handwritten letter"
        letterSpacing: 0.1,
      );

  /// Tagline — "Begin with bismillah" — Playfair Display 16px Italic
  static TextStyle get tagline => TextStyle(
        fontFamily: _heading,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        fontStyle: FontStyle.italic,
        color: AppColors.slateMist,
        height: 1.4,
      );

  /// SILARAH wordmark in the header — Inter 22px ExtraBold, Gold
  /// (Wordmark stays geometric sans-serif for brand identity)
  static TextStyle get wordmark => TextStyle(
        fontFamily: _body,
        fontSize: 22,
        fontWeight: FontWeight.w800,
        letterSpacing: 2.0,
        color: AppColors.champagneGold,
      );

  // Body Font: Inter
  /// Section Label — Inter 11px Medium, 1.5px UPPER tracking, Slate Mist
  static TextStyle get sectionLabel => TextStyle(
        fontFamily: _body,
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 1.5,
        color: AppColors.slateMist,
        height: 1.2,
      );

  /// Body Text — Inter 15px Regular, 0px spacing, Pearl White
  static TextStyle get body => TextStyle(
        fontFamily: _body,
        fontSize: 15,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        color: AppColors.pearlWhite,
        height: 1.5,
      );

  /// Body muted — same as body but Slate Mist
  static TextStyle get bodyMuted => TextStyle(
        fontFamily: _body,
        fontSize: 15,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        color: AppColors.slateMist,
        height: 1.5,
      );

  /// Body Medium — Inter 15px Medium (for labels that need weight)
  static TextStyle get bodyMedium => TextStyle(
        fontFamily: _body,
        fontSize: 15,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
        color: AppColors.pearlWhite,
        height: 1.5,
      );

  /// Caption — Inter 13px Regular, Slate Mist
  static TextStyle get caption => TextStyle(
        fontFamily: _body,
        fontSize: 13,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        color: AppColors.slateMist,
        height: 1.4,
      );

  /// Caption Medium — Inter 13px Medium
  static TextStyle get captionMedium => TextStyle(
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
  static TextStyle get chipLabel => TextStyle(
        fontFamily: _body,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.2,
        color: AppColors.pearlWhite,
      );

  /// Button label — Inter 16px SemiBold
  static TextStyle get button => TextStyle(
        fontFamily: _body,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        color: AppColors.obsidianNight, // Dark text on gold button
        height: 1,
      );

  /// Secondary button label — same but gold text
  static TextStyle get buttonSecondary => TextStyle(
        fontFamily: _body,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        color: AppColors.champagneGold,
        height: 1,
      );

  /// Ghost button label
  static TextStyle get buttonGhost => TextStyle(
        fontFamily: _body,
        fontSize: 16,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.2,
        color: AppColors.pearlWhite,
        height: 1,
      );

  /// Input label (floating) — Inter 13px Regular, Slate Mist
  static TextStyle get inputLabel => TextStyle(
        fontFamily: _body,
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: AppColors.slateMist,
      );

  /// Input text — Inter 15px Regular, Pearl White
  static TextStyle get inputText => TextStyle(
        fontFamily: _body,
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: AppColors.pearlWhite,
        height: 1.4,
      );

  /// Chat message text
  static TextStyle get chatMessage => TextStyle(
        fontFamily: _body,
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: AppColors.pearlWhite,
        height: 1.45,
      );

  /// Timestamp in chat (hidden by default)
  static TextStyle get chatTimestamp => TextStyle(
        fontFamily: _body,
        fontSize: 11,
        fontWeight: FontWeight.w400,
        color: AppColors.slateMist,
      );

  /// Unread count badge
  static TextStyle get badge => TextStyle(
        fontFamily: _body,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppColors.obsidianNight,
        height: 1,
      );

  // Arabic / Urdu Overrides
  // When locale is ar/ur, switch to a system serif that supports
  // Arabic script. Playfair Display does not support Arabic.

  static TextStyle arabicTitle(double size) => TextStyle(
        fontFamily: 'serif',
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: AppColors.pearlWhite,
        height: 1.4,
      );

  // TextTheme Builder
  /// Builds a Material TextTheme mapped to SILARAH's type scale.
  /// Used by every palette created through [AppTheme.forMode].
  static TextTheme get textTheme => TextTheme(
        displayLarge: screenTitle,
        displayMedium: userName,
        displaySmall: tagline,
        headlineLarge: screenTitle,
        headlineMedium: userName,
        headlineSmall: bio,
        titleLarge: bodyMedium,
        titleMedium: body,
        titleSmall: caption,
        bodyLarge: body,
        bodyMedium: bodyMuted,
        bodySmall: caption,
        labelLarge: button.copyWith(color: AppColors.pearlWhite),
        labelMedium: chipLabel,
        labelSmall: sectionLabel,
      );
}
