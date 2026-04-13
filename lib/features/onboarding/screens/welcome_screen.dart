// lib/features/onboarding/screens/welcome_screen.dart
// ============================================================
// NOOR — Welcome Screen (Onboarding Step 10 → Complete)
// Celebration animation + 48-hour probation notice.
// "Start Browsing" routes to /home.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/cubits/auth/auth_cubit.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/buttons/noor_primary_button.dart';
import '../../../core/router/app_router.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {

  late final AnimationController _glowCtrl;
  late final AnimationController _contentCtrl;
  late final Animation<double>   _glowScale;
  late final Animation<double>   _contentOpacity;
  late final Animation<Offset>   _contentSlide;

  @override
  void initState() {
    super.initState();

    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _glowScale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut),
    );

    _contentCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _contentOpacity = CurvedAnimation(
      parent: _contentCtrl,
      curve:  Curves.easeOut,
    );
    _contentSlide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end:   Offset.zero,
    ).animate(CurvedAnimation(parent: _contentCtrl, curve: Curves.easeOutCubic));

    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _contentCtrl.forward();
    });
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.obsidianNight,
      body: Stack(
        children: [
          // ── Pulsing gold glow ─────────────────────────────
          Center(
            child: AnimatedBuilder(
              animation: _glowCtrl,
              builder: (context, _) => Transform.scale(
                scale: _glowScale.value,
                child: Container(
                  width: 320,
                  height: 320,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Color(0x30C5A059),
                        Color(0x00C5A059),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Content ───────────────────────────────────────
          SafeArea(
            child: FadeTransition(
              opacity: _contentOpacity,
              child: SlideTransition(
                position: _contentSlide,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.space24,
                  ),
                  child: Column(
                    children: [
                      const Spacer(flex: 2),

                      // Icon
                      Container(
                        width:  96,
                        height: 96,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.champagneGold.withValues(alpha: 0.1),
                          border: Border.all(
                            color: AppColors.champagneGold.withValues(alpha: 0.4),
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: AppColors.champagneGold,
                          size:  48,
                        ),
                      ),

                      const SizedBox(height: AppDimensions.space24),

                      Text(
                        'Bismillah,\nyou\'re live.',
                        style: AppTypography.screenTitle.copyWith(
                          fontSize: 32,
                          height:   1.2,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: AppDimensions.space12),

                      Text(
                        'Your profile is now visible on NOOR.\n'
                        'May Allah make it easy for you.',
                        style: AppTypography.bodyMuted,
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: AppDimensions.space40),

                      // Probation notice
                      Container(
                        padding: const EdgeInsets.all(AppDimensions.space16),
                        decoration: BoxDecoration(
                          color:        AppColors.surfaceGlass,
                          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                          border:       Border.all(color: AppColors.cardBorder),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width:  40,
                              height: 40,
                              decoration: BoxDecoration(
                                color:  AppColors.verifiedTeal.withValues(alpha: 0.1),
                                shape:  BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.shield_outlined,
                                color: AppColors.verifiedTeal,
                                size:  20,
                              ),
                            ),
                            const SizedBox(width: AppDimensions.space12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Safety period active',
                                    style: AppTypography.captionMedium.copyWith(
                                      color: AppColors.verifiedTeal,
                                    ),
                                  ),
                                  const SizedBox(height: AppDimensions.space4),
                                  Text(
                                    'New members can browse and send interests immediately. '
                                    'Chat messages unlock after 48 hours — '
                                    'our standard protection for the community.',
                                    style: AppTypography.caption,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const Spacer(flex: 3),

                      NoorPrimaryButton(
                        label: 'Start Browsing',
                        onTap: () {
                          // Mark onboarding as fully complete (step >= 14)
                          // so the router redirect allows /home navigation.
                          context.read<AuthCubit>().updateOnboardingStep(14);
                          context.go(AppRoutes.home);
                        },
                      ),

                      const SizedBox(height: AppDimensions.space48),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
