import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_typography.dart';
import '../services/connectivity_service.dart';
import '../../l10n/generated/app_localizations.dart';
import 'buttons/silarah_pressable.dart';

/// Full-screen startup state shown before authentication when Silarah's
/// backend cannot be reached. It intentionally keeps the router hidden so a
/// network failure can never masquerade as a signed-out session.
class StartupOfflineScreen extends StatefulWidget {
  const StartupOfflineScreen({
    super.key,
    required this.onRetry,
    this.quality = BackendConnectionQuality.offline,
  });

  final Future<bool> Function() onRetry;
  final BackendConnectionQuality quality;

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
    final online = await widget.onRetry();
    if (!mounted) return;
    if (!online) {
      setState(() {
        _retrying = false;
        _retryFailed = true;
      });
    }
  }

  BackendConnectionQuality get _visualQuality {
    if (_retryFailed) return BackendConnectionQuality.offline;
    if (_retrying &&
        (widget.quality == BackendConnectionQuality.good ||
            widget.quality == BackendConnectionQuality.poor)) {
      return widget.quality;
    }
    if (_retrying) return BackendConnectionQuality.unknown;
    return BackendConnectionQuality.offline;
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
                    label: l10n.startup_connectivity_offline_body,
                    child: Center(
                      child: RepaintBoundary(
                        child: AnimatedBuilder(
                          animation: _signalController,
                          builder: (_, __) => CustomPaint(
                            size: const Size.square(176),
                            painter: _MobileTowerPainter(
                              progress: _signalController.value,
                              quality: _visualQuality,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppDimensions.space40),
                  Text(
                    l10n.startup_connectivity_offline_title,
                    textAlign: TextAlign.center,
                    style: AppTypography.screenTitle,
                  ),
                  const SizedBox(height: AppDimensions.space12),
                  Text(
                    l10n.startup_connectivity_offline_body,
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyMuted.copyWith(height: 1.55),
                  ),
                  const SizedBox(height: AppDimensions.space24),
                  Center(
                    child: AnimatedSwitcher(
                      duration: AppDimensions.durationTransition,
                      child: _ConnectionStatus(
                        key: ValueKey(
                          (_retrying, _retryFailed, _visualQuality),
                        ),
                        retrying: _retrying,
                        retryFailed: _retryFailed,
                        quality: _visualQuality,
                      ),
                    ),
                  ),
                  const Spacer(flex: 3),
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
                    l10n.startup_connectivity_auto,
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
    required this.quality,
  });

  final bool retrying;
  final bool retryFailed;
  final BackendConnectionQuality quality;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final label = retrying
        ? l10n.startup_connectivity_verifying
        : retryFailed
            ? l10n.startup_connectivity_still_waiting
            : l10n.startup_connectivity_waiting;
    final signalColor = _connectionColor(quality);
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
                color: signalColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: signalColor.withValues(alpha: .38),
                    blurRadius: 8,
                  ),
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

Color _connectionColor(BackendConnectionQuality quality) => switch (quality) {
      BackendConnectionQuality.good => AppColors.onlineGreen,
      BackendConnectionQuality.poor ||
      BackendConnectionQuality.unknown =>
        AppColors.expiryAmber,
      BackendConnectionQuality.offline => AppColors.errorRed,
    };

class _MobileTowerPainter extends CustomPainter {
  const _MobileTowerPainter({
    required this.progress,
    required this.quality,
  });

  final double progress;
  final BackendConnectionQuality quality;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final signalColor = _connectionColor(quality);
    final pulse = (math.sin(progress * math.pi * 2) + 1) / 2;

    canvas.drawCircle(
      center,
      78,
      Paint()
        ..color = signalColor.withValues(alpha: 0.05 + pulse * 0.04)
        ..style = PaintingStyle.fill,
    );

    final node = Offset(center.dx, center.dy - 22);
    final stroke = Paint()
      ..color = signalColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (var ring = 0; ring < 3; ring++) {
      final radius = 23.0 + ring * 17;
      final wave = (math.sin(progress * math.pi * 2 - ring * .8) + 1) / 2;
      final strength = switch (quality) {
        BackendConnectionQuality.good => .52 + wave * .36,
        BackendConnectionQuality.poor => ring == 0
            ? .78
            : ring == 1
                ? .18 + wave * .24
                : .08,
        BackendConnectionQuality.unknown => .18 + wave * .48,
        BackendConnectionQuality.offline => .10,
      };
      stroke
        ..strokeWidth = 2.6 - ring * .35
        ..color = signalColor.withValues(alpha: strength);
      final rect = Rect.fromCircle(center: node, radius: radius);
      canvas.drawArc(rect, math.pi * .72, math.pi * .56, false, stroke);
      canvas.drawArc(rect, -math.pi * .28, math.pi * .56, false, stroke);
    }

    final towerPaint = Paint()
      ..color = signalColor.withValues(alpha: .92)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 3;
    canvas.drawCircle(
      node,
      5.5,
      Paint()
        ..color = signalColor
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      Path()
        ..moveTo(node.dx, node.dy + 7)
        ..lineTo(node.dx - 25, node.dy + 69)
        ..moveTo(node.dx, node.dy + 7)
        ..lineTo(node.dx + 25, node.dy + 69)
        ..moveTo(node.dx - 15, node.dy + 45)
        ..lineTo(node.dx + 15, node.dy + 45)
        ..moveTo(node.dx - 24, node.dy + 69)
        ..lineTo(node.dx + 24, node.dy + 69),
      towerPaint,
    );

    if (quality == BackendConnectionQuality.offline) {
      final crossPaint = Paint()
        ..color = signalColor
        ..strokeWidth = 3.4
        ..strokeCap = StrokeCap.round;
      const half = 8.0;
      final crossCenter = Offset(node.dx, node.dy + 28);
      canvas.drawLine(
        crossCenter - const Offset(half, half),
        crossCenter + const Offset(half, half),
        crossPaint,
      );
      canvas.drawLine(
        crossCenter + const Offset(half, -half),
        crossCenter + const Offset(-half, half),
        crossPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MobileTowerPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.quality != quality;
}
