// lib/features/onboarding/widgets/step_header.dart
// ============================================================
// NOOR — Step Header
// Decorative gold ornament + screen title (Playfair) + subtitle (Inter muted).
// ============================================================

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';

class StepHeader extends StatelessWidget {
  const StepHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.showOrnament = true,
  });

  final String title;
  final String? subtitle;
  final bool showOrnament;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showOrnament) ...[
          _GoldOrnament(),
          const SizedBox(height: AppDimensions.space16),
        ],
        Text(title, style: AppTypography.screenTitle),
        if (subtitle != null) ...[
          const SizedBox(height: AppDimensions.space8),
          Text(subtitle!, style: AppTypography.bodyMuted),
        ],
      ],
    );
  }
}

class _GoldOrnament extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 1,
          color: AppColors.champagneGold.withValues(alpha: 0.6),
        ),
        const SizedBox(width: AppDimensions.space8),
        Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.champagneGold,
          ),
        ),
        const SizedBox(width: AppDimensions.space8),
        Container(
          width: 32,
          height: 1,
          color: AppColors.champagneGold.withValues(alpha: 0.6),
        ),
      ],
    );
  }
}
