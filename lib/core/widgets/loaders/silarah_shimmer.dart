// lib/core/widgets/loaders/silarah_shimmer.dart
// ============================================================
// SILARAH Loading States
// "No spinning wheels. Use Shimmer Effects
//  (Slate Mist → Obsidian Night gradient moving left to right)."
// ============================================================

import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimensions.dart';
import '../../theme/app_typography.dart';

class SilarahPulseLoader extends StatefulWidget {
  const SilarahPulseLoader({
    super.key,
    this.label,
    this.size = 54,
    this.accentColor = AppColors.champagneGold,
    this.highlightColor = AppColors.champagneLight,
    this.markColor = AppColors.obsidianNight,
    this.coreGradientColors,
  });

  final String? label;
  final double size;
  final Color accentColor;
  final Color highlightColor;
  final Color markColor;
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
                          color: widget.accentColor,
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
                          color: widget.accentColor.withValues(alpha: 0.2),
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
                            color: widget.highlightColor,
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
                            const [
                              AppColors.champagneLight,
                              AppColors.champagneGold,
                              AppColors.antiqueGold,
                            ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: widget.accentColor.withValues(alpha: 0.18),
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
          Text(
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

// ── Base Shimmer Widget ───────────────────────────────────────

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
              colors: const [
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

// ── Shimmer Box (building block) ─────────────────────────────

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

// ── Profile Card Shimmer ──────────────────────────────────────

class SilarahProfileCardShimmer extends StatelessWidget {
  const SilarahProfileCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return SilarahShimmer(
      child: AspectRatio(
        aspectRatio: AppDimensions.cardAspectRatio,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceGlassHover,
            borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
            border: Border.all(
              color: AppColors.cardBorder,
              width: AppDimensions.borderThin,
            ),
          ),
          child: const Padding(
            padding: EdgeInsets.all(AppDimensions.space20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Location line
                ShimmerBox(
                    width: 80, height: 12, radius: AppDimensions.radiusTiny),
                SizedBox(height: AppDimensions.space8),
                // Name line
                ShimmerBox(
                    width: 160, height: 20, radius: AppDimensions.radiusTiny),
                SizedBox(height: AppDimensions.space12),
                // Two chips
                Row(
                  children: [
                    ShimmerBox(
                        width: 70,
                        height: 28,
                        radius: AppDimensions.radiusChip),
                    SizedBox(width: AppDimensions.space8),
                    ShimmerBox(
                        width: 90,
                        height: 28,
                        radius: AppDimensions.radiusChip),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Conversation List Item Shimmer ────────────────────────────

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

// ── Interest Card Shimmer ─────────────────────────────────────

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
