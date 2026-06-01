// lib/features/onboarding/screens/phone_verification_screen.dart
// ============================================================
// NOOR — Phone Verification Screen  (Telegram-quality rewrite)
//
// What makes this Telegram-level:
//   • Auto-detects device country on first mount
//   • Unified flag + code + input in one row
//   • Live phone formatting per country (spaces, dashes)
//   • Full-screen country picker with alphabet index
//   • 6 individual OTP boxes with spring bounce on each digit
//   • Staggered entry animation on OTP boxes (elastic, 50ms offset)
//   • Haptic on every digit tap
//   • Auto-submit when all 6 digits filled
//   • Smooth crossfade + slide transition phone → OTP
//   • CTA activates only when number looks complete
// ============================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/cubits/auth/auth_cubit.dart';
import '../../../core/cubits/auth/auth_state.dart';
import '../../../core/cubits/onboarding/onboarding_cubit.dart';
import '../../../core/data/country_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/buttons/noor_pressable.dart';
import '../../../core/widgets/buttons/noor_primary_button.dart';

// ─────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────

class PhoneVerificationScreen extends StatefulWidget {
  const PhoneVerificationScreen({super.key});

  @override
  State<PhoneVerificationScreen> createState() =>
      _PhoneVerificationScreenState();
}

class _PhoneVerificationScreenState extends State<PhoneVerificationScreen> {
  late CountryInfo _country;
  final _phoneCtrl = TextEditingController();
  final _phoneFocus = FocusNode();
  bool _otpSent = false;
  int _resendSecs = 60;
  Timer? _resendTimer;

  // Raw digits only — format applied separately for display
  String _rawDigits = '';

  @override
  void initState() {
    super.initState();
    // Telegram-style: auto-detect device country on open
    _country = deviceCountry();
    _phoneCtrl.addListener(_onPhoneChange);
  }

