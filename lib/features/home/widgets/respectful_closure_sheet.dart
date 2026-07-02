// lib/features/home/widgets/respectful_closure_sheet.dart
// ============================================================
// MITHAQ — Respectful Closure Sheet
// Phase 2: Anti-ghosting feature.
//
// Displays 5 pre-written Islamic closure messages.
// User selects one, confirms, and the match is closed.
//
// Usage:
//   showRespectfulClosureSheet(context, conversationId: '...');
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/cubits/chat/chat_cubit.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';

// ── Entry point ───────────────────────────────────────────────

Future<void> showRespectfulClosureSheet(
  BuildContext context, {
  required String conversationId,
  required String matchName,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => BlocProvider.value(
      value: context.read<ChatCubit>(),
      child: RespectfulClosureSheet(
        conversationId: conversationId,
        matchName: matchName,
      ),
    ),
  );
}

// ── Pre-written closure messages ──────────────────────────────
const _kClosureMessages = [
  'Assalamu Alaikum. After thoughtful reflection, I feel this may not be the right match for us. '
      'I sincerely wish you all the best and pray that Allah blesses you with a wonderful partner. '
      'JazakAllah khair.',
  'Assalamu Alaikum. I wanted to be honest and respectful with you. '
      'I do not think we are the right match, but I pray that Allah opens better doors for you. '
      'Wishing you all the best.',
  'Assalamu Alaikum. After sincere consideration, I feel we may not be compatible. '
      'I hope you find someone truly right for you. '
      'May Allah make it easy for you. JazakAllah khair for your time.',
  'Assalamu Alaikum. I have reflected on our conversations and feel it is best to close this match '
      'at this time. I have nothing but respect for you and I make dua that Allah blesses you with the best.',
  'Assalamu Alaikum. I wanted to be transparent with you rather than fade away. '
      'I do not see this progressing further, but I truly appreciate your time and wish you every happiness. '
      'May Allah bless you.',
];

// ── Widget ────────────────────────────────────────────────────

class RespectfulClosureSheet extends StatefulWidget {
  const RespectfulClosureSheet({
    super.key,
    required this.conversationId,
    required this.matchName,
  });

  final String conversationId;
  final String matchName;

  @override
  State<RespectfulClosureSheet> createState() => _RespectfulClosureSheetState();
}

class _RespectfulClosureSheetState extends State<RespectfulClosureSheet> {
  int? _selectedIndex;

  void _confirm() {
    if (_selectedIndex == null) return;
    HapticFeedback.mediumImpact();
    final message = _kClosureMessages[_selectedIndex!];
    context.read<ChatCubit>().closeMatch(widget.conversationId, message);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Container(
      margin: const EdgeInsets.all(AppDimensions.space16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          AppDimensions.space24,
          AppDimensions.space20,
          AppDimensions.space24,
          AppDimensions.space16 + bottomPad,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.cardBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.space20),

            // Title
            Text(
              'End match with ${widget.matchName}',
              style: AppTypography.bodyMedium
                  .copyWith(color: AppColors.pearlWhite),
            ),
            const SizedBox(height: AppDimensions.space8),
            Text(
              'Choose a respectful message to send. '
              '${widget.matchName} will be notified that the match has been closed.',
              style: AppTypography.caption,
            ),
            const SizedBox(height: AppDimensions.space20),

            // Islamic guidance note
            Container(
              padding: const EdgeInsets.all(AppDimensions.space12),
              decoration: BoxDecoration(
                color: AppColors.champagneGold.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                border: Border.all(color: AppColors.goldBorder),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded,
                      color: AppColors.champagneGold, size: 16),
                  const SizedBox(width: AppDimensions.space8),
                  Expanded(
                    child: Text(
                      '"And when you have decided, then rely upon Allah." — Quran 3:159\n'
                      'A respectful closure is better than silence.',
                      style: AppTypography.caption.copyWith(
                        fontStyle: FontStyle.italic,
                        color: AppColors.champagneGold.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.space16),

            // Message options
            ..._kClosureMessages.asMap().entries.map((entry) {
              final i = entry.key;
              final msg = entry.value;
              final selected = _selectedIndex == i;
              return Padding(
                padding: const EdgeInsets.only(bottom: AppDimensions.space8),
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedIndex = selected ? null : i);
                  },
                  child: AnimatedContainer(
                    duration: AppDimensions.durationTransition,
                    padding: const EdgeInsets.all(AppDimensions.space12),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.champagneGold.withValues(alpha: 0.07)
                          : AppColors.surfaceGlass,
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusButton),
                      border: Border.all(
                        color: selected
                            ? AppColors.champagneGold
                            : AppColors.cardBorder,
                        width: selected
                            ? AppDimensions.borderFocus
                            : AppDimensions.borderThin,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AnimatedContainer(
                          duration: AppDimensions.durationTransition,
                          width: 20,
                          height: 20,
                          margin: const EdgeInsets.only(top: 1, right: 10),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: selected
                                ? AppColors.champagneGold
                                : Colors.transparent,
                            border: Border.all(
                              color: selected
                                  ? AppColors.champagneGold
                                  : AppColors.slateMist,
                            ),
                          ),
                          child: selected
                              ? const Icon(Icons.check_rounded,
                                  color: AppColors.obsidianNight, size: 12)
                              : null,
                        ),
                        Expanded(
                          child: Text(
                            msg,
                            style: AppTypography.caption.copyWith(
                              color: selected
                                  ? AppColors.pearlWhite
                                  : AppColors.slateMist,
                              fontStyle: FontStyle.italic,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),

            const SizedBox(height: AppDimensions.space16),

            // Send & End button
            SizedBox(
              width: double.infinity,
              height: AppDimensions.buttonHeight,
              child: ElevatedButton(
                onPressed: _selectedIndex != null ? _confirm : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.softCoral.withValues(alpha: 0.85),
                  disabledBackgroundColor: AppColors.surfaceGlassHover,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusButton),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.do_not_disturb_on_outlined,
                      color: _selectedIndex != null
                          ? AppColors.pearlWhite
                          : AppColors.slateMist,
                      size: 18,
                    ),
                    const SizedBox(width: AppDimensions.space8),
                    Text(
                      'Send & End Match',
                      style: AppTypography.button.copyWith(
                        color: _selectedIndex != null
                            ? AppColors.pearlWhite
                            : AppColors.slateMist,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.space8),

            // Cancel
            SizedBox(
              width: double.infinity,
              height: AppDimensions.buttonHeightSmall,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.cardBorder),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusButton),
                  ),
                ),
                child: Text('Cancel',
                    style: AppTypography.button
                        .copyWith(color: AppColors.slateMist)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
