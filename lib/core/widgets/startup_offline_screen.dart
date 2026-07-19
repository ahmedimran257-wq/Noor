import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_typography.dart';
import '../../l10n/generated/app_localizations.dart';
import 'buttons/silarah_pressable.dart';

/// Full-screen startup state shown before authentication when Silarah's
/// backend cannot be reached. It intentionally keeps the router hidden so a
/// network failure can never masquerade as a signed-out session.
class StartupOfflineScreen extends StatefulWidget {
  const StartupOfflineScreen({
    super.key,
    this.onRetry,
    this.checking = false,
  }) : assert(checking || onRetry != null);

  final Future<bool> Function()? onRetry;
  final bool checking;

  @override
  State<StartupOfflineScreen> createState() => _StartupOfflineScreenState();
}

class _StartupOfflineScreenState extends State<StartupOfflineScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _signalController;
  bool _retrying = false;
  bool _retryFailed = false;

  @override
  void initState() {
    super.initState();
    _signalController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion && _signalController.isAnimating) {
      _signalController.stop();
      _signalController.value = 0.35;
    } else if (!reduceMotion && !_signalController.isAnimating) {
      _signalController.repeat();
    }
  }

  @override
  void dispose() {
    _signalController.dispose();
    super.dispose();
  }

  Future<void> _retry() async {
    if (_retrying) return;
    setState(() {
      _retrying = true;
      _retryFailed = false;
    });
    final online = await widget.onRetry!();
    if (!mounted) return;
    if (!online) {
      setState(() {
        _retrying = false;
        _retryFailed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.obsidianNight,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.28),
            radius: 1.05,
            colors: [AppColors.midnightPlum, AppColors.obsidianNight],
            stops: const [0, 0.72],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimensions.space24,
              AppDimensions.space20,
              AppDimensions.space24,
              AppDimensions.space24,
            ),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 520),
              curve: Curves.easeOutCubic,
              builder: (context, entrance, child) => Opacity(
                opacity: entrance,
                child: Transform.translate(
                  offset: Offset(0, 14 * (1 - entrance)),
                  child: child,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _OfflineWordmark(),
                  const Spacer(flex: 2),
                  Semantics(
                    image: true,
                    label: widget.checking
                        ? l10n.startup_connectivity_preparing_body
                        : l10n.startup_connectivity_offline_body,
                    child: Center(
                      child: RepaintBoundary(
                        child: AnimatedBuilder(
                          animation: _signalController,
                          builder: (_, __) => CustomPaint(
                            size: const Size.square(176),
                            painter: _ConnectionSealPainter(
                              progress: _signalController.value,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppDimensions.space40),
                  Text(
                    widget.checking
                        ? l10n.startup_connectivity_preparing_title
                        : l10n.startup_connectivity_offline_title,
                    textAlign: TextAlign.center,
                    style: AppTypography.screenTitle,
                  ),
                  const SizedBox(height: AppDimensions.space12),
                  Text(
                    widget.checking
                        ? l10n.startup_connectivity_preparing_body
                        : l10n.startup_connectivity_offline_body,
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyMuted.copyWith(height: 1.55),
                  ),
                  const SizedBox(height: AppDimensions.space24),
                  Center(
                    child: AnimatedSwitcher(
                      duration: AppDimensions.durationTransition,
                      child: _ConnectionStatus(
                        key: ValueKey(
                          (widget.checking, _retrying, _retryFailed),
                        ),
                        retrying: widget.checking || _retrying,
                        retryFailed: _retryFailed,
                      ),
                    ),
                  ),
                  const Spacer(flex: 3),
                  if (widget.checking)
                    const SizedBox(height: AppDimensions.buttonHeight)
                  else
                    SilarahPressable(
                      semanticLabel: l10n.startup_connectivity_check,
                      enabled: !_retrying,
                      onTap: _retry,
                      child: AnimatedContainer(
                        duration: AppDimensions.durationTransition,
                        height: AppDimensions.buttonHeight,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceGlass,
                          borderRadius: BorderRadius.circular(
                            AppDimensions.radiusButton,
                          ),
                          border: Border.all(color: AppColors.goldBorder),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.goldGlow,
                              blurRadius: 28,
                              spreadRadius: -8,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_retrying)
                              SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.champagneGold,
                                ),
                              )
                            else
                              Icon(
                                Icons.sync_rounded,
                                size: 20,
                                color: AppColors.champagneGold,
                              ),
                            const SizedBox(width: AppDimensions.space10),
                            Text(
                              _retrying
                                  ? l10n.startup_connectivity_checking
                                  : l10n.startup_connectivity_check,
                              style: AppTypography.buttonSecondary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: AppDimensions.space16),
                  Text(
                    widget.checking
                        ? l10n.startup_connectivity_protected
                        : l10n.startup_connectivity_auto,
                    textAlign: TextAlign.center,
                    style: AppTypography.caption,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OfflineWordmark extends StatelessWidget {
  const _OfflineWordmark();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(width: 24, child: Divider(color: AppColors.goldBorder)),
        const SizedBox(width: AppDimensions.space12),
        Text('SILARAH', style: AppTypography.wordmark),
        const SizedBox(width: AppDimensions.space12),
        SizedBox(width: 24, child: Divider(color: AppColors.goldBorder)),
      ],
    );
  }
}

class _ConnectionStatus extends StatelessWidget {
  const _ConnectionStatus({
    super.key,
    required this.retrying,
    required this.retryFailed,
  });

  final bool retrying;
  final bool retryFailed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final label = retrying
        ? l10n.startup_connectivity_verifying
        : retryFailed
            ? l10n.startup_connectivity_still_waiting
            : l10n.startup_connectivity_waiting;
    return Semantics(
      liveRegion: true,
      label: label,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.space14,
          vertical: AppDimensions.space8,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceGlass,
          borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: AppColors.champagneGold,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: AppColors.goldGlow, blurRadius: 8),
                ],
              ),
            ),
            const SizedBox(width: AppDimensions.space8),
            Text(label, style: AppTypography.sectionLabel),
          ],
        ),
      ),
    );
  }
}

