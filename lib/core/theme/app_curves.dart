// SILARAH motion language.
//
// These curves deliberately avoid stock bounce/back easing. Motion should
// clarify hierarchy and state change without calling attention to itself.
import 'package:flutter/material.dart';

abstract final class AppCurves {
  /// Decisive entrance with a long, controlled settle.
  static const Curve reveal = Cubic(0.16, 1.0, 0.3, 1.0);

  /// Balanced state change for selection, layout and colour transitions.
  static const Curve transition = Cubic(0.65, 0.0, 0.35, 1.0);

  /// Restrained emphasis for confirmations and small state changes.
  static const Curve tactile = Cubic(0.2, 0.8, 0.2, 1.0);

  /// Immediate compression without a rebound or novelty overshoot.
  static const Curve buttonPress = Cubic(0.2, 0.0, 0.0, 1.0);

  /// Clean acceleration used when content leaves the interface.
  static const Curve dismiss = Cubic(0.4, 0.0, 1.0, 1.0);

  /// Quiet periodic motion for loaders and ambient placeholders.
  static const Curve breathe = Cubic(0.37, 0.0, 0.63, 1.0);

  /// A travelling highlight must remain velocity-stable.
  static const Curve shimmer = Curves.linear;
}
