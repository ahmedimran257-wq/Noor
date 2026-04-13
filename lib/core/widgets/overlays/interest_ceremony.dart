// lib/core/widgets/overlays/interest_ceremony.dart
// ============================================================
// The Interest Ceremony — "The Magic Moment"
// "This is not a screen; it is an Event."
//
// Timeline:
//   0ms    — Overlay appears
//   0ms    — Gold ring at center, radius 0
//   0-400ms — Ring expands to radius 60px (ease-out-cubic)
//   200ms  — Ring begins fading (opacity 1→0 over 300ms)
//   200ms  — 6 gold particles spawn at center
//   200-600ms — Particles move outward 80px at 60° intervals
//   400ms  — Checkmark begins drawing
//   400-700ms — Checkmark completes
//   700ms  — Text fades in
//   1800ms — Overlay fades out
//   2100ms — Complete
// ============================================================

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimensions.dart';
import '../../theme/app_typography.dart';

// ── Public API ────────────────────────────────────────────────

/// Shows the Interest Ceremony overlay over the current screen.
Future<void> showInterestCeremony(BuildContext context) {
  return showGeneralDialog(
    context:          context,
    barrierDismissible: false,
    barrierColor:     Colors.black.withValues(alpha: 0.8),
    transitionDuration: Duration.zero,
    pageBuilder: (_, __, ___) => const _InterestCeremonyOverlay(),
  );
}

// ── Overlay Widget ────────────────────────────────────────────

class _InterestCeremonyOverlay extends StatefulWidget {
  const _InterestCeremonyOverlay();

  @override
  State<_InterestCeremonyOverlay> createState() =>
      _InterestCeremonyOverlayState();
}

class _InterestCeremonyOverlayState extends State<_InterestCeremonyOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _ringController;
  late final AnimationController _particleController;
  late final AnimationController _checkController;
  late final AnimationController _textController;
  late final AnimationController _exitController;

  // Ring animations
  late final Animation<double> _ringRadius;
  late final Animation<double> _ringOpacity;

  // Particle animations
  late final Animation<double> _particleProgress;
  late final Animation<double> _particleOpacity;

  // Checkmark
  late final Animation<double> _checkProgress;

  // Text
  late final Animation<double> _textOpacity;

  // Exit
  late final Animation<double> _exitOpacity;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _runSequence();
  }

  void _setupAnimations() {
    _ringController = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 500),
    );
    _ringRadius = Tween<double>(begin: 0, end: 60).animate(
      CurvedAnimation(parent: _ringController, curve: Curves.easeOutCubic),
    );
    _ringOpacity = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(
        parent: _ringController,
        curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
      ),
    );

    _particleController = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 400),
    );
    _particleProgress = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _particleController, curve: Curves.easeOut),
    );
    _particleOpacity = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(parent: _particleController, curve: Curves.easeIn),
    );

    _checkController = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 300),
    );
    _checkProgress = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _checkController, curve: Curves.easeInOut),
    );

    _textController = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 300),
    );
    _textOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOut),
    );

    _exitController = AnimationController(
      vsync:    this,
      duration: AppDimensions.ceremonyOverlayFade,
    );
    _exitOpacity = Tween<double>(begin: 1, end: 0).animate(_exitController);
  }

  Future<void> _runSequence() async {
    // Phase 1: Ring expands + haptic tap
    HapticFeedback.lightImpact();
    await _ringController.forward();

    // Phase 2: Particles + ring fade (simultaneous with ring)
    _particleController.forward();

    // Phase 3: Checkmark draws
    await Future.delayed(const Duration(milliseconds: 200));
    HapticFeedback.mediumImpact();
    await _checkController.forward();

    // Phase 4: Text fades in
    await _textController.forward();

    // Phase 5: Hold → fade out entire overlay
    await Future.delayed(const Duration(milliseconds: 1100));
    await _exitController.forward();

    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _ringController.dispose();
    _particleController.dispose();
    _checkController.dispose();
    _textController.dispose();
    _exitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _exitOpacity,
      builder: (context, child) => Opacity(
        opacity: _exitOpacity.value,
        child: child,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: AnimatedBuilder(
            animation: Listenable.merge([
              _ringController,
              _particleController,
              _checkController,
              _textController,
            ]),
            builder: (context, _) {
              return SizedBox(
                width:  200,
                height: 240,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // ── Gold Ring ──────────────────────────
                    CustomPaint(
                      size: const Size(200, 200),
                      painter: _RingPainter(
                        radius:  _ringRadius.value,
                        opacity: _ringOpacity.value,
                      ),
                    ),

                    // ── Particles ─────────────────────────
                    CustomPaint(
                      size: const Size(200, 200),
                      painter: _ParticlePainter(
                        progress: _particleProgress.value,
                        opacity:  _particleOpacity.value,
                      ),
                    ),

                    // ── Checkmark ─────────────────────────
                    CustomPaint(
                      size: const Size(60, 60),
                      painter: _CheckmarkPainter(
                        progress: _checkProgress.value,
                      ),
                    ),

                    // ── Text ──────────────────────────────
                    Positioned(
                      bottom: 0,
                      child: Opacity(
                        opacity: _textOpacity.value,
                        child: Text(
                          'May Allah bless this with goodness',
                          style: AppTypography.tagline.copyWith(
                            color: AppColors.pearlWhite,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ── Custom Painters ───────────────────────────────────────────

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.radius, required this.opacity});
  final double radius;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0 || radius <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final paint  = Paint()
      ..color       = AppColors.champagneGold.withValues(alpha: opacity)
      ..style       = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.radius != radius || old.opacity != opacity;
}

class _ParticlePainter extends CustomPainter {
  const _ParticlePainter({required this.progress, required this.opacity});
  final double progress;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0 || progress <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final paint  = Paint()
      ..color = AppColors.champagneGold.withValues(alpha: opacity)
      ..style = PaintingStyle.fill;

    // 6 particles at 60° intervals
    for (int i = 0; i < 6; i++) {
      final angle    = (i * 60) * math.pi / 180;
      final distance = progress * 80;
      final pos = Offset(
        center.dx + distance * math.cos(angle),
        center.dy + distance * math.sin(angle),
      );
      canvas.drawCircle(pos, 4 * (1 - progress * 0.5), paint);
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) =>
      old.progress != progress || old.opacity != opacity;
}

class _CheckmarkPainter extends CustomPainter {
  const _CheckmarkPainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final paint = Paint()
      ..color       = AppColors.champagneGold
      ..style       = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap   = StrokeCap.round
      ..strokeJoin  = StrokeJoin.round;

    final center = Offset(size.width / 2, size.height / 2);

    // Checkmark path: two segments
    // Segment 1: bottom-left arm (25% of progress)
    // Segment 2: top-right arm  (75% of progress)
    final p1 = Offset(center.dx - 18, center.dy + 2);  // Start
    final p2 = Offset(center.dx - 6,  center.dy + 14); // Corner
    final p3 = Offset(center.dx + 20, center.dy - 14); // End

    final path = Path();

    if (progress < 0.35) {
      // Drawing first arm
      final t = progress / 0.35;
      final end = Offset.lerp(p1, p2, t)!;
      path.moveTo(p1.dx, p1.dy);
      path.lineTo(end.dx, end.dy);
    } else {
      // First arm complete, drawing second arm
      final t = (progress - 0.35) / 0.65;
      final end = Offset.lerp(p2, p3, t)!;
      path.moveTo(p1.dx, p1.dy);
      path.lineTo(p2.dx, p2.dy);
      path.lineTo(end.dx, end.dy);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CheckmarkPainter old) => old.progress != progress;
}
