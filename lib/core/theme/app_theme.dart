// lib/core/theme/app_theme.dart
// ============================================================
// SILARAH Design DNA — ThemeData
// Dark mode by default. Zero Material widgets allowed to
// show through — every component uses SILARAH's design language.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'app_dimensions.dart';
import 'app_typography.dart';
import 'silarah_spring.dart';

abstract final class AppTheme {
  // ── Dark Theme (SILARAH Default) ─────────────────────────────

  static ThemeData forMode(SilarahThemeMode mode) {
    AppColors.activate(mode);
    final brightness = mode.isDark ? Brightness.dark : Brightness.light;
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,

      // ── Color Scheme ────────────────────────────────────
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: AppColors.champagneGold,
        onPrimary: AppColors.obsidianNight,
        secondary: AppColors.verifiedTeal,
        onSecondary: AppColors.obsidianNight,
        error: AppColors.softCoral,
        onError: AppColors.pearlWhite,
        surface: AppColors.surfaceGlass,
        onSurface: AppColors.pearlWhite,
        surfaceContainerHighest: AppColors.surfaceGlassHover,
        outline: AppColors.cardBorder,
        tertiary: AppColors.inkTeal,
        onTertiary: AppColors.pearlWhite,
      ),

      // ── Scaffold ─────────────────────────────────────────
      scaffoldBackgroundColor: AppColors.obsidianNight,

      // ── Typography ───────────────────────────────────────
      textTheme: AppTypography.textTheme,
      fontFamily: 'Inter',

