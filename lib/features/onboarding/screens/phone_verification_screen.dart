// lib/features/onboarding/screens/phone_verification_screen.dart
// ============================================================
// NOOR — Phone Verification Screen
// Mock OTP flow: any 6-digit code auto-verifies.
// Country code selector (80+ countries, searchable) →
// phone field (auto-detects code from +prefix) → OTP field.
// ============================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/cubits/auth/auth_cubit.dart';
import '../../../core/cubits/auth/auth_state.dart';
import '../../../core/cubits/onboarding/onboarding_cubit.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/buttons/noor_primary_button.dart';
import '../../../core/widgets/inputs/noor_text_field.dart';

// ── Country code data ─────────────────────────────────────────

class _CountryCode {
  const _CountryCode(this.name, this.flag, this.dialCode);
  final String name;
  final String flag;
  final String dialCode;
}

/// 80+ countries covering all Muslim-majority nations + major diaspora
/// destinations. Sorted alphabetically by display name.
const _kCountryCodes = <_CountryCode>[
  _CountryCode('Afghanistan',       '🇦🇫', '+93'),
  _CountryCode('Albania',           '🇦🇱', '+355'),
  _CountryCode('Algeria',           '🇩🇿', '+213'),
  _CountryCode('Australia',         '🇦🇺', '+61'),
  _CountryCode('Azerbaijan',        '🇦🇿', '+994'),
  _CountryCode('Bahrain',           '🇧🇭', '+973'),
  _CountryCode('Bangladesh',        '🇧🇩', '+880'),
  _CountryCode('Belgium',           '🇧🇪', '+32'),
  _CountryCode('Bosnia & Herz.',    '🇧🇦', '+387'),
  _CountryCode('Brunei',            '🇧🇳', '+673'),
  _CountryCode('Canada',            '🇨🇦', '+1'),
  _CountryCode('Egypt',             '🇪🇬', '+20'),
  _CountryCode('Ethiopia',          '🇪🇹', '+251'),
  _CountryCode('France',            '🇫🇷', '+33'),
  _CountryCode('Germany',           '🇩🇪', '+49'),
  _CountryCode('Ghana',             '🇬🇭', '+233'),
  _CountryCode('India',             '🇮🇳', '+91'),
  _CountryCode('Indonesia',         '🇮🇩', '+62'),
  _CountryCode('Iran',              '🇮🇷', '+98'),
  _CountryCode('Iraq',              '🇮🇶', '+964'),
  _CountryCode('Ireland',           '🇮🇪', '+353'),
  _CountryCode('Italy',             '🇮🇹', '+39'),
  _CountryCode('Jordan',            '🇯🇴', '+962'),
  _CountryCode('Kazakhstan',        '🇰🇿', '+7'),
  _CountryCode('Kenya',             '🇰🇪', '+254'),
  _CountryCode('Kosovo',            '🇽🇰', '+383'),
  _CountryCode('Kuwait',            '🇰🇼', '+965'),
  _CountryCode('Kyrgyzstan',        '🇰🇬', '+996'),
  _CountryCode('Lebanon',           '🇱🇧', '+961'),
  _CountryCode('Libya',             '🇱🇾', '+218'),
  _CountryCode('Malaysia',          '🇲🇾', '+60'),
  _CountryCode('Maldives',          '🇲🇻', '+960'),
  _CountryCode('Mali',              '🇲🇱', '+223'),
  _CountryCode('Mauritania',        '🇲🇷', '+222'),
  _CountryCode('Morocco',           '🇲🇦', '+212'),
  _CountryCode('Myanmar',           '🇲🇲', '+95'),
  _CountryCode('Netherlands',       '🇳🇱', '+31'),
  _CountryCode('New Zealand',       '🇳🇿', '+64'),
  _CountryCode('Niger',             '🇳🇪', '+227'),
  _CountryCode('Nigeria',           '🇳🇬', '+234'),
  _CountryCode('Norway',            '🇳🇴', '+47'),
  _CountryCode('Oman',              '🇴🇲', '+968'),
  _CountryCode('Pakistan',          '🇵🇰', '+92'),
  _CountryCode('Palestine',         '🇵🇸', '+970'),
  _CountryCode('Philippines',       '🇵🇭', '+63'),
  _CountryCode('Qatar',             '🇶🇦', '+974'),
  _CountryCode('Saudi Arabia',      '🇸🇦', '+966'),
  _CountryCode('Senegal',           '🇸🇳', '+221'),
  _CountryCode('Sierra Leone',      '🇸🇱', '+232'),
  _CountryCode('Singapore',         '🇸🇬', '+65'),
  _CountryCode('Somalia',           '🇸🇴', '+252'),
  _CountryCode('South Africa',      '🇿🇦', '+27'),
  _CountryCode('Spain',             '🇪🇸', '+34'),
  _CountryCode('Sri Lanka',         '🇱🇰', '+94'),
  _CountryCode('Sudan',             '🇸🇩', '+249'),
  _CountryCode('Sweden',            '🇸🇪', '+46'),
  _CountryCode('Syria',             '🇸🇾', '+963'),
  _CountryCode('Tajikistan',        '🇹🇯', '+992'),
  _CountryCode('Tanzania',          '🇹🇿', '+255'),
  _CountryCode('Thailand',          '🇹🇭', '+66'),
  _CountryCode('Tunisia',           '🇹🇳', '+216'),
  _CountryCode('Turkey',            '🇹🇷', '+90'),
  _CountryCode('UAE',               '🇦🇪', '+971'),
  _CountryCode('Uganda',            '🇺🇬', '+256'),
  _CountryCode('UK',                '🇬🇧', '+44'),
  _CountryCode('USA',               '🇺🇸', '+1'),
  _CountryCode('Uzbekistan',        '🇺🇿', '+998'),
  _CountryCode('Yemen',             '🇾🇪', '+967'),
];

