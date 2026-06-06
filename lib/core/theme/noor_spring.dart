// lib/core/theme/noor_spring.dart
// ============================================================
// NOOR Design DNA — Spring Physics Core
// "Everything behaves like physical objects with mass and momentum."
// ============================================================

import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

abstract final class NoorSpring {
  /// Standard: mass=1.0, stiffness=500, ratio=0.72 (subtle overshoot — general purpose)
  static const SpringDescription standard = SpringDescription(
    mass: 1.0,
    stiffness: 500.0,
    damping: 32.2,
  );

  /// Snappy: mass=1.0, stiffness=800, ratio=0.65 (button press, tab switch)
  static const SpringDescription snappy = SpringDescription(
    mass: 1.0,
    stiffness: 800.0,
    damping: 36.77,
  );

  /// Gentle: mass=1.0, stiffness=300, ratio=0.85 (bottom sheets, page transitions)
  static const SpringDescription gentle = SpringDescription(
    mass: 1.0,
    stiffness: 300.0,
    damping: 29.44,
  );

  /// Bouncy: mass=1.0, stiffness=400, ratio=0.55 (ceremony, celebrations)
  static const SpringDescription bouncy = SpringDescription(
    mass: 1.0,
    stiffness: 400.0,
    damping: 22.0,
  );
}

extension NoorSpringControllerExtension on AnimationController {
  /// Animates the controller using a spring simulation.
  TickerFuture animateWithSpring(
    SpringDescription spring, {
    double from = 0.0,
    double to = 1.0,
    double velocity = 0.0,
  }) {
    final simulation = SpringSimulation(spring, from, to, velocity);
    return animateWith(simulation);
  }
}

/// A custom Curve that evaluates a SpringSimulation over a given duration.
class SpringCurve extends Curve {
  const SpringCurve({
    this.spring = NoorSpring.standard,
    this.duration = const Duration(milliseconds: 500),
  });

  final SpringDescription spring;
  final Duration duration;

  @override
  double transformInternal(double t) {
    // Normalizes time parameter t (0.0 to 1.0) to duration in seconds
    final simulation = SpringSimulation(
      spring,
      0.0,
      1.0,
      0.0,
    );
    final timeInSeconds = t * duration.inMicroseconds / 1000000.0;
    return simulation.x(timeInSeconds);
  }
}

