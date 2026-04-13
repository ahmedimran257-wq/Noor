// lib/features/home/home_placeholder_screen.dart
// ============================================================
// NOOR — Home Placeholder Screen
// Temporary screen shown after onboarding is complete.
// Replaced by the Discovery Feed in Step 5.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/cubits/auth/auth_cubit.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/buttons/noor_secondary_button.dart';

class HomePlaceholderScreen extends StatelessWidget {
  const HomePlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.obsidianNight,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.space24),
          child: Column(
            children: [
              // App bar
              Row(
                children: [
                  Text('NOOR', style: AppTypography.wordmark),
                  const Spacer(),
                  Icon(Icons.notifications_none_rounded,
                      color: AppColors.slateMist,
                      size: AppDimensions.iconSizeLarge),
                ],
              ),

              const Spacer(flex: 2),

              // Main content
              Container(
                padding: const EdgeInsets.all(AppDimensions.space32),
                decoration: BoxDecoration(
                  color:        AppColors.surfaceGlass,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
                  border:       Border.all(color: AppColors.cardBorder),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.explore_outlined,
                      color: AppColors.champagneGold,
                      size:  64,
                    ),
                    const SizedBox(height: AppDimensions.space20),
                    Text(
                      'Discovery Feed',
                      style: AppTypography.screenTitle,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppDimensions.space12),
                    Text(
                      'The discovery feed with real profiles\nis coming in Step 5.\n\n'
                      'You\'ve successfully completed the\nonboarding flow! 🎉',
                      style: AppTypography.bodyMuted,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              const Spacer(flex: 3),

              NoorSecondaryButton(
                label: 'Sign Out (Test)',
                onTap: () => context.read<AuthCubit>().signOut(),
              ),

              const SizedBox(height: AppDimensions.space24),
            ],
          ),
        ),
      ),
    );
  }
}