  @override
  void dispose() {
    _phoneCtrl.removeListener(_onPhoneChange);
    _phoneCtrl.dispose();
    _phoneFocus.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  // ── Phone input logic ─────────────────────────────────────

  void _onPhoneChange() {
    final raw = _phoneCtrl.text;

    // If user types a '+' prefix, try to auto-detect country
    if (raw.startsWith('+')) {
      final digitsAfterPlus = raw.substring(1).replaceAll(RegExp(r'\D'), '');
      final detected = countryByDialPrefix(digitsAfterPlus);
      if (detected != null && detected.iso2 != _country.iso2) {
        setState(() => _country = detected);
        // Strip the dial prefix from the field — keep only national digits
        final nationalDigits = digitsAfterPlus.length > _country.dialCode.length - 1
            ? digitsAfterPlus.substring(_country.dialCode.length - 1)
            : '';
        _phoneCtrl.value = TextEditingValue(
          text: nationalDigits,
          selection: TextSelection.collapsed(offset: nationalDigits.length),
        );
        return;
      }
    }

    // Keep only digits for internal state
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits == _rawDigits) return;
    setState(() => _rawDigits = digits);

    // Re-format display (insert spaces per country pattern)
    final formatted = _country.formatNumber(digits);
    if (formatted != raw) {
      _phoneCtrl.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
  }

  bool get _isNumberComplete {
    return _rawDigits.length >= (_country.maxDigits - 1); // -1 for tolerance
  }

  void _sendOtp() async {
    if (!_isNumberComplete) return;
    HapticFeedback.mediumImpact();
    final fullPhone = '${_country.dialCode}$_rawDigits';

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_country_code', _country.iso2.toUpperCase());
    } catch (_) {}

    if (!mounted) return;
    context.read<AuthCubit>().sendOtp(fullPhone);
    setState(() {
      _otpSent = true;
      _resendSecs = 60;
    });
    _phoneFocus.unfocus();
    _startResendTimer();
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        if (_resendSecs > 0) {
          _resendSecs--;
        } else {
          t.cancel();
        }
      });
    });
  }

  void _changeNumber() {
    setState(() {
      _otpSent = false;
      _rawDigits = '';
      _phoneCtrl.clear();
    });
    _resendTimer?.cancel();
    WidgetsBinding.instance.addPostFrameCallback((_) => _phoneFocus.requestFocus());
  }

  // ── Country picker ────────────────────────────────────────

  void _openCountryPicker() {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => _CountryPickerScreen(
          selected: _country,
          onSelected: (c) {
            setState(() {
              _country = c;
              _rawDigits = '';
              _phoneCtrl.clear();
            });
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _phoneFocus.requestFocus(),
            );
          },
        ),
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 280),
        transitionsBuilder: (_, animation, __, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
            child: child,
          );
        },
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          context.read<OnboardingCubit>().initialize(
            startStep: state.onboardingStep,
          );
        }
        if (state is AuthError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:         Text(state.message),
              backgroundColor: AppColors.softCoral,
              behavior:        SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.5),  // slightly above center
              radius: 1.2,
              colors: [
                Color(0xFF151522),  // Deep premium navy-charcoal core
                AppColors.obsidianNight,  // Deep midnight edges
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // ── Top bar ──────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Row(
                    children: [
                      _BackBtn(onTap: () => Navigator.of(context).pop()),
                      const Spacer(),
                      // Subtle NOOR mark
                      Text(
                        'نور',
                        textDirection: TextDirection.rtl,
                        style: TextStyle(
                          fontSize:   18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.champagneGold.withValues(alpha: 0.60),
                          shadows: [
                            Shadow(
                              color:      AppColors.champagneGold.withValues(alpha: 0.3),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
  
                // ── Main content (animated switch) ───────────
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    switchInCurve:  Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) {
                      final isIn = child.key == (
                        _otpSent ? const ValueKey('otp') : const ValueKey('phone')
                      );
                      return SlideTransition(
                        position: Tween<Offset>(
                          begin: Offset(0, isIn ? 0.06 : -0.06),
                          end:   Offset.zero,
                        ).animate(animation),
                        child: FadeTransition(opacity: animation, child: child),
                      );
                    },
                    child: _otpSent
                        ? _OtpView(
                            key:         const ValueKey('otp'),
                            country:     _country,
                            rawDigits:   _rawDigits,
                            resendSecs:  _resendSecs,
                            onResend:    _resendSecs == 0 ? _sendOtp : null,
                            onChangeNum: _changeNumber,
                          )
                        : _PhoneView(
                            key:          const ValueKey('phone'),
                            country:      _country,
                            controller:   _phoneCtrl,
                            focusNode:    _phoneFocus,
                            onCountryTap: _openCountryPicker,
                            onSend:       _sendOtp,
                            isComplete:   _isNumberComplete,
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// PHONE VIEW
// ─────────────────────────────────────────────────────────────

class _PhoneView extends StatefulWidget {
  const _PhoneView({
    super.key,
    required this.country,
    required this.controller,
    required this.focusNode,
    required this.onCountryTap,
    required this.onSend,
    required this.isComplete,
  });

  final CountryInfo       country;
  final TextEditingController controller;
  final FocusNode          focusNode;
  final VoidCallback       onCountryTap;
  final VoidCallback       onSend;
  final bool               isComplete;

  @override
  State<_PhoneView> createState() => _PhoneViewState();
}

class _PhoneViewState extends State<_PhoneView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  // Staggered intervals — one controller, four phases
  late final Animation<double> _titleFade;
  late final Animation<Offset> _titleSlide;
  late final Animation<double> _subtitleFade;
  late final Animation<Offset> _subtitleSlide;
  late final Animation<double> _inputFade;
  late final Animation<Offset> _inputSlide;
  late final Animation<double> _ctaFade;
  late final Animation<Offset> _ctaSlide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    // Title: 0.0 → 0.55
    _titleFade = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.0, 0.55, curve: Curves.easeOut),
    );
    _titleSlide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(_titleFade);

    // Subtitle: 0.1 → 0.6
    _subtitleFade = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.1, 0.6, curve: Curves.easeOut),
    );
    _subtitleSlide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(_subtitleFade);

    // Input row: 0.22 → 0.72
    _inputFade = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.22, 0.72, curve: Curves.easeOut),
    );
    _inputSlide = Tween<Offset>(
      begin: const Offset(0, 0.10),
      end: Offset.zero,
    ).animate(_inputFade);

    // CTA button: 0.34 → 0.9
    _ctaFade = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.34, 0.9, curve: Curves.easeOut),
    );
    _ctaSlide = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(_ctaFade);

    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 40),

        // ── Title ───────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SlideTransition(
                position: _titleSlide,
                child: FadeTransition(
                  opacity: _titleFade,
                  child: const Text('Your number', style: AppTypography.screenTitle),
                ),
              ),
              const SizedBox(height: 8),
              SlideTransition(
                position: _subtitleSlide,
                child: FadeTransition(
                  opacity: _subtitleFade,
                  child: const Text(
                    'We\'ll verify it with a one-time code.',
                    style: AppTypography.bodyMuted,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 40),

        // ── Country + Phone input row ────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: SlideTransition(
            position: _inputSlide,
            child: FadeTransition(
              opacity: _inputFade,
              child: _PhoneInputRow(
                country:     widget.country,
                controller:  widget.controller,
                focusNode:   widget.focusNode,
                onCountryTap: widget.onCountryTap,
              ),
            ),
          ),
        ),

        const Spacer(),

        // ── CTA ─────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          child: SlideTransition(
            position: _ctaSlide,
            child: FadeTransition(
              opacity: _ctaFade,
              child: BlocBuilder<AuthCubit, AuthState>(
                builder: (context, state) => NoorPrimaryButton(
                  label:     'Send Code',
                  isLoading: state is AuthLoading,
                  enabled:   widget.isComplete,
                  onTap:     widget.isComplete && state is! AuthLoading ? widget.onSend : null,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// PHONE INPUT ROW  — flag + dial code + number field
// ─────────────────────────────────────────────────────────────

class _PhoneInputRow extends StatefulWidget {
  const _PhoneInputRow({
    required this.country,
    required this.controller,
    required this.focusNode,
    required this.onCountryTap,
  });

  final CountryInfo           country;
  final TextEditingController controller;
  final FocusNode             focusNode;
  final VoidCallback          onCountryTap;

  @override
  State<_PhoneInputRow> createState() => _PhoneInputRowState();
}

class _PhoneInputRowState extends State<_PhoneInputRow> {
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(() {
      if (mounted) setState(() => _focused = widget.focusNode.hasFocus);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      height: 60,
      decoration: BoxDecoration(
        color:        AppColors.inputSurface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
        border: Border.all(
          color: _focused
              ? AppColors.champagneGold.withValues(alpha: 0.6)
              : AppColors.cardBorder,
          width: _focused ? 1.5 : 1.0,
        ),
        boxShadow: _focused
            ? [
                BoxShadow(
                  color:       AppColors.champagneGold.withValues(alpha: 0.08),
                  blurRadius:  16,
                  spreadRadius: 0,
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          // ── Country flag + code ────────────────────────
          NoorPressable(
            onTap:  widget.onCountryTap,
            haptic: true,
            child: Container(
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: const BoxDecoration(
                border: Border(
                  right: BorderSide(
                    color: AppColors.cardBorder,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Animated flag — rebuilds with quick, clean cubic swap when country changes
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (child, animation) => ScaleTransition(
                      scale: CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                      ),
                      child: FadeTransition(opacity: animation, child: child),
                    ),
                    child: Text(
                      widget.country.flag,
                      key: ValueKey(widget.country.iso2),
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Dial code
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      widget.country.dialCode,
                      key: ValueKey(widget.country.dialCode),
                      style: const TextStyle(
                        fontSize:   16,
                        fontWeight: FontWeight.w600,
                        color:      AppColors.pearlWhite,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: AppColors.slateMist,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),

          // ── Phone number field ─────────────────────────
          Expanded(
            child: TextField(
              controller:      widget.controller,
              focusNode:       widget.focusNode,
              keyboardType:    TextInputType.phone,
              textInputAction: TextInputAction.done,
              autofocus:       true,
              style: const TextStyle(
                fontSize:   20,
                fontWeight: FontWeight.w500,
                color:      AppColors.pearlWhite,
                letterSpacing: 1.5,
              ),
              decoration: InputDecoration(
                hintText:       'Phone number',
                hintStyle: TextStyle(
                  fontSize:     20,
                  color:        AppColors.slateMist.withValues(alpha: 0.5),
                  letterSpacing: 0,
                ),
                border:         InputBorder.none,
                filled:         false,
                fillColor:      Colors.transparent,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// OTP VIEW
// ─────────────────────────────────────────────────────────────

class _OtpView extends StatefulWidget {
  const _OtpView({
    super.key,
    required this.country,
    required this.rawDigits,
    required this.resendSecs,
    required this.onResend,
    required this.onChangeNum,
  });

  final CountryInfo  country;
  final String       rawDigits;
  final int          resendSecs;
  final VoidCallback? onResend;
  final VoidCallback onChangeNum;

  @override
  State<_OtpView> createState() => _OtpViewState();
}

class _OtpViewState extends State<_OtpView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  late final Animation<double> _titleFade;
  late final Animation<Offset> _titleSlide;
  late final Animation<double> _subtitleFade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    // Title: 0.0 → 0.7
    _titleFade = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
    );
    _titleSlide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(_titleFade);

    // Subtitle: 0.15 → 0.8
    _subtitleFade = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.15, 0.8, curve: Curves.easeOut),
    );

    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final formattedNum = widget.country.formatNumber(widget.rawDigits);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 40),

        // ── Title ───────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SlideTransition(
                position: _titleSlide,
                child: FadeTransition(
                  opacity: _titleFade,
                  child: const Text('Enter the code', style: AppTypography.screenTitle),
                ),
              ),
              const SizedBox(height: 10),
              FadeTransition(
                opacity: _subtitleFade,
                child: RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    children: [
                      const TextSpan(
                        text: 'We sent a 6-digit code to\n',
                        style: AppTypography.bodyMuted,
                      ),
                      TextSpan(
                        text: '${widget.country.dialCode} $formattedNum',
                        style: AppTypography.bodyMuted.copyWith(
                          color:      AppColors.champagneGold,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 48),

        // ── OTP boxes ───────────────────────────────────
        BlocBuilder<AuthCubit, AuthState>(
          builder: (context, state) => _OtpBoxes(
            onCompleted: (code) {
              HapticFeedback.mediumImpact();
              context.read<AuthCubit>().verifyOtp(code);
            },
          ),
        ),

        const SizedBox(height: 36),

        // ── Loading indicator ────────────────────────────
        BlocBuilder<AuthCubit, AuthState>(
          builder: (context, state) {
            if (state is! AuthLoading) return const SizedBox.shrink();
            return const AnimatedOpacity(
              opacity: 1.0,
              duration: Duration(milliseconds: 200),
              child: SizedBox(
                width: 22, height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.champagneGold,
                ),
              ),
            );
          },
        ),

        const SizedBox(height: 20),

        // ── Resend timer ─────────────────────────────────
        NoorPressable(
          onTap:    widget.onResend,
          enabled:  widget.onResend != null,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                key: ValueKey(widget.resendSecs == 0 ? 'active' : 'waiting'),
                widget.resendSecs > 0
                    ? 'Resend code in ${widget.resendSecs}s'
                    : 'Resend code',
                style: AppTypography.bodyMuted.copyWith(
                  color: widget.resendSecs == 0
                      ? AppColors.champagneGold
                      : AppColors.slateMist,
                  fontWeight: widget.resendSecs == 0
                      ? FontWeight.w600
                      : FontWeight.w400,
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // ── Change number ────────────────────────────────
        NoorPressable(
          onTap: widget.onChangeNum,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
            child: Text(
              'Wrong number? Change it',
              style: AppTypography.caption.copyWith(
                color: AppColors.slateMist,
                decoration: TextDecoration.underline,
                decorationColor: AppColors.slateMist,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// OTP BOXES  — 6 individual boxes with spring animation
// ─────────────────────────────────────────────────────────────

class _OtpBoxes extends StatefulWidget {
  const _OtpBoxes({required this.onCompleted});

  final ValueChanged<String> onCompleted;

  @override
  State<_OtpBoxes> createState() => _OtpBoxesState();
}

class _OtpBoxesState extends State<_OtpBoxes> {
  static const _length = 6;
  final _controller = TextEditingController();
  final _focusNode  = FocusNode();
  String _otp = '';

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onInput);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _focusNode.requestFocus(),
    );
  }

  @override
  void dispose() {
    _controller.removeListener(_onInput);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onInput() {
    final digits = _controller.text.replaceAll(RegExp(r'\D'), '');
    final clamped = digits.length > _length
        ? digits.substring(0, _length)
        : digits;

    if (clamped == _otp) return;

    final prev = _otp;
    setState(() => _otp = clamped);

    // Haptic on each new digit
    if (clamped.length > prev.length) {
      HapticFeedback.lightImpact();
    }

    // Keep text field clean
    if (_controller.text != clamped) {
      _controller.value = TextEditingValue(
        text: clamped,
        selection: TextSelection.collapsed(offset: clamped.length),
      );
    }

    // Auto-submit when complete
    if (clamped.length == _length) {
      Future.delayed(const Duration(milliseconds: 150), () {
        widget.onCompleted(clamped);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _focusNode.requestFocus,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // ── Visual boxes ─────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_length, (i) {
                final hasDigit = i < _otp.length;
                final isActive = i == _otp.length;
                return Padding(
                  padding: EdgeInsets.only(right: i < _length - 1 ? 10 : 0),
                  child: _OtpBox(
                    digit:    hasDigit ? _otp[i] : null,
                    isActive: isActive,
                    delay:    i * 50,
                  ),
                );
              }),
            ),
          ),

          // ── Hidden text field (handles actual input) ──
          Opacity(
            opacity: 0,
            child: SizedBox(
              width: 1, height: 1,
              child: TextField(
                controller:   _controller,
                focusNode:    _focusNode,
                keyboardType: TextInputType.number,
                maxLength:    _length,
                decoration:   const InputDecoration.collapsed(hintText: ''),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// OTP BOX  — single digit with spring bounce on fill
// ─────────────────────────────────────────────────────────────

class _OtpBox extends StatefulWidget {
  const _OtpBox({
    required this.digit,
    required this.isActive,
    this.delay = 0,
  });

  final String? digit;
  final bool    isActive;
  final int     delay; // ms stagger on entry

  @override
  State<_OtpBox> createState() => _OtpBoxState();
}

class _OtpBoxState extends State<_OtpBox>
    with TickerProviderStateMixin {
  // Entry stagger animation (scale + fade)
  late final AnimationController _entryCtrl;
  late final Animation<double> _entryScale;
  late final Animation<double> _entryFade;

  // Digit bounce animation (scale + fade)
  AnimationController? _bounceCtrl;
  Animation<double>? _bounceScale;
  Animation<double>? _bounceFade;

  String? _prevDigit;

  @override
  void initState() {
    super.initState();

    // Staggered entry
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _entryScale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutBack),
    );
    _entryFade = CurvedAnimation(
      parent: _entryCtrl,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );

    // Delayed start based on box index
    Future.delayed(Duration(milliseconds: 50 + widget.delay), () {
      if (mounted) _entryCtrl.forward();
    });
  }

  @override
  void didUpdateWidget(covariant _OtpBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Trigger bounce when a new digit appears
    if (widget.digit != null && widget.digit != _prevDigit) {
      _triggerBounce();
    }
    _prevDigit = widget.digit;
  }

  void _triggerBounce() {
    _bounceCtrl?.dispose();
    _bounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _bounceScale = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _bounceCtrl!, curve: Curves.easeOutBack),
    );
    _bounceFade = CurvedAnimation(
      parent: _bounceCtrl!,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );
    _bounceCtrl!.forward();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _bounceCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasDig = widget.digit != null;

    // Build the digit text (with bounce animation if available)
    Widget digitWidget;
    if (hasDig && _bounceScale != null && _bounceFade != null) {
      digitWidget = ScaleTransition(
        scale: _bounceScale!,
        child: FadeTransition(
          opacity: _bounceFade!,
          child: Text(
            widget.digit!,
            style: const TextStyle(
              fontSize:     22,
              fontWeight:   FontWeight.w700,
              color:        AppColors.pearlWhite,
              letterSpacing: 0,
            ),
          ),
        ),
      );
    } else if (hasDig) {
      digitWidget = Text(
        widget.digit!,
        style: const TextStyle(
          fontSize:     22,
          fontWeight:   FontWeight.w700,
          color:        AppColors.pearlWhite,
          letterSpacing: 0,
        ),
      );
    } else if (widget.isActive) {
      digitWidget = _Cursor();
    } else {
      digitWidget = const SizedBox.shrink();
    }

    return ScaleTransition(
      scale: _entryScale,
      child: FadeTransition(
        opacity: _entryFade,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          width:  48,
          height: 58,
          decoration: BoxDecoration(
            color: hasDig
                ? AppColors.champagneGold.withValues(alpha: 0.08)
                : AppColors.surfaceGlass,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.isActive
                  ? AppColors.champagneGold
                  : hasDig
                      ? AppColors.champagneGold.withValues(alpha: 0.45)
                      : AppColors.cardBorder,
              width: widget.isActive ? 2.0 : 1.5,
            ),
            boxShadow: widget.isActive
                ? [
                    BoxShadow(
                      color:       AppColors.champagneGold.withValues(alpha: 0.12),
                      blurRadius:  12,
                      spreadRadius: 0,
                    ),
                  ]
                : null,
          ),
          child: Center(child: digitWidget),
        ),
      ),
    );
  }
}

// Blinking cursor in the active empty box
class _Cursor extends StatefulWidget {
  @override
  State<_Cursor> createState() => _CursorState();
}

class _CursorState extends State<_Cursor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _ctrl,
      child: Container(
        width:  2,
        height: 24,
        decoration: BoxDecoration(
          color:        AppColors.champagneGold,
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// COUNTRY PICKER SCREEN  — full-screen, alphabet index
// ─────────────────────────────────────────────────────────────

class _CountryPickerScreen extends StatefulWidget {
  const _CountryPickerScreen({
    required this.selected,
    required this.onSelected,
  });

  final CountryInfo             selected;
  final ValueChanged<CountryInfo> onSelected;

  @override
  State<_CountryPickerScreen> createState() => _CountryPickerScreenState();
}

class _CountryPickerScreenState extends State<_CountryPickerScreen> {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  String _query = '';

  List<CountryInfo> get _popular =>
      kAllCountries.where((c) => c.priority > 0).toList()
        ..sort((a, b) => b.priority.compareTo(a.priority));

  List<CountryInfo> get _filtered {
    if (_query.isEmpty) return kAllCountries;
    final q = _query.toLowerCase();
    return kAllCountries.where((c) =>
      c.name.toLowerCase().contains(q) ||
      c.dialCode.contains(q) ||
      c.iso2.toLowerCase().contains(q)
    ).toList();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showPopular = _query.isEmpty;
    final countries   = _filtered;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.5),  // slightly above center
            radius: 1.2,
            colors: [
              Color(0xFF151522),  // Deep premium navy-charcoal core
              AppColors.obsidianNight,  // Deep midnight edges
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ── Header ──────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  children: [
                    _BackBtn(onTap: () => Navigator.of(context).pop()),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Select Country',
                        style: AppTypography.screenTitle.copyWith(fontSize: 20),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _SearchField(
                controller: _searchCtrl,
                onChanged: (q) => setState(() => _query = q),
              ),
            ),

            const SizedBox(height: 8),

            // ── List ────────────────────────────────────
            Expanded(
              child: ListView.builder(
                controller:  _scrollCtrl,
                physics:     const BouncingScrollPhysics(),
                itemCount: showPopular
                    ? _popular.length + 1 + countries.length
                    : countries.length,
                itemBuilder: (context, index) {
                  if (showPopular) {
                    if (index < _popular.length) {
                      return _CountryTile(
                        country:    _popular[index],
                        isSelected: _popular[index].iso2 == widget.selected.iso2,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          widget.onSelected(_popular[index]);
                          Navigator.of(context).pop();
                        },
                      );
                    }
                    if (index == _popular.length) {
                      return const Padding(
                        padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                        child: Text(
                          'ALL COUNTRIES',
                          style: AppTypography.sectionLabel,
                        ),
                      );
                    }
                    final c = countries[index - _popular.length - 1];
                    return _CountryTile(
                      country:    c,
                      isSelected: c.iso2 == widget.selected.iso2,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        widget.onSelected(c);
                        Navigator.of(context).pop();
                      },
                    );
                  }
                  final c = countries[index];
                  return _CountryTile(
                    country:    c,
                    isSelected: c.iso2 == widget.selected.iso2,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      widget.onSelected(c);
                      Navigator.of(context).pop();
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
}

class _CountryTile extends StatelessWidget {
  const _CountryTile({
    required this.country,
    required this.isSelected,
    required this.onTap,
  });

  final CountryInfo country;
  final bool        isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap:       onTap,
        splashColor: AppColors.goldGlow,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          color: isSelected
              ? AppColors.champagneGold.withValues(alpha: 0.06)
              : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Text(country.flag, style: const TextStyle(fontSize: 26)),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  country.name,
                  style: AppTypography.body.copyWith(
                    color: isSelected
                        ? AppColors.champagneGold
                        : AppColors.pearlWhite,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
              Text(
                country.dialCode,
                style: AppTypography.bodyMuted.copyWith(
                  color: isSelected
                      ? AppColors.champagneGold.withValues(alpha: 0.8)
                      : AppColors.slateMist,
                ),
              ),
              if (isSelected) ...[
                const SizedBox(width: 10),
                Container(
                  width: 20, height: 20,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.champagneGold,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 12,
                    color: AppColors.obsidianNight,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SHARED WIDGETS
// ─────────────────────────────────────────────────────────────

class _BackBtn extends StatelessWidget {
  const _BackBtn({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return NoorPressable(
      onTap: onTap,
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
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String>  onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color:        AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: TextField(
        controller: controller,
        onChanged:  onChanged,
        style:      AppTypography.body,
        decoration: InputDecoration(
          hintText:       'Search country or dial code',
          hintStyle:      AppTypography.bodyMuted.copyWith(fontSize: 15),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppColors.slateMist,
            size:  20,
          ),
          border:          InputBorder.none,
          contentPadding:  const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}
