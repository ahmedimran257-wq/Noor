import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

class _Greeting {
  const _Greeting(
    this.text, {
    required this.isRtl,
    required this.fontSize,
    this.isGold = false,
  });

  final String text;
  final bool isRtl;
  final double fontSize;
  final bool isGold;
}

class _LogoDot {
  const _LogoDot({
    required this.start,
    required this.end,
    required this.size,
  });

  final Offset start;
  final Offset end;
  final double size;
}

const List<_Greeting> _kGreetings = [
  _Greeting('السلام عليكم', isRtl: true, fontSize: 31, isGold: true),
  _Greeting('Assalamu Alaikum', isRtl: false, fontSize: 21),
  _Greeting('السلام علیکم', isRtl: true, fontSize: 27),
  _Greeting('Selamun Aleykum', isRtl: false, fontSize: 18),
  _Greeting('আসসালামু আলাইকুম', isRtl: false, fontSize: 19, isGold: true),
  _Greeting('Assalamualaikum', isRtl: false, fontSize: 17),
  _Greeting('سلام علیکم', isRtl: true, fontSize: 23),
  _Greeting('Assalamou Alaykoum', isRtl: false, fontSize: 16),
  _Greeting('Assalaamu Calaykum', isRtl: false, fontSize: 16),
  _Greeting('Assalamualaikum', isRtl: false, fontSize: 17),
];

const List<Offset> _kStartPositions = [
  Offset(0.04, 0.11),
  Offset(0.48, 0.07),
  Offset(0.55, 0.21),
  Offset(0.06, 0.36),
  Offset(0.58, 0.43),
  Offset(0.12, 0.57),
  Offset(0.42, 0.62),
  Offset(0.05, 0.72),
  Offset(0.53, 0.75),
  Offset(0.22, 0.84),
];

const List<Offset> _kDriftVectors = [
  Offset(0.025, -0.030),
  Offset(-0.015, 0.025),
  Offset(-0.030, 0.010),
  Offset(0.010, -0.040),
  Offset(-0.020, -0.020),
  Offset(0.030, 0.020),
  Offset(-0.010, -0.035),
  Offset(0.025, -0.020),
  Offset(-0.030, 0.030),
  Offset(0.015, 0.025),
];

class AssalamAnimationScreen extends StatefulWidget {
  const AssalamAnimationScreen({super.key});

  @override
  State<AssalamAnimationScreen> createState() => _AssalamAnimationScreenState();
}