      // ── App Bar ──────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.obsidianNight,
        foregroundColor: AppColors.pearlWhite,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: AppTypography.wordmark,
        iconTheme: IconThemeData(
          color: AppColors.pearlWhite,
          size: AppDimensions.iconSizeLarge,
        ),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness:
              mode.isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: mode.isDark ? Brightness.dark : Brightness.light,
          systemNavigationBarColor: AppColors.obsidianNight,
          systemNavigationBarIconBrightness:
              mode.isDark ? Brightness.light : Brightness.dark,
          systemNavigationBarDividerColor: Colors.transparent,
          systemNavigationBarContrastEnforced: false,
        ),
      ),

      // ── Eliminate ALL Material ripple/ink effects ─────────
      // SILARAH uses scale-based press animations instead.
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      splashColor: Colors.transparent,
      hoverColor: Colors.transparent,
      focusColor: AppColors.goldGlow,

      // ── Icon Theme ───────────────────────────────────────
      iconTheme: IconThemeData(
        color: AppColors.pearlWhite,
        size: AppDimensions.iconSizeLarge,
      ),

      // ── Elevated Button Theme (for default button overrides)
      // NOTE: Use SilarahPrimaryButton widget directly.
      // This theme is a fallback so any accidentally placed
      // ElevatedButton still looks correct.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.champagneGold,
          foregroundColor: AppColors.obsidianNight,
          minimumSize: const Size(double.infinity, AppDimensions.buttonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          ),
          elevation: 0,
          shadowColor: Colors.transparent,
          overlayColor: Colors.transparent,
          textStyle: AppTypography.button,
          padding: const EdgeInsets.symmetric(horizontal: 24),
        ),
      ),

      // ── Text Button Theme ────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.champagneGold,
          overlayColor: Colors.transparent,
          textStyle: AppTypography.buttonSecondary,
        ),
      ),

      // ── Input Decoration Theme ───────────────────────────
      // Premium: near-transparent fill + crisp outline border.
      // The fill is barely there — just enough to define the field
      // against the background. Borders provide the real definition.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.inputSurface,
        hintStyle: AppTypography.inputLabel,
        labelStyle: AppTypography.inputLabel,
        floatingLabelStyle: AppTypography.inputLabel.copyWith(
          color: AppColors.champagneGold,
          fontSize: 12,
        ),
        // Rounded outline border — premium, not underline
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          borderSide: BorderSide(
            color: AppColors.cardBorder,
            width: AppDimensions.borderThin,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          borderSide: BorderSide(
            color: AppColors.cardBorder,
            width: AppDimensions.borderThin,
          ),
        ),
        // Focus: refined gold border
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          borderSide: BorderSide(
            color: AppColors.champagneGold,
            width: AppDimensions.borderThin,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          borderSide: BorderSide(
            color: AppColors.softCoral,
            width: AppDimensions.borderThin,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          borderSide: BorderSide(
            color: AppColors.softCoral,
            width: AppDimensions.borderThin,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.space16,
          vertical: AppDimensions.space16,
        ),
      ),

      // ── Card Theme ───────────────────────────────────────
      cardTheme: CardThemeData(
        color: AppColors.surfaceGlass,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
          side: BorderSide(
            color: AppColors.cardBorder,
            width: AppDimensions.borderThin,
          ),
        ),
        margin: EdgeInsets.zero,
      ),

      // ── Chip Theme ───────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceGlass,
        selectedColor: AppColors.goldGlow,
        labelStyle: AppTypography.chipLabel,
        side: BorderSide(
          color: AppColors.cardBorder,
          width: AppDimensions.borderThin,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.space12,
          vertical: AppDimensions.space6,
        ),
        showCheckmark: false,
      ),

      // ── Bottom Sheet Theme ───────────────────────────────
      // "NO Pop-ups: Use Bottom Sheets that slide up with easeOutCubic."
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.obsidianNight,
        modalBackgroundColor: AppColors.obsidianNight,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppDimensions.radiusCard),
          ),
        ),
        showDragHandle: false,
      ),

      // ── Navigation Bar Theme (bottom nav) ────────────────
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.obsidianNight,
        indicatorColor: AppColors.goldGlow,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return AppTypography.caption.copyWith(
            color: selected ? AppColors.champagneGold : AppColors.slateMist,
            fontSize: 10,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? AppColors.champagneGold : AppColors.slateMist,
            size: AppDimensions.iconSizeLarge,
          );
        }),
      ),

      // ── Divider Theme ────────────────────────────────────
      dividerTheme: DividerThemeData(
        color: AppColors.divider,
        thickness: AppDimensions.borderThin,
        space: 0,
      ),

      // ── Progress Indicator ───────────────────────────────
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppColors.champagneGold,
        linearTrackColor: AppColors.progressBarBase,
      ),

      // ── Snack Bar — replaced by bottom sheets in SILARAH ────
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceGlassHover,
        contentTextStyle: AppTypography.body,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
        ),
        behavior: SnackBarBehavior.floating,
      ),

      // ── Dialog → use SilarahBottomSheet instead ─────────────
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.obsidianNight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        ),
        titleTextStyle: AppTypography.userName,
        contentTextStyle: AppTypography.body,
      ),

      // ── Page Transitions ─────────────────────────────────
      // Overridden globally via GoRouter — kept here as fallback.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: SilarahPageTransition(),
          TargetPlatform.iOS: SilarahPageTransition(),
        },
      ),
    );
  }
}

// ── Custom Page Transition Builder ───────────────────────────
// "The Unfolding Effect: fade in + shift upward 20px → 0px."

class SilarahPageTransition extends PageTransitionsBuilder {
  const SilarahPageTransition();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // Gentle spring curve for both animations
    const springCurve = SpringCurve(
      spring: SilarahSpring.gentle,
      duration: Duration(milliseconds: 500),
    );

    // Primary (incoming) slide: slides in from right
    final primarySlide = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: animation,
        curve: springCurve,
      ),
    );

    // Secondary (outgoing) slide: slides left at 0.3x speed
    final secondarySlide = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(-0.3, 0.0),
    ).animate(
      CurvedAnimation(
        parent: secondaryAnimation,
        curve: springCurve,
      ),
    );

    // Primary (incoming) fade
    final primaryFade = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: animation,
        curve: Curves.easeOut,
      ),
    );

    // Secondary (outgoing) fade: dims slightly to 80% opacity when pushed over
    final secondaryFade = Tween<double>(
      begin: 1.0,
      end: 0.8,
    ).animate(
      CurvedAnimation(
        parent: secondaryAnimation,
        curve: Curves.easeOut,
      ),
    );

    return SlideTransition(
      position: secondarySlide,
      child: FadeTransition(
        opacity: secondaryFade,
        child: SlideTransition(
          position: primarySlide,
          child: FadeTransition(
            opacity: primaryFade,
            child: child,
          ),
        ),
      ),
    );
  }
}
