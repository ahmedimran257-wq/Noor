// lib/features/onboarding/screens/splash_brand_screen.dart
// ============================================================
// NOOR — Splash Brand Screen (Step 0 in the overall flow)
// Spec from blueprint:
//   0ms    — Dark background #0A0A0F
//   300ms  — نور fades in, scales 0.8→1.0 (600ms ease-out-cubic)
//   600ms  — 6 light rays emanate from center (staggered 50ms)
//   900ms  — Rays fade out (400ms)
//   1000ms — "NOOR" wordmark fades in (400ms)
//   1400ms — Tagline "Begin with bismillah" fades in (300ms)
//   2000ms — Buttons slide up from bottom (400ms)
//   2500ms — Everything settled, interactive
// ============================================================

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/buttons/noor_primary_button.dart';
import '../../../core/widgets/buttons/noor_secondary_button.dart';
import '../../../core/router/app_router.dart';

class SplashBrandScreen extends StatefulWidget {
  const SplashBrandScreen({super.key});

  @override
  State<SplashBrandScreen> createState() => _SplashBrandScreenState();
}

class _SplashBrandScreenState extends State<SplashBrandScreen>
    with TickerProviderStateMixin {

  // ── Animation controllers ─────────────────────────────────
  late final AnimationController _noorCtrl;
  late final AnimationController _raysCtrl;
  late final AnimationController _wordmarkCtrl;
  late final AnimationController _taglineCtrl;
  late final AnimationController _buttonsCtrl;

  // ── Animations ────────────────────────────────────────────
  late final Animation<double> _noorOpacity;
  late final Animation<double> _noorScale;
  late final Animation<double> _raysOpacity;
  late final Animation<double> _raysLength;
  late final Animation<double> _wordmarkOpacity;
  late final Animation<double> _taglineOpacity;
  late final Animation<Offset> _buttonsSlide;
  late final Animation<double> _buttonsOpacity;

  @override
  void initState() {
    super.initState();

    // نور letterform — 600ms
    _noorCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _noorOpacity = CurvedAnimation(parent: _noorCtrl, curve: Curves.easeOut);
    _noorScale   = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _noorCtrl, curve: Curves.easeOutCubic),
    );

    // Light rays — 800ms total (start fading at 400ms)
    _raysCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _raysOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.8), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 0.8, end: 0.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _raysCtrl, curve: Curves.easeInOut));
    _raysLength = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _raysCtrl, curve: Curves.easeOut),
    );

    // NOOR wordmark — 400ms
    _wordmarkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _wordmarkOpacity = CurvedAnimation(
      parent: _wordmarkCtrl,
      curve: Curves.easeOut,
    );

    // Tagline — 300ms
    _taglineCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _taglineOpacity = CurvedAnimation(
      parent: _taglineCtrl,
      curve: Curves.easeOut,
    );

    // Buttons — 400ms
    _buttonsCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _buttonsSlide = Tween<Offset>(
      begin: const Offset(0, 0.6),
      end:   Offset.zero,
    ).animate(CurvedAnimation(parent: _buttonsCtrl, curve: Curves.easeOutCubic));
    _buttonsOpacity = CurvedAnimation(
      parent: _buttonsCtrl,
      curve: Curves.easeOut,
    );

    _runSequence();
  }

  Future<void> _runSequence() async {
    await Future.delayed(const Duration(milliseconds: 300));
    _noorCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 300));
    _raysCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 400));
    _wordmarkCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 400));
    _taglineCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 600));
    _buttonsCtrl.forward();
  }

  @override
  void dispose() {
    _noorCtrl.dispose();
    _raysCtrl.dispose();
    _wordmarkCtrl.dispose();
    _taglineCtrl.dispose();
    _buttonsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.obsidianNight,
      body: Stack(
        children: [
          // ── Radial glow from center ───────────────────────
          Center(
            child: AnimatedBuilder(
              animation: _noorCtrl,
              builder: (context, _) => Opacity(
                opacity: _noorCtrl.value * 0.4,
                child: Container(
                  width: 280,
                  height: 280,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Color(0x40C5A059),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Light rays ────────────────────────────────────
          Center(
            child: AnimatedBuilder(
              animation: _raysCtrl,
              builder: (context, _) => CustomPaint(
                size: const Size(280, 280),
                painter: _RaysPainter(
                  opacity: _raysOpacity.value,
                  length:  _raysLength.value,
                ),
              ),
            ),
          ),

          // ── Main content ──────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 3),

                // نور Arabic letterform
                AnimatedBuilder(
                  animation: _noorCtrl,
                  builder: (context, _) => Opacity(
                    opacity: _noorOpacity.value,
                    child: Transform.scale(
                      scale: _noorScale.value,
                      child: Text(
                        'نور',
                        style: TextStyle(
                          fontFamily: 'serif',
                          fontSize: 72,
                          color: AppColors.champagneGold,
                          height: 1.0,
                          shadows: [
                            Shadow(
                              color: AppColors.champagneGold.withValues(alpha: 0.4),
                              blurRadius: 24,
                            ),
                          ],
                        ),
                        textDirection: TextDirection.rtl,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: AppDimensions.space16),

                // NOOR wordmark
                FadeTransition(
                  opacity: _wordmarkOpacity,
                  child: Text('NOOR', style: AppTypography.wordmark),
                ),

                const SizedBox(height: AppDimensions.space12),

                // Tagline
                FadeTransition(
                  opacity: _taglineOpacity,
                  child: Text(
                    'Begin with bismillah',
                    style: AppTypography.tagline,
                  ),
                ),

                const Spacer(flex: 4),

                // Buttons
                SlideTransition(
                  position: _buttonsSlide,
                  child: FadeTransition(
                    opacity: _buttonsOpacity,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.space24,
                      ),
                      child: Column(
                        children: [
                          NoorPrimaryButton(
                            label: 'Create Profile',
                            onTap: () => context.push(AppRoutes.legal),
                          ),
                          const SizedBox(height: AppDimensions.space12),
                          NoorSecondaryButton(
                            label: 'Sign In',
                            onTap: () => context.push(AppRoutes.phone),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: AppDimensions.space48),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Light rays painter ────────────────────────────────────────

class _RaysPainter extends CustomPainter {
  const _RaysPainter({required this.opacity, required this.length});
  final double opacity;
  final double length;

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final paint  = Paint()
      ..color       = AppColors.champagneGold.withValues(alpha: opacity * 0.7)
      ..strokeWidth = 1.5
      ..strokeCap   = StrokeCap.round;

    for (int i = 0; i < 6; i++) {
      final angle = (i * 60) * (math.pi / 180);
      final startR = 48.0;
      final endR   = startR + (80 * length);
      final start  = Offset(
        center.dx + startR * math.cos(angle),
        center.dy + startR * math.sin(angle),
      );
      final end = Offset(
        center.dx + endR * math.cos(angle),
        center.dy + endR * math.sin(angle),
      );
      canvas.drawLine(start, end, paint);
    }
  }

  @override
  bool shouldRepaint(_RaysPainter old) =>
      old.opacity != opacity || old.length != length;
}
