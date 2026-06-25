// lib/core/theme/app_curves.dart
// ============================================================
// MITHAQ Design DNA — Motion Manifesto
// "No linear animations. Everything must have weight and momentum."
// ============================================================

import 'package:flutter/material.dart';

abstract final class AppCurves {
  /// "The Reveal" — elements entering the screen.
  /// Fast start, soft landing. Used for 300–500ms durations.
  static const Curve reveal = Curves.easeOutCubic;

  /// "The Transition" — state changes (chip color, tab switch).
  /// Used for 200–300ms durations.
  static const Curve transition = Curves.easeInOutQuart;

  /// "The Tactile Pop" — micro-interactions (heart icon, checkmark).
  /// Used for 300–400ms durations.
  static const Curve tactile = Curves.easeOutBack;

  /// Button press scale — snappy feel.
  static const Curve buttonPress = Curves.easeInOut;

  /// Shimmer sweep — linear for smooth shimmer effect.
  static const Curve shimmer = Curves.linear;
}
