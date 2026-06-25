// lib/core/widgets/mithaq_empty_state.dart
// ============================================================
// MITHAQ — Shared Empty State Widget (Item 26)
//
// Used across: InterestsScreen, ChatListScreen, NotificationsScreen,
//              ProfileViewsScreen, BlockListScreen, MyProfileScreen
// ============================================================

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_typography.dart';

class MithaqEmptyState extends StatelessWidget {
  const MithaqEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.ctaLabel,
    this.onCta,
  });

  final IconData icon;
  final String   title;
  final String   subtitle;
  final String?  ctaLabel;
  final VoidCallback? onCta;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.space40,
          vertical:   AppDimensions.space24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon in muted circle
            Container(
              width:  88,
              height: 88,
              decoration: BoxDecoration(
                shape:  BoxShape.circle,
                color:  AppColors.surfaceGlass,
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Icon(icon, color: AppColors.slateMist, size: 38),
            ),
            const SizedBox(height: AppDimensions.space20),

            // Title
            Text(
              title,
              style: AppTypography.bodyMedium.copyWith(
                color:    AppColors.pearlWhite,
                fontSize: 17,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.space8),

            // Subtitle
            Text(
              subtitle,
              style: AppTypography.bodyMuted.copyWith(height: 1.6),
              textAlign: TextAlign.center,
            ),

            // Optional CTA
            if (ctaLabel != null && onCta != null) ...{
              const SizedBox(height: AppDimensions.space24),
              OutlinedButton(
                onPressed: onCta,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.champagneGold),
                  foregroundColor: AppColors.champagneGold,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.space24,
                    vertical:   AppDimensions.space12,
                  ),
                ),
                child: Text(ctaLabel!, style: AppTypography.buttonSecondary),
              ),
            },
          ],
        ),
      ),
    );
  }
}
