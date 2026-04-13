// lib/core/theme/app_typography.dart
// ============================================================
// NOOR Design DNA — Typography System
// "We use a Font Pairing strategy to make the app feel like
//  a high-end magazine or a wedding invitation."
//
// Heading Font: Playfair Display (Serif)
//   Vibe: Prestigious, timeless, elegant.
//   Usage: User names, screen titles, "Bismillah" tagline, bios.
//
// Body Font: Inter (Geometric Sans-Serif)
//   Vibe: Modern, clean, professional.
//   Usage: Labels, settings, chat messages, body copy.
// ============================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

abstract final class AppTypography {
  // ── Heading Font: Playfair Display ────────────────────────

  /// Screen Title — Playfair 28px Bold, 0.5px spacing, Pearl White
  static TextStyle get screenTitle => GoogleFonts.playfairDisplay(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
        color: AppColors.pearlWhite,
        height: 1.2,
      );

  /// User Name — Playfair 24px SemiBold, 0.2px spacing, Pearl White
  static TextStyle get userName => GoogleFonts.playfairDisplay(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        color: AppColors.pearlWhite,
        height: 1.25,
      );

  /// Bio — Playfair 17px Italic, Pearl White, wide line-height
  /// "Displayed in italic display font — these are the person's own words."
  static TextStyle get bio => GoogleFonts.playfairDisplay(
        fontSize: 17,
        fontWeight: FontWeight.w400,
        fontStyle: FontStyle.italic,
        color: AppColors.pearlWhite,
        height: 1.6, // "wide line-height to feel like a handwritten letter"
        letterSpacing: 0,
      );

  /// Tagline — "Begin with bismillah" — Playfair 16px Italic
  static TextStyle get tagline => GoogleFonts.playfairDisplay(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        fontStyle: FontStyle.italic,
        color: AppColors.slateMist,
        height: 1.4,
      );

  /// NOOR wordmark in the header — Playfair 22px SemiBold, Gold
  static TextStyle get wordmark => GoogleFonts.playfairDisplay(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        letterSpacing: 2.0,
        color: AppColors.champagneGold,
      );

  // ── Body Font: Inter ──────────────────────────────────────

  /// Section Label — Inter 11px Medium, 1.5px UPPER tracking, Slate Mist
  static TextStyle get sectionLabel => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 1.5,
        color: AppColors.slateMist,
        height: 1.2,
      );

  /// Body Text — Inter 15px Regular, 0px spacing, Pearl White
  static TextStyle get body => GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        color: AppColors.pearlWhite,
        height: 1.5,
      );

  /// Body muted — same as body but Slate Mist
  static TextStyle get bodyMuted => GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        color: AppColors.slateMist,
        height: 1.5,
      );

  /// Body Medium — Inter 15px Medium (for labels that need weight)
  static TextStyle get bodyMedium => GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
        color: AppColors.pearlWhite,
        height: 1.5,
      );

  /// Caption — Inter 13px Regular, Slate Mist
  static TextStyle get caption => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        color: AppColors.slateMist,
        height: 1.4,
      );

  /// Caption Medium — Inter 13px Medium
  static TextStyle get captionMedium => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: AppColors.pearlWhite,
        height: 1.4,
      );

  /// Location text on discovery card — Inter 14px Regular
  static TextStyle get cardLocation => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.pearlWhite.withValues(alpha: 0.85),
        height: 1.3,
      );

  /// Chip label — Inter 12px Medium
  static TextStyle get chipLabel => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.2,
        color: AppColors.pearlWhite,
      );

  /// Button label — Inter 16px SemiBold
  static TextStyle get button => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        color: AppColors.obsidianNight,    // Dark text on gold button
        height: 1,
      );

  /// Secondary button label — same but gold text
  static TextStyle get buttonSecondary => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        color: AppColors.champagneGold,
        height: 1,
      );

  /// Ghost button label
  static TextStyle get buttonGhost => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.2,
        color: AppColors.pearlWhite,
        height: 1,
      );

  /// Input label (floating) — Inter 13px Regular, Slate Mist
  static TextStyle get inputLabel => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: AppColors.slateMist,
      );

  /// Input text — Inter 15px Regular, Pearl White
  static TextStyle get inputText => GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: AppColors.pearlWhite,
        height: 1.4,
      );

  /// Chat message text
  static TextStyle get chatMessage => GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: AppColors.pearlWhite,
        height: 1.45,
      );

  /// Timestamp in chat (hidden by default)
  static TextStyle get chatTimestamp => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w400,
        color: AppColors.slateMist,
      );

  /// Unread count badge
  static TextStyle get badge => GoogleFonts.inter(
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
