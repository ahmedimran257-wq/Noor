// lib/features/onboarding/screens/welcome_screen.dart
// ============================================================
// MITHAQ — Welcome Screen (Onboarding Step 10 → Complete)
// Celebration animation + community guidelines.
// "Start Browsing" routes to /home.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mithaq/l10n/generated/app_localizations.dart';
import '../../../core/cubits/auth/auth_cubit.dart';
import '../../../core/services/profile_write_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/buttons/mithaq_primary_button.dart';
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
    final l10n = AppLocalizations.of(context);
    final isAr = l10n.localeName == 'ar';
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.5),  // slightly above center
            radius: 1.2,
            colors: [
              AppColors.navyCharcoal,  // Deep premium navy-charcoal core
              AppColors.obsidianNight,  // Deep midnight edges
            ],
          ),
        ),
        child: Stack(
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
                          isAr ? 'بسم الله،\nملفك نشط الآن.' : 'Bismillah,\nyou\'re live.',
                          style: AppTypography.screenTitle.copyWith(
                            fontSize: 32,
                            height:   1.2,
                          ),
                          textAlign: TextAlign.center,
                        ),
  
                        const SizedBox(height: AppDimensions.space12),
  
                        Text(
                          isAr
                              ? 'ملفك الشخصي مرئي الآن على ميثاق.\nيسّر الله لك أمرك.'
                              : 'Your profile is now visible on Mithaq.\n'
                                'May Allah make it easy for you.',
                          style: AppTypography.bodyMuted,
                          textAlign: TextAlign.center,
                        ),
  
                        const SizedBox(height: AppDimensions.space40),
  
                        // Community guidelines notice
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
                                      isAr ? 'أنت في مساحة آمنة' : 'You\'re in a safe space',
                                      style: AppTypography.captionMedium.copyWith(
                                        color: AppColors.verifiedTeal,
                                      ),
                                    ),
                                    const SizedBox(height: AppDimensions.space4),
                                    Text(
                                      isAr
                                          ? 'تتم مراجعة جميع الملفات الشخصية للأمان. تصفح، أرسل اهتماماتك، وابدأ محادثات هادفة بكل صدق.'
                                          : 'All profiles are reviewed for safety. '
                                            'Browse, send interests, and start meaningful '
                                            'conversations with sincerity.',
                                      style: AppTypography.caption,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
  
                        const Spacer(flex: 3),
  
                        MithaqPrimaryButton(
                          label: isAr ? 'ابدأ التصفح' : 'Start Browsing',
                          onTap: () async {
                            const completedStep = 14;
                            await ProfileWriteService.updateOnboardingStep(
                              completedStep,
                            );
                            if (!context.mounted) return;
                            context
                                .read<AuthCubit>()
                                .updateOnboardingStep(completedStep);
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
      ),
    );
  }
}
