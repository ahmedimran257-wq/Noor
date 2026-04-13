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
  /// rgba(255, 255, 255, 0.05) = 5% white
  static const Color surfaceGlass = Color(0x0DFFFFFF);

  /// Slightly more opaque surface for interactive elements.
  /// rgba(255, 255, 255, 0.08)
  static const Color surfaceGlassHover = Color(0x14FFFFFF);

  /// Card border. Gives a "sharp" edge that feels high-end.
  /// rgba(255, 255, 255, 0.10)
  static const Color cardBorder = Color(0x1AFFFFFF);

  /// Gold border — for selected states, verified rings.
  /// rgba(197, 160, 89, 0.40)
  static const Color goldBorder = Color(0x66C5A059);

  /// Subtle gold glow — for focus states and active indicators.
  /// rgba(197, 160, 89, 0.15)
  static const Color goldGlow = Color(0x26C5A059);

  /// Verified badge. Muted teal — not neon green.
  static const Color verifiedTeal = Color(0xFF2DCDA9);

  /// Error/warning color. Dignified — not a harsh Material red.
  static const Color softCoral = Color(0xFFE67E7E);

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
}
