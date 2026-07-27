import 'package:flutter/material.dart';

/// The intentional visual identities available in Silarah.
///
/// Storage values are explicit so renaming a display label never invalidates a
/// member's saved preference.
enum SilarahThemeMode {
  obsidian('obsidian', 'Obsidian', 'Signature dark'),
  rose('rose', 'Rose', 'Warm and feminine'),
  porcelain('porcelain', 'Porcelain', 'Pure and luminous');

  const SilarahThemeMode(this.storageValue, this.label, this.description);

  final String storageValue;
  final String label;
  final String description;

  bool get isDark => this != SilarahThemeMode.porcelain;

  static SilarahThemeMode fromStorage(String? value) => values.firstWhere(
        (mode) => mode.storageValue == value,
        orElse: () => SilarahThemeMode.obsidian,
      );
}

/// Immutable semantic palette. Widgets consume meaning (surface, content,
/// border) rather than theme-specific color names.
@immutable
class SilarahPalette {
  const SilarahPalette({
    required this.mode,
    required this.background,
    required this.backgroundDeep,
    required this.accent,
    required this.accentHighlight,
    required this.accentPressed,
    required this.complementary,
    required this.decorativeDepth,
    required this.contentPrimary,
    required this.contentSecondary,
    required this.surface,
    required this.surfaceInteractive,
    required this.input,
    required this.border,
    required this.accentBorder,
    required this.accentGlow,
    required this.success,
    required this.danger,
    required this.messageReceived,
    required this.progressTrack,
    required this.divider,
    required this.surfaceElevated,
    required this.surfaceMid,
    required this.surfaceDark,
    required this.surfacePressed,
    required this.surfacePanelTop,
    required this.premium,
    required this.online,
    required this.message,
    required this.warning,
    required this.gradientCore,
    required this.dropdown,
    required this.snackbar,
    required this.navBar,
    required this.navBorder,
  });

  final SilarahThemeMode mode;
  final Color background;
  final Color backgroundDeep;
  final Color accent;
  final Color accentHighlight;
  final Color accentPressed;
  final Color complementary;
  final Color decorativeDepth;
  final Color contentPrimary;
  final Color contentSecondary;
  final Color surface;
  final Color surfaceInteractive;
  final Color input;
  final Color border;
  final Color accentBorder;
  final Color accentGlow;
  final Color success;
  final Color danger;
  final Color messageReceived;
  final Color progressTrack;
  final Color divider;
  final Color surfaceElevated;
  final Color surfaceMid;
  final Color surfaceDark;
  final Color surfacePressed;
  final Color surfacePanelTop;
  final Color premium;
  final Color online;
  final Color message;
  final Color warning;
  final Color gradientCore;
  final Color dropdown;
  final Color snackbar;
  final Color navBar;
  final Color navBorder;

  static const obsidian = SilarahPalette(
    mode: SilarahThemeMode.obsidian,
    background: Color(0xFF0A0A0F),
    backgroundDeep: Color(0xFF1A1A2F),
    accent: Color(0xFFC5A059),
    accentHighlight: Color(0xFFE4C77A),
    accentPressed: Color(0xFF8F7137),
    complementary: Color(0xFF143A3B),
    decorativeDepth: Color(0xFF181220),
    contentPrimary: Color(0xFFF5F5F7),
    contentSecondary: Color(0xFF8E8E93),
    surface: Color(0x0AFFFFFF),
    surfaceInteractive: Color(0x12FFFFFF),
    input: Color(0x0DFFFFFF),
    border: Color(0x14FFFFFF),
    accentBorder: Color(0x66C5A059),
    accentGlow: Color(0x26C5A059),
    success: Color(0xFF2DCDA9),
    danger: Color(0xFFE67E7E),
    messageReceived: Color(0xFF1C1C24),
    progressTrack: Color(0x338E8E93),
    divider: Color(0x0FFFFFFF),
    surfaceElevated: Color(0xFF13131A),
    surfaceMid: Color(0xFF12121A),
    surfaceDark: Color(0xFF1A1A25),
    surfacePressed: Color(0xFF201E25),
    surfacePanelTop: Color(0xFF17151F),
    premium: Color(0xFFF6C344),
    online: Color(0xFF4ADE80),
    message: Color(0xFF5B9BD5),
    warning: Color(0xFFFFBF47),
    gradientCore: Color(0xFF151522),
    dropdown: Color(0xFF14141E),
    snackbar: Color(0xFF1A1A24),
    navBar: Color(0xF20A0A0F),
    navBorder: Color(0x14FFFFFF),
  );

