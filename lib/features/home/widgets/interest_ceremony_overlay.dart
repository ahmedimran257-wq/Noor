// lib/features/home/widgets/interest_ceremony_overlay.dart
// ============================================================
// NOOR — The Interest Ceremony Overlay
// Blueprint-exact animation sequence when "Send Interest" fires.
//
// Timeline:
//   0ms:    Overlay + blur appears
//   0ms:    Gold ring expands (400ms)
//   400ms:  Gold particles spray outward (400ms, staggered)
//   800ms:  Gold checkmark draws in (300ms)
//   1100ms: "Interest Sent" + name text fades in (300ms)
//   2100ms: Overlay fades out
// ============================================================

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';

/// Shows the ceremony overlay over the entire screen.
/// Returns a [Future] that completes when the overlay has faded out.
Future<void> showInterestCeremony(
  BuildContext context, {
  required String firstName,
}) {
  return showGeneralDialog(
    context:          context,
    barrierDismissible: false,
    barrierLabel:     'Interest Ceremony',
    barrierColor:     Colors.transparent,
    transitionDuration: Duration.zero,
    pageBuilder: (context, _, __) {
      return _CeremonyOverlay(firstName: firstName);
    },
  );
}

class _CeremonyOverlay extends StatefulWidget {
  const _CeremonyOverlay({required this.firstName});
  final String firstName;

  @override
  State<_CeremonyOverlay> createState() => _CeremonyOverlayState();
}

