import 'package:flutter/material.dart';

import '../../theme/app_dimensions.dart';

/// Restrained content entrance used across onboarding.
///
/// It combines a short 10px lift, a 0.6% scale settle and opacity in one
/// transform. This avoids chains of nested fade/slide controllers and respects
/// the platform's reduced-motion preference.
class SilarahEntrance extends StatelessWidget {
  const SilarahEntrance({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 360),
    this.offset = 10,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final double offset;

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final total = reduceMotion ? Duration.zero : duration + delay;
    final delayRatio = total.inMicroseconds == 0
        ? 0.0
        : delay.inMicroseconds / total.inMicroseconds;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: reduceMotion ? 1 : 0, end: 1),
      duration: total,
      curve: Curves.linear,
      builder: (context, value, child) {
        final local = value <= delayRatio
            ? 0.0
            : ((value - delayRatio) / (1 - delayRatio))
                .clamp(0.0, 1.0)
                .toDouble();
        final eased = Curves.easeOutCubic.transform(local);
        return Opacity(
          opacity: eased,
          child: Transform.translate(
            offset: Offset(0, offset * (1 - eased)),
            child: Transform.scale(
              scale: 0.994 + (0.006 * eased),
              alignment: Alignment.topCenter,
              child: child,
            ),
          ),
        );
      },
      child: child,
    );
  }
}

/// Shared-axis state replacement for onboarding content.
class SilarahContentSwap extends StatelessWidget {
  const SilarahContentSwap({
    super.key,
    required this.child,
    this.alignment = Alignment.topCenter,
  });

  final Widget child;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return AnimatedSwitcher(
      duration: reduceMotion ? Duration.zero : AppDimensions.durationReveal,
      reverseDuration:
          reduceMotion ? Duration.zero : AppDimensions.durationTransition,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (currentChild, previousChildren) => Stack(
        alignment: alignment,
        fit: StackFit.passthrough,
        children: [...previousChildren, if (currentChild != null) currentChild],
      ),
      transitionBuilder: (child, animation) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.025, 0),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
