// lib/features/onboarding/widgets/select_chip.dart
// ============================================================
// NOOR — Shared Select Chip Widget
// Reusable chip used across onboarding screens for single-select
// options with Quiet Luxury styling.
// ============================================================

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';

class SelectChip extends StatelessWidget {
  const SelectChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String     label;
  final bool       isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppDimensions.durationTransition,
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.space16,
          vertical:   AppDimensions.space10,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.champagneGold.withValues(alpha: 0.12)
              : AppColors.surfaceGlass,
          borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
          border: Border.all(
            color: isSelected ? AppColors.champagneGold : AppColors.cardBorder,
            width: isSelected ? AppDimensions.borderFocus : AppDimensions.borderThin,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.chipLabel.copyWith(
            color: isSelected ? AppColors.champagneGold : AppColors.pearlWhite,
          ),
        ),
      ),
    );
  }
}
