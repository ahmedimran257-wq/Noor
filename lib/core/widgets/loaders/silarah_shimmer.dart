// SILARAH Loading States
// "No spinning wheels. Use Shimmer Effects
//  (Slate Mist → Obsidian Night gradient moving left to right)."
import 'package:silarah/l10n/ui_copy.dart';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimensions.dart';
import '../../theme/app_typography.dart';

class SilarahPulseLoader extends StatefulWidget {
  const SilarahPulseLoader({
    super.key,
    this.label,
    this.size = 54,
    this.accentColor,
    this.highlightColor,
    this.markColor,
    this.coreGradientColors,
  });

  final String? label;
  final double size;
  final Color? accentColor;
  final Color? highlightColor;
  final Color? markColor;
  final List<Color>? coreGradientColors;

  @override
  State<SilarahPulseLoader> createState() => _SilarahPulseLoaderState();
}

class _SilarahPulseLoaderState extends State<SilarahPulseLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = widget.accentColor ?? AppColors.champagneGold;
    final highlightColor = widget.highlightColor ?? AppColors.champagneLight;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: widget.size,
          height: widget.size,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final t = _controller.value;
              final pulse = Curves.easeInOutCubic.transform(
                t < 0.5 ? t * 2 : (1 - t) * 2,
              );
              return Stack(
                alignment: Alignment.center,
                children: [
                  Transform.scale(
                    scale: 0.92 + pulse * 0.36,
                    child: Opacity(
                      opacity: 0.30 - pulse * 0.18,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: accentColor,
                        ),
                      ),
                    ),
                  ),
                  Transform.rotate(
                    angle: t * 6.283185307179586,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: accentColor.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: Container(
                          width: widget.size * 0.12,
                          height: widget.size * 0.12,
                          margin: EdgeInsets.only(top: widget.size * 0.08),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: highlightColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Container(
                    width: widget.size * 0.56,
                    height: widget.size * 0.56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: widget.coreGradientColors ??
                            [
                              AppColors.champagneLight,
                              AppColors.champagneGold,
                              AppColors.antiqueGold,
                            ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accentColor.withValues(alpha: 0.18),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/icon/app_icon.png',
                        width: widget.size * 0.52,
                        height: widget.size * 0.52,
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.medium,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        if (widget.label != null) ...[
          const SizedBox(height: AppDimensions.space12),
          UiText(
            widget.label!,
            style: AppTypography.caption.copyWith(
              color: AppColors.slateMist,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

// Base Shimmer Widget
class SilarahShimmer extends StatefulWidget {
  const SilarahShimmer({
    super.key,
    required this.child,
    this.enabled = true,
  });

  final Widget child;
  final bool enabled;

  @override
  State<SilarahShimmer> createState() => _SilarahShimmerState();
}

class _SilarahShimmerState extends State<SilarahShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppDimensions.durationShimmer,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            // Shimmer sweep: moves from -1.0 to 2.0 (ensures full coverage)
            final t = _controller.value * 3 - 1;
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                AppColors.surfaceGlass,
                AppColors.slateMist, // The bright sweep point
                AppColors.surfaceGlassHover,
                AppColors.surfaceGlass,
              ],
              stops: [
                (t - 0.3).clamp(0.0, 1.0),
                t.clamp(0.0, 1.0),
                (t + 0.1).clamp(0.0, 1.0),
                (t + 0.3).clamp(0.0, 1.0),
              ],
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

// Shimmer Box (building block)
class ShimmerBox extends StatelessWidget {
  const ShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.radius,
  });

  final double width;
  final double height;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceGlassHover,
        borderRadius: BorderRadius.circular(
          radius ?? AppDimensions.radiusTiny,
        ),
      ),
    );
  }
}

// Profile Card Shimmer
/// A restrained discovery placeholder.
///
/// Profile cards occupy most of the viewport, so the generic full-surface
/// shimmer becomes a high-contrast vertical band on tall phones. This loader
/// keeps the card geometry stable and animates only a quiet focal mark and
/// small information placeholders.
class SilarahProfileCardShimmer extends StatefulWidget {
  const SilarahProfileCardShimmer({super.key});

  @override
  State<SilarahProfileCardShimmer> createState() =>
      _SilarahProfileCardShimmerState();
}

class _SilarahProfileCardShimmerState extends State<SilarahProfileCardShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
      value: .34,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion == reduceMotion &&
        (_controller.isAnimating || reduceMotion)) {
      return;
    }
    _reduceMotion = reduceMotion;
    if (reduceMotion) {
      _controller
        ..stop()
        ..value = .5;
    } else {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Preparing profile recommendations',
      liveRegion: true,
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final pulse = _reduceMotion
                ? .5
                : Curves.easeInOutCubic.transform(_controller.value);
            final tonalSurface = Color.lerp(
              AppColors.surfaceDark,
              AppColors.surfaceGlassHover,
              .16 + pulse * .12,
            )!;

            return AspectRatio(
              aspectRatio: AppDimensions.cardAspectRatio,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.surfaceMid,
                        tonalSurface,
                        AppColors.surfaceDark,
                      ],
                      stops: const [0, .58, 1],
                    ),
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusCard),
                    border: Border.all(
                      color: AppColors.cardBorder,
                      width: AppDimensions.borderThin,
                    ),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Positioned(
                        top: -64,
                        right: -58,
                        child: Container(
                          width: 210,
                          height: 210,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.champagneGold.withValues(
                              alpha: .025 + pulse * .018,
                            ),
                          ),
                        ),
                      ),
                      Center(
                        child: Transform.scale(
                          scale: .96 + pulse * .05,
                          child: Container(
                            width: 40,
                            height: 40,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.surfaceElevated
                                  .withValues(alpha: .88),
                              border: Border.all(
                                color: AppColors.cardBorder,
                              ),
                            ),
                            child: Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.champagneGold.withValues(
                                  alpha: .56 + pulse * .34,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.champagneGold.withValues(
                                      alpha: .08 + pulse * .09,
                                    ),
                                    blurRadius: 12,
                                    spreadRadius: 3,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: AppDimensions.space16,
                        right: AppDimensions.space16,
                        bottom: AppDimensions.space16,
                        child: Container(
                          padding: const EdgeInsets.all(AppDimensions.space16),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceElevated
                                .withValues(alpha: .90),
                            borderRadius: BorderRadius.circular(
                              AppDimensions.radiusButton,
                            ),
                            border: Border.all(color: AppColors.cardBorder),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _ProfileLoaderLine(
                                widthFactor: .28,
                                height: 9,
                                opacity: .34 + pulse * .08,
                              ),
                              const SizedBox(height: AppDimensions.space10),
                              _ProfileLoaderLine(
                                widthFactor: .58,
                                height: 16,
                                opacity: .46 + pulse * .08,
                              ),
                              const SizedBox(height: AppDimensions.space14),
                              Row(
                                children: [
                                  _ProfileLoaderPill(
                                    width: 68,
                                    opacity: .32 + pulse * .07,
                                  ),
                                  const SizedBox(width: AppDimensions.space8),
                                  _ProfileLoaderPill(
                                    width: 88,
                                    opacity: .28 + pulse * .07,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ProfileLoaderLine extends StatelessWidget {
  const _ProfileLoaderLine({
    required this.widthFactor,
    required this.height,
    required this.opacity,
  });

  final double widthFactor;
  final double height;
  final double opacity;

  @override
  Widget build(BuildContext context) => FractionallySizedBox(
        widthFactor: widthFactor,
        alignment: AlignmentDirectional.centerStart,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: AppColors.slateMist.withValues(alpha: opacity),
            borderRadius: BorderRadius.circular(99),
          ),
        ),
      );
}

class _ProfileLoaderPill extends StatelessWidget {
  const _ProfileLoaderPill({
    required this.width,
    required this.opacity,
  });

  final double width;
  final double opacity;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: 26,
        decoration: BoxDecoration(
          color: AppColors.slateMist.withValues(alpha: opacity),
          borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
        ),
      );
}

// Conversation List Item Shimmer
class SilarahConversationShimmer extends StatelessWidget {
  const SilarahConversationShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return const SilarahShimmer(
      child: Padding(
        padding: EdgeInsetsDirectional.symmetric(
          horizontal: AppDimensions.horizontalMargin,
          vertical: AppDimensions.space12,
        ),
        child: Row(
          children: [
            // Avatar
            ShimmerBox(width: 52, height: 52, radius: 26),
            SizedBox(width: AppDimensions.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerBox(
                      width: 120, height: 14, radius: AppDimensions.radiusTiny),
                  SizedBox(height: AppDimensions.space8),
                  ShimmerBox(
                    width: double.infinity,
                    height: 12,
                    radius: AppDimensions.radiusTiny,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Interest Card Shimmer
class SilarahInterestShimmer extends StatelessWidget {
  const SilarahInterestShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return SilarahShimmer(
      child: Container(
        margin: const EdgeInsetsDirectional.fromSTEB(
          AppDimensions.horizontalMargin,
          0,
          AppDimensions.horizontalMargin,
          AppDimensions.space12,
        ),
        padding: const EdgeInsets.all(AppDimensions.space16),
        decoration: BoxDecoration(
          color: AppColors.surfaceGlass,
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: const Row(
          children: [
            ShimmerBox(
                width: 56, height: 56, radius: AppDimensions.radiusButton),
            SizedBox(width: AppDimensions.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerBox(
                      width: 140, height: 16, radius: AppDimensions.radiusTiny),
                  SizedBox(height: AppDimensions.space8),
                  ShimmerBox(
                      width: 100, height: 12, radius: AppDimensions.radiusTiny),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
