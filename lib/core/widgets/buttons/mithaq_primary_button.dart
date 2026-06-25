// lib/core/widgets/buttons/mithaq_primary_button.dart
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
import 'mithaq_pressable.dart';

class MithaqPrimaryButton extends StatelessWidget {
  const MithaqPrimaryButton({
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
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        width: width ?? double.infinity,
        height: AppDimensions.buttonHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isActive
                ? const [
                    AppColors.champagneLight,
                    AppColors.champagneGold,
                    AppColors.antiqueGold,
                  ]
                : [
                    AppColors.champagneGold.withValues(alpha: 0.46),
                    AppColors.antiqueGold.withValues(alpha: 0.38),
                  ],
          ),
          border: Border.all(
            color: isActive
                ? AppColors.champagneLight.withValues(alpha: 0.62)
                : AppColors.goldBorder.withValues(alpha: 0.28),
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: AppColors.champagneGold.withValues(alpha: 0.18),
                    blurRadius: 22,
                    offset: const Offset(0, 12),
                  ),
                  BoxShadow(
                    color: AppColors.obsidianNight.withValues(alpha: 0.55),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ]
              : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              left: 1,
              right: 1,
              top: 1,
              height: 20,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppDimensions.radiusButton - 1),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: isActive ? 0.22 : 0.08),
                      Colors.white.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
            Center(
              child: isLoading
                  ? const SizedBox(
                      width: 20,
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
                            size: AppDimensions.iconSizeMedium,
                          ),
                          const SizedBox(width: AppDimensions.space8),
                        ],
                        Text(
                          label,
                          style: AppTypography.button.copyWith(
                            color: AppColors.obsidianNight,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