// ── Screen ────────────────────────────────────────────────────

class PhoneVerificationScreen extends StatefulWidget {
  const PhoneVerificationScreen({super.key});

  @override
  State<PhoneVerificationScreen> createState() =>
      _PhoneVerificationScreenState();
}

class _PhoneVerificationScreenState extends State<PhoneVerificationScreen> {
  _CountryCode _selectedCode = _kCountryCodes
      .firstWhere((c) => c.name == 'India', orElse: () => _kCountryCodes.first);
  final _phoneController = TextEditingController();
  bool _otpSent     = false;
  int  _resendSecs  = 60;
  Timer? _resendTimer;

  @override
  void dispose() {
    _phoneController.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    setState(() => _resendSecs = 60);
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_resendSecs <= 0) {
        t.cancel();
      } else {
        setState(() => _resendSecs--);
      }
    });
  }

  void _sendOtp() {
    final fullPhone =
        '${_selectedCode.dialCode}${_phoneController.text.trim()}';
    context.read<AuthCubit>().sendOtp(fullPhone);
    setState(() => _otpSent = true);
    _startResendTimer();
  }

  void _resendOtp() {
    if (_resendSecs > 0) return;
    _sendOtp();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          // Router will automatically redirect to onboarding step 0
          context.read<OnboardingCubit>().initialize(
            startStep: state.onboardingStep,
          );
        }
        if (state is AuthError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:          Text(state.message),
              backgroundColor:  AppColors.softCoral,
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.obsidianNight,
        body: SafeArea(
          child: Column(
            children: [
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
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
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
                    Text(
                      _otpSent ? 'Enter your code' : 'Your phone number',
                      style: AppTypography.screenTitle,
                    ),
                    const SizedBox(height: AppDimensions.space8),
                    Text(
                      _otpSent
                          ? 'We sent a 6-digit code to '
                            '${_selectedCode.dialCode} ${_phoneController.text}.\n'
                            '(Mock: any 6 digits work)'
                          : 'We\'ll send a one-time code to verify.',
                      style: AppTypography.bodyMuted,
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.space24,
                    vertical:   AppDimensions.space32,
                  ),
                  child: AnimatedSwitcher(
                    duration: AppDimensions.durationReveal,
                    child: _otpSent
                        ? _OtpSection(
                            key: const ValueKey('otp'),
                            resendSeconds: _resendSecs,
                            onResend:      _resendOtp,
                          )
                        : _PhoneSection(
                            key:            const ValueKey('phone'),
                            selectedCode:   _selectedCode,
                            controller:     _phoneController,
                            onCodeChanged:  (c) =>
                                setState(() => _selectedCode = c),
                          ),
                  ),
                ),
              ),

              // ── CTA ──────────────────────────────────────
              if (!_otpSent)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimensions.space24,
                    0,
                    AppDimensions.space24,
                    AppDimensions.space32,
                  ),
                  child: BlocBuilder<AuthCubit, AuthState>(
                    builder: (context, state) => NoorPrimaryButton(
                      label:     'Send Code',
                      isLoading: state is AuthLoading,
                      onTap:     state is AuthLoading ? null : _sendOtp,
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

// ── Phone entry section ───────────────────────────────────────

class _PhoneSection extends StatefulWidget {
  const _PhoneSection({
    super.key,
    required this.selectedCode,
    required this.controller,
    required this.onCodeChanged,
  });

  final _CountryCode selectedCode;
  final TextEditingController controller;
  final ValueChanged<_CountryCode> onCodeChanged;

  @override
  State<_PhoneSection> createState() => _PhoneSectionState();
}

class _PhoneSectionState extends State<_PhoneSection> {
  void _showCountryPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF12121A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _CountryPickerSheet(
        selected:   widget.selectedCode,
        onSelected: (c) {
          widget.onCodeChanged(c);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  /// Auto-detects the dial code when the user types a number starting with '+'.
  /// Tries 4-digit code first, then 3, 2, 1 after the '+'.
  void _onPhoneChanged(String text) {
    if (!text.startsWith('+')) return;
    final digits = text.substring(1); // strip leading '+'
    for (final len in [4, 3, 2, 1]) {
      if (digits.length < len) continue;
      final candidate = '+${digits.substring(0, len)}';
      final match = _kCountryCodes.where(
        (c) => c.dialCode == candidate,
      );
      if (match.isNotEmpty) {
        widget.onCodeChanged(match.first);
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('COUNTRY CODE', style: AppTypography.sectionLabel),
        const SizedBox(height: AppDimensions.space8),
        GestureDetector(
          onTap: () => _showCountryPicker(context),
          child: Container(
            height: AppDimensions.buttonHeight,
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppDimensions.space16, 0, AppDimensions.space16, 0,
            ),
            decoration: BoxDecoration(
              color:        AppColors.surfaceGlass,
              borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
            ),
            child: Row(
              children: [
                Text(widget.selectedCode.flag,
                    style: const TextStyle(fontSize: 22)),
                const SizedBox(width: AppDimensions.space12),
                Text(
                  '${widget.selectedCode.name}  ${widget.selectedCode.dialCode}',
                  style: AppTypography.inputText,
                ),
                const Spacer(),
                const Icon(Icons.expand_more_rounded,
                    color: AppColors.slateMist),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppDimensions.space20),
        Text('PHONE NUMBER', style: AppTypography.sectionLabel),
        const SizedBox(height: AppDimensions.space8),
        NoorTextField(
          controller:      widget.controller,
          hint:            'Enter phone number or +country-code',
          keyboardType:    TextInputType.phone,
          textInputAction: TextInputAction.done,
          autofocus:       true,
          onChanged:       _onPhoneChanged,
        ),
      ],
    );
  }
}

// ── OTP entry section ─────────────────────────────────────────

class _OtpSection extends StatelessWidget {
  const _OtpSection({
    super.key,
    required this.resendSeconds,
    required this.onResend,
  });

  final int resendSeconds;
  final VoidCallback onResend;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        BlocBuilder<AuthCubit, AuthState>(
          builder: (context, state) {
            final isLoading = state is AuthLoading;
            return NoorOtpField(
              onCompleted: (code) {
                if (!isLoading) {
                  context.read<AuthCubit>().verifyOtp(code);
                }
              },
            );
          },
        ),
        const SizedBox(height: AppDimensions.space32),
        BlocBuilder<AuthCubit, AuthState>(
          builder: (context, state) {
            final isLoading = state is AuthLoading;
            if (isLoading) {
              return const SizedBox(
                width: 24, height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.champagneGold,
                ),
              );
            }
            return GestureDetector(
              onTap: resendSeconds == 0 ? onResend : null,
              child: Text(
                resendSeconds > 0
                    ? 'Resend code in ${resendSeconds}s'
                    : 'Resend code',
                style: AppTypography.bodyMuted.copyWith(
                  color: resendSeconds == 0
                      ? AppColors.champagneGold
                      : AppColors.slateMist,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

// ── Country picker bottom sheet ───────────────────────────────

class _CountryPickerSheet extends StatefulWidget {
  const _CountryPickerSheet({
    required this.selected,
    required this.onSelected,
  });

  final _CountryCode selected;
  final ValueChanged<_CountryCode> onSelected;

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  final _searchCtrl = TextEditingController();
  List<_CountryCode> _filtered = List.unmodifiable(_kCountryCodes);

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch(String q) {
    final lower = q.trim().toLowerCase();
    setState(() {
      _filtered = lower.isEmpty
          ? List.unmodifiable(_kCountryCodes)
          : _kCountryCodes
              .where((c) =>
                  c.name.toLowerCase().contains(lower) ||
                  c.dialCode.contains(lower))
              .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppDimensions.space16),
            // Drag handle
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color:        AppColors.slateMist.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppDimensions.space16),
            Text('Select country code', style: AppTypography.bodyMedium),
            const SizedBox(height: AppDimensions.space12),

            // Search field
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.space16,
              ),
              child: TextField(
                controller:  _searchCtrl,
                onChanged:   _onSearch,
                autofocus:   false,
                style:       AppTypography.inputText,
                decoration: InputDecoration(
                  hintText:  'Search country or dial code',
                  hintStyle: AppTypography.inputLabel,
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: AppColors.slateMist,
                    size:  20,
                  ),
                  filled:          true,
                  fillColor:       AppColors.surfaceGlass,
                  contentPadding:  const EdgeInsets.symmetric(
                    horizontal: AppDimensions.space12,
                    vertical:   AppDimensions.space10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                    borderSide:   const BorderSide(color: AppColors.cardBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                    borderSide:   const BorderSide(color: AppColors.cardBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                    borderSide:   const BorderSide(
                      color: AppColors.champagneGold,
                      width: AppDimensions.borderFocus,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: AppDimensions.space8),
            Flexible(
              child: _filtered.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(AppDimensions.space24),
                      child: Text(
                        'No countries found.',
                        style: AppTypography.bodyMuted,
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const BouncingScrollPhysics(),
                      itemCount: _filtered.length,
                      itemBuilder: (context, i) {
                        final code = _filtered[i];
                        final isSelected =
                            code.dialCode == widget.selected.dialCode &&
                            code.name     == widget.selected.name;
                        return ListTile(
                          leading: Text(code.flag,
                              style: const TextStyle(fontSize: 24)),
                          title: Text(code.name, style: AppTypography.body),
                          trailing: Text(code.dialCode,
                              style: AppTypography.bodyMuted),
                          selected:      isSelected,
                          selectedColor: AppColors.champagneGold,
                          onTap:         () => widget.onSelected(code),
                        );
                      },
                    ),
            ),
            const SizedBox(height: AppDimensions.space16),
          ],
        ),
      ),
    );
  }
}
