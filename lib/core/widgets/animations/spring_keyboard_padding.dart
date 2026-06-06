// lib/core/widgets/animations/spring_keyboard_padding.dart
// ============================================================
// NOOR — Spring Keyboard Padding
// Animates bottom padding to match keyboard height changes using spring physics.
// Replaces default Scaffold resizing for a premium Telegram-like experience.
// ============================================================

import 'package:flutter/widgets.dart';
import '../../theme/noor_spring.dart';

class SpringKeyboardPadding extends StatefulWidget {
  const SpringKeyboardPadding({super.key, required this.child});
  final Widget child;

  @override
  State<SpringKeyboardPadding> createState() => _SpringKeyboardPaddingState();
}

class _SpringKeyboardPaddingState extends State<SpringKeyboardPadding>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  double _targetPadding = 0.0;
  double _currentPadding = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      lowerBound: double.negativeInfinity,
      upperBound: double.infinity,
    );

    _controller.addListener(() {
      if (mounted) {
        setState(() {
          _currentPadding = _controller.value;
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    if (keyboardHeight != _targetPadding) {
      final start = _currentPadding;
      _targetPadding = keyboardHeight;
      _controller.animateWithSpring(
        NoorSpring.gentle,
        from: start,
        to: _targetPadding,
      );
    }

    return Padding(
      padding: EdgeInsets.only(bottom: _currentPadding),
      child: widget.child,
    );
  }
}