class _CeremonyOverlayState extends State<_CeremonyOverlay>
    with TickerProviderStateMixin {
  // Overlay background fade
  late final AnimationController _bgCtrl;
  late final Animation<double>   _bgOpacity;

  // Ring expand
  late final AnimationController _ringCtrl;
  late final Animation<double>   _ringScale;
  late final Animation<double>   _ringOpacity;

  // Particles
  late final AnimationController _particleCtrl;

  // Checkmark draw
  late final AnimationController _checkCtrl;
  late final Animation<double>   _checkProgress;

  // Text fade
  late final AnimationController _textCtrl;
  late final Animation<double>   _textOpacity;

  @override
  void initState() {
    super.initState();

    // Background
    _bgCtrl = AnimationController(
      vsync:    this,
      duration: AppDimensions.ceremonyOverlayFade,
    );
    _bgOpacity = CurvedAnimation(parent: _bgCtrl, curve: Curves.easeIn);

    // Ring
    _ringCtrl = AnimationController(
      vsync:    this,
      duration: AppDimensions.ceremonyRingExpand,
    );
    _ringScale = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _ringCtrl, curve: Curves.easeOutCubic),
    );
    _ringOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _ringCtrl,
        curve:  const Interval(0.6, 1.0, curve: Curves.easeOut),
      ),
    );

    // Particles
    _particleCtrl = AnimationController(
      vsync:    this,
      duration: AppDimensions.ceremonyParticles,
    );

    // Checkmark
    _checkCtrl = AnimationController(
      vsync:    this,
      duration: AppDimensions.ceremonyCheckmark,
    );
    _checkProgress = CurvedAnimation(parent: _checkCtrl, curve: Curves.easeOut);

    // Text
    _textCtrl = AnimationController(
      vsync:    this,
      duration: AppDimensions.ceremonyTextFade,
    );
    _textOpacity = CurvedAnimation(parent: _textCtrl, curve: Curves.easeIn);

    _runSequence();
  }

  Future<void> _runSequence() async {
    _bgCtrl.forward();
    _ringCtrl.forward();

    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    _particleCtrl.forward();

    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    _checkCtrl.forward();

    await Future.delayed(AppDimensions.ceremonyCheckmark);
    if (!mounted) return;
    _textCtrl.forward();

    // Hold then dismiss
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    await _bgCtrl.reverse();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _ringCtrl.dispose();
    _particleCtrl.dispose();
    _checkCtrl.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _bgOpacity,
      child: Container(
        color: AppColors.obsidianNight.withValues(alpha: 0.85),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Ring + Particles + Checkmark stacked
              SizedBox(
                width:  200,
                height: 200,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Ring
                    AnimatedBuilder(
                      animation: _ringCtrl,
                      builder: (_, __) => Opacity(
                        opacity: _ringOpacity.value,
                        child: Transform.scale(
                          scale: _ringScale.value,
                          child: Container(
                            width:  160,
                            height: 160,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.champagneGold,
                                width: 2.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Particles
                    AnimatedBuilder(
                      animation: _particleCtrl,
                      builder: (_, __) => CustomPaint(
                        size: const Size(200, 200),
                        painter: _ParticlePainter(progress: _particleCtrl.value),
                      ),
                    ),

                    // Checkmark
                    AnimatedBuilder(
                      animation: _checkCtrl,
                      builder: (_, __) => CustomPaint(
                        size: const Size(80, 80),
                        painter: _CheckmarkPainter(progress: _checkProgress.value),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppDimensions.space24),

              // Text
              FadeTransition(
                opacity: _textOpacity,
                child: Column(
                  children: [
                    Text(
                      'Interest Sent',
                      style: AppTypography.screenTitle.copyWith(
                        color: AppColors.champagneGold,
                        fontSize: 26,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.space8),
                    Text(
                      'to ${widget.firstName}',
                      style: AppTypography.bodyMuted,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Particle Painter ─────────────────────────────────────────

class _ParticlePainter extends CustomPainter {
  _ParticlePainter({required this.progress});
  final double progress;

  static const _particleCount = 12;
  static final _rng = math.Random(42); // seeded for consistent positions

  @override
  void paint(Canvas canvas, Size size) {
    if (progress == 0.0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color   = AppColors.champagneGold.withValues(alpha: (1 - progress) * 0.9)
      ..style   = PaintingStyle.fill
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < _particleCount; i++) {
      final angle    = (i / _particleCount) * 2 * math.pi;
      final distance = 60.0 + _rng.nextDouble() * 40;
      final spread   = progress * distance;
      final size2    = 3.0 + _rng.nextDouble() * 3;

      final pos = Offset(
        center.dx + math.cos(angle) * spread,
        center.dy + math.sin(angle) * spread,
      );

      final opacity = (1 - progress).clamp(0.0, 1.0);
      canvas.drawCircle(pos, size2 * opacity, paint..color = AppColors.champagneGold.withValues(alpha: opacity * 0.8));
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => old.progress != progress;
}

// ── Checkmark Painter ─────────────────────────────────────────

class _CheckmarkPainter extends CustomPainter {
  _CheckmarkPainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress == 0.0) return;

    final paint = Paint()
      ..color       = AppColors.champagneGold
      ..style       = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap   = StrokeCap.round
      ..strokeJoin  = StrokeJoin.round;

    // Path: checkmark from left → bottom → top-right
    final startX = size.width  * 0.2;
    final startY = size.height * 0.5;
    final midX   = size.width  * 0.42;
    final midY   = size.height * 0.68;
    final endX   = size.width  * 0.78;
    final endY   = size.height * 0.32;

    // Total path length (approx)
    final seg1Length = math.sqrt(
      math.pow(midX - startX, 2) + math.pow(midY - startY, 2),
    );
    final seg2Length = math.sqrt(
      math.pow(endX - midX, 2) + math.pow(endY - midY, 2),
    );
    final totalLength = seg1Length + seg2Length;

    final drawn = progress * totalLength;

    final path = Path();
    if (drawn <= seg1Length) {
      final t = drawn / seg1Length;
      path.moveTo(startX, startY);
      path.lineTo(startX + (midX - startX) * t, startY + (midY - startY) * t);
    } else {
      final t = (drawn - seg1Length) / seg2Length;
      path.moveTo(startX, startY);
      path.lineTo(midX, midY);
      path.lineTo(midX + (endX - midX) * t, midY + (endY - midY) * t);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CheckmarkPainter old) => old.progress != progress;
}
