// lib/features/onboarding/widgets/select_chip.dart
// ============================================================
// MITHAQ — Shared Select Chip Widget
// Reusable chip used across onboarding screens for single-select
// options with Quiet Luxury styling.
// ============================================================

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/buttons/mithaq_pressable.dart';

class SelectChip extends StatelessWidget {
  const SelectChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MithaqPressable(
      onTap: () {
        FocusManager.instance.primaryFocus?.unfocus();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.space16,
          vertical: AppDimensions.space10,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isSelected
                ? [
                    AppColors.champagneGold.withValues(alpha: 0.18),
                    AppColors.inkTeal.withValues(alpha: 0.12),
                  ]
                : [
                    AppColors.surfaceGlassHover.withValues(alpha: 0.45),
                    AppColors.surfaceGlass.withValues(alpha: 0.18),
                  ],
          ),
          borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
          border: Border.all(
            color: isSelected ? AppColors.goldBorder : AppColors.cardBorder,
            width: isSelected
                ? AppDimensions.borderFocus
                : AppDimensions.borderThin,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.champagneGold.withValues(alpha: 0.12),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              duration: AppDimensions.durationTransition,
              scale: isSelected ? 1 : 0,
              child: const Icon(
                Icons.check_rounded,
                color: AppColors.champagneLight,
                size: AppDimensions.iconSizeSmall,
              ),
            ),
            AnimatedContainer(
              duration: AppDimensions.durationTransition,
              width: isSelected ? AppDimensions.space6 : 0,
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.chipLabel.copyWith(
                color: isSelected
                    ? AppColors.champagneLight
                    : AppColors.pearlWhite,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
