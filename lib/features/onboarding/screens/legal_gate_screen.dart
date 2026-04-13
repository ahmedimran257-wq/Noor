// lib/features/onboarding/screens/legal_gate_screen.dart
// ============================================================
// NOOR — Legal Gate Screen
// Two mandatory checkboxes (age + terms).
// Cannot proceed without both checked.
// Consent version logged (in production: to user_consents table).
// ============================================================

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/buttons/noor_primary_button.dart';
import '../../../core/router/app_router.dart';

class LegalGateScreen extends StatefulWidget {
  const LegalGateScreen({super.key});

  @override
  State<LegalGateScreen> createState() => _LegalGateScreenState();
}

class _LegalGateScreenState extends State<LegalGateScreen> {
  bool _ageConfirmed   = false;
  bool _termsConfirmed = false;

  bool get _canProceed => _ageConfirmed && _termsConfirmed;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.obsidianNight,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ─────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.space24,
                AppDimensions.space32,
                AppDimensions.space24,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color:  AppColors.surfaceGlass,
                        shape:  BoxShape.circle,
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: Icon(
                        Directionality.of(context) == TextDirection.rtl
                            ? Icons.arrow_forward_ios_rounded
                            : Icons.arrow_back_ios_new_rounded,
                        color: AppColors.pearlWhite,
                        size:  16,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppDimensions.space32),
                  Text('A dignified beginning',
                      style: AppTypography.screenTitle),
                  const SizedBox(height: AppDimensions.space8),
                  Text(
                    'Please read and agree to continue.',
                    style: AppTypography.bodyMuted,
                  ),
                ],
              ),
            ),

            // ── Scrollable body ────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.space24,
                  vertical:   AppDimensions.space24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TermsSummaryCard(),
                    const SizedBox(height: AppDimensions.space24),

                    // ── Checkboxes ─────────────────────────
                    _NoorCheckbox(
                      value:    _ageConfirmed,
                      onChanged: (v) => setState(() => _ageConfirmed = v ?? false),
                      label:    'I confirm that I am 18 years of age or older.',
                    ),
                    const SizedBox(height: AppDimensions.space16),
                    _NoorCheckbox(
                      value:    _termsConfirmed,
                      onChanged: (v) => setState(() => _termsConfirmed = v ?? false),
                      label:    'I have read and agree to the',
                      richSuffix: TextSpan(
                        children: [
                          TextSpan(
                            text:       ' Terms of Service',
                            style:      AppTypography.body.copyWith(
                              color: AppColors.champagneGold,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () {
                                // TODO: open ToS bottom sheet / web view
                              },
                          ),
                          TextSpan(
                            text:  ' and ',
                            style: AppTypography.body,
                          ),
                          TextSpan(
                            text:       'Privacy Policy',
                            style:      AppTypography.body.copyWith(
                              color: AppColors.champagneGold,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () {
                                // TODO: open Privacy Policy
                              },
                          ),
                          TextSpan(
                            text:  '.',
                            style: AppTypography.body,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppDimensions.space48),
                  ],
                ),
              ),
            ),

            // ── Bottom CTA ─────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.space24,
                0,
                AppDimensions.space24,
                AppDimensions.space32,
              ),
              child: AnimatedOpacity(
                opacity:  _canProceed ? 1.0 : 0.45,
                duration: AppDimensions.durationTransition,
                child: NoorPrimaryButton(
                  label: 'Continue',
                  onTap: _canProceed
                      ? () => context.push(AppRoutes.phone)
                      : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Terms Summary Card ────────────────────────────────────────

class _TermsSummaryCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const items = [
      (
        icon: Icons.security_outlined,
        text: 'Your data is encrypted and never sold to third parties.',
      ),
      (
        icon: Icons.photo_camera_outlined,
        text: 'Your photos are reviewed before your profile goes live.',
      ),
      (
        icon: Icons.block_outlined,
        text: 'Harassment, fake profiles, and scams result in permanent bans.',
      ),
      (
        icon: Icons.family_restroom_outlined,
        text: 'This platform is for marriage intentions only. Dignity is the standard.',
      ),
      (
        icon: Icons.delete_outline_rounded,
        text: 'You may delete your account and all data at any time.',
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(AppDimensions.space20),
      decoration: BoxDecoration(
        color:        AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border:       Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: items.map((item) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AppDimensions.space16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(item.icon, color: AppColors.champagneGold, size: 20),
                const SizedBox(width: AppDimensions.space12),
                Expanded(
                  child: Text(item.text, style: AppTypography.body),
                ),
              ],
            ),
          );
        }).toList()
          ..last = Padding(
            padding: EdgeInsets.zero,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.delete_outline_rounded,
                    color: AppColors.champagneGold, size: 20),
                const SizedBox(width: AppDimensions.space12),
                Expanded(
                  child: Text(
                    'You may delete your account and all data at any time.',
                    style: AppTypography.body,
                  ),
                ),
              ],
            ),
          ),
      ),
    );
  }
}

// ── Noor Checkbox ─────────────────────────────────────────────

class _NoorCheckbox extends StatelessWidget {
  const _NoorCheckbox({
    required this.value,
    required this.onChanged,
    required this.label,
    this.richSuffix,
  });

  final bool value;
  final ValueChanged<bool?> onChanged;
  final String label;
  final InlineSpan? richSuffix;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedContainer(
            duration: AppDimensions.durationTransition,
            width:  24,
            height: 24,
            decoration: BoxDecoration(
              color: value ? AppColors.champagneGold : AppColors.surfaceGlass,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: value ? AppColors.champagneGold : AppColors.slateMist,
                width: value ? 0 : 1,
              ),
            ),
            child: value
                ? const Icon(Icons.check_rounded,
                    color: AppColors.obsidianNight, size: 16)
                : null,
          ),
          const SizedBox(width: AppDimensions.space12),
          Expanded(
            child: richSuffix != null
                ? RichText(
                    text: TextSpan(
                      text:  label,
                      style: AppTypography.body,
                      children: [richSuffix!],
                    ),
                  )
                : Text(label, style: AppTypography.body),
          ),
        ],
      ),
    );
  }
}
