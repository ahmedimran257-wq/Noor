// lib/core/theme/app_theme.dart
// ============================================================
// NOOR Design DNA — ThemeData
// Dark mode by default. Zero Material widgets allowed to
// show through — every component uses NOOR's design language.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'app_dimensions.dart';
import 'app_typography.dart';

abstract final class AppTheme {
  // ── Dark Theme (NOOR Default) ─────────────────────────────

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,

      // ── Color Scheme ────────────────────────────────────
      colorScheme: const ColorScheme.dark(
        brightness:      Brightness.dark,
        primary:         AppColors.champagneGold,
        onPrimary:       AppColors.obsidianNight,
        secondary:       AppColors.verifiedTeal,
        onSecondary:     AppColors.obsidianNight,
        error:           AppColors.softCoral,
        onError:         AppColors.pearlWhite,
        surface:         AppColors.surfaceGlass,
        onSurface:       AppColors.pearlWhite,
        surfaceContainerHighest: AppColors.surfaceGlassHover,
        outline:         AppColors.cardBorder,
      ),

      // ── Scaffold ─────────────────────────────────────────
      scaffoldBackgroundColor: AppColors.obsidianNight,

      // ── Typography ───────────────────────────────────────
      textTheme: AppTypography.textTheme,
      fontFamily: 'Inter',

      // ── App Bar ──────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor:  AppColors.obsidianNight,
        foregroundColor:  AppColors.pearlWhite,
        elevation:        0,
        scrolledUnderElevation: 0,
        centerTitle:      true,
        titleTextStyle:   AppTypography.wordmark,
        iconTheme:        const IconThemeData(
          color: AppColors.pearlWhite,
          size:  AppDimensions.iconSizeLarge,
        ),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor:           Colors.transparent,
          statusBarIconBrightness:  Brightness.light,
          statusBarBrightness:      Brightness.dark,
        ),
      ),

      // ── Eliminate ALL Material ripple/ink effects ─────────
      // NOOR uses scale-based press animations instead.
      splashFactory:         NoSplash.splashFactory,
      highlightColor:        Colors.transparent,
      splashColor:           Colors.transparent,
      hoverColor:            Colors.transparent,
      focusColor:            AppColors.goldGlow,

      // ── Icon Theme ───────────────────────────────────────
      iconTheme: const IconThemeData(
        color: AppColors.pearlWhite,
        size:  AppDimensions.iconSizeLarge,
      ),

      // ── Elevated Button Theme (for default button overrides)
      // NOTE: Use NoorPrimaryButton widget directly.
      // This theme is a fallback so any accidentally placed
      // ElevatedButton still looks correct.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor:   AppColors.champagneGold,
          foregroundColor:   AppColors.obsidianNight,
          minimumSize:       const Size(double.infinity, AppDimensions.buttonHeight),
          shape:             RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          ),
          elevation:         0,
          shadowColor:       Colors.transparent,
          overlayColor:      Colors.transparent,
          textStyle:         AppTypography.button,
          padding:           const EdgeInsets.symmetric(horizontal: 24),
        ),
      ),

      // ── Text Button Theme ────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.champagneGold,
          overlayColor:    Colors.transparent,
          textStyle:       AppTypography.buttonSecondary,
        ),
      ),

      // ── Input Decoration Theme ───────────────────────────
      // "BG: Surface Glass. Border: Bottom border only."
      inputDecorationTheme: InputDecorationTheme(
        filled:      true,
        fillColor:   AppColors.surfaceGlass,
        hintStyle:   AppTypography.inputLabel,
        labelStyle:  AppTypography.inputLabel,
        floatingLabelStyle: AppTypography.inputLabel.copyWith(
          color: AppColors.champagneGold,
          fontSize: 12,
        ),
        // Bottom border only — no outline
        border: const UnderlineInputBorder(
          borderSide: BorderSide(
            color: AppColors.slateMist,
            width: AppDimensions.borderThin,
          ),
        ),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(
            color: AppColors.slateMist,
            width: AppDimensions.borderThin,
          ),
        ),
        // "Focus State: Bottom border transitions to 2px Champagne Gold."
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(
            color: AppColors.champagneGold,
            width: AppDimensions.borderFocus,
          ),
        ),
        errorBorder: const UnderlineInputBorder(
          borderSide: BorderSide(
            color: AppColors.softCoral,
            width: AppDimensions.borderFocus,
          ),
        ),
        focusedErrorBorder: const UnderlineInputBorder(
          borderSide: BorderSide(
            color: AppColors.softCoral,
            width: AppDimensions.borderFocus,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 0,
          vertical: AppDimensions.space16,
        ),
      ),

      // ── Card Theme ───────────────────────────────────────
      cardTheme: CardThemeData(
        color:        AppColors.surfaceGlass,
        elevation:    0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
          side: const BorderSide(
            color: AppColors.cardBorder,
            width: AppDimensions.borderThin,
          ),
        ),
        margin: EdgeInsets.zero,
      ),

      // ── Chip Theme ───────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor:         AppColors.surfaceGlass,
        selectedColor:           AppColors.goldGlow,
        labelStyle:              AppTypography.chipLabel,
        side: const BorderSide(
          color: AppColors.cardBorder,
          width: AppDimensions.borderThin,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.space12,
          vertical:   AppDimensions.space6,
        ),
        showCheckmark: false,
      ),

      // ── Bottom Sheet Theme ───────────────────────────────
      // "NO Pop-ups: Use Bottom Sheets that slide up with easeOutCubic."
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor:   AppColors.obsidianNight,
        modalBackgroundColor: AppColors.obsidianNight,
        elevation:         0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppDimensions.radiusCard),
          ),
        ),
        showDragHandle: false,
      ),

      // ── Navigation Bar Theme (bottom nav) ────────────────
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.obsidianNight,
        indicatorColor:  AppColors.goldGlow,
        surfaceTintColor: Colors.transparent,
        elevation:       0,
        labelTextStyle:  WidgetStateProperty.resolveWith((states) {
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
      dividerTheme: const DividerThemeData(
        color:     AppColors.divider,
        thickness: AppDimensions.borderThin,
        space:     0,
      ),

      // ── Progress Indicator ───────────────────────────────
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.champagneGold,
        linearTrackColor: AppColors.progressBarBase,
      ),

      // ── Snack Bar — replaced by bottom sheets in NOOR ────
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceGlassHover,
        contentTextStyle: AppTypography.body,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
        ),
        behavior: SnackBarBehavior.floating,
      ),

      // ── Dialog → use NoorBottomSheet instead ─────────────
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.obsidianNight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        ),
        titleTextStyle:   AppTypography.userName,
        contentTextStyle: AppTypography.body,
      ),

      // ── Page Transitions ─────────────────────────────────
      // Overridden globally via GoRouter — kept here as fallback.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: NoorPageTransition(),
          TargetPlatform.iOS:     NoorPageTransition(),
        },
      ),
    );
  }
}

// ── Custom Page Transition Builder ───────────────────────────
// "The Unfolding Effect: fade in + shift upward 20px → 0px."

class NoorPageTransition extends PageTransitionsBuilder {
  const NoorPageTransition();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final fadeTween = CurveTween(curve: Curves.easeOutCubic);
    final slideTween = Tween<Offset>(
      begin: const Offset(0, 0.04),   // 20px at typical 500px height ≈ 4%
      end:   Offset.zero,
    ).chain(CurveTween(curve: Curves.easeOutCubic));

    return FadeTransition(
      opacity: animation.drive(fadeTween),
      child: SlideTransition(
        position: animation.drive(slideTween),
        child: child,
      ),
    );
  }
}
