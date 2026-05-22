// lib/features/onboarding/screens/assalam_animation_screen.dart
// ============================================================
// NOOR — Assalam Animation Screen
//
// iPhone-style floating greeting animation.
// "Assalamu Alaikum" in every language the app supports,
// floating across the screen like the iPhone first-boot "hello".
//
// Flow:
//   0s        — 10 greetings drift across screen, staggered
//   4.0s      — Central Arabic reveal fades in while particles fade
//   5.0s      — "Welcome to NOOR" subtitle appears
//   6.5s      — Auto-navigate to /language
//   Tap/Skip  — Navigate immediately
//
// Only shown on first install. Once language is selected,
// this screen never appears again.
// ============================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/router/app_router.dart';

// ── Greeting data ─────────────────────────────────────────────

class _Greeting {
  const _Greeting(
    this.text, {
    required this.isRtl,
    required this.fontSize,
    this.isGold = false,
  });

  final String text;
  final bool   isRtl;
  final double fontSize;
  final bool   isGold; // champagneGold accent for select scripts
}

// 10 greetings — one per floating particle
// Ordered to show the most visually rich scripts throughout the sequence.
const List<_Greeting> _kGreetings = [
  _Greeting('السلام عليكم',       isRtl: true,  fontSize: 31, isGold: true),  // Arabic
  _Greeting('Assalamu Alaikum',    isRtl: false, fontSize: 21),                // English
  _Greeting('السلام علیکم',        isRtl: true,  fontSize: 27),                // Urdu
  _Greeting('Selamün Aleyküm',     isRtl: false, fontSize: 18),                // Turkish
  _Greeting('আস্সালামু আলাইকুম',  isRtl: false, fontSize: 19, isGold: true),  // Bengali
  _Greeting('Assalamualaikum',     isRtl: false, fontSize: 17),                // Malay
  _Greeting('سلام علیکم',          isRtl: true,  fontSize: 23),                // Persian
  _Greeting('Assalamou Alaykoum',  isRtl: false, fontSize: 16),                // French
  _Greeting('Assalaamu Calaykum',  isRtl: false, fontSize: 16),                // Somali
  _Greeting('Assalamualaikum',     isRtl: false, fontSize: 17),                // Indonesian
];

// Pre-defined positions (fraction of screen width × height).
// Curated so they feel naturally scattered — not random, not grid.
const List<Offset> _kStartPositions = [
  Offset(0.04, 0.11),  // top-left
  Offset(0.48, 0.07),  // top-center-right
  Offset(0.55, 0.21),  // upper-right
  Offset(0.06, 0.36),  // left-middle-upper
  Offset(0.58, 0.43),  // right-middle
  Offset(0.12, 0.57),  // left-middle
  Offset(0.42, 0.62),  // center-ish
  Offset(0.05, 0.72),  // left-lower
  Offset(0.53, 0.75),  // right-lower
  Offset(0.22, 0.84),  // lower-center-left
];

// Subtle drift vectors (fraction — applied to width/height).
// Each greeting slowly moves in its own direction.
const List<Offset> _kDriftVectors = [
  Offset( 0.025, -0.030),  // right-up
  Offset(-0.015,  0.025),  // left-down
  Offset(-0.030,  0.010),  // left-down gentle
  Offset( 0.010, -0.040),  // right-up strong
  Offset(-0.020, -0.020),  // left-up
  Offset( 0.030,  0.020),  // right-down
  Offset(-0.010, -0.035),  // left-up
  Offset( 0.025, -0.020),  // right-up
  Offset(-0.030,  0.030),  // left-down
  Offset( 0.015,  0.025),  // right-down
];

// ── Screen ────────────────────────────────────────────────────

class AssalamAnimationScreen extends StatefulWidget {
  const AssalamAnimationScreen({super.key});

  @override
  State<AssalamAnimationScreen> createState() =>
      _AssalamAnimationScreenState();
}

