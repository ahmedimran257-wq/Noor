// SILARAH — Subscription Screen (RevenueCat Dynamic Pricing)
//
//   "The price in local currency."
//
// Pricing is fetched exclusively from RevenueCat Offerings.
// No hardcoded fallback — shows error state if unavailable.
// Dynamic "Best value — save X%" on annual card.
import 'package:silarah/l10n/ui_copy.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../core/data/country_data.dart';
import '../../../core/services/phone_verification_service.dart';
import '../../../core/services/billing_portal_service.dart';
import '../../../core/services/subscription_service.dart';
import '../../../core/services/launch_configuration_service.dart';
import '../../../core/cubits/auth/auth_cubit.dart';
import '../../../core/cubits/auth/auth_state.dart';
import '../../../core/cubits/subscription/subscription_cubit.dart';
import '../../../core/cubits/subscription/subscription_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/inputs/silarah_field_frame.dart';
import '../../../core/widgets/loaders/silarah_shimmer.dart';
import 'legal_doc_screen.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen>
    with SingleTickerProviderStateMixin {
  // 'monthly' or 'annual'
  String _selectedPlan = 'monthly';

  late final AnimationController _headerAnim;
  late final Animation<double> _headerFade;
  late final Animation<Offset> _headerSlide;

  // Pricing (loaded from RevenueCat via SubscriptionService)
  DisplayPricing _pricing = DisplayPricing.loading();
  StreamSubscription<DisplayPricing>? _pricingSub;
  Timer? _countdownTimer;
  bool _purchaseFlowInProgress = false;

  @override
  void initState() {
    super.initState();
    _headerAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _headerFade = CurvedAnimation(parent: _headerAnim, curve: Curves.easeOut);
    _headerSlide = Tween<Offset>(
      begin: const Offset(0, 0.18),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _headerAnim, curve: Curves.easeOutCubic));
    _headerAnim.forward();
    _loadPricing();
    _countdownTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;
      final subscription = context.read<SubscriptionCubit>().state;
      final expiry = subscription.expiresAt;
      if (subscription.isTemporaryPromotional &&
          expiry != null &&
          !expiry.isAfter(DateTime.now())) {
        unawaited(
          context.read<SubscriptionCubit>().refreshEntitlement(),
        );
        return;
      }
      if (subscription.isTemporaryPromotional) setState(() {});
    });
  }

  Future<void> _loadPricing() async {
    // Get pricing from RevenueCat via SubscriptionService
    final service = SubscriptionService.instance;
    final pricing = service.currentPricing;

    if (pricing != null && mounted) {
      setState(() => _pricing = pricing);
    }

    // Listen for pricing updates (e.g., retry succeeds)
    _pricingSub = service.pricingStream.listen((updated) {
      if (mounted) setState(() => _pricing = updated);
    });
  }

  Future<void> _retryPricing() async {
    setState(() => _pricing = DisplayPricing.loading());
    await SubscriptionService.instance.retryPricing();
  }

  @override
  void dispose() {
    _pricingSub?.cancel();
    _countdownTimer?.cancel();
    _headerAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthCubit>().state;
    final gender =
        authState is AuthAuthenticated ? (authState.gender ?? 'male') : 'male';
    final isFemale = gender == 'female';

    final double screenHeight = MediaQuery.of(context).size.height;
    final bool isSmallScreen = screenHeight < 750;

    final double spaceLarge = isSmallScreen ? 16 : 36;
    final double spaceMedium = isSmallScreen ? 12 : 28;
    final double spaceSmall = isSmallScreen ? 10 : 20;

    return BlocConsumer<SubscriptionCubit, SubscriptionState>(
      listener: (context, state) {
        if (state.successMessage != null) {
          _showSuccess(context, state.successMessage!);
          context.read<SubscriptionCubit>().clearMessages();
        }
        if (state.error != null) {
          _showError(context, state.error!);
          context.read<SubscriptionCubit>().clearMessages();
        }
      },
      builder: (context, state) {
        if (state.hasPaidPremium) {
          return _safeBackShell(
            context,
            Scaffold(
              backgroundColor: AppColors.obsidianNight,
              appBar: _appBar(),
              body: _PaidPremiumActiveView(
                isFemale: isFemale,
                onBackToProfile: _closeScreen,
              ),
            ),
          );
        }
        if (state.isReferralOnly) {
          return _safeBackShell(
            context,
            Scaffold(
              backgroundColor: AppColors.obsidianNight,
              appBar: _appBar(),
              body: _ReferralPremiumActiveView(
                expiresAt: state.expiresAt,
                isFemale: isFemale,
                onBackToProfile: _closeScreen,
              ),
            ),
          );
        }
        if (state.isTestOnly) {
          return _safeBackShell(
            context,
            Scaffold(
              backgroundColor: AppColors.obsidianNight,
              appBar: _appBar(),
              body: _ReferralPremiumActiveView(
                expiresAt: state.expiresAt,
                isFemale: isFemale,
                isTest: true,
                onBackToProfile: _closeScreen,
              ),
            ),
          );
        }

        return _safeBackShell(
          context,
          Scaffold(
            backgroundColor: AppColors.obsidianNight,
            appBar: _appBar(),
            body: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(20, 0, 20, isSmallScreen ? 20 : 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  SlideTransition(
                    position: _headerSlide,
                    child: FadeTransition(
                      opacity: _headerFade,
                      child: _Header(
                          isFemale: isFemale, isSmallScreen: isSmallScreen),
                    ),
                  ),

                  SizedBox(height: spaceLarge),

                  // Plan Cards
                  if (_pricing.source == PricingSource.loading)
                    _PricingStatusCard(
                      isLoading: true,
                      isSmallScreen: isSmallScreen,
                      onRetry: _retryPricing,
                    )
                  else if (!_pricing.isAvailable)
                    _PricingStatusCard(
                      isLoading: false,
                      isSmallScreen: isSmallScreen,
                      onRetry: _retryPricing,
                    )
                  else
                    _PlanCards(
                      pricing: _pricing,
                      selectedPlan: _selectedPlan,
                      onSelect: (plan) => setState(() => _selectedPlan = plan),
                      isSmallScreen: isSmallScreen,
                    ),

                  SizedBox(height: spaceMedium),

                  // What's included
                  _IncludedFeatures(
                      isFemale: isFemale, isSmallScreen: isSmallScreen),

                  SizedBox(height: spaceLarge),

                  // CTA Button
                  if (_pricing.isAvailable)
                    _CtaButton(
                      selectedPlan: _selectedPlan,
                      pricing: _pricing,
                      isLoading: state.isLoading || _purchaseFlowInProgress,
                      isSmallScreen: isSmallScreen,
                      onTap: _startPurchase,
                    ),

                  SizedBox(height: spaceSmall),

                  // Secondary links
                  _SecondaryLinks(
                    isLoading: state.isLoading,
                    isSmallScreen: isSmallScreen,
                    onRestore: () =>
                        context.read<SubscriptionCubit>().restore(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  PreferredSizeWidget _appBar() => AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: _closeScreen,
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.pearlWhite,
            size: 20,
          ),
        ),
      );

  Widget _safeBackShell(BuildContext context, Widget child) {
    return PopScope(
      canPop: Navigator.of(context).canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && context.mounted) context.go('/home?tab=3');
      },
      child: child,
    );
  }

  void _closeScreen() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go('/home?tab=3');
    }
  }

  Future<void> _startPurchase() async {
    if (_purchaseFlowInProgress) return;
    final pricingReady = _pricing.isAvailable;
    if (!pricingReady) {
      _showError(context, 'Plans are not available right now.');
      return;
    }

    setState(() => _purchaseFlowInProgress = true);
    try {
      final status = await PhoneVerificationService.instance.currentStatus();
      if (!mounted) return;
      final entitlement = context.read<SubscriptionCubit>().state;
      if (entitlement.hasPaidPremium) {
        if (!status.isVerified) {
          final authState = context.read<AuthCubit>().state;
          final countryCode =
              authState is AuthAuthenticated ? authState.countryCode : null;
          await showPhoneVerificationSheet(
            context,
            countryCode: countryCode,
          );
        } else {
          _closeScreen();
        }
        return;
      }
      if (!status.isVerified) {
        final authState = context.read<AuthCubit>().state;
        final countryCode =
            authState is AuthAuthenticated ? authState.countryCode : null;
        final verified = await showPhoneVerificationSheet(
          context,
          countryCode: countryCode,
          isBeforePurchase: true,
        );
        if (!mounted || verified != true) return;
      }

      final planId = _selectedPlan == 'annual'
          ? SubscriptionCubit.annualProductId
          : SubscriptionCubit.monthlyProductId;
      await context.read<SubscriptionCubit>().purchase(planId);
    } finally {
      if (mounted) setState(() => _purchaseFlowInProgress = false);
    }
  }

  void _showSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: UiText(
          message,
          style: AppTypography.body.copyWith(
            color: AppColors.readableOn(AppColors.verifiedTeal),
          ),
        ),
        backgroundColor: AppColors.verifiedTeal,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: UiText(
          message,
          style: AppTypography.body.copyWith(
            color: AppColors.readableOn(AppColors.softCoral),
          ),
        ),
        backgroundColor: AppColors.softCoral,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _PaidPremiumActiveView extends StatelessWidget {
  const _PaidPremiumActiveView({
    required this.isFemale,
    required this.onBackToProfile,
  });

  final bool isFemale;
  final VoidCallback onBackToProfile;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(AppDimensions.space24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.champagneGold.withValues(alpha: 0.18),
                  AppColors.verifiedTeal.withValues(alpha: 0.10),
                ],
              ),
              borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
              border: Border.all(color: AppColors.goldBorder, width: 1.5),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.workspace_premium_rounded,
                  color: AppColors.champagneGold,
                  size: 62,
                ),
                const SizedBox(height: AppDimensions.space16),
                UiText(
                  l10n.appName,
                  style: AppTypography.screenTitle.copyWith(fontSize: 26),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppDimensions.space8),
                UiText(
                  l10n.referral_premiumFeaturesUnlocked,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.verifiedTeal,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.space24),
          _IncludedFeatures(isFemale: isFemale, isSmallScreen: false),
          const SizedBox(height: AppDimensions.space24),
          SizedBox(
            height: AppDimensions.buttonHeight,
            child: OutlinedButton.icon(
              onPressed: () => _SecondaryLinks._openBillingPortal(context),
              icon: const Icon(Icons.settings_outlined),
              label: UiText(
                context.uiCopy('Manage Subscription'),
                style: AppTypography.button,
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.space12),
          SizedBox(
            height: AppDimensions.buttonHeight,
            child: ElevatedButton.icon(
              onPressed: onBackToProfile,
              icon: const Icon(Icons.person_outline_rounded),
              label: UiText(
                l10n.referral_premiumBackToProfile,
                style: AppTypography.button,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReferralPremiumActiveView extends StatelessWidget {
  const _ReferralPremiumActiveView({
    required this.expiresAt,
    required this.isFemale,
    required this.onBackToProfile,
    this.isTest = false,
  });

  final DateTime? expiresAt;
  final bool isFemale;
  final VoidCallback onBackToProfile;
  final bool isTest;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final expiry = expiresAt?.toLocal();
    final remaining = expiry?.difference(DateTime.now());
    final remainingLabel = _remainingLabel(l10n, remaining);
    final expiryLabel = expiry == null
        ? null
        : '${MaterialLocalizations.of(context).formatMediumDate(expiry)} · '
            '${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(expiry))}';

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(AppDimensions.space24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.champagneGold.withValues(alpha: 0.18),
                  AppColors.verifiedTeal.withValues(alpha: 0.10),
                ],
              ),
              borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
              border: Border.all(color: AppColors.goldBorder, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: AppColors.champagneGold.withValues(alpha: 0.07),
                  blurRadius: 28,
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.champagneGold.withValues(alpha: 0.14),
                    border: Border.all(color: AppColors.goldBorder, width: 1.5),
                  ),
                  child: Icon(
                    Icons.workspace_premium_rounded,
                    color: AppColors.champagneGold,
                    size: 38,
                  ),
                ),
                const SizedBox(height: AppDimensions.space16),
                UiText(
                  isTest
                      ? context.uiCopy('Test Premium is active')
                      : l10n.referral_premiumActiveTitle,
                  style: AppTypography.screenTitle.copyWith(fontSize: 26),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppDimensions.space8),
                UiText(
                  remainingLabel,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.verifiedTeal,
                    fontSize: 18,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (expiryLabel != null) ...[
                  const SizedBox(height: 4),
                  UiText(
                    l10n.referral_premiumEndsAt(expiryLabel),
                    style: AppTypography.caption,
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.space20),
          Container(
            padding: const EdgeInsets.all(AppDimensions.space16),
            decoration: BoxDecoration(
              color: AppColors.verifiedTeal.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
              border: Border.all(
                color: AppColors.verifiedTeal.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.check_circle_rounded,
                    color: AppColors.verifiedTeal, size: 22),
                const SizedBox(width: AppDimensions.space12),
                Expanded(
                  child: UiText(
                    isTest
                        ? context.uiCopy(
                            'Temporary owner-supervised access. No purchase, renewal, referral reward or phone trust badge was created.',
                          )
                        : l10n.referral_premiumNoPayment,
                    style: AppTypography.bodyMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.space24),
          _IncludedFeatures(isFemale: isFemale, isSmallScreen: false),
          const SizedBox(height: AppDimensions.space24),
          Container(
            padding: const EdgeInsets.all(AppDimensions.space16),
            decoration: BoxDecoration(
              color: AppColors.surfaceGlass,
              borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.shield_outlined,
                    color: AppColors.champagneGold, size: 21),
                const SizedBox(width: AppDimensions.space12),
                Expanded(
                  child: UiText(
                    isTest
                        ? context.uiCopy(
                            'All Premium feature gates are enabled for testing until this countdown ends or the grant is revoked.',
                          )
                        : l10n.referral_premiumPlansAfter,
                    style: AppTypography.caption,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.space24),
          SizedBox(
            height: AppDimensions.buttonHeight,
            child: ElevatedButton.icon(
              onPressed: onBackToProfile,
              icon: const Icon(Icons.person_outline_rounded),
              label: UiText(
                l10n.referral_premiumBackToProfile,
                style: AppTypography.button,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _remainingLabel(
    AppLocalizations l10n,
    Duration? remaining,
  ) {
    if (remaining == null) return l10n.referral_premiumRemainingDaysHours(3, 0);
    if (remaining <= Duration.zero) return l10n.referral_premiumEndingNow;
    final days = remaining.inDays;
    final hours = remaining.inHours.remainder(24);
    final minutes = remaining.inMinutes.remainder(60);
    if (days > 0) {
      return l10n.referral_premiumRemainingDaysHours(days, hours);
    }
    if (hours > 0) {
      return l10n.referral_premiumRemainingHoursMinutes(hours, minutes);
    }
    return l10n.referral_premiumRemainingMinutes(
      remaining.inMinutes.clamp(1, 59),
    );
  }
}

// Header
Future<bool?> showPhoneVerificationSheet(
  BuildContext context, {
  String? countryCode,
  bool isChangingNumber = false,
  bool isBeforePurchase = false,
  String? guardianInvitationCode,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _PremiumPhoneVerificationSheet(
      countryCode: countryCode,
      isChangingNumber: isChangingNumber,
      isBeforePurchase: isBeforePurchase,
      guardianInvitationCode: guardianInvitationCode,
    ),
  );
}

class _PremiumPhoneVerificationSheet extends StatefulWidget {
  const _PremiumPhoneVerificationSheet({
    this.countryCode,
    required this.isChangingNumber,
    required this.isBeforePurchase,
    this.guardianInvitationCode,
  });

  final String? countryCode;
  final bool isChangingNumber;
  final bool isBeforePurchase;
  final String? guardianInvitationCode;

  @override
  State<_PremiumPhoneVerificationSheet> createState() =>
      _PremiumPhoneVerificationSheetState();
}

class _PremiumPhoneVerificationSheetState
    extends State<_PremiumPhoneVerificationSheet> {
  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  late CountryInfo _country;
  LaunchConfiguration _launch = LaunchConfiguration.india;
  bool _codeSent = false;
  bool _loading = false;
  String? _error;
  String _rawDigits = '';
  Timer? _resendTimer;
  int _resendSeconds = 0;

  @override
  void initState() {
    super.initState();
    _country = _indiaCountry;
    _phoneCtrl.addListener(_onPhoneChanged);
    _loadLaunchConfiguration();
  }

  Future<void> _loadLaunchConfiguration() async {
    final launch = await LaunchConfigurationService.load();
    if (!mounted) return;
    final requested = _countryForCode(widget.countryCode);
    final selected =
        requested != null && launch.enabledCountries.contains(requested.iso2)
            ? requested
            : _countryForCode(launch.defaultCountry) ?? _indiaCountry;
    setState(() {
      _launch = launch;
      _country = selected;
      _rawDigits = '';
      _phoneCtrl.clear();
    });
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _phoneCtrl.removeListener(_onPhoneChanged);
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  bool get _phoneReady =>
      _rawDigits.length == _country.maxDigits &&
      (_country.iso2 != 'IN' || RegExp(r'^[6-9]').hasMatch(_rawDigits));
  bool get _otpReady => _otpCtrl.text.replaceAll(RegExp(r'\D'), '').length == 6;

  void _onPhoneChanged() {
    final raw = _phoneCtrl.text;
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits == _rawDigits) return;
    _rawDigits = digits;

    final formatted = _country.formatNumber(digits);
    if (formatted != raw) {
      _phoneCtrl.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
    setState(() {});
  }

  Future<void> _sendCode() async {
    if (!_phoneReady || _loading) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await PhoneVerificationService.instance.sendCode(
        country: _country,
        nationalDigits: _rawDigits,
        purpose: widget.guardianInvitationCode == null
            ? PhoneVerificationPurpose.premium
            : PhoneVerificationPurpose.guardian,
        isChangingNumber: widget.isChangingNumber,
        guardianInvitationCode: widget.guardianInvitationCode,
      );
      if (!mounted) return;
      setState(() {
        _codeSent = true;
        _loading = false;
        _otpCtrl.clear();
      });
      _startResendCooldown();
    } on PhoneVerificationException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not send the SMS. Please try again.';
      });
    }
  }

  void _startResendCooldown() {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _resendSeconds <= 1) {
        timer.cancel();
        if (mounted) setState(() => _resendSeconds = 0);
        return;
      }
      setState(() => _resendSeconds--);
    });
  }

  Future<void> _verifyCode() async {
    if (!_otpReady || _loading) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await PhoneVerificationService.instance.verifyCode(
        country: _country,
        nationalDigits: _rawDigits,
        code: _otpCtrl.text.replaceAll(RegExp(r'\D'), ''),
        purpose: widget.guardianInvitationCode == null
            ? PhoneVerificationPurpose.premium
            : PhoneVerificationPurpose.guardian,
        guardianInvitationCode: widget.guardianInvitationCode,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on PhoneVerificationException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Phone verification could not be completed. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          border: Border(top: BorderSide(color: AppColors.cardBorder)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.verified_user_outlined,
                  color: AppColors.champagneGold,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: UiText(
                    context.uiCopy(widget.isChangingNumber
                        ? 'Change verified phone number'
                        : widget.guardianInvitationCode != null
                            ? 'Verify your Guardian phone'
                            : widget.isBeforePurchase
                                ? 'Verify phone before purchase'
                                : 'Verify phone to continue'),
                    style: AppTypography.bodyMedium,
                  ),
                ),
                IconButton(
                  onPressed:
                      _loading ? null : () => Navigator.of(context).pop(false),
                  icon: Icon(
                    Icons.close_rounded,
                    color: AppColors.slateMist,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            UiText(
              context.uiCopy(widget.isChangingNumber
                  ? 'Your new number becomes verified only after the SMS code succeeds. Changing it does not cancel Premium or alter its expiry date.'
                  : widget.guardianInvitationCode != null
                      ? 'Use the same India mobile number that the member entered for this Guardian invitation.'
                      : widget.isBeforePurchase
                          ? 'Verify an India +91 number once, then your selected Premium purchase will continue. Your subscription remains tied to your account, not this phone number.'
                          : 'Verify your phone with a one-time SMS code.'),
              style: AppTypography.caption.copyWith(color: AppColors.slateMist),
            ),
            const SizedBox(height: 18),
            _PhoneEntryRow(
              country: _country,
              controller: _phoneCtrl,
              enabled: !_codeSent && !_loading,
              enabledCountryCodes: _launch.enabledCountries.toSet(),
              onCountryChanged: (country) {
                setState(() {
                  _country = country;
                  _rawDigits = '';
                  _phoneCtrl.clear();
                });
              },
            ),
            if (_launch.isSingleCountry) ...[
              const SizedBox(height: 8),
              UiText(
                context.uiCopy(
                  'India launch: only +91 verification is available. Other countries are shown as coming later.',
                ),
                style: AppTypography.caption.copyWith(
                  color: AppColors.slateMist,
                ),
              ),
            ],
            if (_codeSent) ...[
              const SizedBox(height: 14),
              TextField(
                controller: _otpCtrl,
                keyboardType: TextInputType.number,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => setState(() {}),
                textAlign: TextAlign.center,
                style: AppTypography.userName.copyWith(
                  color: AppColors.pearlWhite,
                  letterSpacing: 8,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '000000',
                  hintStyle: AppTypography.userName.copyWith(
                    color: AppColors.slateMist.withValues(alpha: 0.4),
                    letterSpacing: 8,
                  ),
                  filled: true,
                  fillColor: AppColors.inputSurface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: AppColors.cardBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: AppColors.cardBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: AppColors.champagneGold,
                      width: AppDimensions.borderThin,
                    ),
                  ),
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 10),
              UiText(
                _error!,
                style: AppTypography.caption.copyWith(
                  color: AppColors.softCoral,
                ),
              ),
            ],
            const SizedBox(height: 18),
            _SheetPrimaryButton(
              label: _codeSent ? 'Verify & Continue' : 'Send Code',
              loading: _loading,
              enabled: _codeSent ? _otpReady : _phoneReady,
              onTap: _codeSent ? _verifyCode : _sendCode,
            ),
            if (_codeSent) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: !_loading && _resendSeconds == 0 ? _sendCode : null,
                child: UiText(
                  _resendSeconds > 0
                      ? l10n.auth_label_resendCodeIn(_resendSeconds)
                      : l10n.auth_label_resendCode,
                  style: AppTypography.caption.copyWith(
                    color: _resendSeconds == 0
                        ? AppColors.champagneGold
                        : AppColors.slateMist,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static CountryInfo? _countryForCode(String? code) {
    if (code == null || code.isEmpty) return null;
    final normalized = code.toUpperCase();
    for (final country in kAllCountries) {
      if (country.iso2 == normalized) return country;
    }
    return null;
  }

  static CountryInfo get _indiaCountry =>
      kAllCountries.firstWhere((country) => country.iso2 == 'IN');
}

class _PhoneEntryRow extends StatefulWidget {
  const _PhoneEntryRow({
    required this.country,
    required this.controller,
    required this.enabled,
    required this.enabledCountryCodes,
    required this.onCountryChanged,
  });

  final CountryInfo country;
  final TextEditingController controller;
  final bool enabled;
  final Set<String> enabledCountryCodes;
  final ValueChanged<CountryInfo> onCountryChanged;

  @override
  State<_PhoneEntryRow> createState() => _PhoneEntryRowState();
}

class _PhoneEntryRowState extends State<_PhoneEntryRow> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocus);
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_handleFocus)
      ..dispose();
    super.dispose();
  }

  void _handleFocus() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return SilarahFieldFrame(
      focused: _focusNode.hasFocus,
      enabled: widget.enabled,
      minHeight: 58,
      child: Row(
        children: [
          SizedBox(
            width: 126,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<CountryInfo>(
                value: widget.country,
                isExpanded: true,
                dropdownColor: AppColors.surfaceDark,
                iconEnabledColor: AppColors.slateMist,
                padding: const EdgeInsets.only(left: 12, right: 4),
                onChanged: widget.enabled
                    ? (value) {
                        if (value != null) widget.onCountryChanged(value);
                      }
                    : null,
                selectedItemBuilder: (_) => kAllCountries
                    .map(
                      (c) => Align(
                        alignment: Alignment.centerLeft,
                        child: UiText(
                          '${c.flag} ${c.dialCode}',
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.body.copyWith(
                            color: AppColors.pearlWhite,
                          ),
                        ),
                      ),
                    )
                    .toList(),
                items: kAllCountries
                    .map(
                      (c) => DropdownMenuItem(
                        value: c,
                        enabled: widget.enabledCountryCodes.contains(c.iso2),
                        child: Row(
                          children: [
                            Expanded(
                              child: UiText(
                                '${c.flag} ${c.name} ${c.dialCode}',
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.body.copyWith(
                                  color: widget.enabledCountryCodes
                                          .contains(c.iso2)
                                      ? AppColors.pearlWhite
                                      : AppColors.slateMist
                                          .withValues(alpha: 0.55),
                                ),
                              ),
                            ),
                            if (!widget.enabledCountryCodes.contains(c.iso2))
                              UiText(
                                context.uiCopy('Coming later'),
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.slateMist
                                      .withValues(alpha: 0.55),
                                ),
                              ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
          VerticalDivider(
            width: 1,
            thickness: 1,
            color: AppColors.cardBorder,
          ),
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: _focusNode,
              enabled: widget.enabled,
              keyboardType: TextInputType.phone,
              style: AppTypography.body.copyWith(color: AppColors.pearlWhite),
              decoration: InputDecoration(
                hintText: context.uiCopy('Phone number'),
                hintStyle: AppTypography.bodyMuted,
                filled: false,
                fillColor: Colors.transparent,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetPrimaryButton extends StatelessWidget {
  const _SheetPrimaryButton({
    required this.label,
    required this.loading,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool loading;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final active = enabled && !loading;
    return GestureDetector(
      onTap: active ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active
              ? AppColors.champagneGold
              : AppColors.champagneGold.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(14),
        ),
        child: loading
            ? SilarahPulseLoader(
                size: 24,
                accentColor: AppColors.obsidianNight,
                highlightColor: AppColors.obsidianDeep,
                markColor: AppColors.champagneLight,
                coreGradientColors: [
                  AppColors.obsidianNight,
                  AppColors.obsidianDeep,
                ],
              )
            : UiText(label, style: AppTypography.button),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({this.isFemale = false, this.isSmallScreen = false});
  final bool isFemale;
  final bool isSmallScreen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Gold crown icon
        Container(
          width: isSmallScreen ? 44 : 56,
          height: isSmallScreen ? 44 : 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.goldGlow,
            border: Border.all(color: AppColors.goldBorder, width: 1.5),
          ),
          child: Icon(Icons.workspace_premium_rounded,
              color: AppColors.champagneGold, size: isSmallScreen ? 22 : 28),
        ),
        SizedBox(height: isSmallScreen ? 12 : 20),
        UiText(
          isFemale ? 'Unlock Premium' : 'Unlock SILARAH',
          style: AppTypography.screenTitle.copyWith(
            fontSize: isSmallScreen ? 22 : 28,
          ),
        ),
        const SizedBox(height: 8),
        UiText(
          isFemale
              ? 'You already message free.\nUnlock advanced features.'
              : 'Women message free.\nMen subscribe to connect.',
          style: AppTypography.bodyMuted.copyWith(
            height: 1.6,
            fontSize: isSmallScreen ? 13 : 15,
          ),
        ),
      ],
    );
  }
}

// Plan Cards
class _PricingStatusCard extends StatelessWidget {
  const _PricingStatusCard({
    required this.isLoading,
    required this.isSmallScreen,
    required this.onRetry,
  });

  final bool isLoading;
  final bool isSmallScreen;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: isLoading ? 'Loading subscription plans' : 'Plans unavailable',
      child: Container(
        padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
        decoration: BoxDecoration(
          color: AppColors.surfaceGlass,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          children: [
            SizedBox.square(
              dimension: isSmallScreen ? 36 : 42,
              child: isLoading
                  ? SilarahPulseLoader(
                      size: 30,
                      accentColor: AppColors.champagneGold,
                      highlightColor: AppColors.champagneLight,
                      markColor: AppColors.obsidianNight,
                      coreGradientColors: [
                        AppColors.champagneGold,
                        AppColors.champagneLight,
                      ],
                    )
                  : DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.goldGlow,
                      ),
                      child: Icon(
                        Icons.cloud_off_rounded,
                        color: AppColors.champagneGold,
                        size: 20,
                      ),
                    ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  UiText(
                    isLoading ? 'Loading plans' : 'Plans couldn’t load',
                    style: AppTypography.body.copyWith(
                      color: AppColors.pearlWhite,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  UiText(
                    isLoading
                        ? 'Getting secure pricing from the store…'
                        : 'Check your connection, then try again.',
                    style: AppTypography.caption.copyWith(height: 1.4),
                  ),
                ],
              ),
            ),
            if (!isLoading)
              TextButton(
                onPressed: onRetry,
                child: UiText(context.uiCopy('Try again')),
              ),
          ],
        ),
      ),
    );
  }
}

class _PlanCards extends StatelessWidget {
  final DisplayPricing pricing;
  final String selectedPlan;
  final void Function(String) onSelect;
  final bool isSmallScreen;

  const _PlanCards({
    required this.pricing,
    required this.selectedPlan,
    required this.onSelect,
    this.isSmallScreen = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _PlanCard(
            planId: 'monthly',
            label: 'Monthly',
            price: pricing.monthlyPrice,
            period: 'per month',
            billing: 'Billed monthly',
            isBest: false,
            savings: null,
            isSelected: selectedPlan == 'monthly',
            isSmallScreen: isSmallScreen,
            onTap: () => onSelect('monthly'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _PlanCard(
            planId: 'annual',
            label: 'Annual',
            price: pricing.annualPrice,
            period: 'per year',
            billing: 'Billed annually',
            isBest: true,
            savings: pricing.savingsPercent,
            isSelected: selectedPlan == 'annual',
            isSmallScreen: isSmallScreen,
            onTap: () => onSelect('annual'),
          ),
        ),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String planId;
  final String label;
  final String price;
  final String period;
  final String billing;
  final bool isBest;
  final int? savings;
  final bool isSelected;
  final bool isSmallScreen;
  final VoidCallback onTap;

  const _PlanCard({
    required this.planId,
    required this.label,
    required this.price,
    required this.period,
    required this.billing,
    required this.isBest,
    required this.savings,
    required this.isSelected,
    required this.onTap,
    this.isSmallScreen = false,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor =
        isSelected ? AppColors.champagneGold : AppColors.cardBorder;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isSelected ? AppColors.goldGlow : AppColors.surfaceGlass,
          border: Border.all(color: borderColor, width: isSelected ? 1.5 : 1),
        ),
        padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Best Value badge with dynamic savings %
            if (isBest) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: AppColors.champagneGold,
                ),
                child: UiText(
                  savings != null && savings! > 0
                      ? 'SAVE $savings%'
                      : 'BEST VALUE',
                  style: AppTypography.sectionLabel.copyWith(
                    color: AppColors.obsidianNight,
                    fontWeight: FontWeight.w700,
                    fontSize: 8,
                    letterSpacing: 1,
                  ),
                ),
              ),
              SizedBox(height: isSmallScreen ? 6 : 10),
            ] else
              SizedBox(height: isSmallScreen ? 20 : 23), // align with badge row

            UiText(label,
                style: AppTypography.captionMedium.copyWith(
                    color: AppColors.slateMist,
                    fontSize: isSmallScreen ? 12 : 14)),
            const SizedBox(height: 6),
            UiText(
              price,
              style: AppTypography.screenTitle.copyWith(
                fontSize: isSmallScreen ? 18 : 22,
                color:
                    isSelected ? AppColors.champagneGold : AppColors.pearlWhite,
              ),
            ),
            const SizedBox(height: 2),
            UiText(period, style: AppTypography.caption.copyWith(fontSize: 10)),
            const SizedBox(height: 4),
            // Billing note (Billed annually / monthly)
            UiText(
              billing,
              style: AppTypography.caption.copyWith(
                fontSize: 9,
                color: AppColors.slateMist.withValues(alpha: 0.7),
                fontStyle: FontStyle.italic,
              ),
            ),

            SizedBox(height: isSmallScreen ? 8 : 12),

            // Selection indicator
            Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? AppColors.champagneGold
                        : AppColors.cardBorder,
                    width: isSelected ? 0 : 1.5,
                  ),
                  color:
                      isSelected ? AppColors.champagneGold : Colors.transparent,
                ),
                child: isSelected
                    ? Icon(Icons.check_rounded,
                        size: 10, color: AppColors.obsidianNight)
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Included Features
class _IncludedFeatures extends StatelessWidget {
  const _IncludedFeatures({this.isFemale = false, this.isSmallScreen = false});
  final bool isFemale;
  final bool isSmallScreen;

  static const _maleFeatures = [
    (Icons.all_inclusive_rounded, 'Unlimited profile browsing'),
    (Icons.favorite_rounded, '25 interests per day'),
    (Icons.chat_bubble_outline_rounded, 'Full messaging access'),
    (Icons.visibility_rounded, 'See everyone who viewed your profile'),
    (Icons.travel_explore_rounded, 'All India, state, city & trust filters'),
    (Icons.hub_outlined, 'Mutual compatibility insights'),
    (Icons.bookmarks_outlined, 'Private shortlists, notes & reminders'),
    (Icons.visibility_off_outlined, 'Incognito Discovery'),
    (Icons.rocket_launch_outlined, 'One profile boost per week'),
  ];

  static const _femaleFeatures = [
    (Icons.favorite_rounded, '25 interests per day'),
    (Icons.travel_explore_rounded, 'All India, state, city & trust filters'),
    (Icons.hub_outlined, 'Mutual compatibility insights'),
    (Icons.bookmarks_outlined, 'Private shortlists, notes & reminders'),
    (Icons.visibility_off_outlined, 'Incognito Discovery'),
    (Icons.rocket_launch_outlined, 'Weekly profile boost'),
    (Icons.visibility_rounded, 'See everyone who viewed your profile'),
    (Icons.bookmark_border_rounded, 'Save multiple filter presets'),
    (Icons.trending_up_rounded, 'Priority in search results'),
  ];

  @override
  Widget build(BuildContext context) {
    final features = isFemale ? _femaleFeatures : _maleFeatures;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: AppColors.surfaceGlass,
        border: Border.all(color: AppColors.cardBorder),
      ),
      padding: EdgeInsets.all(isSmallScreen ? 12 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UiText(
            context.uiCopy("WHAT'S INCLUDED"),
            style: AppTypography.sectionLabel.copyWith(
              fontSize: isSmallScreen ? 10 : 12,
            ),
          ),
          SizedBox(height: isSmallScreen ? 10 : 16),
          ...features.map((f) => _FeatureRow(
              icon: f.$1, label: f.$2, isSmallScreen: isSmallScreen)),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSmallScreen;

  const _FeatureRow(
      {required this.icon, required this.label, this.isSmallScreen = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isSmallScreen ? 8 : 12),
      child: Row(
        children: [
          Container(
            width: isSmallScreen ? 24 : 32,
            height: isSmallScreen ? 24 : 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.goldGlow,
            ),
            child: Icon(icon,
                color: AppColors.champagneGold, size: isSmallScreen ? 12 : 16),
          ),
          SizedBox(width: isSmallScreen ? 8 : 12),
          Expanded(
            child: UiText(context.uiCopy(label),
                style: AppTypography.body
                    .copyWith(fontSize: isSmallScreen ? 12 : 14)),
          ),
        ],
      ),
    );
  }
}

// CTA Button
class _CtaButton extends StatelessWidget {
  final String selectedPlan;
  final DisplayPricing pricing;
  final bool isLoading;
  final bool isSmallScreen;
  final VoidCallback onTap;

  const _CtaButton({
    required this.selectedPlan,
    required this.pricing,
    required this.isLoading,
    required this.onTap,
    this.isSmallScreen = false,
  });

  @override
  Widget build(BuildContext context) {
    final label =
        selectedPlan == 'annual' ? pricing.annualCta : pricing.monthlyCta;

    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: isSmallScreen ? 48 : 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: isLoading
              ? AppColors.champagneGold.withValues(alpha: 0.5)
              : AppColors.champagneGold,
        ),
        alignment: Alignment.center,
        child: isLoading
            ? SilarahPulseLoader(
                size: 26,
                accentColor: AppColors.obsidianNight,
                highlightColor: AppColors.obsidianDeep,
                markColor: AppColors.champagneLight,
                coreGradientColors: [
                  AppColors.obsidianNight,
                  AppColors.obsidianDeep,
                ],
              )
            : UiText(label,
                style: AppTypography.button
                    .copyWith(fontSize: isSmallScreen ? 14 : 16)),
      ),
    );
  }
}

// Secondary Links
class _SecondaryLinks extends StatelessWidget {
  final bool isLoading;
  final bool isSmallScreen;
  final VoidCallback onRestore;

  const _SecondaryLinks({
    required this.isLoading,
    required this.onRestore,
    this.isSmallScreen = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextButton(
          onPressed: isLoading ? null : onRestore,
          style: TextButton.styleFrom(
            padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 4 : 8),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: UiText(
            context.uiCopy('Restore Purchase'),
            style: AppTypography.caption.copyWith(
                color: AppColors.champagneGold,
                fontSize: isSmallScreen ? 12 : 14),
          ),
        ),
        SizedBox(height: isSmallScreen ? 2 : 4),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 2,
          runSpacing: 0,
          children: [
            TextButton(
              onPressed: () => _openLegalPage(context, 'privacy'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: UiText(context.uiCopy('Privacy Policy'),
                  style: AppTypography.caption
                      .copyWith(fontSize: isSmallScreen ? 11 : 12)),
            ),
            UiText('·',
                style:
                    AppTypography.caption.copyWith(color: AppColors.slateMist)),
            TextButton(
              onPressed: () => _openLegalPage(context, 'tos'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: UiText(context.uiCopy('Terms of Service'),
                  style: AppTypography.caption
                      .copyWith(fontSize: isSmallScreen ? 11 : 12)),
            ),
            UiText('·',
                style:
                    AppTypography.caption.copyWith(color: AppColors.slateMist)),
            TextButton(
              onPressed: () => _openLegalPage(context, 'refund-policy'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: UiText(context.uiCopy('Refund Policy'),
                  style: AppTypography.caption
                      .copyWith(fontSize: isSmallScreen ? 11 : 12)),
            ),
            UiText('·',
                style:
                    AppTypography.caption.copyWith(color: AppColors.slateMist)),
            TextButton(
              onPressed: () => _openBillingPortal(context),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: UiText(context.uiCopy('Manage Subscription'),
                  style: AppTypography.caption.copyWith(
                    color: AppColors.champagneGold,
                    fontSize: isSmallScreen ? 11 : 12,
                  )),
            ),
          ],
        ),
        SizedBox(height: isSmallScreen ? 4 : 8),
        UiText(
          context.uiCopy(
            'Auto-renews at the displayed price and billing period unless cancelled in Google Play before the renewal date shown there.\nCancellation normally keeps access through the paid period and does not automatically refund it. Statutory rights apply.',
          ),
          style: AppTypography.caption
              .copyWith(fontSize: isSmallScreen ? 10 : 11, height: 1.5),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  static void _openLegalPage(BuildContext context, String type) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => LegalDocScreen(type: type)),
    );
  }

  static Future<void> _openBillingPortal(BuildContext context) async {
    final opened = await BillingPortalService.openGooglePlaySubscriptions();
    if (opened || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: UiText(
          context.uiCopy(
            'Unable to open Google Play subscriptions. Try again.',
          ),
        ),
      ),
    );
  }
}

// Free For Women Screen
// _FreeForWomenScreen removed — women now see the main subscription
// screen with differentiated messaging (isFemale: true).
