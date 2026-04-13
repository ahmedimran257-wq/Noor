// lib/core/widgets/buttons/noor_pressable.dart
// ============================================================
// Internal base widget for tactile press animation.
// "Button Press: Scale 1.0 → 0.97 → 1.0 (100ms).
//  Feels like a physical button. No ripple effect."
// All NOOR buttons wrap this.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_dimensions.dart';
import '../../theme/app_curves.dart';

class NoorPressable extends StatefulWidget {
  const NoorPressable({
    super.key,
    required this.child,
    required this.onTap,
    this.onLongPress,
    this.enabled = true,
    this.haptic = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool enabled;
  final bool haptic;

  @override
  State<NoorPressable> createState() => _NoorPressableState();
}

class _NoorPressableState extends State<NoorPressable>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync:    this,
      duration: AppDimensions.durationButtonPress,
    );
    _scale = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _controller, curve: AppCurves.buttonPress),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleTapDown(TapDownDetails _) async {
    if (!widget.enabled) return;
    await _controller.forward();
  }

  Future<void> _handleTapUp(TapUpDetails _) async {
    await _controller.reverse();
    if (widget.haptic) HapticFeedback.lightImpact();
    widget.onTap?.call();
  }

  Future<void> _handleTapCancel() async {
    await _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:   _handleTapDown,
      onTapUp:     _handleTapUp,
      onTapCancel: _handleTapCancel,
      onLongPress: widget.onLongPress,
      behavior:    HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _scale,
        builder: (context, child) => Transform.scale(
          scale: _scale.value,
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}