  /// A sophisticated dark feminine palette: rosewood, muted blush and ivory.
  /// It deliberately avoids saturated pink and preserves WCAG contrast.
  static const rose = SilarahPalette(
    mode: SilarahThemeMode.rose,
    background: Color(0xFF120E13),
    backgroundDeep: Color(0xFF2A1724),
    accent: Color(0xFFD79AAF),
    accentHighlight: Color(0xFFF0C4D1),
    accentPressed: Color(0xFF9E637A),
    complementary: Color(0xFF3C2634),
    decorativeDepth: Color(0xFF261520),
    contentPrimary: Color(0xFFFFF8FA),
    contentSecondary: Color(0xFFB9AAB1),
    surface: Color(0x0FFFFFFF),
    surfaceInteractive: Color(0x17FFFFFF),
    input: Color(0x12FFFFFF),
    border: Color(0x1FFFFFFF),
    accentBorder: Color(0x73D79AAF),
    accentGlow: Color(0x2ED79AAF),
    success: Color(0xFF55C9AF),
    danger: Color(0xFFEA8691),
    messageReceived: Color(0xFF251C23),
    progressTrack: Color(0x3DB9AAB1),
    divider: Color(0x17FFFFFF),
    surfaceElevated: Color(0xFF1B151B),
    surfaceMid: Color(0xFF191318),
    surfaceDark: Color(0xFF251B23),
    surfacePressed: Color(0xFF30232D),
    surfacePanelTop: Color(0xFF211820),
    premium: Color(0xFFE7B86B),
    online: Color(0xFF5BD09B),
    message: Color(0xFF82A8D8),
    warning: Color(0xFFE8B86D),
    gradientCore: Color(0xFF281822),
    dropdown: Color(0xFF201820),
    snackbar: Color(0xFF251C23),
    navBar: Color(0xF2120E13),
    navBorder: Color(0x1FFFFFFF),
  );

  /// A true light theme. White is the canvas; warm porcelain surfaces create
  /// hierarchy without the grey-on-grey "template" appearance.
  static const porcelain = SilarahPalette(
    mode: SilarahThemeMode.porcelain,
    background: Color(0xFFFFFFFF),
    backgroundDeep: Color(0xFFF8F3EA),
    accent: Color(0xFF825A18),
    accentHighlight: Color(0xFFB58B3E),
    accentPressed: Color(0xFF60410F),
    complementary: Color(0xFF0E5B59),
    decorativeDepth: Color(0xFFF5EEF2),
    contentPrimary: Color(0xFF19161B),
    contentSecondary: Color(0xFF69636D),
    surface: Color(0xFFFFFFFF),
    surfaceInteractive: Color(0xFFF8F6F2),
    input: Color(0xFFFCFBF9),
    border: Color(0xFFE6E0D9),
    accentBorder: Color(0x99825A18),
    accentGlow: Color(0x1F825A18),
    success: Color(0xFF087765),
    danger: Color(0xFFB63E49),
    messageReceived: Color(0xFFF2F0ED),
    progressTrack: Color(0xFFDCD6CE),
    divider: Color(0xFFECE7E1),
    surfaceElevated: Color(0xFFFFFFFF),
    surfaceMid: Color(0xFFFAF8F5),
    surfaceDark: Color(0xFFF4F1ED),
    surfacePressed: Color(0xFFEDE8E1),
    surfacePanelTop: Color(0xFFFFFDFC),
    premium: Color(0xFF825A18),
    online: Color(0xFF198754),
    message: Color(0xFF326DA8),
    warning: Color(0xFF9A6500),
    gradientCore: Color(0xFFF7F1E8),
    dropdown: Color(0xFFFFFFFF),
    snackbar: Color(0xFF242027),
    navBar: Color(0xFAFFFFFF),
    navBorder: Color(0xFFE6E0D9),
  );

