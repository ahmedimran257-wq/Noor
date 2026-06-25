// lib/features/home/screens/subscription_screen.dart
// ============================================================
// MITHAQ — Subscription Screen (RevenueCat Dynamic Pricing)
//
// Blueprint (Part 8):
//   "The price in local currency."
//
// Pricing is fetched exclusively from RevenueCat Offerings.
// No hardcoded fallback — shows error state if unavailable.
// Dynamic "Best value — save X%" on annual card.
// ============================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import '../../../core/data/country_data.dart';
import '../../../core/services/phone_verification_service.dart';
import '../../../core/services/subscription_service.dart';
import '../../../core/cubits/auth/auth_cubit.dart';
import '../../../core/cubits/auth/auth_state.dart';
import '../../../core/cubits/subscription/subscription_cubit.dart';
import '../../../core/cubits/subscription/subscription_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
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
  DisplayPricing _pricing = DisplayPricing.unavailable();
  StreamSubscription<DisplayPricing>? _pricingSub;

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

  @override
  void dispose() {
    _pricingSub?.cancel();
    _headerAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Blueprint Part 2: detect gender for differentiated messaging.
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
        return Scaffold(
          backgroundColor: AppColors.obsidianNight,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: AppColors.pearlWhite, size: 20),
            ),
          ),
          body: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(20, 0, 20, isSmallScreen ? 20 : 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Header ──────────────────────────────────
                SlideTransition(
                  position: _headerSlide,
                  child: FadeTransition(
                    opacity: _headerFade,
                    child: _Header(
                        isFemale: isFemale, isSmallScreen: isSmallScreen),
                  ),
                ),

                SizedBox(height: spaceLarge),

                // ── Plan Cards ──────────────────────────────
                _PlanCards(
                  pricing: _pricing,
                  selectedPlan: _selectedPlan,
                  onSelect: (plan) => setState(() => _selectedPlan = plan),
                  isSmallScreen: isSmallScreen,
                ),

                SizedBox(height: spaceMedium),

                // ── What's included ─────────────────────────
                _IncludedFeatures(
                    isFemale: isFemale, isSmallScreen: isSmallScreen),

                SizedBox(height: spaceLarge),

                // ── CTA Button ──────────────────────────────
                _CtaButton(
                  selectedPlan: _selectedPlan,
                  pricing: _pricing,
                  isLoading: state.isLoading,
                  isSmallScreen: isSmallScreen,
                  onTap: _startPurchase,
                ),

                SizedBox(height: spaceSmall),

                // ── Secondary links ─────────────────────────
                _SecondaryLinks(
                  isLoading: state.isLoading,
                  isSmallScreen: isSmallScreen,
                  onRestore: () => context.read<SubscriptionCubit>().restore(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _startPurchase() async {
    final pricingReady = _pricing.isAvailable;
    if (!pricingReady) {
      _showError(context, 'Plans are not available right now.');
      return;
    }

    final status = await PhoneVerificationService.instance.currentStatus();
    if (!mounted) return;
    if (!status.isVerified) {
      final authState = context.read<AuthCubit>().state;
      final countryCode =
          authState is AuthAuthenticated ? authState.countryCode : null;
      final verified = await _showPhoneVerificationSheet(
        context,
        countryCode: countryCode,
      );
      if (!mounted || verified != true) return;
    }

    final planId = _selectedPlan == 'annual'
        ? SubscriptionCubit.annualProductId
        : SubscriptionCubit.monthlyProductId;
    context.read<SubscriptionCubit>().purchase(planId);
  }

  void _showSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: AppTypography.body),
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
        content: Text(message, style: AppTypography.body),
        backgroundColor: AppColors.softCoral,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────

Future<bool?> _showPhoneVerificationSheet(
  BuildContext context, {
  String? countryCode,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _PremiumPhoneVerificationSheet(countryCode: countryCode),
  );
}

class _PremiumPhoneVerificationSheet extends StatefulWidget {
  const _PremiumPhoneVerificationSheet({this.countryCode});

  final String? countryCode;

  @override
  State<_PremiumPhoneVerificationSheet> createState() =>
      _PremiumPhoneVerificationSheetState();
}

class _PremiumPhoneVerificationSheetState
    extends State<_PremiumPhoneVerificationSheet> {
  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  late CountryInfo _country;
  bool _codeSent = false;
  bool _loading = false;
  String? _error;
  String _rawDigits = '';

  @override
  void initState() {
    super.initState();
    _country = _countryForCode(widget.countryCode) ?? deviceCountry();
    _phoneCtrl.addListener(_onPhoneChanged);
  }

  @override
  void dispose() {
    _phoneCtrl.removeListener(_onPhoneChanged);
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  bool get _phoneReady => _rawDigits.length >= (_country.maxDigits - 1);
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
      );
      if (!mounted) return;
      setState(() {
        _codeSent = true;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not send code. Please check the number.';
      });
    }
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
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Invalid code. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          border: Border(top: BorderSide(color: AppColors.cardBorder)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.verified_user_outlined,
                  color: AppColors.champagneGold,
                  size: 22,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Verify phone to continue',
                    style: AppTypography.bodyMedium,
                  ),
                ),
                IconButton(
                  onPressed:
                      _loading ? null : () => Navigator.of(context).pop(false),
                  icon: const Icon(
                    Icons.close_rounded,
                    color: AppColors.slateMist,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'This is only required before subscription purchase.',
              style: AppTypography.caption.copyWith(color: AppColors.slateMist),
            ),
            const SizedBox(height: 18),
            _PhoneEntryRow(
              country: _country,
              controller: _phoneCtrl,
              enabled: !_codeSent && !_loading,
              onCountryChanged: (country) {
                setState(() {
                  _country = country;
                  _rawDigits = '';
                  _phoneCtrl.clear();
                });
              },
            ),
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
                    borderSide: const BorderSide(color: AppColors.cardBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.cardBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: AppColors.champagneGold,
                      width: 1.4,
                    ),
                  ),
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
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
}

