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
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -.55),
            radius: 1.2,
            colors: [
              AppColors.inkTeal.withValues(alpha: .18),
              AppColors.obsidianNight.withValues(alpha: .95),
              AppColors.obsidianNight,
            ],
            stops: const [0, .45, 1],
          ),
        ),
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
            alignment: const Alignment(0, -.10),
            child: Transform.translate(
              offset: Offset(0, drift),
              child: Opacity(
                opacity: reveal,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'السلام عليكم',
                      textDirection: TextDirection.rtl,
                      textAlign: TextAlign.center,
                      style: AppTypography.screenTitle.copyWith(
                        color: AppColors.champagneGold.withValues(alpha: .36),
                        fontSize: 38,
                        fontWeight: FontWeight.w500,
                        letterSpacing: .4,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _GreetingRule(
                          color: AppColors.champagneGold.withValues(alpha: .30),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'Assalamu Alaikum',
                            style: AppTypography.tagline.copyWith(
                              color: AppColors.champagneLight
                                  .withValues(alpha: .56),
                              fontSize: 18,
                              letterSpacing: .5,
                            ),
                          ),
                        ),
                        _GreetingRule(
                          color: AppColors.champagneGold.withValues(alpha: .30),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
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
