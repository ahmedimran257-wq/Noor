import 'package:flutter/material.dart';

/// The intentional visual identities available in Silarah.
///
/// Storage values are explicit so renaming a display label never invalidates a
/// member's saved preference.
enum SilarahThemeMode {
  blackWhite(
    'black_white',
    'Black & White',
    'Pure white, absolute black, no colour',
  ),
  oled('oled', 'Pure OLED', 'Absolute black and precision contrast'),
  prismLuxe(
    'prism_luxe',
    'Prism Luxe',
    'Midnight depth with luminous jewel colour',
  );

  const SilarahThemeMode(this.storageValue, this.label, this.description);

  final String storageValue;
  final String label;
  final String description;

  bool get isDark =>
      this == SilarahThemeMode.oled || this == SilarahThemeMode.prismLuxe;
  bool get isChromatic => this == SilarahThemeMode.prismLuxe;

  static SilarahThemeMode fromStorage(String? value) => switch (value) {
        'prism_luxe' => SilarahThemeMode.prismLuxe,
        'oled' => SilarahThemeMode.oled,
        'black_white' => SilarahThemeMode.blackWhite,
        // Removed light identities and unknown values migrate to the new
        // monochrome signature instead of leaving an unsupported preference.
        'porcelain' => SilarahThemeMode.blackWhite,
        'floral_pink' => SilarahThemeMode.blackWhite,
        _ => SilarahThemeMode.blackWhite,
      };
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
    required this.spectrum,
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
  final List<Color> spectrum;

  /// A rigorous light identity with no chromatic colour. Pure white and
  /// absolute black establish the hierarchy; carefully spaced neutral greys
  /// retain depth, states and accessibility without diluting the concept.
  static const blackWhite = SilarahPalette(
    mode: SilarahThemeMode.blackWhite,
    background: Color(0xFFFFFFFF),
    backgroundDeep: Color(0xFFF3F3F3),
    accent: Color(0xFF000000),
    accentHighlight: Color(0xFF2A2A2A),
    accentPressed: Color(0xFF151515),
    complementary: Color(0xFF303030),
    decorativeDepth: Color(0xFFE9E9E9),
    contentPrimary: Color(0xFF080808),
    contentSecondary: Color(0xFF565656),
    surface: Color(0xFFFFFFFF),
    surfaceInteractive: Color(0xFFF4F4F4),
    input: Color(0xFFFAFAFA),
    border: Color(0xFFD9D9D9),
    accentBorder: Color(0x99000000),
    accentGlow: Color(0x18000000),
    success: Color(0xFF202020),
    danger: Color(0xFF000000),
    messageReceived: Color(0xFFF1F1F1),
    progressTrack: Color(0xFFD6D6D6),
    divider: Color(0xFFE6E6E6),
    surfaceElevated: Color(0xFFFFFFFF),
    surfaceMid: Color(0xFFF8F8F8),
    surfaceDark: Color(0xFFEDEDED),
    surfacePressed: Color(0xFFE2E2E2),
    surfacePanelTop: Color(0xFFFCFCFC),
    premium: Color(0xFF111111),
    online: Color(0xFF242424),
    message: Color(0xFF343434),
    warning: Color(0xFF2A2A2A),
    gradientCore: Color(0xFFECECEC),
    dropdown: Color(0xFFFFFFFF),
    snackbar: Color(0xFF090909),
    navBar: Color(0xFCFFFFFF),
    navBorder: Color(0xFFDCDCDC),
    spectrum: [
      Color(0xFF000000),
      Color(0xFF1A1A1A),
      Color(0xFF333333),
      Color(0xFF505050),
      Color(0xFF727272),
      Color(0xFF969696),
    ],
  );

  /// A true emissive-display identity. The primary canvas and navigation
  /// surfaces are literal black so OLED pixels can switch off; restrained
  /// graphite elevation and a luminous rose accent preserve hierarchy.
  static const oled = SilarahPalette(
    mode: SilarahThemeMode.oled,
    background: Color(0xFF000000),
    backgroundDeep: Color(0xFF050506),
    accent: Color(0xFFE8A6BF),
    accentHighlight: Color(0xFFFFD8E6),
    accentPressed: Color(0xFFBE718E),
    complementary: Color(0xFF8ED9D2),
    decorativeDepth: Color(0xFF180C13),
    contentPrimary: Color(0xFFF8F6F8),
    contentSecondary: Color(0xFFB9B2B7),
    surface: Color(0xFF09090B),
    surfaceInteractive: Color(0xFF131316),
    input: Color(0xFF0C0C0F),
    border: Color(0xFF29262B),
    accentBorder: Color(0xB3E8A6BF),
    accentGlow: Color(0x33E8A6BF),
    success: Color(0xFF73D6C2),
    danger: Color(0xFFFF8296),
    messageReceived: Color(0xFF171318),
    progressTrack: Color(0xFF262227),
    divider: Color(0xFF1D1B1E),
    surfaceElevated: Color(0xFF111114),
    surfaceMid: Color(0xFF0C0C0F),
    surfaceDark: Color(0xFF070709),
    surfacePressed: Color(0xFF1B181C),
    surfacePanelTop: Color(0xFF101012),
    premium: Color(0xFFE8C172),
    online: Color(0xFF63D39F),
    message: Color(0xFF8CBDF0),
    warning: Color(0xFFF1C66C),
    gradientCore: Color(0xFF170C12),
    dropdown: Color(0xFF101012),
    snackbar: Color(0xFF17171A),
    navBar: Color(0xFF000000),
    navBorder: Color(0xFF211F22),
    spectrum: [
      Color(0xFFE8A6BF),
      Color(0xFFFFD8E6),
      Color(0xFF8ED9D2),
      Color(0xFF73D6C2),
      Color(0xFFE8C172),
      Color(0xFF8CBDF0),
    ],
  );

