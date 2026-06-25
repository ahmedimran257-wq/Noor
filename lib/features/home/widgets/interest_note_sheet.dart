// lib/features/home/widgets/interest_note_sheet.dart
// ============================================================
// MITHAQ — Interest Note Sheet (D1)
//
// Shows a compact bottom sheet where the user can optionally
// attach a personal note to their interest before sending.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/animations/spring_keyboard_padding.dart';
import '../../../core/utils/content_filter.dart';

/// Shows the interest note sheet and returns the note text (or null).
/// If the user presses "Send without note", returns empty string.
/// If the user cancels, returns null.
Future<String?> showInterestNoteSheet(
  BuildContext context, {
  required String firstName,
}) {
  return showModalBottomSheet<String>(
    context:            context,
    backgroundColor:    Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _InterestNoteSheet(firstName: firstName),
  );
}

class _InterestNoteSheet extends StatefulWidget {
  const _InterestNoteSheet({required this.firstName});
  final String firstName;

  @override
  State<_InterestNoteSheet> createState() => _InterestNoteSheetState();
}

class _InterestNoteSheetState extends State<_InterestNoteSheet> {
  final TextEditingController _ctrl = TextEditingController();
  String _error = '';
  static const _maxLength = 200;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    setState(() {
      _error = ContentFilter.validate(text) ?? '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return SpringKeyboardPadding(
      child: Container(
        margin:  const EdgeInsets.all(AppDimensions.space16),
        padding: const EdgeInsets.all(AppDimensions.space24),
        decoration: BoxDecoration(
          color:        AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
          border:       Border.all(color: AppColors.cardBorder),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.cardBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            )),
            const SizedBox(height: AppDimensions.space20),

            // Title
            Text(
              'Add a note for ${widget.firstName}',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.pearlWhite,
              ),
            ),
            const SizedBox(height: AppDimensions.space6),
            const Text(
              'A personal note makes your interest stand out.',
              style: AppTypography.caption,
            ),
            const SizedBox(height: AppDimensions.space16),

            // Text input
            Container(
              decoration: BoxDecoration(
                color:        AppColors.surfaceGlass,
                borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                border: Border.all(
                  color: _error.isNotEmpty
                      ? AppColors.softCoral
                      : AppColors.cardBorder,
                ),
              ),
              child: TextField(
                controller:    _ctrl,
                onChanged:     _onChanged,
                maxLines:      3,
                maxLength:     _maxLength,
                style:         AppTypography.body,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  hintText:  'Assalamu Alaikum! I was really impressed by…',
                  hintStyle: AppTypography.inputLabel,
                  border:    InputBorder.none,
                  counterStyle: AppTypography.caption.copyWith(fontSize: 10),
                  contentPadding: const EdgeInsets.all(AppDimensions.space14),
                ),
              ),
            ),
            if (_error.isNotEmpty) ...[
              const SizedBox(height: AppDimensions.space6),
              Text(_error,
                style: AppTypography.caption.copyWith(color: AppColors.softCoral),
              ),
            ],

            const SizedBox(height: AppDimensions.space16),

            // Send with note
            SizedBox(
              width:  double.infinity,
              height: AppDimensions.buttonHeight,
              child: ElevatedButton(
                onPressed: _error.isEmpty && _ctrl.text.trim().isNotEmpty
                    ? () {
                        HapticFeedback.selectionClick();
                        Navigator.pop(context, _ctrl.text.trim());
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor:         AppColors.champagneGold,
                  disabledBackgroundColor:  AppColors.surfaceGlassHover,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Send with Note',
                  style: AppTypography.button.copyWith(
                    color: _error.isEmpty && _ctrl.text.trim().isNotEmpty
                        ? AppColors.obsidianNight
                        : AppColors.slateMist,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.space8),

            // Send without note
            SizedBox(
              width:  double.infinity,
              height: AppDimensions.buttonHeightSmall,
              child: OutlinedButton(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  Navigator.pop(context, ''); // empty = no note
                },
                style: OutlinedButton.styleFrom(
                  side:  const BorderSide(color: AppColors.cardBorder),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                  ),
                ),
                child: Text(
                  'Send without note',
                  style: AppTypography.button.copyWith(color: AppColors.slateMist),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
