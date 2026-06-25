// lib/core/widgets/buttons/mithaq_pressable.dart
// ============================================================
// Internal base widget for tactile press animation.
// "Button Press: Scale 1.0 → 0.96 → 1.0 with bouncy overshoot.
//  Feels like a physical button. No ripple effect."
// All MITHAQ buttons wrap this.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/mithaq_spring.dart';

class MithaqPressable extends StatefulWidget {
  const MithaqPressable({
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
  State<MithaqPressable> createState() => _MithaqPressableState();
}

class _MithaqPressableState extends State<MithaqPressable>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _hovered = false;

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
      MithaqSpring.snappy,
      from: _controller.value,
      to: 0.96,
      velocity: _controller.velocity,
    );
  }

  void _handleTapUp(TapUpDetails _) {
    if (!widget.enabled) return;
    _controller.animateWithSpring(
      MithaqSpring.bouncy,
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
      MithaqSpring.bouncy,
      from: _controller.value,
      to: 1.0,
      velocity: _controller.velocity,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: widget.enabled,
      child: MouseRegion(
        cursor: widget.enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTapDown: widget.enabled ? _handleTapDown : null,
          onTapUp: widget.enabled ? _handleTapUp : null,
          onTapCancel: widget.enabled ? _handleTapCancel : null,
          onLongPress: widget.enabled ? widget.onLongPress : null,
          behavior: HitTestBehavior.opaque,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final lift = _hovered && widget.enabled ? -1.0 : 0.0;
              return AnimatedSlide(
                duration: const Duration(milliseconds: 140),
                curve: Curves.easeOutCubic,
                offset: Offset(0, lift / 56),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 140),
                  opacity: widget.enabled ? 1 : 0.58,
                  child: Transform.scale(
                    scale: _controller.value,
                    child: child,
                  ),
                ),
              );
            },
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