class _PhoneEntryRow extends StatelessWidget {
  const _PhoneEntryRow({
    required this.country,
    required this.controller,
    required this.enabled,
    required this.onCountryChanged,
  });

  final CountryInfo country;
  final TextEditingController controller;
  final bool enabled;
  final ValueChanged<CountryInfo> onCountryChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      decoration: BoxDecoration(
        color: AppColors.inputSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 126,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<CountryInfo>(
                value: country,
                isExpanded: true,
                dropdownColor: AppColors.surfaceDark,
                iconEnabledColor: AppColors.slateMist,
                padding: const EdgeInsets.only(left: 12, right: 4),
                onChanged: enabled
                    ? (value) {
                        if (value != null) onCountryChanged(value);
                      }
                    : null,
                selectedItemBuilder: (_) => kAllCountries
                    .map(
                      (c) => Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
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
                        child: Text(
                          '${c.flag} ${c.name} ${c.dialCode}',
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.body,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
          const VerticalDivider(
            width: 1,
            thickness: 1,
            color: AppColors.cardBorder,
          ),
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled,
              keyboardType: TextInputType.phone,
              style: AppTypography.body.copyWith(color: AppColors.pearlWhite),
              decoration: const InputDecoration(
                hintText: 'Phone number',
                hintStyle: AppTypography.bodyMuted,
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 14),
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
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.obsidianNight,
                ),
              )
            : Text(label, style: AppTypography.button),
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
        Text(
          isFemale ? 'Unlock Premium' : 'Unlock MITHAQ',
          style: AppTypography.screenTitle.copyWith(
            fontSize: isSmallScreen ? 22 : 28,
          ),
        ),
        const SizedBox(height: 8),
        Text(
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

// ── Plan Cards ────────────────────────────────────────────────

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
                child: Text(
                  savings != null ? 'SAVE $savings%' : 'BEST VALUE',
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

            Text(label,
                style: AppTypography.captionMedium.copyWith(
                    color: AppColors.slateMist,
                    fontSize: isSmallScreen ? 12 : 14)),
            const SizedBox(height: 6),
            Text(
              price,
              style: AppTypography.screenTitle.copyWith(
                fontSize: isSmallScreen ? 18 : 22,
                color:
                    isSelected ? AppColors.champagneGold : AppColors.pearlWhite,
              ),
            ),
            const SizedBox(height: 2),
            Text(period, style: AppTypography.caption.copyWith(fontSize: 10)),
            const SizedBox(height: 4),
            // Billing note (Billed annually / monthly)
            Text(
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
                    ? const Icon(Icons.check_rounded,
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

// ── Included Features ─────────────────────────────────────────

class _IncludedFeatures extends StatelessWidget {
  const _IncludedFeatures({this.isFemale = false, this.isSmallScreen = false});
  final bool isFemale;
  final bool isSmallScreen;

  static const _maleFeatures = [
    (Icons.all_inclusive_rounded, 'Unlimited profile browsing'),
    (Icons.favorite_rounded, '20 interests per day'),
    (Icons.chat_bubble_outline_rounded, 'Full messaging access'),
    (Icons.visibility_rounded, 'See who liked your profile'),
    (Icons.tune_rounded, 'Advanced filters — income & distance'),
    (Icons.rocket_launch_outlined, 'One profile boost per week'),
  ];

  static const _femaleFeatures = [
    (Icons.tune_rounded, 'Advanced filters (distance, income)'),
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
          Text(
            "WHAT'S INCLUDED",
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
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.goldGlow,
            ),
            child: Icon(icon,
                color: AppColors.champagneGold, size: isSmallScreen ? 12 : 16),
          ),
          SizedBox(width: isSmallScreen ? 8 : 12),
          Expanded(
            child: Text(label,
                style: AppTypography.body
                    .copyWith(fontSize: isSmallScreen ? 12 : 14)),
          ),
        ],
      ),
    );
  }
}

// ── CTA Button ────────────────────────────────────────────────

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
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: AppColors.obsidianNight,
                  strokeWidth: 2.5,
                ),
              )
            : Text(label,
                style: AppTypography.button
                    .copyWith(fontSize: isSmallScreen ? 14 : 16)),
      ),
    );
  }
}

