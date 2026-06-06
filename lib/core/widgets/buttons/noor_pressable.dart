// lib/core/widgets/buttons/noor_pressable.dart
// ============================================================
// Internal base widget for tactile press animation.
// "Button Press: Scale 1.0 → 0.96 → 1.0 with bouncy overshoot.
//  Feels like a physical button. No ripple effect."
// All NOOR buttons wrap this.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/noor_spring.dart';

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

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      value: 1.0,
      lowerBound: -double.infinity,
      upperBound: double.infinity,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails _) {
    if (!widget.enabled) return;
    _controller.animateWithSpring(
      NoorSpring.snappy,
      from: _controller.value,
      to: 0.96,
      velocity: _controller.velocity,
    );
  }

  void _handleTapUp(TapUpDetails _) {
    if (!widget.enabled) return;
    _controller.animateWithSpring(
      NoorSpring.bouncy,
      from: _controller.value,
      to: 1.0,
      velocity: _controller.velocity,
    );
    if (widget.haptic) HapticFeedback.lightImpact();
    widget.onTap?.call();
  }

  void _handleTapCancel() {
    if (!widget.enabled) return;
    _controller.animateWithSpring(
      NoorSpring.bouncy,
      from: _controller.value,
      to: 1.0,
      velocity: _controller.velocity,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:   widget.enabled ? _handleTapDown : null,
      onTapUp:     widget.enabled ? _handleTapUp : null,
      onTapCancel: widget.enabled ? _handleTapCancel : null,
      onLongPress: widget.enabled ? widget.onLongPress : null,
      behavior:    HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => Transform.scale(
          scale: _controller.value,
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}