  static SilarahPalette forMode(SilarahThemeMode mode) => switch (mode) {
        SilarahThemeMode.obsidian => obsidian,
        SilarahThemeMode.rose => rose,
        SilarahThemeMode.porcelain => porcelain,
      };
}

/// Backward-compatible semantic token facade.
///
/// The app historically consumed static design tokens directly. Keeping this
/// facade makes the migration atomic: every existing screen responds to a
/// palette change, while new code can use [SilarahPalette] explicitly.
abstract final class AppColors {
  static SilarahPalette _active = SilarahPalette.obsidian;

  static SilarahPalette get active => _active;

  static void activate(SilarahThemeMode mode) {
    _active = SilarahPalette.forMode(mode);
  }

  static Color get obsidianNight => _active.background;
  static Color get obsidianDeep => _active.backgroundDeep;
  static Color get champagneGold => _active.accent;
  static Color get champagneLight => _active.accentHighlight;
  static Color get antiqueGold => _active.accentPressed;
  static Color get inkTeal => _active.complementary;
  static Color get midnightPlum => _active.decorativeDepth;
  static Color get pearlWhite => _active.contentPrimary;
  static Color get slateMist => _active.contentSecondary;
  static Color get surfaceGlass => _active.surface;
  static Color get surfaceGlassHover => _active.surfaceInteractive;
  static Color get inputSurface => _active.input;
  static Color get cardBorder => _active.border;
  static Color get goldBorder => _active.accentBorder;
  static Color get goldGlow => _active.accentGlow;
  static Color get verifiedTeal => _active.success;
  static Color get softCoral => _active.danger;
  static Color get errorRed => _active.danger;
  static Color get messageBubbleReceived => _active.messageReceived;
  static Color get unreadBorder => _active.accent;
  static Color get progressBarBase => _active.progressTrack;
  static Color get divider => _active.divider;
  static const Color transparent = Colors.transparent;

  /// Stable high-contrast content for controls rendered over photography.
  static const Color onMedia = Color(0xFFF8F8FA);
  static Color get cardGradientTop => _active.background.withValues(alpha: 0);
  static Color get cardGradientMid => _active.background.withValues(alpha: .30);
  static Color get cardGradientBottom => _active.background;
  static Color get surfaceElevated => _active.surfaceElevated;
  static Color get surfaceMid => _active.surfaceMid;
  static Color get surfaceDark => _active.surfaceDark;
  static Color get surfacePressed => _active.surfacePressed;
  static Color get surfacePanelTop => _active.surfacePanelTop;
  static Color get premiumGold => _active.premium;
  static Color get onlineGreen => _active.online;
  static Color get messageBlue => _active.message;
  static Color get expiryAmber => _active.warning;
  static Color get navyCharcoal => _active.gradientCore;
  static Color get dropdownSurface => _active.dropdown;
  static Color get snackbarSurface => _active.snackbar;
  static Color get navBarSurface => _active.navBar;
  static Color get navBarBorder => _active.navBorder;

  // Image legibility overlays remain neutral and theme-independent.
  static const Color overlayBlack55 = Color(0x8C000000);
  static const Color overlayBlack45 = Color(0x73000000);
  static const Color overlayBlack87 = Color(0xDE000000);
}