class _AssalamAnimationScreenState extends State<AssalamAnimationScreen>
    with SingleTickerProviderStateMixin {

  // Single master controller — every animation derives from it via t.
  late final AnimationController _master;
  bool _navigated = false;

  // ── Timing constants (normalized 0.0 → 1.0 over 6500ms) ──────
  //
  // Particle animation layout:
  //   particle i starts at: i × 0.05
  //   fade-in  duration:    0.10
  //   hold     duration:    0.18
  //   fade-out duration:    0.10
  //   total per particle:   0.38
  //
  //   particle 0 : 0.00 → 0.38
  //   particle 9 : 0.45 → 0.83  (ends at ~5400ms)
  //
  // Reveal (large Arabic + subtitle):
  //   Arabic starts:   0.615  (~4000ms)
  //   Arabic ends:     0.730  (~4745ms)  fully visible
  //   Subtitle starts: 0.735  (~4778ms)
  //   Subtitle ends:   0.820  (~5330ms)  fully visible

  static const double _particleStep      = 0.05;
  static const double _particleFadeIn    = 0.10;
  static const double _particleHold      = 0.18;
  static const double _particleFadeOut   = 0.10;
  static const double _particleTotal     = 0.38; // fadein+hold+fadeout

  static const double _revealStart       = 0.615;
  static const double _revealEnd         = 0.730;
  static const double _subtitleStart     = 0.735;
  static const double _subtitleEnd       = 0.820;

  @override
  void initState() {
    super.initState();
    _master = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 6500),
    )
      ..addStatusListener(_onStatus)
      ..forward();
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) _navigate();
  }

  void _navigate() async {
    if (_navigated || !mounted) return;
    _navigated = true;
    // Check if this is the first launch or a returning user
    final prefs = await SharedPreferences.getInstance();
    final introCompleted = prefs.getBool('noor_intro_completed') ?? false;
    if (!mounted) return;
    if (introCompleted) {
      // Returning user → go straight to splash (Create Profile / Sign In)
      context.go(AppRoutes.splash);
    } else {
      // First launch → go to language selection
      context.go(AppRoutes.languageSelect);
    }
  }

  @override
  void dispose() {
    _master.dispose();
    super.dispose();
  }

  // ── Per-particle opacity ──────────────────────────────────────

  double _particleOpacity(int i) {
    final t  = _master.value;
    final s  = i * _particleStep;
    final fi = s + _particleFadeIn;
    final fo = s + _particleFadeIn + _particleHold;
    final e  = s + _particleTotal;

    if (t <= s || t >= e) return 0.0;
    if (t < fi) return ((t - s) / _particleFadeIn).clamp(0.0, 1.0);
    if (t < fo) return 1.0;
    return ((e - t) / _particleFadeOut).clamp(0.0, 1.0);
  }

  // ── Per-particle position (resolves fractions to pixels) ─────

  Offset _particlePosition(int i, Size screen) {
    final t = _master.value;
    final s = i * _particleStep;

    final progress = ((t - s) / _particleTotal).clamp(0.0, 1.0);
    final base = _kStartPositions[i];
    final drift = _kDriftVectors[i];

    return Offset(
      (base.dx + drift.dx * progress) * screen.width,
      (base.dy + drift.dy * progress) * screen.height,
    );
  }

  // ── Reveal animations ─────────────────────────────────────────

  double _revealOpacity() {
    final t = _master.value;
    if (t <= _revealStart) return 0.0;
    if (t >= _revealEnd)   return 1.0;
    return ((t - _revealStart) / (_revealEnd - _revealStart)).clamp(0.0, 1.0);
  }

  double _revealScale() {
    // Scales 0.85 → 1.0 as it fades in. Gentle "emerge" feel.
    return 0.85 + _revealOpacity() * 0.15;
  }

  double _subtitleOpacity() {
    final t = _master.value;
    if (t <= _subtitleStart) return 0.0;
    if (t >= _subtitleEnd)   return 1.0;
    return ((t - _subtitleStart) / (_subtitleEnd - _subtitleStart))
        .clamp(0.0, 1.0);
  }

  // ── Radial glow (grows as reveal approaches) ─────────────────

  Widget _buildGlow() {
    final alpha = (_revealOpacity() * 0.28).clamp(0.0, 0.28);
    if (alpha <= 0.0) return const SizedBox.shrink();
    return Center(
      child: Container(
        width:  520,
        height: 520,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              AppColors.champagneGold.withValues(alpha: alpha),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        _master.stop();
        _navigate();
      },
      child: Scaffold(
        backgroundColor: AppColors.obsidianNight,
        body: AnimatedBuilder(
          animation: _master,
          builder: (context, _) {
            return Stack(
              clipBehavior: Clip.none,
              children: [
                // ── Radial background glow ──────────────────
                _buildGlow(),

                // ── Floating particles ──────────────────────
                ...List.generate(_kGreetings.length, (i) {
                  final opacity = _particleOpacity(i);
                  if (opacity <= 0.005) return const SizedBox.shrink();

                  final pos     = _particlePosition(i, size);
                  final greeting = _kGreetings[i];

                  return Positioned(
                    left: pos.dx,
                    top:  pos.dy,
                    child: Opacity(
                      opacity: opacity,
                      child: Text(
                        greeting.text,
                        textDirection: greeting.isRtl
                            ? TextDirection.rtl
                            : TextDirection.ltr,
                        style: TextStyle(
                          fontSize:   greeting.fontSize,
                          fontWeight: greeting.isGold
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: greeting.isGold
                              ? AppColors.champagneGold
                              : AppColors.pearlWhite
                                  .withValues(alpha: 0.72),
                          shadows: greeting.isGold
                              ? [
                                  Shadow(
                                    color: AppColors.champagneGold
                                        .withValues(alpha: 0.55),
                                    blurRadius: 18,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                    ),
                  );
                }),

                // ── Central reveal — final Arabic greeting ──
                Center(
                  child: Opacity(
                    opacity: _revealOpacity(),
                    child: Transform.scale(
                      scale: _revealScale(),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Large Arabic
                          Text(
                            'السلام عليكم',
                            textDirection: TextDirection.rtl,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize:   52,
                              fontWeight: FontWeight.w700,
                              color:      AppColors.champagneGold,
                              height:     1.2,
                              shadows: [
                                Shadow(
                                  color: AppColors.champagneGold
                                      .withValues(alpha: 0.65),
                                  blurRadius: 36,
                                ),
                                Shadow(
                                  color: AppColors.champagneGold
                                      .withValues(alpha: 0.30),
                                  blurRadius: 72,
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 14),

                          // Subtitle — "Welcome to NOOR"
                          Opacity(
                            opacity: _subtitleOpacity(),
                            child: Text(
                              'Welcome to NOOR',
                              style: AppTypography.tagline.copyWith(
                                color:         AppColors.pearlWhite
                                    .withValues(alpha: 0.75),
                                letterSpacing: 2.5,
                                fontSize:      14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── Skip button ─────────────────────────────
                SafeArea(
                  child: Align(
                    alignment: Alignment.bottomRight,
                    child: Padding(
                      padding: const EdgeInsets.only(
                        right: 24,
                        bottom: 40,
                      ),
                      child: GestureDetector(
                        onTap: () {
                          _master.stop();
                          _navigate();
                        },
                        child: Opacity(
                          opacity: 0.45,
                          child: Text(
                            'Skip',
                            style: AppTypography.caption.copyWith(
                              color:         AppColors.slateMist,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