class _AssalamAnimationScreenState extends State<AssalamAnimationScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _master;
  late final List<_LogoDot> _logoDots;
  bool _navigated = false;

  static const double _greetingPhaseStart = 0.38;
  static const double _logoFadeEnd = 0.07;
  static const double _logoDisperseStart = 0.18;
  static const double _logoDisperseEnd = 0.28;
  static const double _logoGlowEnd = 0.30;

  static const double _particleStep = 0.05;
  static const double _particleFadeIn = 0.10;
  static const double _particleHold = 0.18;
  static const double _particleFadeOut = 0.10;
  static const double _particleTotal = 0.38;

  static const double _revealStart = 0.615;
  static const double _revealEnd = 0.730;
  static const double _subtitleStart = 0.735;
  static const double _subtitleEnd = 0.820;

  @override
  void initState() {
    super.initState();
    _logoDots = _buildLogoDots();
    _master = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 8500),
    )
      ..addStatusListener(_onStatus)
      ..forward();
  }

  List<_LogoDot> _buildLogoDots() {
    final random = math.Random(42);
    const anchors = <Offset>[
      Offset(-118, -18),
      Offset(-112, 0),
      Offset(-106, 18),
      Offset(-88, -10),
      Offset(-66, -18),
      Offset(-66, 0),
      Offset(-66, 18),
      Offset(-42, -16),
      Offset(-20, -18),
      Offset(-20, 0),
      Offset(-20, 18),
      Offset(6, -18),
      Offset(30, -18),
      Offset(30, 0),
      Offset(30, 18),
      Offset(58, -18),
      Offset(78, -6),
      Offset(96, -18),
      Offset(108, 2),
      Offset(116, 18),
    ];

    return anchors.map((anchor) {
      final angle = random.nextDouble() * math.pi * 2;
      final distance = 60 + random.nextDouble() * 60;
      final size = 4 + random.nextDouble() * 2;
      return _LogoDot(
        start: anchor,
        end: Offset(
          anchor.dx + math.cos(angle) * distance,
          anchor.dy + math.sin(angle) * distance,
        ),
        size: size,
      );
    }).toList(growable: false);
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) _navigate();
  }

  Future<void> _navigate() async {
    if (_navigated || !mounted) return;
    _navigated = true;
    final prefs = await SharedPreferences.getInstance();
    final introCompleted = prefs.getBool('mithaq_intro_completed') ?? false;
    if (!mounted) return;
    context.go(introCompleted ? AppRoutes.splash : AppRoutes.languageSelect);
  }

  @override
  void dispose() {
    _master.dispose();
    super.dispose();
  }

  double get _phaseT {
    final t = _master.value;
    if (t <= _greetingPhaseStart) return 0.0;
    return ((t - _greetingPhaseStart) / (1 - _greetingPhaseStart))
        .clamp(0.0, 1.0);
  }

  double _particleOpacity(int i) {
    final t = _phaseT;
    final s = i * _particleStep;
    final fi = s + _particleFadeIn;
    final fo = s + _particleFadeIn + _particleHold;
    final e = s + _particleTotal;

    if (t <= s || t >= e) return 0.0;
    if (t < fi) return ((t - s) / _particleFadeIn).clamp(0.0, 1.0);
    if (t < fo) return 1.0;
    return ((e - t) / _particleFadeOut).clamp(0.0, 1.0);
  }

  Offset _particlePosition(int i, Size screen) {
    final t = _phaseT;
    final s = i * _particleStep;
    final progress = ((t - s) / _particleTotal).clamp(0.0, 1.0);
    final base = _kStartPositions[i];
    final drift = _kDriftVectors[i];

    return Offset(
      (base.dx + drift.dx * progress) * screen.width,
      (base.dy + drift.dy * progress) * screen.height,
    );
  }

  double _revealOpacity() {
    final t = _phaseT;
    if (t <= _revealStart) return 0.0;
    if (t >= _revealEnd) return 1.0;
    return ((t - _revealStart) / (_revealEnd - _revealStart)).clamp(0.0, 1.0);
  }

  double _revealScale() => 0.85 + _revealOpacity() * 0.15;

  double _subtitleOpacity() {
    final t = _phaseT;
    if (t <= _subtitleStart) return 0.0;
    if (t >= _subtitleEnd) return 1.0;
    return ((t - _subtitleStart) / (_subtitleEnd - _subtitleStart))
        .clamp(0.0, 1.0);
  }

  double _logoOpacity() {
    final t = _master.value;
    if (t < _logoFadeEnd) return (t / _logoFadeEnd).clamp(0.0, 1.0);
    if (t < _logoDisperseStart) return 1.0;
    if (t >= _logoDisperseEnd) return 0.0;
    return (1 -
            (t - _logoDisperseStart) / (_logoDisperseEnd - _logoDisperseStart))
        .clamp(0.0, 1.0);
  }

  double _logoDotProgress() {
    final t = _master.value;
    if (t <= _logoDisperseStart) return 0.0;
    if (t >= _logoDisperseEnd) return 1.0;
    final raw =
        (t - _logoDisperseStart) / (_logoDisperseEnd - _logoDisperseStart);
    return Curves.easeOut.transform(raw.clamp(0.0, 1.0));
  }

  double _logoDotOpacity() {
    final progress = _logoDotProgress();
    if (progress <= 0) return 0.0;
    return (1 - progress).clamp(0.0, 1.0);
  }

  Widget _buildGlow() {
    final t = _master.value;
    final introGlow = t < _logoGlowEnd
        ? (1 - (t / _logoGlowEnd)).clamp(0.0, 1.0) * 0.22
        : 0.0;
    final alpha = (introGlow + _revealOpacity() * 0.28).clamp(0.0, 0.28);
    if (alpha <= 0.0) return const SizedBox.shrink();
    return Center(
      child: Container(
        width: 520,
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

  Widget _buildLogoIntro() {
    final textOpacity = _logoOpacity();
    final dotProgress = _logoDotProgress();
    final dotOpacity = _logoDotOpacity();
    if (textOpacity <= 0.005 && dotOpacity <= 0.005) {
      return const SizedBox.shrink();
    }

    return Center(
      child: SizedBox(
        width: 300,
        height: 150,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Opacity(
              opacity: textOpacity,
              child: const Text(
                'MITHAQ',
                style: TextStyle(
                  fontFamily: 'PlayfairDisplay',
                  fontSize: 48,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                  color: Color(0xFFD4A843),
                  shadows: [
                    Shadow(color: Color(0x66D4A843), blurRadius: 30),
                    Shadow(color: Color(0x33D4A843), blurRadius: 70),
                  ],
                ),
              ).animate().fadeIn(duration: 600.ms, curve: Curves.easeOut),
            ),
            ..._logoDots.map((dot) {
              final pos = Offset.lerp(dot.start, dot.end, dotProgress)!;
              return Positioned(
                left: 150 + pos.dx - dot.size / 2,
                top: 75 + pos.dy - dot.size / 2,
                child: Opacity(
                  opacity: dotOpacity,
                  child: Container(
                    width: dot.size,
                    height: dot.size,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD4A843),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFD4A843).withValues(alpha: 0.5),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  void _skip() {
    _master.stop();
    _navigate();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _skip,
      child: Scaffold(
        backgroundColor: AppColors.obsidianNight,
        body: AnimatedBuilder(
          animation: _master,
          builder: (context, _) {
            return Stack(
              clipBehavior: Clip.none,
              children: [
                _buildGlow(),
                _buildLogoIntro(),
                ...List.generate(_kGreetings.length, (i) {
                  final opacity = _particleOpacity(i);
                  if (opacity <= 0.005) return const SizedBox.shrink();

                  final pos = _particlePosition(i, size);
                  final greeting = _kGreetings[i];

                  return Positioned(
                    left: pos.dx,
                    top: pos.dy,
                    child: Opacity(
                      opacity: opacity,
                      child: Text(
                        greeting.text,
                        textDirection: greeting.isRtl
                            ? TextDirection.rtl
                            : TextDirection.ltr,
                        style: TextStyle(
                          fontSize: greeting.fontSize,
                          fontWeight: greeting.isGold
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: greeting.isGold
                              ? AppColors.champagneGold
                              : AppColors.pearlWhite.withValues(alpha: 0.72),
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
                Center(
                  child: Opacity(
                    opacity: _revealOpacity(),
                    child: Transform.scale(
                      scale: _revealScale(),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'السلام عليكم',
                            textDirection: TextDirection.rtl,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 52,
                              fontWeight: FontWeight.w700,
                              color: AppColors.champagneGold,
                              height: 1.2,
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
                          Opacity(
                            opacity: _subtitleOpacity(),
                            child: Text(
                              'Welcome to Mithaq',
                              style: AppTypography.tagline.copyWith(
                                color: AppColors.pearlWhite
                                    .withValues(alpha: 0.75),
                                letterSpacing: 2.5,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  child: Align(
                    alignment: Alignment.bottomRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 24, bottom: 40),
                      child: GestureDetector(
                        onTap: _skip,
                        child: Opacity(
                          opacity: 0.45,
                          child: Text(
                            'Skip',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.slateMist,
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
