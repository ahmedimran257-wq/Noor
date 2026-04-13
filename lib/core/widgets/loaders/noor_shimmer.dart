// lib/core/widgets/loaders/noor_shimmer.dart
// ============================================================
// NOOR Loading States
// "No spinning wheels. Use Shimmer Effects
//  (Slate Mist → Obsidian Night gradient moving left to right)."
// ============================================================

import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimensions.dart';

// ── Base Shimmer Widget ───────────────────────────────────────

class NoorShimmer extends StatefulWidget {
  const NoorShimmer({
    super.key,
    required this.child,
    this.enabled = true,
  });

  final Widget child;
  final bool enabled;

  @override
  State<NoorShimmer> createState() => _NoorShimmerState();
}

class _NoorShimmerState extends State<NoorShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync:    this,
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
              end:   Alignment.centerRight,
              colors: const [
                AppColors.surfaceGlass,
                AppColors.slateMist,        // The bright sweep point
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
      width:  width,
      height: height,
      decoration: BoxDecoration(
        color:        AppColors.surfaceGlassHover,
        borderRadius: BorderRadius.circular(
          radius ?? AppDimensions.radiusTiny,
        ),
      ),
    );
  }
}

// ── Profile Card Shimmer ──────────────────────────────────────

class NoorProfileCardShimmer extends StatelessWidget {
  const NoorProfileCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return NoorShimmer(
      child: AspectRatio(
        aspectRatio: AppDimensions.cardAspectRatio,
        child: Container(
          decoration: BoxDecoration(
            color:        AppColors.surfaceGlassHover,
            borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
            border: Border.all(
              color: AppColors.cardBorder,
              width: AppDimensions.borderThin,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.space20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Location line
                ShimmerBox(width: 80, height: 12, radius: AppDimensions.radiusTiny),
                const SizedBox(height: AppDimensions.space8),
                // Name line
                ShimmerBox(width: 160, height: 20, radius: AppDimensions.radiusTiny),
                const SizedBox(height: AppDimensions.space12),
                // Two chips
                Row(
                  children: [
                    ShimmerBox(width: 70, height: 28, radius: AppDimensions.radiusChip),
                    const SizedBox(width: AppDimensions.space8),
                    ShimmerBox(width: 90, height: 28, radius: AppDimensions.radiusChip),
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

class NoorConversationShimmer extends StatelessWidget {
  const NoorConversationShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return NoorShimmer(
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppDimensions.horizontalMargin,
          vertical:   AppDimensions.space12,
        ),
        child: Row(
          children: [
            // Avatar
            const ShimmerBox(width: 52, height: 52, radius: 26),
            const SizedBox(width: AppDimensions.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerBox(width: 120, height: 14, radius: AppDimensions.radiusTiny),
                  const SizedBox(height: AppDimensions.space8),
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

class NoorInterestShimmer extends StatelessWidget {
  const NoorInterestShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return NoorShimmer(
      child: Container(
        margin: const EdgeInsetsDirectional.fromSTEB(
          AppDimensions.horizontalMargin,
          0,
          AppDimensions.horizontalMargin,
          AppDimensions.space12,
        ),
        padding: const EdgeInsets.all(AppDimensions.space16),
        decoration: BoxDecoration(
          color:        AppColors.surfaceGlass,
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          children: [
            const ShimmerBox(width: 56, height: 56, radius: AppDimensions.radiusButton),
            const SizedBox(width: AppDimensions.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerBox(width: 140, height: 16, radius: AppDimensions.radiusTiny),
                  const SizedBox(height: AppDimensions.space8),
                  ShimmerBox(width: 100, height: 12, radius: AppDimensions.radiusTiny),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
