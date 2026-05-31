// lib/features/home/screens/subscription_screen.dart
// ============================================================
// NOOR — Subscription Screen (RevenueCat Dynamic Pricing)
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
  late final Animation<double>   _headerFade;
  late final Animation<Offset>   _headerSlide;

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
    final gender = authState is AuthAuthenticated
        ? (authState.gender ?? 'male')
        : 'male';
    final isFemale = gender == 'female';

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
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Header ──────────────────────────────────
                SlideTransition(
                  position: _headerSlide,
                  child: FadeTransition(
                    opacity: _headerFade,
                    child: _Header(isFemale: isFemale),
                  ),
                ),

                const SizedBox(height: 36),

                // ── Plan Cards ──────────────────────────────
                _PlanCards(
                  pricing:      _pricing,
                  selectedPlan: _selectedPlan,
                  onSelect: (plan) => setState(() => _selectedPlan = plan),
                ),

                const SizedBox(height: 28),

                // ── What's included ─────────────────────────
                _IncludedFeatures(isFemale: isFemale),

                const SizedBox(height: 36),

                // ── CTA Button ──────────────────────────────
                _CtaButton(
                  selectedPlan: _selectedPlan,
                  pricing:      _pricing,
                  isLoading: state.isLoading,
                  onTap: () {
                    final planId = _selectedPlan == 'annual'
                        ? SubscriptionCubit.annualProductId
                        : SubscriptionCubit.monthlyProductId;
                    context.read<SubscriptionCubit>().purchase(planId);
                  },
                ),

                const SizedBox(height: 20),

                // ── Secondary links ─────────────────────────
                _SecondaryLinks(
                  isLoading: state.isLoading,
                  onRestore: () => context.read<SubscriptionCubit>().restore(),
                ),
              ],
            ),
          ),
        );
      },
    );
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

class _Header extends StatelessWidget {
  const _Header({this.isFemale = false});
  final bool isFemale;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Gold crown icon
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.goldGlow,
            border: Border.all(color: AppColors.goldBorder, width: 1.5),
          ),
          child: const Icon(Icons.workspace_premium_rounded,
              color: AppColors.champagneGold, size: 28),
        ),
        const SizedBox(height: 20),
        Text(
          isFemale ? 'Unlock Premium' : 'Unlock NOOR',
          style: AppTypography.screenTitle,
        ),
        const SizedBox(height: 8),
        Text(
          isFemale
              ? 'You already message free.\nUnlock advanced features.'
              : 'Women message free.\nMen subscribe to connect.',
          style: AppTypography.bodyMuted.copyWith(height: 1.6),
        ),
      ],
    );
  }
}

// ── Plan Cards ────────────────────────────────────────────────

class _PlanCards extends StatelessWidget {
  final DisplayPricing pricing;
  final String      selectedPlan;
  final void Function(String) onSelect;

  const _PlanCards({
    required this.pricing,
    required this.selectedPlan,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _PlanCard(
            planId:    'monthly',
            label:     'Monthly',
            price:     pricing.monthlyPrice,
            period:    'per month',
            billing:   'Billed monthly',
            isBest:    false,
            savings:   null,
            isSelected: selectedPlan == 'monthly',
            onTap:     () => onSelect('monthly'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _PlanCard(
            planId:    'annual',
            label:     'Annual',
            price:     pricing.annualPrice,
            period:    'per year',
            billing:   'Billed annually',
            isBest:    true,
            savings:   pricing.savingsPercent,
            isSelected: selectedPlan == 'annual',
            onTap:     () => onSelect('annual'),
          ),
        ),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String  planId;
  final String  label;
  final String  price;
  final String  period;
  final String  billing;
  final bool    isBest;
  final int?    savings;
  final bool    isSelected;
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
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isSelected
        ? AppColors.champagneGold
        : AppColors.cardBorder;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isSelected
              ? AppColors.goldGlow
              : AppColors.surfaceGlass,
          border: Border.all(color: borderColor, width: isSelected ? 1.5 : 1),
        ),
        padding: const EdgeInsets.all(16),
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
                  savings != null
                      ? 'SAVE $savings%'
                      : 'BEST VALUE',
                  style: AppTypography.sectionLabel.copyWith(
                    color: AppColors.obsidianNight,
                    fontWeight: FontWeight.w700,
                    fontSize: 9,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ] else
              const SizedBox(height: 23), // align with badge row

            Text(label,
                style: AppTypography.captionMedium
                    .copyWith(color: AppColors.slateMist)),
            const SizedBox(height: 6),
            Text(
              price,
              style: AppTypography.screenTitle.copyWith(
                fontSize: 22,
                color: isSelected
                    ? AppColors.champagneGold
                    : AppColors.pearlWhite,
              ),
            ),
            const SizedBox(height: 2),
            Text(period,
                style: AppTypography.caption.copyWith(fontSize: 11)),
            const SizedBox(height: 4),
            // Billing note (Billed annually / monthly)
            Text(
              billing,
              style: AppTypography.caption.copyWith(
                fontSize:   10,
                color:      AppColors.slateMist.withValues(alpha: 0.7),
                fontStyle:  FontStyle.italic,
              ),
            ),

            const SizedBox(height: 12),

            // Selection indicator
            Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? AppColors.champagneGold
                        : AppColors.cardBorder,
                    width: isSelected ? 0 : 1.5,
                  ),
                  color: isSelected
                      ? AppColors.champagneGold
                      : Colors.transparent,
                ),
                child: isSelected
                    ? const Icon(Icons.check_rounded,
                        size: 12, color: AppColors.obsidianNight)
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
  const _IncludedFeatures({this.isFemale = false});
  final bool isFemale;

