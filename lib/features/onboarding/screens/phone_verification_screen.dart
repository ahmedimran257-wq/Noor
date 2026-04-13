// lib/features/onboarding/screens/phone_verification_screen.dart
// ============================================================
// NOOR — Phone Verification Screen
// Mock OTP flow: any 6-digit code auto-verifies.
// Country code selector → phone field → OTP field with timer.
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

/// Country code data (simplified list for Phase 1 markets).
class _CountryCode {
  const _CountryCode(this.name, this.flag, this.dialCode);
  final String name;
  final String flag;
  final String dialCode;
}

const _kCountryCodes = <_CountryCode>[
  _CountryCode('India',        '🇮🇳', '+91'),
  _CountryCode('Pakistan',     '🇵🇰', '+92'),
  _CountryCode('Bangladesh',   '🇧🇩', '+880'),
  _CountryCode('UK',           '🇬🇧', '+44'),
  _CountryCode('USA',          '🇺🇸', '+1'),
  _CountryCode('Canada',       '🇨🇦', '+1'),
  _CountryCode('UAE',          '🇦🇪', '+971'),
  _CountryCode('Saudi Arabia', '🇸🇦', '+966'),
  _CountryCode('Malaysia',     '🇲🇾', '+60'),
  _CountryCode('Indonesia',    '🇮🇩', '+62'),
  _CountryCode('Turkey',       '🇹🇷', '+90'),
  _CountryCode('Egypt',        '🇪🇬', '+20'),
  _CountryCode('Nigeria',      '🇳🇬', '+234'),
  _CountryCode('Germany',      '🇩🇪', '+49'),
  _CountryCode('France',       '🇫🇷', '+33'),
];

class PhoneVerificationScreen extends StatefulWidget {
  const PhoneVerificationScreen({super.key});

  @override
  State<PhoneVerificationScreen> createState() =>
      _PhoneVerificationScreenState();
}

class _PhoneVerificationScreenState extends State<PhoneVerificationScreen> {
  _CountryCode _selectedCode = _kCountryCodes.first;
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

class _PhoneSection extends StatelessWidget {
  const _PhoneSection({
    super.key,
    required this.selectedCode,
    required this.controller,
    required this.onCodeChanged,
  });

  final _CountryCode selectedCode;
  final TextEditingController controller;
  final ValueChanged<_CountryCode> onCodeChanged;

  void _showCountryPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF12121A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _CountryPickerSheet(
        selected:   selectedCode,
        onSelected: (c) {
          onCodeChanged(c);
          Navigator.of(context).pop();
        },
      ),
    );
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
                Text(selectedCode.flag, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: AppDimensions.space12),
                Text(
                  '${selectedCode.name}  ${selectedCode.dialCode}',
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
          controller:      controller,
          hint:            'Enter phone number',
          keyboardType:    TextInputType.phone,
          textInputAction: TextInputAction.done,
          autofocus:       true,
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

class _CountryPickerSheet extends StatelessWidget {
  const _CountryPickerSheet({
    required this.selected,
    required this.onSelected,
  });

  final _CountryCode selected;
  final ValueChanged<_CountryCode> onSelected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: AppDimensions.space16),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color:        AppColors.slateMist.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: AppDimensions.space16),
          Text('Select country code', style: AppTypography.bodyMedium),
          const SizedBox(height: AppDimensions.space16),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              physics: const BouncingScrollPhysics(),
              itemCount: _kCountryCodes.length,
              itemBuilder: (context, i) {
                final code = _kCountryCodes[i];
                final isSelected = code.dialCode == selected.dialCode &&
                    code.name == selected.name;
                return ListTile(
                  leading: Text(code.flag,
                      style: const TextStyle(fontSize: 24)),
                  title: Text(code.name, style: AppTypography.body),
                  trailing: Text(code.dialCode,
                      style: AppTypography.bodyMuted),
                  selected:      isSelected,
                  selectedColor: AppColors.champagneGold,
                  onTap:         () => onSelected(code),
                );
              },
            ),
          ),
          const SizedBox(height: AppDimensions.space16),
        ],
      ),
    );
  }
}
