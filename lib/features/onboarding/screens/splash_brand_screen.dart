import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/buttons/silarah_primary_button.dart';
import '../../../core/widgets/buttons/silarah_secondary_button.dart';
import '../../../core/widgets/silarah_launch_sequence.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Unauthenticated landing surface. Its top lockup is the exact final frame
/// of [SilarahLaunchSequence], preventing a second logo animation after startup.
class SplashBrandScreen extends StatefulWidget {
  const SplashBrandScreen({super.key});

  @override
  State<SplashBrandScreen> createState() => _SplashBrandScreenState();
}

class _SplashBrandScreenState extends State<SplashBrandScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _orchestrator;
  late final Animation<double> _lockupOpacity;
  late final Animation<Offset> _lockupSlide;
  late final Animation<double> _taglineOpacity;
  late final Animation<Offset> _taglineSlide;
  late final Animation<double> _primaryOpacity;
  late final Animation<Offset> _primarySlide;
  late final Animation<double> _secondaryOpacity;
  late final Animation<Offset> _secondarySlide;
  late final Animation<double> _tertiaryOpacity;
  bool _motionPreferenceApplied = false;
  bool _orchestrationStarted = false;

  @override
  void initState() {
    super.initState();
    _orchestrator = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _lockupOpacity = CurvedAnimation(
      parent: _orchestrator,
      curve: const Interval(0, .25, curve: Curves.easeOutCubic),
    );
    _lockupSlide = Tween<Offset>(
      begin: const Offset(0, .06),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _orchestrator,
        curve: const Interval(0, .30, curve: Curves.easeOutCubic),
      ),
    );
    _taglineOpacity = CurvedAnimation(
      parent: _orchestrator,
      curve: const Interval(.15, .40, curve: Curves.easeOutCubic),
    );
    _taglineSlide = Tween<Offset>(
      begin: const Offset(0, .08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _orchestrator,
        curve: const Interval(.15, .42, curve: Curves.easeOutCubic),
      ),
    );
    _primaryOpacity = CurvedAnimation(
      parent: _orchestrator,
      curve: const Interval(.35, .60, curve: Curves.easeOutCubic),
    );
    _primarySlide = Tween<Offset>(
      begin: const Offset(0, .12),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _orchestrator,
        curve: const Interval(.35, .65, curve: Curves.easeOutCubic),
      ),
    );
    _secondaryOpacity = CurvedAnimation(
      parent: _orchestrator,
      curve: const Interval(.45, .70, curve: Curves.easeOutCubic),
    );
    _secondarySlide = Tween<Offset>(
      begin: const Offset(0, .12),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _orchestrator,
        curve: const Interval(.45, .75, curve: Curves.easeOutCubic),
      ),
    );
    _tertiaryOpacity = CurvedAnimation(
      parent: _orchestrator,
      curve: const Interval(.60, .85, curve: Curves.easeOutCubic),
    );
    SilarahLaunchSequence.revealCompleted.addListener(_handleLaunchReveal);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_motionPreferenceApplied) return;
    _motionPreferenceApplied = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _orchestrationStarted = true;
      _orchestrator.value = 1;
    } else {
      _handleLaunchReveal();
    }
  }

  void _handleLaunchReveal() {
    if (!mounted ||
        !_motionPreferenceApplied ||
        _orchestrationStarted ||
        !SilarahLaunchSequence.revealCompleted.value) {
      return;
    }
    _orchestrationStarted = true;
    _orchestrator.forward();
  }

  @override
  void dispose() {
    SilarahLaunchSequence.revealCompleted.removeListener(_handleLaunchReveal);
    _orchestrator.dispose();
    super.dispose();
  }

  void _lightTap(VoidCallback action) {
    HapticFeedback.lightImpact();
    action();
  }

  void _showReferralSheet(BuildContext context) {
    FocusManager.instance.primaryFocus?.unfocus();
    final l10n = AppLocalizations.of(context);
    final codeController = TextEditingController();

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceMid,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final bottom = MediaQuery.viewInsetsOf(sheetContext).bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: bottom),
          child: Padding(
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
                  controller: codeController,
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
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusButton,
                      ),
                      borderSide: BorderSide(color: AppColors.cardBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusButton,
                      ),
                      borderSide: BorderSide(color: AppColors.cardBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusButton,
                      ),
                      borderSide: BorderSide(
                        color: AppColors.champagneGold,
                        width: AppDimensions.borderThin,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppDimensions.space24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.champagneGold,
                    foregroundColor: AppColors.obsidianNight,
                    minimumSize: const Size(
                      double.infinity,
                      AppDimensions.buttonHeight,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusButton,
                      ),
                    ),
                  ),
                  onPressed: () async {
                    final code = codeController.text.trim().toUpperCase();
                    if (code.length != 6) {
                      ScaffoldMessenger.of(sheetContext).showSnackBar(
                        SnackBar(
                          content: Text(l10n.splash_referral_invalid),
                          backgroundColor: AppColors.errorRed,
                        ),
                      );
                      return;
                    }
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString('pending_referral_code', code);
                    if (!sheetContext.mounted) return;
                    Navigator.pop(sheetContext);
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
                            AppDimensions.radiusButton,
                          ),
                          side: BorderSide(color: AppColors.cardBorder),
                        ),
                      ),
                    );
                  },
                  child: Text(
                    l10n.splash_referral_button,
                    style: AppTypography.button,
                  ),
                ),
                const SizedBox(height: AppDimensions.space12),
              ],
            ),
          ),
        );
      },
    ).whenComplete(codeController.dispose);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.obsidianNight,
      body: _ObsidianWelcomeCanvas(
        child: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: _WelcomeGreetingBackdrop(
                    animation: _orchestrator,
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 14),
                  FadeTransition(
                    opacity: _lockupOpacity,
                    child: SlideTransition(
                      position: _lockupSlide,
                      child: const Center(child: SilarahCompactLockup()),
                    ),
                  ),
                  FadeTransition(
                    opacity: _taglineOpacity,
                    child: SlideTransition(
                      position: _taglineSlide,
                      child: Text(
                        l10n.appTagline,
                        textAlign: TextAlign.center,
                        style: AppTypography.tagline,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.space24,
                    ),
                    child: Column(
                      children: [
                        FadeTransition(
                          opacity: _primaryOpacity,
                          child: SlideTransition(
                            position: _primarySlide,
                            child: SilarahPrimaryButton(
                              label: l10n.splash_button_createProfile,
                              haptic: false,
                              onTap: () => _lightTap(
                                () => context.push(AppRoutes.legal),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppDimensions.space12),
                        FadeTransition(
                          opacity: _secondaryOpacity,
                          child: SlideTransition(
                            position: _secondarySlide,
                            child: SilarahSecondaryButton(
                              label: l10n.splash_button_signIn,
                              haptic: false,
                              onTap: () => _lightTap(
                                () => context.push(
                                  '${AppRoutes.email}?mode=signin',
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppDimensions.space16),
                        FadeTransition(
                          opacity: _tertiaryOpacity,
                          child: TextButton(
                            onPressed: () => _lightTap(
                              () => _showReferralSheet(context),
                            ),
                            child: Text(
                              l10n.splash_referral_question,
                              style: AppTypography.captionMedium.copyWith(
                                color: AppColors.champagneGold,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppDimensions.space48),
                ],
              ),
              PositionedDirectional(
                start: 12,
                top: 8,
                child: FadeTransition(
                  opacity: _tertiaryOpacity,
                  child: Semantics(
                    button: true,
                    label: 'Change language',
                    child: InkResponse(
                      onTap: () => _lightTap(
                        () => context.go(AppRoutes.languageSelect),
                      ),
                      radius: 28,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceGlass,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.cardBorder),
                        ),
                        child: Icon(
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
        ),
      ),
    );
  }
}

class _WelcomeGreetingBackdrop extends StatelessWidget {
  const _WelcomeGreetingBackdrop({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final reveal = Curves.easeOutCubic.transform(
            ((animation.value - .12) / .46).clamp(0.0, 1.0),
          );
          final drift = 10 * (1 - reveal);
          return Align(
            alignment: const Alignment(0, -.08),
            child: Transform.translate(
              offset: Offset(0, drift),
              child: Opacity(
                opacity: reveal,
                child: RepaintBoundary(
                  child: SizedBox(
                    width: 340,
                    height: 236,
                    child: CustomPaint(
                      painter: _WelcomeFiligreePainter(),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _GreetingRule(
                                color: AppColors.champagneGold
                                    .withValues(alpha: .28),
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 10),
                                child: Transform.rotate(
                                  angle: .785,
                                  child: Container(
                                    width: 5,
                                    height: 5,
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: AppColors.champagneGold
                                            .withValues(alpha: .78),
                                        width: .8,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              _GreetingRule(
                                color: AppColors.champagneGold
                                    .withValues(alpha: .28),
                              ),
                            ],
                          ),
                          const SizedBox(height: 22),
                          SizedBox(
                            width: 292,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: ShaderMask(
                                blendMode: BlendMode.srcIn,
                                shaderCallback: (bounds) => LinearGradient(
                                  colors: [
                                    AppColors.antiqueGold,
                                    AppColors.champagneLight,
                                    AppColors.champagneGold,
                                  ],
                                ).createShader(bounds),
                                child: Text(
                                  'السلام عليكم',
                                  textDirection: TextDirection.rtl,
                                  textAlign: TextAlign.center,
                                  style: AppTypography.screenTitle.copyWith(
                                    color: Colors.white,
                                    fontSize: 43,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: .2,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 13),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _GreetingRule(
                                color: AppColors.champagneGold
                                    .withValues(alpha: .46),
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 14),
                                child: SizedBox(
                                  width: 190,
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      'Assalamu Alaikum',
                                      style: AppTypography.tagline.copyWith(
                                        color: AppColors.champagneLight
                                            .withValues(alpha: .88),
                                        fontSize: 17,
                                        letterSpacing: .45,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              _GreetingRule(
                                color: AppColors.champagneGold
                                    .withValues(alpha: .46),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
}

class _ObsidianWelcomeCanvas extends StatelessWidget {
  const _ObsidianWelcomeCanvas({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.obsidianNight,
              AppColors.midnightPlum.withValues(alpha: .34),
              AppColors.obsidianNight,
            ],
            stops: const [0, .44, 1],
          ),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -.18),
              radius: .78,
              colors: [
                AppColors.champagneGold.withValues(alpha: .075),
                AppColors.antiqueGold.withValues(alpha: .025),
                Colors.transparent,
              ],
              stops: const [0, .48, 1],
            ),
          ),
          child: child,
        ),
      );
}

class _WelcomeFiligreePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 + 3);
    final gold = AppColors.champagneGold;
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .8
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          gold.withValues(alpha: .20),
          gold.withValues(alpha: .20),
          Colors.transparent,
        ],
        stops: const [0, .28, .72, 1],
      ).createShader(Offset.zero & size);

    canvas.drawArc(
      Rect.fromCenter(center: center, width: 304, height: 178),
      3.46,
      2.50,
      false,
      arcPaint,
    );
    canvas.drawArc(
      Rect.fromCenter(center: center, width: 304, height: 178),
      .32,
      2.50,
      false,
      arcPaint,
    );

    final pointPaint = Paint()..color = gold.withValues(alpha: .58);
    canvas.drawCircle(Offset(center.dx, 18), 1.8, pointPaint);
    canvas.drawCircle(Offset(center.dx, size.height - 18), 1.8, pointPaint);
  }

  @override
  bool shouldRepaint(covariant _WelcomeFiligreePainter oldDelegate) => false;
}

class _GreetingRule extends StatelessWidget {
  const _GreetingRule({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: 34,
        height: 1,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(1),
        ),
      );
}
