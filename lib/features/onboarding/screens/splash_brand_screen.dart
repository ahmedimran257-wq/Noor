// lib/features/onboarding/screens/splash_brand_screen.dart
// ============================================================
// SILARAH - Splash Brand Screen
// Spec from blueprint:
//   0ms    — Dark background #0A0A0F
//   300ms  — سيلارا fades in, scales 0.8→1.0 (600ms ease-out-cubic)
//   600ms  — 6 light rays emanate from center (staggered 50ms)
//   900ms  — Rays fade out (400ms)
//   1000ms — "SILARAH" wordmark fades in (400ms)
//   1400ms — Tagline "Begin with bismillah" fades in (300ms)
//   2000ms — Buttons slide up from bottom (400ms)
//   2500ms — Everything settled, interactive
// ============================================================

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/buttons/silarah_primary_button.dart';
import '../../../core/widgets/buttons/silarah_secondary_button.dart';
import '../../../core/router/app_router.dart';
import '../../../l10n/generated/app_localizations.dart';

class SplashBrandScreen extends StatefulWidget {
  const SplashBrandScreen({super.key});

  @override
  State<SplashBrandScreen> createState() => _SplashBrandScreenState();
}

class _SplashBrandScreenState extends State<SplashBrandScreen>
    with TickerProviderStateMixin {
  // ── Animation controllers ─────────────────────────────────
  late final AnimationController _silarahCtrl;
  late final AnimationController _raysCtrl;
  late final AnimationController _wordmarkCtrl;
  late final AnimationController _taglineCtrl;
  late final AnimationController _buttonsCtrl;
  bool _sequenceCancelled = false;
  Timer? _sequenceTimer;
  Completer<bool>? _sequenceDelayCompleter;

  // ── Animations ────────────────────────────────────────────
  late final Animation<double> _silarahOpacity;
  late final Animation<double> _silarahScale;
  late final Animation<double> _raysOpacity;
  late final Animation<double> _raysLength;
  late final Animation<double> _wordmarkOpacity;
  late final Animation<double> _taglineOpacity;
  late final Animation<Offset> _buttonsSlide;
  late final Animation<double> _buttonsOpacity;

  @override
  void initState() {
    super.initState();

    // سيلارا letterform — 600ms
    _silarahCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _silarahOpacity =
        CurvedAnimation(parent: _silarahCtrl, curve: Curves.easeOut);
    _silarahScale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _silarahCtrl, curve: Curves.easeOutCubic),
    );

    // Light rays — 800ms total (start fading at 400ms)
    _raysCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _raysOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.8), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 0.8, end: 0.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _raysCtrl, curve: Curves.easeInOut));
    _raysLength = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _raysCtrl, curve: Curves.easeOut),
    );

    // SILARAH wordmark — 400ms
    _wordmarkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _wordmarkOpacity = CurvedAnimation(
      parent: _wordmarkCtrl,
      curve: Curves.easeOut,
    );

    // Tagline — 300ms
    _taglineCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _taglineOpacity = CurvedAnimation(
      parent: _taglineCtrl,
      curve: Curves.easeOut,
    );

    // Buttons — 400ms
    _buttonsCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _buttonsSlide = Tween<Offset>(
      begin: const Offset(0, 0.6),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _buttonsCtrl, curve: Curves.easeOutCubic));
    _buttonsOpacity = CurvedAnimation(
      parent: _buttonsCtrl,
      curve: Curves.easeOut,
    );

    _runSequence();
  }

  Future<void> _runSequence() async {
    Future<bool> wait(Duration delay) async {
      _sequenceTimer?.cancel();
      final completer = Completer<bool>();
      _sequenceDelayCompleter = completer;
      _sequenceTimer = Timer(delay, () {
        if (!completer.isCompleted) {
          completer.complete(mounted && !_sequenceCancelled);
        }
      });
      return completer.future;
    }

    if (!await wait(const Duration(milliseconds: 300))) return;
    _silarahCtrl.forward();
    if (!await wait(const Duration(milliseconds: 300))) return;
    _raysCtrl.forward();
    if (!await wait(const Duration(milliseconds: 400))) return;
    _wordmarkCtrl.forward();
    if (!await wait(const Duration(milliseconds: 400))) return;
    _taglineCtrl.forward();
    if (!await wait(const Duration(milliseconds: 600))) return;
    _buttonsCtrl.forward();
  }

  @override
  void dispose() {
    _sequenceCancelled = true;
    _sequenceTimer?.cancel();
    final completer = _sequenceDelayCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete(false);
    }
    _silarahCtrl.dispose();
    _raysCtrl.dispose();
    _wordmarkCtrl.dispose();
    _taglineCtrl.dispose();
    _buttonsCtrl.dispose();
    super.dispose();
  }

  void _showReferralSheet(BuildContext context) {
    FocusManager.instance.primaryFocus?.unfocus();
    final l10n = AppLocalizations.of(context);
    final codeCtrl = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceMid,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final bottom = MediaQuery.of(context).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: bottom),
          child: Container(
            padding: const EdgeInsets.all(AppDimensions.space24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppDimensions.space8),
                Text(
                  l10n.splash_referral_title,
                  style: AppTypography.screenTitle.copyWith(fontSize: 20),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppDimensions.space12),
                Text(
                  l10n.splash_referral_subtitle,
                  style: AppTypography.bodyMuted,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppDimensions.space24),
                TextField(
                  controller: codeCtrl,
                  onTapOutside: (_) =>
                      FocusManager.instance.primaryFocus?.unfocus(),
                  style: AppTypography.inputText,
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 6,
                  decoration: InputDecoration(
                    hintText: l10n.splash_referral_hint,
                    hintStyle: AppTypography.inputLabel,
                    filled: true,
                    fillColor: AppColors.inputSurface,
                    counterText: '',
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusButton),
                      borderSide: const BorderSide(color: AppColors.cardBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusButton),
                      borderSide: const BorderSide(color: AppColors.cardBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusButton),
                      borderSide: const BorderSide(
                          color: AppColors.champagneGold,
                          width: AppDimensions.borderThin),
                    ),
                  ),
                ),
                const SizedBox(height: AppDimensions.space24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.champagneGold,
                    foregroundColor: AppColors.obsidianNight,
                    minimumSize:
                        const Size(double.infinity, AppDimensions.buttonHeight),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusButton),
                    ),
                  ),
                  onPressed: () async {
                    final code = codeCtrl.text.trim().toUpperCase();
                    if (code.length != 6) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(l10n.splash_referral_invalid),
                          backgroundColor: AppColors.errorRed,
                        ),
                      );
                      return;
                    }

                    // Save to SharedPreferences
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString('pending_referral_code', code);

                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            l10n.splash_referral_saved,
                            style: AppTypography.body,
                          ),
                          backgroundColor: AppColors.surfaceGlassHover,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                                AppDimensions.radiusButton),
                            side: const BorderSide(color: AppColors.cardBorder),
                          ),
                        ),
                      );
                    }
                  },
                  child: Text(l10n.splash_referral_button,
                      style: AppTypography.button),
                ),
                const SizedBox(height: AppDimensions.space12),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.obsidianNight,
      body: Stack(
        children: [
          // ── Radial glow from center ───────────────────────
          Center(
            child: AnimatedBuilder(
              animation: _silarahCtrl,
              builder: (context, _) => Opacity(
                opacity: _silarahCtrl.value * 0.4,
                child: Container(
                  width: 280,
                  height: 280,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Color(0x40C5A059),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Light rays ────────────────────────────────────
          Center(
            child: AnimatedBuilder(
              animation: _raysCtrl,
              builder: (context, _) => CustomPaint(
                size: const Size(280, 280),
                painter: _RaysPainter(
                  opacity: _raysOpacity.value,
                  length: _raysLength.value,
                ),
              ),
            ),
          ),

          // ── Main content ──────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 3),

                // سيلارا Arabic letterform
                AnimatedBuilder(
                  animation: _silarahCtrl,
                  builder: (context, _) => Opacity(
                    opacity: _silarahOpacity.value,
                    child: Transform.scale(
                      scale: _silarahScale.value,
                      child: Text(
                        l10n.localeName == 'ar' ? 'سيلارا' : 'سيلارا',
                        style: TextStyle(
                          fontFamily: 'serif',
                          fontSize: 72,
                          color: AppColors.champagneGold,
                          height: 1.0,
                          shadows: [
                            Shadow(
                              color: AppColors.champagneGold
                                  .withValues(alpha: 0.4),
                              blurRadius: 24,
                            ),
                          ],
                        ),
                        textDirection: TextDirection.rtl,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: AppDimensions.space16),

                // SILARAH wordmark
                FadeTransition(
                  opacity: _wordmarkOpacity,
                  child: Text(l10n.appName, style: AppTypography.wordmark),
                ),

                const SizedBox(height: AppDimensions.space12),

                // Tagline
                FadeTransition(
                  opacity: _taglineOpacity,
                  child: Text(
                    l10n.appTagline,
                    style: AppTypography.tagline,
                  ),
                ),

                const Spacer(flex: 4),

                // Buttons
                SlideTransition(
                  position: _buttonsSlide,
                  child: FadeTransition(
                    opacity: _buttonsOpacity,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.space24,
                      ),
                      child: Column(
                        children: [
                          SilarahPrimaryButton(
                            label: l10n.splash_button_createProfile,
                            onTap: () => context.push(AppRoutes.legal),
                          ),
                          const SizedBox(height: AppDimensions.space12),
                          SilarahSecondaryButton(
                            label: l10n.splash_button_signIn,
                            onTap: () =>
                                context.push('${AppRoutes.email}?mode=signin'),
                          ),
                          const SizedBox(height: AppDimensions.space16),
                          TextButton(
                            onPressed: () => _showReferralSheet(context),
                            child: Text(
                              l10n.splash_referral_question,
                              style: AppTypography.captionMedium.copyWith(
                                color: AppColors.champagneGold,
                                decoration: TextDecoration.underline,
                                decorationColor: AppColors.champagneGold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: AppDimensions.space48),
              ],
            ),
          ),

          // ── Back button (top-left, visible after animations) ──
          SafeArea(
            child: FadeTransition(
              opacity: _buttonsOpacity,
              child: Padding(
                padding: const EdgeInsets.only(left: 12, top: 8),
                child: GestureDetector(
                  onTap: () => context.go(AppRoutes.languageSelect),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceGlass,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: const Icon(
                      Icons.language_rounded,
                      color: AppColors.pearlWhite,
                      size: 20,
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

// ── Light rays painter ────────────────────────────────────────

class _RaysPainter extends CustomPainter {
  const _RaysPainter({required this.opacity, required this.length});
  final double opacity;
  final double length;

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = AppColors.champagneGold.withValues(alpha: opacity * 0.7)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 6; i++) {
      final angle = (i * 60) * (math.pi / 180);
      const startR = 48.0;
      final endR = startR + (80 * length);
      final start = Offset(
        center.dx + startR * math.cos(angle),
        center.dy + startR * math.sin(angle),
      );
      final end = Offset(
        center.dx + endR * math.cos(angle),
        center.dy + endR * math.sin(angle),
      );
      canvas.drawLine(start, end, paint);
    }
  }

  @override
  bool shouldRepaint(_RaysPainter old) =>
      old.opacity != opacity || old.length != length;
}
