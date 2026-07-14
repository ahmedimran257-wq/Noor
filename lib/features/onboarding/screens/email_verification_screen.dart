// lib/features/onboarding/screens/email_verification_screen.dart
// ============================================================
// SILARAH - Email Verification Screen
// Supabase email OTP with the existing six-box spring OTP UI.
// ============================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/cubits/auth/auth_cubit.dart';
import '../../../core/cubits/auth/auth_state.dart';
import '../../../core/services/email_address_validation.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/buttons/silarah_pressable.dart';
import '../../../core/widgets/buttons/silarah_primary_button.dart';
import '../../../core/widgets/loaders/silarah_shimmer.dart';
import '../../../l10n/generated/app_localizations.dart';

enum EmailAuthMode { signIn, signUp }

enum _AuthPivotReason { accountExists, accountMissing }

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
  late EmailAuthMode _mode;
  _AuthPivotReason? _pivotReason;
  bool _otpSent = false;
  int _resendSecs = 60;
  int _otpResetNonce = 0;
  Timer? _resendTimer;

  String get _email => EmailAddressValidation.normalize(_emailCtrl.text);

  @override
  void initState() {
    super.initState();
    _mode = widget.mode;
    _emailCtrl.addListener(_onEmailChanged);
  }

  @override
  void dispose() {
    _emailCtrl.removeListener(_onEmailChanged);
    _emailCtrl.dispose();
    _emailFocus.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  void _onEmailChanged() {
    if (!mounted) return;
    setState(() => _pivotReason = null);
  }

  void _sendOtp() {
    HapticFeedback.mediumImpact();
    setState(() => _pivotReason = null);
    final authMode = _mode == EmailAuthMode.signUp ? 'signup' : 'signin';
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
    setState(() {
      _otpSent = false;
      _pivotReason = null;
    });
    _resendTimer?.cancel();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _emailFocus.requestFocus(),
    );
  }

  void _switchMode(
    EmailAuthMode mode, {
    _AuthPivotReason? reason,
    bool focusEmail = true,
  }) {
    _resendTimer?.cancel();
    setState(() {
      _mode = mode;
      _otpSent = false;
      _pivotReason = reason;
      _otpResetNonce++;
      _resendSecs = 60;
    });
    if (focusEmail) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _emailFocus.requestFocus();
      });
    }
  }

  bool _isAccountExistsError(String message) {
    final lower = message.toLowerCase();
    return lower.contains('already exists') ||
        lower.contains('already registered');
  }

  bool _isMissingAccountError(String message) {
    final lower = message.toLowerCase();
    return lower.contains('no account found');
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is AuthOtpSent) {
          setState(() {
            _otpSent = true;
            _pivotReason = null;
            _resendSecs = 60;
          });
          _emailFocus.unfocus();
          _startResendTimer();
        }
        if (state is AuthError) {
          if (_mode == EmailAuthMode.signUp &&
              _isAccountExistsError(state.message)) {
            HapticFeedback.selectionClick();
            _switchMode(
              EmailAuthMode.signIn,
              reason: _AuthPivotReason.accountExists,
            );
            return;
          }

          if (_mode == EmailAuthMode.signIn &&
              _isMissingAccountError(state.message)) {
            HapticFeedback.selectionClick();
            _switchMode(
              EmailAuthMode.signUp,
              reason: _AuthPivotReason.accountMissing,
            );
            return;
          }

          if (_otpSent) {
            setState(() => _otpResetNonce++);
          }
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
                        'Silarah',
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
                            resetNonce: _otpResetNonce,
                            onResend: _resendSecs == 0
                                ? () => context.read<AuthCubit>().resendOtp()
                                : null,
                            onChangeEmail: _changeEmail,
                          )
                        : _EmailView(
                            key: const ValueKey('email'),
                            controller: _emailCtrl,
                            focusNode: _emailFocus,
                            mode: _mode,
                            pivotReason: _pivotReason,
                            onModeChanged: (mode) => _switchMode(
                              mode,
                              reason: null,
                            ),
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
    required this.mode,
    required this.pivotReason,
    required this.onModeChanged,
    required this.onSend,
    required this.isComplete,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final EmailAuthMode mode;
  final _AuthPivotReason? pivotReason;
  final ValueChanged<EmailAuthMode> onModeChanged;
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
    final isSignIn = widget.mode == EmailAuthMode.signIn;
    final title = isSignIn ? 'Welcome back' : 'Create your Silarah profile';
    final subtitle = isSignIn
        ? 'Enter your email and we will send a 6-digit verification code.'
        : 'Use your real email. We will send a 6-digit verification code.';
    final ctaLabel = isSignIn ? 'Send sign-in code' : 'Send verification code';
    final switchLabel = isSignIn
        ? 'New to Silarah? Create profile'
        : 'Already registered? Sign in';
    final nextMode = isSignIn ? EmailAuthMode.signUp : EmailAuthMode.signIn;

    return _KeyboardSafeScroll(
      child: Column(
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
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      child: Text(
                        title,
                        key: ValueKey('email-title-$title'),
                        style: AppTypography.screenTitle,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SlideTransition(
                  position: _subtitleSlide,
                  child: FadeTransition(
                    opacity: _subtitleFade,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      child: Text(
                        subtitle,
                        key: ValueKey('email-subtitle-$subtitle'),
                        style: AppTypography.bodyMuted,
                      ),
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
          AnimatedSize(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: widget.pivotReason == null
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
                    child: _AuthPivotNoticeCard(
                      reason: widget.pivotReason!,
                      onTap: widget.onSend,
                    ),
                  ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            child: SlideTransition(
              position: _ctaSlide,
              child: FadeTransition(
                opacity: _ctaFade,
                child: BlocBuilder<AuthCubit, AuthState>(
                  builder: (context, state) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SilarahPrimaryButton(
                        label: ctaLabel,
                        isLoading: state is AuthLoading,
                        enabled: widget.isComplete,
                        onTap: widget.isComplete && state is! AuthLoading
                            ? widget.onSend
                            : null,
                      ),
                      const SizedBox(height: 14),
                      SilarahPressable(
                        onTap: () => widget.onModeChanged(nextMode),
                        enabled: state is! AuthLoading,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 12,
                          ),
                          child: Text(
                            switchLabel,
                            textAlign: TextAlign.center,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.champagneGold,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                              decorationColor: AppColors.champagneGold
                                  .withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KeyboardSafeScroll extends StatelessWidget {
  const _KeyboardSafeScroll({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(child: child),
          ),
        );
      },
    );
  }
}

class _AuthPivotNoticeCard extends StatelessWidget {
  const _AuthPivotNoticeCard({
    required this.reason,
    required this.onTap,
  });

  final _AuthPivotReason reason;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accountExists = reason == _AuthPivotReason.accountExists;
    final title = accountExists ? 'Account found' : 'No account yet';
    final message = accountExists
        ? 'This email is already registered. Continue by signing in here.'
        : 'This email is not registered yet. Create your profile here.';
    final actionLabel = accountExists ? 'Send sign-in code' : 'Create profile';
    final icon = accountExists
        ? Icons.verified_user_outlined
        : Icons.person_add_alt_1_rounded;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.96, end: 1),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      builder: (context, scale, child) => Transform.scale(
        scale: scale,
        alignment: Alignment.topCenter,
        child: child,
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.champagneGold.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.champagneGold.withValues(alpha: 0.36),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.champagneGold.withValues(alpha: 0.08),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.champagneGold.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.champagneGold.withValues(alpha: 0.28),
                ),
              ),
              child: Icon(icon, color: AppColors.champagneGold, size: 19),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.body.copyWith(
                      color: AppColors.pearlWhite,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(message, style: AppTypography.caption),
                  const SizedBox(height: 10),
                  SilarahPressable(
                    onTap: onTap,
                    child: Text(
                      actionLabel,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.champagneGold,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
        onTapOutside: (_) => widget.focusNode.unfocus(),
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
    required this.resetNonce,
    required this.onResend,
    required this.onChangeEmail,
  });

  final String email;
  final int resendSecs;
  final int resetNonce;
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
    return _KeyboardSafeScroll(
      child: Column(
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
            resetNonce: widget.resetNonce,
            onCompleted: (code) {
              HapticFeedback.mediumImpact();
              context.read<AuthCubit>().verifyOtp(code);
            },
          ),
          const SizedBox(height: 36),
          BlocBuilder<AuthCubit, AuthState>(
            builder: (context, state) {
              if (state is! AuthLoading) return const SizedBox.shrink();
              return const SilarahPulseLoader(size: 28);
            },
          ),
          const SizedBox(height: 20),
          SilarahPressable(
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
          SilarahPressable(
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
      ),
    );
  }
}

class _OtpBoxes extends StatefulWidget {
  const _OtpBoxes({
    required this.resetNonce,
    required this.onCompleted,
  });

  final int resetNonce;
  final ValueChanged<String> onCompleted;

  @override
  State<_OtpBoxes> createState() => _OtpBoxesState();
}

class _OtpBoxesState extends State<_OtpBoxes> with WidgetsBindingObserver {
  static const _length = 6;
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  String _otp = '';
  bool _completionSubmitted = false;
  Timer? _keyboardTimer;
  Timer? _completionTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller.addListener(_onInput);
    WidgetsBinding.instance.addPostFrameCallback((_) => _openKeyboard());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _keyboardTimer?.cancel();
    _completionTimer?.cancel();
    _controller.removeListener(_onInput);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _OtpBoxes oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.resetNonce != oldWidget.resetNonce) {
      _completionSubmitted = false;
      _controller.clear();
      if (mounted) setState(() => _otp = '');
      _openKeyboard(reconnect: true);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Android can resume with the FocusNode still focused but with its text
      // input connection closed after the user checks OTP in another app.
      _openKeyboard(reconnect: true);
    }
  }

  void _openKeyboard({bool reconnect = false}) {
    if (!mounted) return;
    if (reconnect) {
      _focusNode.unfocus();
      SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    }

    _keyboardTimer?.cancel();
    _keyboardTimer = Timer(Duration(milliseconds: reconnect ? 90 : 0), () {
      if (!mounted) return;
      FocusScope.of(context).requestFocus(_focusNode);
      SystemChannels.textInput.invokeMethod<void>('TextInput.show');
    });
  }

  void _onInput() {
    final digits = _controller.text.replaceAll(RegExp(r'\D'), '');
    final clamped =
        digits.length > _length ? digits.substring(0, _length) : digits;

    if (clamped == _otp) return;

    final prev = _otp;
    if (clamped.length < _length) {
      _completionSubmitted = false;
    }
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

    if (clamped.length == _length && !_completionSubmitted) {
      _completionSubmitted = true;
      _completionTimer?.cancel();
      _completionTimer = Timer(const Duration(milliseconds: 150), () {
        if (mounted) widget.onCompleted(clamped);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openKeyboard(reconnect: true),
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
          Positioned.fill(
            child: Opacity(
              opacity: 0.01,
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                autofocus: true,
                autocorrect: false,
                enableSuggestions: false,
                enableInteractiveSelection: false,
                showCursor: false,
                onTapOutside: (_) => _focusNode.unfocus(),
                maxLength: _length,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(_length),
                ],
                style: const TextStyle(
                  color: Colors.transparent,
                  fontSize: 1,
                  height: 1,
                ),
                cursorColor: Colors.transparent,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  counterText: '',
                  contentPadding: EdgeInsets.zero,
                ),
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
  Timer? _entryTimer;
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
    _entryTimer = Timer(Duration(milliseconds: 50 + widget.delay), () {
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
    _entryTimer?.cancel();
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
    return SilarahPressable(
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