class _ConnectionSealPainter extends CustomPainter {
  const _ConnectionSealPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final pulse = (math.sin(progress * math.pi * 2) + 1) / 2;

    canvas.drawCircle(
      center,
      78,
      Paint()
        ..color = AppColors.goldGlow.withValues(alpha: 0.18 + pulse * 0.12)
        ..style = PaintingStyle.fill,
    );

    for (var ring = 0; ring < 3; ring++) {
      final radius = 42.0 + (ring * 17);
      final direction = ring.isEven ? 1.0 : -1.0;
      final start = (progress * math.pi * 2 * direction) + (ring * 0.85);
      final sweep = math.pi * (0.72 + ring * 0.08);
      final rect = Rect.fromCircle(center: center, radius: radius);
      canvas.drawArc(
        rect,
        start,
        sweep,
        false,
        Paint()
          ..color = AppColors.champagneGold.withValues(
            alpha: 0.28 + (ring * 0.12),
          )
          ..strokeWidth = ring == 0 ? 2.2 : 1.2
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke,
      );
    }

    final orbitAngle = progress * math.pi * 2;
    final orbitDot =
        center + Offset(math.cos(orbitAngle), math.sin(orbitAngle)) * 59;
    canvas.drawCircle(
      orbitDot,
      3.2,
      Paint()..color = AppColors.champagneLight,
    );

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(math.pi / 4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-13, -13, 26, 26),
        const Radius.circular(6),
      ),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.champagneLight, AppColors.antiqueGold],
        ).createShader(const Rect.fromLTWH(-13, -13, 26, 26)),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ConnectionSealPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
