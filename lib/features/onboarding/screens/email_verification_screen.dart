// lib/features/onboarding/screens/email_verification_screen.dart
// ============================================================
// MITHAQ - Email Verification Screen
// Supabase email OTP with the existing six-box spring OTP UI.
// ============================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/cubits/auth/auth_cubit.dart';
import '../../../core/cubits/auth/auth_state.dart';
import '../../../core/cubits/onboarding/onboarding_cubit.dart';
import '../../../core/services/email_address_validation.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/buttons/mithaq_pressable.dart';
import '../../../core/widgets/buttons/mithaq_primary_button.dart';
import '../../../l10n/generated/app_localizations.dart';

enum EmailAuthMode { signIn, signUp }

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({
    super.key,
    this.mode = EmailAuthMode.signIn,
  });

  final EmailAuthMode mode;

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final _emailCtrl = TextEditingController();
  final _emailFocus = FocusNode();
  bool _otpSent = false;
  int _resendSecs = 60;
  Timer? _resendTimer;

  String get _email => EmailAddressValidation.normalize(_emailCtrl.text);

  @override
  void initState() {
    super.initState();
    _emailCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _emailFocus.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  void _sendOtp() {
    HapticFeedback.mediumImpact();
    final authMode = widget.mode == EmailAuthMode.signUp ? 'signup' : 'signin';
    context.read<AuthCubit>().sendOtp(_email, mode: authMode);
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_resendSecs > 0) {
          _resendSecs--;
        } else {
          timer.cancel();
        }
      });
    });
  }

  void _changeEmail() {
    setState(() => _otpSent = false);
    _resendTimer?.cancel();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _emailFocus.requestFocus(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is AuthOtpSent) {
          setState(() {
            _otpSent = true;
            _resendSecs = 60;
          });
          _emailFocus.unfocus();
          _startResendTimer();
        }
        if (state is AuthAuthenticated) {
          context.read<OnboardingCubit>().initialize(
                startStep: state.onboardingStep,
              );
        }
        if (state is AuthError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.softCoral,
              behavior: SnackBarBehavior.floating,
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
              center: Alignment(0, -0.5),
              radius: 1.2,
              colors: [
                AppColors.navyCharcoal,
                AppColors.obsidianNight,
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Row(
                    children: [
                      _BackBtn(onTap: () => Navigator.of(context).pop()),
                      const Spacer(),
                      Text(
                        'Mithaq',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color:
                              AppColors.champagneGold.withValues(alpha: 0.60),
                          shadows: [
                            Shadow(
                              color: AppColors.champagneGold
                                  .withValues(alpha: 0.3),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) {
                      final isIn = child.key ==
                          (_otpSent
                              ? const ValueKey('otp')
                              : const ValueKey('email'));
                      return SlideTransition(
                        position: Tween<Offset>(
                          begin: Offset(0, isIn ? 0.06 : -0.06),
                          end: Offset.zero,
                        ).animate(animation),
                        child: FadeTransition(opacity: animation, child: child),
                      );
                    },
                    child: _otpSent
                        ? _OtpView(
                            key: const ValueKey('otp'),
                            email: _email,
                            resendSecs: _resendSecs,
                            onResend: _resendSecs == 0
                                ? () => context.read<AuthCubit>().resendOtp()
                                : null,
                            onChangeEmail: _changeEmail,
                          )
                        : _EmailView(
                            key: const ValueKey('email'),
                            controller: _emailCtrl,
                            focusNode: _emailFocus,
                            onSend: _sendOtp,
                            isComplete: true,
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

class _EmailView extends StatefulWidget {
  const _EmailView({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onSend,
    required this.isComplete,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSend;
  final bool isComplete;

  @override
  State<_EmailView> createState() => _EmailViewState();
}

class _EmailViewState extends State<_EmailView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
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
    _titleFade = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.0, 0.55, curve: Curves.easeOut),
    );
    _titleSlide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(_titleFade);
    _subtitleFade = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.1, 0.6, curve: Curves.easeOut),
    );
    _subtitleSlide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(_subtitleFade);
    _inputFade = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.22, 0.72, curve: Curves.easeOut),
    );
    _inputSlide = Tween<Offset>(
      begin: const Offset(0, 0.10),
      end: Offset.zero,
    ).animate(_inputFade);
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SlideTransition(
                position: _titleSlide,
                child: FadeTransition(
                  opacity: _titleFade,
                  child: const Text(
                    'Enter your email',
                    style: AppTypography.screenTitle,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SlideTransition(
                position: _subtitleSlide,
                child: FadeTransition(
                  opacity: _subtitleFade,
                  child: const Text(
                    'We will send a 6-digit verification code to your email.',
                    style: AppTypography.bodyMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 40),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: SlideTransition(
            position: _inputSlide,
            child: FadeTransition(
              opacity: _inputFade,
              child: _EmailInput(
                controller: widget.controller,
                focusNode: widget.focusNode,
                onSubmitted: widget.isComplete ? widget.onSend : null,
              ),
            ),
          ),
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          child: SlideTransition(
            position: _ctaSlide,
            child: FadeTransition(
              opacity: _ctaFade,
              child: BlocBuilder<AuthCubit, AuthState>(
                builder: (context, state) => MithaqPrimaryButton(
                  label: 'Send verification code',
                  isLoading: state is AuthLoading,
                  enabled: widget.isComplete,
                  onTap: widget.isComplete && state is! AuthLoading
                      ? widget.onSend
                      : null,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _EmailInput extends StatefulWidget {
  const _EmailInput({
    required this.controller,
    required this.focusNode,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback? onSubmitted;

  @override
  State<_EmailInput> createState() => _EmailInputState();
}

class _EmailInputState extends State<_EmailInput> {
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
        color: AppColors.inputSurface,
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
                  color: AppColors.champagneGold.withValues(alpha: 0.08),
                  blurRadius: 16,
                ),
              ]
            : null,
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: widget.focusNode,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.done,
        autofocus: true,
        autocorrect: false,
        enableSuggestions: false,
        textCapitalization: TextCapitalization.none,
        onSubmitted: (_) => widget.onSubmitted?.call(),
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w500,
          color: AppColors.pearlWhite,
          letterSpacing: 0,
        ),
        decoration: InputDecoration(
          hintText: 'name@example.com',
          hintStyle: TextStyle(
            fontSize: 18,
            color: AppColors.slateMist.withValues(alpha: 0.5),
            letterSpacing: 0,
          ),
          prefixIcon: const Icon(
            Icons.alternate_email_rounded,
            color: AppColors.slateMist,
            size: 21,
          ),
          border: InputBorder.none,
          filled: false,
          fillColor: Colors.transparent,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 18,
          ),
        ),
      ),
    );
  }
}

class _OtpView extends StatefulWidget {
  const _OtpView({
    super.key,
    required this.email,
    required this.resendSecs,
    required this.onResend,
    required this.onChangeEmail,
  });

  final String email;
  final int resendSecs;
  final VoidCallback? onResend;
  final VoidCallback onChangeEmail;

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
    _titleFade = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
    );
    _titleSlide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(_titleFade);
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
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 40),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SlideTransition(
                position: _titleSlide,
                child: FadeTransition(
                  opacity: _titleFade,
                  child: Text(
                    l10n.auth_title_enterCode,
                    style: AppTypography.screenTitle,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              FadeTransition(
                opacity: _subtitleFade,
                child: RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: l10n.auth_label_sentCodeTo,
                        style: AppTypography.bodyMuted,
                      ),
                      TextSpan(
                        text: widget.email,
                        style: AppTypography.bodyMuted.copyWith(
                          color: AppColors.champagneGold,
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
        _OtpBoxes(
          onCompleted: (code) {
            HapticFeedback.mediumImpact();
            context.read<AuthCubit>().verifyOtp(code);
          },
        ),
        const SizedBox(height: 36),
        BlocBuilder<AuthCubit, AuthState>(
          builder: (context, state) {
            if (state is! AuthLoading) return const SizedBox.shrink();
            return const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.champagneGold,
              ),
            );
          },
        ),
        const SizedBox(height: 20),
        MithaqPressable(
          onTap: widget.onResend,
          enabled: widget.onResend != null,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                key: ValueKey(widget.resendSecs == 0 ? 'active' : 'waiting'),
                widget.resendSecs > 0
                    ? l10n.auth_label_resendCodeIn(widget.resendSecs)
                    : l10n.auth_label_resendCode,
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
        MithaqPressable(
          onTap: widget.onChangeEmail,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
            child: Text(
              'Change email',
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

class _OtpBoxes extends StatefulWidget {
  const _OtpBoxes({required this.onCompleted});

  final ValueChanged<String> onCompleted;

  @override
  State<_OtpBoxes> createState() => _OtpBoxesState();
}

class _OtpBoxesState extends State<_OtpBoxes> {
  static const _length = 6;
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
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
    final clamped =
        digits.length > _length ? digits.substring(0, _length) : digits;

    if (clamped == _otp) return;

    final prev = _otp;
    setState(() => _otp = clamped);

    if (clamped.length > prev.length) {
      HapticFeedback.lightImpact();
    }

    if (_controller.text != clamped) {
      _controller.value = TextEditingValue(
        text: clamped,
        selection: TextSelection.collapsed(offset: clamped.length),
      );
    }

    if (clamped.length == _length) {
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted) widget.onCompleted(clamped);
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
                    digit: hasDigit ? _otp[i] : null,
                    isActive: isActive,
                    delay: i * 50,
                  ),
                );
              }),
            ),
          ),
          Opacity(
            opacity: 0,
            child: SizedBox(
              width: 1,
              height: 1,
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                keyboardType: TextInputType.number,
                maxLength: _length,
                decoration: const InputDecoration.collapsed(hintText: ''),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OtpBox extends StatefulWidget {
  const _OtpBox({
    required this.digit,
    required this.isActive,
    this.delay = 0,
  });

  final String? digit;
  final bool isActive;
  final int delay;

  @override
  State<_OtpBox> createState() => _OtpBoxState();
}

class _OtpBoxState extends State<_OtpBox> with TickerProviderStateMixin {
  late final AnimationController _entryCtrl;
  late final Animation<double> _entryScale;
  late final Animation<double> _entryFade;
  AnimationController? _bounceCtrl;
  Animation<double>? _bounceScale;
  Animation<double>? _bounceFade;
  String? _prevDigit;

  @override
  void initState() {
    super.initState();
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
    Future.delayed(Duration(milliseconds: 50 + widget.delay), () {
      if (mounted) _entryCtrl.forward();
    });
  }

  @override
  void didUpdateWidget(covariant _OtpBox oldWidget) {
    super.didUpdateWidget(oldWidget);
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
    final hasDigit = widget.digit != null;
    final Widget digitWidget;
    if (hasDigit && _bounceScale != null && _bounceFade != null) {
      digitWidget = ScaleTransition(
        scale: _bounceScale!,
        child: FadeTransition(
          opacity: _bounceFade!,
          child: _DigitText(widget.digit!),
        ),
      );
    } else if (hasDigit) {
      digitWidget = _DigitText(widget.digit!);
    } else if (widget.isActive) {
      digitWidget = const _Cursor();
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
          width: 48,
          height: 58,
          decoration: BoxDecoration(
            color: hasDigit
                ? AppColors.champagneGold.withValues(alpha: 0.08)
                : AppColors.surfaceGlass,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.isActive
                  ? AppColors.champagneGold
                  : hasDigit
                      ? AppColors.champagneGold.withValues(alpha: 0.45)
                      : AppColors.cardBorder,
              width: widget.isActive ? 2.0 : 1.5,
            ),
            boxShadow: widget.isActive
                ? [
                    BoxShadow(
                      color: AppColors.champagneGold.withValues(alpha: 0.12),
                      blurRadius: 12,
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

class _DigitText extends StatelessWidget {
  const _DigitText(this.digit);

  final String digit;

  @override
  Widget build(BuildContext context) {
    return Text(
      digit,
      style: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: AppColors.pearlWhite,
        letterSpacing: 0,
      ),
    );
  }
}

class _Cursor extends StatefulWidget {
  const _Cursor();

  @override
  State<_Cursor> createState() => _CursorState();
}

class _CursorState extends State<_Cursor> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
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
        width: 2,
        height: 24,
        decoration: BoxDecoration(
          color: AppColors.champagneGold,
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }
}

class _BackBtn extends StatelessWidget {
  const _BackBtn({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MithaqPressable(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.surfaceGlass,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Icon(
          Directionality.of(context) == TextDirection.rtl
              ? Icons.arrow_forward_ios_rounded
              : Icons.arrow_back_ios_new_rounded,
          color: AppColors.pearlWhite,
          size: 16,
        ),
      ),
    );
  }
}
