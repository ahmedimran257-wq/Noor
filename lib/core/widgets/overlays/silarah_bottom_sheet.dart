// lib/core/widgets/overlays/silarah_bottom_sheet.dart
// ============================================================
// SILARAH Bottom Sheet
// "NO Pop-ups: Use Bottom Sheets that slide up with spring physics."
// All dialogs and confirmations use this.
// ============================================================

import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimensions.dart';
import '../../theme/app_typography.dart';
import '../buttons/silarah_primary_button.dart';
import '../buttons/silarah_secondary_button.dart';

// ── Custom Route for Frosted Glass & Spring Transition ────────

class SilarahBottomSheetRoute<T> extends ModalBottomSheetRoute<T> {
  SilarahBottomSheetRoute({
    required super.builder,
    super.capturedThemes,
    super.barrierLabel,
    super.isDismissible = true,
    super.enableDrag = true,
    super.isScrollControlled = true,
    super.scrollControlDisabledMaxHeightRatio,
    super.settings,
    super.transitionAnimationController,
    super.anchorPoint,
    super.useSafeArea = true,
  });

  @override
  Color get barrierColor => const Color(0x66000000); // 40% black barrier

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final routeAnimation = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    final slide = Tween<Offset>(
      begin: const Offset(0.0, 1.0),
      end: Offset.zero,
    ).animate(routeAnimation);

    return SlideTransition(
      position: slide,
      child: child,
    );
  }
}

// ── Show Helper ───────────────────────────────────────────────

Future<T?> showSilarahBottomSheet<T>({
  required BuildContext context,
  required Widget child,
  bool isDismissible = true,
  bool isScrollControlled = true,
}) {
  return Navigator.of(context).push<T>(
    SilarahBottomSheetRoute<T>(
      builder: (_) => child,
      isDismissible: isDismissible,
      enableDrag: isDismissible,
      isScrollControlled: isScrollControlled,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    ),
  );
}

// ── Pulsing Handle Bar ────────────────────────────────────────

class SilarahPulseHandle extends StatelessWidget {
  const SilarahPulseHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: AppDimensions.space12),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: AppColors.slateMist.withValues(alpha: 0.46),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

// ── Standard Bottom Sheet Shell ───────────────────────────────

class SilarahBottomSheet extends StatelessWidget {
  const SilarahBottomSheet({
    super.key,
    this.title,
    this.subtitle,
    required this.child,
    this.primaryAction,
    this.secondaryAction,
    this.showHandle = true,
    this.padding,
  });

  final String? title;
  final String? subtitle;
  final Widget child;
  final BottomSheetAction? primaryAction;
  final BottomSheetAction? secondaryAction;
  final bool showHandle;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0x990A0A0F), // Frosted glass obsidian night
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusCard),
        ),
        border: Border(
          top: BorderSide(
              color: AppColors.cardBorder, width: AppDimensions.borderThin),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle indicator
          if (showHandle)
            const Center(
              child: SilarahPulseHandle(),
            ),

          // Title
          if (title != null)
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(
                AppDimensions.horizontalMargin,
                AppDimensions.space20,
                AppDimensions.horizontalMargin,
                subtitle != null ? AppDimensions.space4 : AppDimensions.space20,
              ),
              child: Text(title!, style: AppTypography.userName),
            ),

          // Subtitle
          if (subtitle != null)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppDimensions.horizontalMargin,
                0,
                AppDimensions.horizontalMargin,
                AppDimensions.space20,
              ),
              child: Text(subtitle!, style: AppTypography.bodyMuted),
            ),

          // Content
          Padding(
            padding: padding ??
                const EdgeInsetsDirectional.symmetric(
                  horizontal: AppDimensions.horizontalMargin,
                ),
            child: child,
          ),

          // Actions
          if (primaryAction != null || secondaryAction != null) ...[
            const SizedBox(height: AppDimensions.space24),
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: AppDimensions.horizontalMargin,
              ),
              child: Column(
                children: [
                  if (primaryAction != null)
                    SilarahPrimaryButton(
                      label: primaryAction!.label,
                      onTap: primaryAction!.onTap,
                    ),
                  if (secondaryAction != null) ...[
                    const SizedBox(height: AppDimensions.space12),
                    SilarahSecondaryButton(
                      label: secondaryAction!.label,
                      onTap: secondaryAction!.onTap,
                    ),
                  ],
                ],
              ),
            ),
          ],

          // Safe area bottom padding
          SizedBox(
            height:
                MediaQuery.of(context).padding.bottom + AppDimensions.space24,
          ),
        ],
      ),
    );
  }
}

class BottomSheetAction {
  const BottomSheetAction({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
}

// ── Report Options Sheet ──────────────────────────────────────

class SilarahReportSheet extends StatefulWidget {
  const SilarahReportSheet({super.key, required this.onSubmit});
  final ValueChanged<String> onSubmit;

  @override
  State<SilarahReportSheet> createState() => _SilarahReportSheetState();
}

class _SilarahReportSheetState extends State<SilarahReportSheet> {
  String? _selected;

  static const _reasons = [
    ('fake_profile', 'Fake or impersonating someone'),
    ('inappropriate_photos', 'Inappropriate photos'),
    ('harassment', 'Harassment or abusive messages'),
    ('scam', 'Scam or asking for money'),
    ('underage', 'Appears to be under 18'),
    ('already_married', 'Already married'),
    ('offensive_bio', 'Offensive or inappropriate bio'),
    ('other', 'Other reason'),
  ];

  @override
  Widget build(BuildContext context) {
    return SilarahBottomSheet(
      title: 'Report Profile',
      subtitle: 'Help keep SILARAH safe for everyone.',
      padding: EdgeInsets.zero,
      primaryAction: _selected != null
          ? BottomSheetAction(
              label: 'Submit Report',
              onTap: () {
                Navigator.pop(context);
                widget.onSubmit(_selected!);
              },
            )
          : null,
      child: Column(
        children: _reasons.map((reason) {
          final (key, label) = reason;
          final isSelected = _selected == key;
          return _ReportOption(
            label: label,
            isSelected: isSelected,
            onTap: () => setState(() => _selected = key),
          );
        }).toList(),
      ),
    );
  }
}

class _ReportOption extends StatelessWidget {
  const _ReportOption({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppDimensions.horizontalMargin,
          AppDimensions.space16,
          AppDimensions.horizontalMargin,
          AppDimensions.space16,
        ),
        decoration: BoxDecoration(
          border: const Border(
            bottom: BorderSide(
              color: AppColors.divider,
              width: AppDimensions.borderThin,
            ),
          ),
          color: isSelected ? AppColors.goldGlow : Colors.transparent,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: AppTypography.body.copyWith(
                  color: isSelected
                      ? AppColors.champagneGold
                      : AppColors.pearlWhite,
                ),
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_rounded,
                color: AppColors.champagneGold,
                size: AppDimensions.iconSizeMedium,
              ),
          ],
        ),
      ),
    );
  }
}
