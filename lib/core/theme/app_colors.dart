// lib/core/theme/app_colors.dart
// ============================================================
// NOOR Design DNA — Color Tokens
// Source of truth for every color in the app.
// NEVER hardcode hex values elsewhere — always reference this.
// ============================================================

import 'package:flutter/material.dart';

abstract final class AppColors {
  // ── Primary Palette ───────────────────────────────────────

  /// The main background. Not pure black — a deep midnight blue-black.
  /// Creates depth and feels expensive.
  static const Color obsidianNight = Color(0xFF0A0A0F);

  /// Subtle radial gradient background variant used on the Splash screen.
  static const Color obsidianDeep = Color(0xFF1A1A2F);

  /// The accent color. Used SPARINGLY — CTAs, badges, borders, gold moments.
  /// "Champagne Gold" — not trophy gold. Muted and sophisticated.
  static const Color champagneGold = Color(0xFFC5A059);

  /// Primary text. Soft muted white (Apple-style) — not stark white.
  /// Reduces eye strain. Feels premium.
  static const Color pearlWhite = Color(0xFFF5F5F7);

  /// Secondary text. Used for labels, muted info, hints, captions.
  static const Color slateMist = Color(0xFF8E8E93);

  // ── Surface & Semantic ────────────────────────────────────

  /// Card and overlay background. Creates glassmorphism.
  /// rgba(255, 255, 255, 0.04) — barely visible depth layer.
  /// Premium dark-mode apps keep fills near-invisible; definition
  /// comes from borders, not fill color.
  static const Color surfaceGlass = Color(0x0AFFFFFF);

  /// Slightly more opaque surface for interactive / hovered elements.
  /// rgba(255, 255, 255, 0.07)
  static const Color surfaceGlassHover = Color(0x12FFFFFF);

  /// Dedicated input field fill — a hair brighter than surfaceGlass
  /// so text fields have just enough contrast to feel "present"
  /// without creating the ugly grey wash.
  /// rgba(255, 255, 255, 0.05)
  static const Color inputSurface = Color(0x0DFFFFFF);

  /// Card border. Gives a "sharp" edge that feels high-end.
  /// rgba(255, 255, 255, 0.08)
  static const Color cardBorder = Color(0x14FFFFFF);

  /// Gold border — for selected states, verified rings.
  /// rgba(212, 170, 96, 0.40)
  static const Color goldBorder = Color(0x66C5A059);

  /// Subtle gold glow — for focus states and active indicators.
  /// rgba(212, 170, 96, 0.15)
  static const Color goldGlow = Color(0x26C5A059);

  /// Verified badge. Muted teal — not neon green.
  static const Color verifiedTeal = Color(0xFF2DCDA9);

  /// Error/warning color. Dignified — not a harsh Material red.
  static const Color softCoral = Color(0xFFE67E7E);

  /// Alias used by UI components that need a clear error/danger signal.
  static const Color errorRed  = softCoral;

  // ── Derived / Utility ─────────────────────────────────────

  /// Received chat message bubble background.
  static const Color messageBubbleReceived = Color(0xFF1C1C24);

  /// Conversation list unread indicator border.
  static const Color unreadBorder = champagneGold;

  /// Progress bar base (Slate Mist → fills with Gold).
  static const Color progressBarBase = Color(0x338E8E93);

  /// Divider — barely visible on dark background.
  static const Color divider = Color(0x0FFFFFFF);

  /// Transparent — for clarity in code.
  static const Color transparent = Colors.transparent;

  // ── Gradient Stops ────────────────────────────────────────

  /// Discovery card gradient — top (fully transparent)
  static const Color cardGradientTop = Color(0x000A0A0F);

  /// Discovery card gradient — middle (30% opacity)
  static const Color cardGradientMid = Color(0x4D0A0A0F);

  /// Discovery card gradient — bottom (fully opaque)
  static const Color cardGradientBottom = Color(0xFF0A0A0F);

  // ── New Surface Tokens ────────────────────────────────────
  static const Color surfaceElevated = Color(0xFF13131A);
  static const Color surfaceMid      = Color(0xFF12121A);
  static const Color surfaceDark     = Color(0xFF1A1A25);

  // ── Phase 3 Color System Cleanup ─────────────────────────
  static const Color premiumGold     = Color(0xFFF6C344);  // Bright gold — subscription badges
  static const Color onlineGreen     = Color(0xFF4ADE80);  // Online status indicator
  static const Color messageBlue     = Color(0xFF5B9BD5);  // New message notification
  static const Color expiryAmber     = Color(0xFFFFBF47);  // Expiry warning
  static const Color navyCharcoal    = Color(0xFF151522);  // Gradient core (onboarding)
  static const Color dropdownSurface = Color(0xFF14141E);  // Dropdown background
  static const Color snackbarSurface = Color(0xFF1A1A24);  // Snackbar background
  static const Color navBarSurface   = Color(0xCC0A0A0F);  // Nav bar frosted
  static const Color navBarBorder    = Color(0x14FFFFFF);  // Nav bar border
  static const Color overlayBlack55  = Color(0x8C000000);  // 55% black overlay
  static const Color overlayBlack45  = Color(0x73000000);  // 45% black overlay
  static const Color overlayBlack87  = Color(0xDE000000);  // 87% black overlay
}

