// lib/core/widgets/buttons/noor_primary_button.dart
// ============================================================
// Primary Button — "The Action"
// BG: Champagne Gold | Text: Obsidian Night
// Radius: 12px | Height: 56px
// Effect: Subtle scale down (0.97) on press. No ripple.
// NO Gradients in buttons. Solid Champagne Gold only.
// ============================================================

import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimensions.dart';
import '../../theme/app_typography.dart';
import 'noor_pressable.dart';

class NoorPrimaryButton extends StatelessWidget {
  const NoorPrimaryButton({
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width:  width ?? double.infinity,
        height: AppDimensions.buttonHeight,
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.champagneGold
              : AppColors.champagneGold.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width:  20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.obsidianNight,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(
                        icon,
                        color: AppColors.obsidianNight,
                        size:  AppDimensions.iconSizeMedium,
                      ),
                      const SizedBox(width: AppDimensions.space8),
                    ],
                    Text(label, style: AppTypography.button),
                  ],
                ),
        ),
      ),
    );
  }
}
