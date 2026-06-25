// lib/core/widgets/buttons/mithaq_secondary_button.dart
// ============================================================
// Secondary Button — "The Alternative"
// BG: Transparent | Border: 1px solid Champagne Gold
// Text: Champagne Gold
// ============================================================

import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimensions.dart';
import '../../theme/app_typography.dart';
import 'mithaq_pressable.dart';

class MithaqSecondaryButton extends StatelessWidget {
  const MithaqSecondaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.isLoading = false,
    this.enabled = true,
    this.icon,
    this.width,
  });

  final String label;
  final VoidCallback? onTap;
  final bool isLoading;
  final bool enabled;
  final IconData? icon;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final isActive = enabled && !isLoading;

    return MithaqPressable(
      onTap: isActive ? onTap : null,
      enabled: isActive,
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
              AppColors.inkTeal.withValues(alpha: isActive ? 0.18 : 0.08),
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
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.champagneGold,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(
                        icon,
                        color: AppColors.champagneGold,
                        size: AppDimensions.iconSizeMedium,
                      ),
                      const SizedBox(width: AppDimensions.space8),
                    ],
                    Text(
                      label,
                      style: AppTypography.buttonSecondary.copyWith(
                        color: isActive
                            ? AppColors.champagneLight
                            : AppColors.slateMist,
                      ),
                    ),
                  ],
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

class MithaqGhostButton extends StatelessWidget {
  const MithaqGhostButton({
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
    return MithaqPressable(
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
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  color: AppColors.pearlWhite,
                  size: AppDimensions.iconSizeMedium,
                ),
                const SizedBox(width: AppDimensions.space8),
              ],
              Text(
                label,
                style: AppTypography.buttonGhost.copyWith(
                  color: enabled ? AppColors.pearlWhite : AppColors.slateMist,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
