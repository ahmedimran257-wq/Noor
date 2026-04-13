// lib/core/widgets/buttons/noor_secondary_button.dart
// ============================================================
// Secondary Button — "The Alternative"
// BG: Transparent | Border: 1px solid Champagne Gold
// Text: Champagne Gold
// ============================================================

import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimensions.dart';
import '../../theme/app_typography.dart';
import 'noor_pressable.dart';

class NoorSecondaryButton extends StatelessWidget {
  const NoorSecondaryButton({
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

    return NoorPressable(
      onTap:   isActive ? onTap : null,
      enabled: isActive,
      child: Container(
        width:  width ?? double.infinity,
        height: AppDimensions.buttonHeight,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          border: Border.all(
            color: isActive
                ? AppColors.champagneGold
                : AppColors.champagneGold.withValues(alpha: 0.4),
            width: AppDimensions.borderThin,
          ),
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width:  20,
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
                        size:  AppDimensions.iconSizeMedium,
                      ),
                      const SizedBox(width: AppDimensions.space8),
                    ],
                    Text(label, style: AppTypography.buttonSecondary),
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

class NoorGhostButton extends StatelessWidget {
  const NoorGhostButton({
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
    return NoorPressable(
      onTap:   enabled ? onTap : null,
      enabled: enabled,
      child: SizedBox(
        height: AppDimensions.buttonHeight,
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  color: AppColors.pearlWhite,
                  size:  AppDimensions.iconSizeMedium,
                ),
                const SizedBox(width: AppDimensions.space8),
              ],
              Text(
                label,
                style: AppTypography.buttonGhost.copyWith(
                  color: enabled
                      ? AppColors.pearlWhite
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