  /// A chromatic dark identity built from luminous jewel tones rather than a
  /// single repeated accent. Deep blue-black surfaces keep the spectrum
  /// elegant while violet, pink, cyan, emerald, gold and coral own distinct
  /// interaction roles.
  static const prismLuxe = SilarahPalette(
    mode: SilarahThemeMode.prismLuxe,
    background: Color(0xFF080914),
    backgroundDeep: Color(0xFF11142A),
    accent: Color(0xFFB99CFF),
    accentHighlight: Color(0xFFFF7DB8),
    accentPressed: Color(0xFF57D7E8),
    complementary: Color(0xFF57D7E8),
    decorativeDepth: Color(0xFF21174F),
    contentPrimary: Color(0xFFF9F7FF),
    contentSecondary: Color(0xFFBBBBD5),
    surface: Color(0xFF111429),
    surfaceInteractive: Color(0xFF1A1E3B),
    input: Color(0xFF12162D),
    border: Color(0xFF30365E),
    accentBorder: Color(0xB3B99CFF),
    accentGlow: Color(0x38B99CFF),
    success: Color(0xFF63E0AE),
    danger: Color(0xFFFF7895),
    messageReceived: Color(0xFF171C39),
    progressTrack: Color(0xFF2D3358),
    divider: Color(0xFF242946),
    surfaceElevated: Color(0xFF171A34),
    surfaceMid: Color(0xFF0E1123),
    surfaceDark: Color(0xFF090B19),
    surfacePressed: Color(0xFF23294A),
    surfacePanelTop: Color(0xFF1A1D39),
    premium: Color(0xFFFFD166),
    online: Color(0xFF63E0AE),
    message: Color(0xFF65B8FF),
    warning: Color(0xFFFFBC66),
    gradientCore: Color(0xFF211247),
    dropdown: Color(0xFF181B35),
    snackbar: Color(0xFF1B1E39),
    navBar: Color(0xFA0B0D1D),
    navBorder: Color(0xFF2B3053),
    spectrum: [
      Color(0xFFB99CFF),
      Color(0xFFFF7DB8),
      Color(0xFF57D7E8),
      Color(0xFF63E0AE),
      Color(0xFFFFD166),
      Color(0xFFFF8B76),
    ],
  );

  static SilarahPalette forMode(SilarahThemeMode mode) => switch (mode) {
        SilarahThemeMode.blackWhite => blackWhite,
        SilarahThemeMode.oled => oled,
        SilarahThemeMode.prismLuxe => prismLuxe,
      };
}

/// Backward-compatible semantic token facade.
///
/// The app historically consumed static design tokens directly. Keeping this
/// facade makes the migration atomic: every existing screen responds to a
/// palette change, while new code can use [SilarahPalette] explicitly.
abstract final class AppColors {
  static SilarahPalette _active = SilarahPalette.blackWhite;

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
  static Color get onSnackbar => readableOn(_active.snackbar);
  static Color get navBarSurface => _active.navBar;
  static Color get navBarBorder => _active.navBorder;
  static bool get isChromatic => _active.mode.isChromatic;

  /// Returns whichever absolute neutral has the stronger WCAG contrast
  /// against [background]. Feedback surfaces use several semantic colours,
  /// so their foreground cannot safely inherit the page's normal text colour.
  static Color readableOn(Color background) {
    final luminance = background.computeLuminance();
    final blackContrast = (luminance + 0.05) / 0.05;
    final whiteContrast = 1.05 / (luminance + 0.05);
    return blackContrast >= whiteContrast
        ? const Color(0xFF000000)
        : const Color(0xFFFFFFFF);
  }

  /// Returns a categorical accent only for the chromatic identity. Other
  /// identities retain their disciplined single-accent character.
  static Color spectrum(int slot) {
    if (!isChromatic) return _active.accent;
    return _active.spectrum[slot.abs() % _active.spectrum.length];
  }

  // Image legibility overlays remain neutral and theme-independent.
  static const Color overlayBlack55 = Color(0x8C000000);
  static const Color overlayBlack45 = Color(0x73000000);
  static const Color overlayBlack87 = Color(0xDE000000);
}
