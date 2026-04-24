// lib/features/home/widgets/report_bottom_sheet.dart
// ============================================================
// NOOR — Report Bottom Sheet (Step 10)
//
// Blueprint (Part 9 — Report Reasons):
//   fake_profile, inappropriate_photos, harassment, scam,
//   underage, already_married, offensive_bio, other
//
// "other" requires a text description.
// On submit: calls BlockReportCubit.reportUser()
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/cubits/block_report/block_report_cubit.dart';
import '../../../core/cubits/block_report/block_report_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

class ReportBottomSheet {
  static Future<void> show(
    BuildContext context, {
    required String reportedUserId,
    required String reportedName,
  }) {
    return showModalBottomSheet<void>(
      context:            context,
      isScrollControlled: true,
      backgroundColor:    Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: context.read<BlockReportCubit>(),
        child: _ReportContent(
          reportedUserId: reportedUserId,
          reportedName:   reportedName,
        ),
      ),
    );
  }
}

class _ReportContent extends StatefulWidget {
  final String reportedUserId;
  final String reportedName;

  const _ReportContent({
    required this.reportedUserId,
    required this.reportedName,
  });

  @override
  State<_ReportContent> createState() => _ReportContentState();
}

class _ReportContentState extends State<_ReportContent> {
  ReportReason? _selected;
  final _descController = TextEditingController();
  bool _submitted = false;

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewInsets.bottom +
        MediaQuery.of(context).viewPadding.bottom;

    return BlocConsumer<BlockReportCubit, BlockReportState>(
      listener: (context, state) {
        if (state.successMessage != null && _submitted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.successMessage!,
                  style: AppTypography.body),
              backgroundColor: AppColors.verifiedTeal,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          );
          context.read<BlockReportCubit>().clearMessages();
        }
      },
      builder: (context, state) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF12121A),
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(24)),
            border:
                Border(top: BorderSide(color: AppColors.goldBorder)),
          ),
          padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + bottomPad),
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
              const SizedBox(height: 20),

              // Title
              Text(
                'Report ${widget.reportedName}',
                style: AppTypography.screenTitle.copyWith(fontSize: 20),
              ),
              const SizedBox(height: 6),
              Text(
                'Help keep the community safe. Your report is anonymous.',
                style: AppTypography.bodyMuted,
              ),
              const SizedBox(height: 20),

              // Reason list
              ...ReportReason.values.map(
                (reason) => _ReasonTile(
                  reason:     reason,
                  isSelected: _selected == reason,
                  onTap: () => setState(() => _selected = reason),
                ),
              ),

              // Description field for "other"
              if (_selected == ReportReason.other) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _descController,
                  maxLines:   3,
                  maxLength:  200,
                  style:      AppTypography.body,
                  decoration: InputDecoration(
                    hintText:  'Please describe the issue…',
                    hintStyle: AppTypography.bodyMuted,
                    fillColor: AppColors.surfaceGlass,
                    filled:    true,
                    border:    OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AppColors.cardBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: AppColors.champagneGold, width: 1.5),
                    ),
                    counterStyle: AppTypography.caption,
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Submit
              GestureDetector(
                onTap: (_selected == null || state.isSubmitting)
                    ? null
                    : () {
                        setState(() => _submitted = true);
                        context.read<BlockReportCubit>().reportUser(
                              reportedUserId: widget.reportedUserId,
                              reportedName:   widget.reportedName,
                              reason:         _selected!,
                              description:
                                  _selected == ReportReason.other
                                      ? _descController.text.trim()
                                      : null,
                            );
                      },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  height: 52,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: _selected == null
                        ? AppColors.surfaceGlass
                        : AppColors.softCoral,
                  ),
                  alignment: Alignment.center,
                  child: state.isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: AppColors.pearlWhite,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'Submit Report',
                          style: AppTypography.button.copyWith(
                            color: _selected == null
                                ? AppColors.slateMist
                                : AppColors.pearlWhite,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 10),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Cancel',
                      style: AppTypography.bodyMuted),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ReasonTile extends StatelessWidget {
  final ReportReason reason;
  final bool         isSelected;
  final VoidCallback onTap;

  const _ReasonTile({
    required this.reason,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: isSelected
              ? AppColors.softCoral.withValues(alpha: 0.12)
              : AppColors.surfaceGlass,
          border: Border.all(
            color: isSelected ? AppColors.softCoral : AppColors.cardBorder,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(reason.label, style: AppTypography.body),
                  Text(reason.detail,
                      style: AppTypography.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width:  20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? AppColors.softCoral
                    : Colors.transparent,
                border: Border.all(
                  color: isSelected
                      ? AppColors.softCoral
                      : AppColors.cardBorder,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check_rounded,
                      size: 12, color: AppColors.pearlWhite)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