// ── Secondary Links ───────────────────────────────────────────

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
          child: Text(
            'Restore Purchase',
            style: AppTypography.caption.copyWith(
                color: AppColors.champagneGold,
                fontSize: isSmallScreen ? 12 : 14),
          ),
        ),
        SizedBox(height: isSmallScreen ? 2 : 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: () => _openLegalPage(context, 'Privacy Policy'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text('Privacy Policy',
                  style: AppTypography.caption
                      .copyWith(fontSize: isSmallScreen ? 11 : 12)),
            ),
            Text('·',
                style:
                    AppTypography.caption.copyWith(color: AppColors.slateMist)),
            TextButton(
              onPressed: () => _openLegalPage(context, 'Terms of Service'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text('Terms of Service',
                  style: AppTypography.caption
                      .copyWith(fontSize: isSmallScreen ? 11 : 12)),
            ),
          ],
        ),
        SizedBox(height: isSmallScreen ? 4 : 8),
        Text(
          'Subscription auto-renews unless cancelled 24h before renewal.\nWomen always message free on MITHAQ.',
          style: AppTypography.caption
              .copyWith(fontSize: isSmallScreen ? 10 : 11, height: 1.5),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // TODO (legal): Replace with url_launcher or in-app WebView
  // once Privacy Policy and Terms of Service URLs are hosted.
  static void _openLegalPage(BuildContext context, String title) {
    final type = title.toLowerCase().contains('privacy') ? 'privacy' : 'tos';
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => LegalDocScreen(type: type)),
    );
  }
}

// ── Free For Women Screen ─────────────────────────────────────

// _FreeForWomenScreen removed — women now see the main subscription
// screen with differentiated messaging (isFemale: true).
