import 'package:flutter/material.dart';

/// The only Flutter-owned launch treatment.
///
/// The native layer stays solid obsidian and hands directly to this text-only
/// wordmark. No launcher artwork is reused here: that separation prevents the
/// icon, opening sequence, and signed-out landing screen from drifting apart.
class SilarahLaunchSequence extends StatefulWidget {
  const SilarahLaunchSequence({
    super.key,
    this.play = true,
    this.onCompleted,
  });

  static const duration = Duration(milliseconds: 2400);
  static const surface = Color(0xFF050507);
  static final ValueNotifier<bool> revealCompleted = ValueNotifier(false);

  /// Root startup keeps this false until the first Flutter-owned frame has
  /// actually replaced the native launch surface.
  final bool play;
  final VoidCallback? onCompleted;

  @override
  State<SilarahLaunchSequence> createState() => _SilarahLaunchSequenceState();
}

class _SilarahLaunchSequenceState extends State<SilarahLaunchSequence>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _wordOpacity;
  late final Animation<double> _wordScale;
  late final Animation<double> _wordTracking;
  late final Animation<double> _wordLift;
  late final Animation<double> _sheenProgress;
  late final Animation<double> _departureOpacity;
  bool _completionDelivered = false;
  bool _motionPreferenceApplied = false;
  bool _disableAnimations = false;
  bool _playbackScheduled = false;

  @override
  void initState() {
    super.initState();
    SilarahLaunchSequence.revealCompleted.value = false;
    _controller = AnimationController(
      vsync: this,
      duration: SilarahLaunchSequence.duration,
    )..addStatusListener(_handleStatus);

    _wordOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(.12, .38, curve: Curves.easeOutCubic),
    );
    _wordScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: .94, end: 1.018)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 64,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.018, end: 1)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 36,
      ),
    ]).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(.10, .62),
      ),
    );
    _wordTracking = Tween<double>(begin: 8.5, end: .6).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(.12, .48, curve: Curves.easeOutQuart),
      ),
    );
    _wordLift = Tween<double>(begin: 12, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(.12, .46, curve: Curves.easeOutCubic),
      ),
    );
    _sheenProgress = Tween<double>(begin: -1.4, end: 1.4).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(.30, .70, curve: Curves.easeInOutCubic),
      ),
    );
    _departureOpacity = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(.82, 1, curve: Curves.easeInCubic),
      ),
    );
  }

  @override
  void didUpdateWidget(covariant SilarahLaunchSequence oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.play && widget.play) _beginPlayback();
  }

  void _beginPlayback() {
    if (!widget.play || !_motionPreferenceApplied || _completionDelivered) {
      return;
    }
    if (_disableAnimations) {
      _controller.value = 1;
      _deliverCompletion();
      return;
    }
    if (_playbackScheduled ||
        _controller.isAnimating ||
        _controller.status == AnimationStatus.completed) {
      return;
    }

    _playbackScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _playbackScheduled = false;
      if (!mounted ||
          !widget.play ||
          _completionDelivered ||
          _controller.isAnimating) {
        return;
      }
      _controller.forward();
    });
  }

  void _handleStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) _deliverCompletion();
  }

  void _deliverCompletion() {
    if (_completionDelivered) return;
    _completionDelivered = true;
    SilarahLaunchSequence.revealCompleted.value = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onCompleted?.call();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_motionPreferenceApplied) return;
    _motionPreferenceApplied = true;
    _disableAnimations = MediaQuery.disableAnimationsOf(context);
    _beginPlayback();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: SilarahLaunchSequence.surface,
      child: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: CustomPaint(
              painter: _ObsidianBloomPainter(_controller),
            ),
          ),
          RepaintBoundary(
            child: CustomPaint(
              painter: _GreetingTracePainter(_controller),
            ),
          ),
          SafeArea(
            child: Center(
              child: FadeTransition(
                opacity: _departureOpacity,
                child: FadeTransition(
                  opacity: _wordOpacity,
                  child: AnimatedBuilder(
                    animation: Listenable.merge([
                      _wordScale,
                      _wordTracking,
                      _wordLift,
                      _sheenProgress,
                    ]),
                    builder: (context, _) => Transform.translate(
                      offset: Offset(0, _wordLift.value),
                      child: Transform.scale(
                        scale: _wordScale.value,
                        child: Semantics(
                          image: true,
                          label: 'Silarah',
                          child: _SilarahWordmark(
                            fontSize: 58,
                            letterSpacing: _wordTracking.value,
                            sheenProgress: _sheenProgress.value,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SilarahWordmark extends StatelessWidget {
  const _SilarahWordmark({
    required this.fontSize,
    required this.letterSpacing,
    this.sheenProgress = 0,
  });

  final double fontSize;
  final double letterSpacing;
  final double sheenProgress;

  @override
  Widget build(BuildContext context) => ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (bounds) => LinearGradient(
          begin: Alignment(sheenProgress - .75, -1),
          end: Alignment(sheenProgress + .75, 1),
          colors: const [
            Color(0xFF9E7938),
            Color(0xFFD8AF55),
            Color(0xFFFFE9AF),
            Color(0xFFD8AF55),
            Color(0xFF9E7938),
          ],
          stops: const [0, .34, .5, .66, 1],
        ).createShader(bounds),
        child: Text(
          'Silarah',
          maxLines: 1,
          style: TextStyle(
            inherit: false,
            color: Colors.white,
            fontFamily: 'PlayfairDisplay',
            fontSize: fontSize,
            height: 1.08,
            fontWeight: FontWeight.w600,
            letterSpacing: letterSpacing,
            decoration: TextDecoration.none,
          ),
        ),
      );
}

class _ObsidianBloomPainter extends CustomPainter {
  _ObsidianBloomPainter(this.progress) : super(repaint: progress);

  final Animation<double> progress;

  @override
  void paint(Canvas canvas, Size size) {
    final entrance = Curves.easeOutCubic.transform(
      (progress.value / .34).clamp(0.0, 1.0),
    );
    final departure = ((progress.value - .82) / .18).clamp(0.0, 1.0);
    final opacity = entrance * (1 - Curves.easeInCubic.transform(departure));
    if (opacity <= .001) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide * (.34 + .035 * entrance);
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFD8AF55).withValues(alpha: .14 * opacity),
          const Color(0xFF6B5128).withValues(alpha: .055 * opacity),
          Colors.transparent,
        ],
        stops: const [0, .48, 1],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _ObsidianBloomPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _GreetingTracePainter extends CustomPainter {
  _GreetingTracePainter(this.progress) : super(repaint: progress);

  final Animation<double> progress;

  @override
  void paint(Canvas canvas, Size size) {
    final raw = progress.value;
    final fadeIn = Curves.easeOutCubic.transform((raw / .14).clamp(0.0, 1.0));
    final fadeOut = Curves.easeInCubic.transform(
      ((raw - .48) / .24).clamp(0.0, 1.0),
    );
    final opacity = fadeIn * (1 - fadeOut);
    if (opacity <= .001) return;

    final center = Offset(size.width / 2, size.height / 2);
    final drift = Curves.easeOutCubic.transform((raw / .72).clamp(0.0, 1.0));
    final entries = [
      _GreetingEntry(
        text: 'السلام عليكم',
        offset: Offset(0, -118 - drift * 12),
        fontSize: 34,
        alpha: .58,
        direction: TextDirection.rtl,
      ),
      _GreetingEntry(
        text: 'Assalamu Alaikum',
        offset: Offset(0, 116 - drift * 9),
        fontSize: 23,
        alpha: .46,
        direction: TextDirection.ltr,
      ),
    ];

    for (final entry in entries) {
      final painter = TextPainter(
        text: TextSpan(
          text: entry.text,
          style: TextStyle(
            inherit: false,
            color: const Color(0xFFE7CA84)
                .withValues(alpha: opacity * entry.alpha),
            fontFamily: 'PlayfairDisplay',
            fontSize: entry.fontSize,
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.w500,
            letterSpacing: .25,
            decoration: TextDecoration.none,
          ),
        ),
        textDirection: entry.direction,
      )..layout();
      painter.paint(
        canvas,
        center + entry.offset - Offset(painter.width / 2, painter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GreetingTracePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _GreetingEntry {
  const _GreetingEntry({
    required this.text,
    required this.offset,
    required this.fontSize,
    required this.alpha,
    required this.direction,
  });

  final String text;
  final Offset offset;
  final double fontSize;
  final double alpha;
  final TextDirection direction;
}

/// Static, text-only lockup used by the signed-out welcome screen.
class SilarahCompactLockup extends StatelessWidget {
  const SilarahCompactLockup({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
        image: true,
        label: 'Silarah',
        child: const _SilarahWordmark(
          fontSize: 43,
          letterSpacing: .4,
        ),
      );
}