  static const _maleFeatures = [
    (Icons.all_inclusive_rounded,       'Unlimited profile browsing'),
    (Icons.favorite_rounded,            '20 interests per day'),
    (Icons.chat_bubble_outline_rounded, 'Full messaging access'),
    (Icons.visibility_rounded,          'See who liked your profile'),
    (Icons.tune_rounded,                'Advanced filters — income & distance'),
    (Icons.rocket_launch_outlined,      'One profile boost per week'),
  ];

  static const _femaleFeatures = [
    (Icons.tune_rounded,                'Advanced filters (distance, income)'),
    (Icons.rocket_launch_outlined,      'Weekly profile boost'),
    (Icons.visibility_rounded,          'See everyone who viewed your profile'),
    (Icons.bookmark_border_rounded,     'Save multiple filter presets'),
    (Icons.trending_up_rounded,         'Priority in search results'),
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
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "WHAT'S INCLUDED",
            style: AppTypography.sectionLabel,
          ),
          const SizedBox(height: 16),
          ...features.map((f) => _FeatureRow(icon: f.$1, label: f.$2)),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String   label;

  const _FeatureRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.goldGlow,
            ),
            child: Icon(icon, color: AppColors.champagneGold, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: AppTypography.body.copyWith(fontSize: 14)),
          ),
        ],
      ),
    );
  }
}

// ── CTA Button ────────────────────────────────────────────────

class _CtaButton extends StatelessWidget {
  final String         selectedPlan;
  final DisplayPricing pricing;
  final bool           isLoading;
  final VoidCallback onTap;

  const _CtaButton({
    required this.selectedPlan,
    required this.pricing,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final label = selectedPlan == 'annual'
        ? pricing.annualCta
        : pricing.monthlyCta;

    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 56,
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
            : Text(label, style: AppTypography.button),
      ),
    );
  }
}

// ── Secondary Links ───────────────────────────────────────────

class _SecondaryLinks extends StatelessWidget {
  final bool     isLoading;
  final VoidCallback onRestore;

  const _SecondaryLinks({
    required this.isLoading,
    required this.onRestore,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextButton(
          onPressed: isLoading ? null : onRestore,
          child: Text(
            'Restore Purchase',
            style: AppTypography.caption
                .copyWith(color: AppColors.champagneGold),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: () => _openLegalPage(context, 'Privacy Policy'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
              ),
              child: Text('Privacy Policy',
                  style: AppTypography.caption
                      .copyWith(fontSize: 12)),
            ),
            Text('·',
                style:
                    AppTypography.caption.copyWith(color: AppColors.slateMist)),
            TextButton(
              onPressed: () => _openLegalPage(context, 'Terms of Service'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
              ),
              child: Text('Terms of Service',
                  style: AppTypography.caption
                      .copyWith(fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Subscription auto-renews unless cancelled 24h before renewal.\nWomen always message free on NOOR.',
          style: AppTypography.caption
              .copyWith(fontSize: 11, height: 1.5),
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
