// lib/core/widgets/inputs/noor_text_field.dart
// ============================================================
// NOOR Input System
// BG: Surface Glass (rgba(255,255,255,0.05))
// Border: Bottom border only (1px solid Slate Mist)
// Focus State: Bottom border → 2px Champagne Gold
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimensions.dart';
import '../../theme/app_typography.dart';

class NoorTextField extends StatelessWidget {
  const NoorTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.label,
    this.hint,
    this.helperText,
    this.errorText,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.maxLength,
    this.maxLines = 1,
    this.minLines,
    this.enabled = true,
    this.readOnly = false,
    this.autofocus = false,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
    this.showCounter = false,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? label;
  final String? hint;
  final String? helperText;
  final String? errorText;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final int? maxLength;
  final int? maxLines;
  final int? minLines;
  final bool enabled;
  final bool readOnly;
  final bool autofocus;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;
  final bool showCounter;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
      ),
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppDimensions.space16, 0, AppDimensions.space16, 0,
      ),
      child: TextField(
        controller:          controller,
        focusNode:           focusNode,
        obscureText:         obscureText,
        keyboardType:        keyboardType,
        textInputAction:     textInputAction,
        onChanged:           onChanged,
        onSubmitted:         onSubmitted,
        onTap:               onTap,
        maxLength:           maxLength,
        maxLines:            maxLines,
        minLines:            minLines,
        enabled:             enabled,
        readOnly:            readOnly,
        autofocus:           autofocus,
        inputFormatters:     inputFormatters,
        textCapitalization:  textCapitalization,
        style:               AppTypography.inputText,
        cursorColor:         AppColors.champagneGold,
        cursorWidth:         1.5,
        buildCounter:        showCounter ? null : (_, {required currentLength, required isFocused, maxLength}) => null,
        decoration: InputDecoration(
          labelText:   label,
          hintText:    hint,
          helperText:  helperText,
          errorText:   errorText,
          helperStyle: AppTypography.caption,
          errorStyle:  AppTypography.caption.copyWith(color: AppColors.softCoral),
          prefixIcon:  prefixIcon != null
              ? Icon(prefixIcon, color: AppColors.slateMist, size: AppDimensions.iconSizeMedium)
              : null,
          suffixIcon: suffixIcon,
          // Override theme's contentPadding for single-line inputs
          contentPadding: EdgeInsets.symmetric(
            vertical: maxLines != null && maxLines! > 1
                ? AppDimensions.space16
                : AppDimensions.space20,
          ),
        ),
      ),
    );
  }
}


// ============================================================
// OTP Input Field
// Used on the Phone Verification screen.
// Six individual boxes with auto-advance.
// ============================================================

class NoorOtpField extends StatefulWidget {
  const NoorOtpField({
    super.key,
    required this.onCompleted,
    this.length = 6,
    this.onChanged,
  });

  final int length;
  final ValueChanged<String> onCompleted;
  final ValueChanged<String>? onChanged;

  @override
  State<NoorOtpField> createState() => _NoorOtpFieldState();
}

class _NoorOtpFieldState extends State<NoorOtpField> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(widget.length, (_) => TextEditingController());
    _focusNodes  = List.generate(widget.length, (_) => FocusNode());
  }

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes)  f.dispose();
    super.dispose();
  }

  void _onDigitEntered(int index, String value) {
    if (value.length > 1) {
      // Handle paste: distribute digits across boxes
      final digits = value.replaceAll(RegExp(r'\D'), '');
      for (int i = 0; i < widget.length && i < digits.length; i++) {
        _controllers[i].text = digits[i];
      }
      if (digits.length >= widget.length) {
        FocusScope.of(context).unfocus();
        _notifyCompletion();
      } else {
        _focusNodes[digits.length.clamp(0, widget.length - 1)].requestFocus();
      }
      return;
    }

    if (value.isNotEmpty) {
      HapticFeedback.selectionClick(); // "Haptic feedback on each digit entry"
      if (index < widget.length - 1) {
        _focusNodes[index + 1].requestFocus();
      } else {
        FocusScope.of(context).unfocus();
        _notifyCompletion();
      }
    }
    widget.onChanged?.call(_buildOtpString());
  }

  void _onKeyPressed(int index, RawKeyEvent event) {
    if (event is RawKeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      _focusNodes[index - 1].requestFocus();
      _controllers[index - 1].clear();
    }
  }

  void _notifyCompletion() {
    final otp = _buildOtpString();
    if (otp.length == widget.length) {
      widget.onCompleted(otp);
    }
  }

  String _buildOtpString() =>
      _controllers.map((c) => c.text).join();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(widget.length, (index) {
        return SizedBox(
          width: 44,
          child: RawKeyboardListener(
            focusNode: FocusNode(),
            onKey: (event) => _onKeyPressed(index, event),
            child: TextField(
              controller:      _controllers[index],
              focusNode:       _focusNodes[index],
              textAlign:       TextAlign.center,
              keyboardType:    TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(1),
              ],
              style: AppTypography.userName.copyWith(
                color: AppColors.champagneGold,
              ),
              cursorColor: AppColors.champagneGold,
              onChanged: (v) => _onDigitEntered(index, v),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                hintText: '·',
                hintStyle: AppTypography.userName.copyWith(
                  color: AppColors.slateMist,
                ),
                // Override: use full underline border for OTP boxes
                enabledBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: AppColors.slateMist,
                    width: AppDimensions.borderThin,
                  ),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: AppColors.champagneGold,
                    width: AppDimensions.borderFocus,
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
