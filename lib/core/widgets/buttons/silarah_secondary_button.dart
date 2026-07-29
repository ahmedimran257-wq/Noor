// lib/core/widgets/buttons/silarah_secondary_button.dart
// ============================================================
// Secondary Button — "The Alternative"
// BG: Transparent | Border: 1px solid Champagne Gold
// Text: Champagne Gold
// ============================================================

import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimensions.dart';
import '../../theme/app_typography.dart';
import '../loaders/silarah_shimmer.dart';
import 'silarah_pressable.dart';

class SilarahSecondaryButton extends StatelessWidget {
  const SilarahSecondaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.isLoading = false,
    this.enabled = true,
    this.icon,
    this.width,
    this.haptic = true,
  });

  final String label;
  final VoidCallback? onTap;
  final bool isLoading;
  final bool enabled;
  final IconData? icon;
  final double? width;
  final bool haptic;

  @override
  Widget build(BuildContext context) {
    final isActive = enabled && !isLoading;

    return SilarahPressable(
      onTap: isActive ? onTap : null,
      enabled: isActive,
      haptic: haptic,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        width: width ?? double.infinity,
        height: AppDimensions.buttonHeight,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.surfacePanelTop
                  .withValues(alpha: isActive ? 0.72 : 0.42),
              AppColors.midnightPlum.withValues(
                alpha: isActive ? 0.28 : 0.12,
              ),
              AppColors.surfaceGlass.withValues(alpha: 0.16),
            ],
          ),
          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          border: Border.all(
            color: isActive
                ? AppColors.goldBorder
                : AppColors.champagneGold.withValues(alpha: 0.4),
            width: AppDimensions.borderThin,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: AppColors.obsidianNight.withValues(alpha: 0.42),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: isLoading
              ? const SilarahPulseLoader(size: 26)
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (icon != null) ...[
                        Icon(
                          icon,
                          color: AppColors.champagneGold,
                          size: AppDimensions.iconSizeMedium,
                        ),
                        const SizedBox(width: AppDimensions.space8),
                      ],
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: AppTypography.buttonSecondary.copyWith(
                            color: isActive
                                ? AppColors.champagneLight
                                : AppColors.slateMist,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

// ============================================================
// Ghost Button — "The Quiet Action"
// BG: Transparent | Border: None | Text: Pearl White
// ============================================================

class SilarahGhostButton extends StatelessWidget {
  const SilarahGhostButton({
    super.key,
    required this.label,
    required this.onTap,
    this.enabled = true,
    this.icon,
  });

  final String label;
  final VoidCallback? onTap;
  final bool enabled;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SilarahPressable(
      onTap: enabled ? onTap : null,
      enabled: enabled,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: AppDimensions.space12),
        height: AppDimensions.buttonHeight,
        decoration: BoxDecoration(
          color: enabled ? AppColors.surfaceGlass : Colors.transparent,
          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          border: Border.all(
            color: enabled ? AppColors.cardBorder : AppColors.transparent,
          ),
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  color: AppColors.pearlWhite,
                  size: AppDimensions.iconSizeMedium,
                ),
                const SizedBox(width: AppDimensions.space8),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: AppTypography.buttonGhost.copyWith(
                    color: enabled ? AppColors.pearlWhite : AppColors.slateMist,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
