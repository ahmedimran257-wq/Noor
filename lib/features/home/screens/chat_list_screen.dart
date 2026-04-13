// lib/features/home/screens/chat_list_screen.dart
// ============================================================
// NOOR — Chat List
// Empty state for Step 5; Supabase Realtime wired in Step 6.
// ============================================================

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimensions.space24,
            AppDimensions.space16,
            AppDimensions.space24,
            AppDimensions.space24,
          ),
          child: Row(
            children: [
              Text('Messages', style: AppTypography.screenTitle),
              const Spacer(),
              // Search icon (placeholder for future search)
              Container(
                width:  AppDimensions.minTouchTarget,
                height: AppDimensions.minTouchTarget,
                decoration: BoxDecoration(
                  color:        AppColors.surfaceGlass,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                  border:       Border.all(color: AppColors.cardBorder),
                ),
                child: const Icon(
                  Icons.search_rounded,
                  color: AppColors.slateMist,
                  size:  AppDimensions.iconSizeLarge,
                ),
              ),
            ],
          ),
        ),

        // Empty state
        const Expanded(child: _ChatEmptyState()),
      ],
    );
  }
}

class _ChatEmptyState extends StatelessWidget {
  const _ChatEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.space40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Illustrated icon
            Container(
              width:  100,
              height: 100,
              decoration: BoxDecoration(
                color:  AppColors.surfaceGlass,
                shape:  BoxShape.circle,
                border: Border.all(color: AppColors.goldBorder),
                boxShadow: [
                  BoxShadow(
                    color:       AppColors.goldGlow,
                    blurRadius:  24,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                color: AppColors.champagneGold,
                size:  44,
              ),
            ),

            const SizedBox(height: AppDimensions.space28),

            Text(
              'No conversations yet',
              style: AppTypography.screenTitle.copyWith(fontSize: 22),
            ),
            const SizedBox(height: AppDimensions.space12),
            Text(
              'Accept an interest or have your\ninterest accepted to begin\na conversation.',
              style: AppTypography.bodyMuted,
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: AppDimensions.space32),

            // 48-hour probation notice
            Container(
              padding: const EdgeInsets.all(AppDimensions.space16),
              decoration: BoxDecoration(
                color:        AppColors.champagneGold.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                border: Border.all(color: AppColors.goldBorder),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.champagneGold,
                    size:  AppDimensions.iconSizeMedium,
                  ),
                  const SizedBox(width: AppDimensions.space12),
                  Expanded(
                    child: Text(
                      'New members may message after a\n48-hour reflection period.',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.champagneGold.withValues(alpha: 0.85),
                      ),
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
