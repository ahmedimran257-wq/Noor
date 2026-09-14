import 'package:silarah/l10n/ui_copy.dart';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimensions.dart';
import '../../theme/app_typography.dart';
import '../buttons/silarah_primary_button.dart';
import '../buttons/silarah_pressable.dart';
import '../buttons/silarah_secondary_button.dart';

/// Theme-native modal route with one controlled entrance treatment.
///
/// Flutter already positions and drag-tracks modal sheets. Adding another
/// full-height slide here creates a visible double movement, so Silarah only
/// keeps its content opaque and leaves movement to the native drag geometry.
class SilarahBottomSheetRoute<T> extends ModalBottomSheetRoute<T> {
  SilarahBottomSheetRoute({
    required super.builder,
    super.capturedThemes,
    super.barrierLabel,
    super.barrierOnTapHint,
    super.backgroundColor,
    super.elevation,
    super.shape,
    super.clipBehavior,
    super.constraints,
    super.modalBarrierColor,
    super.isDismissible = true,
    super.enableDrag = true,
    super.showDragHandle,
    super.isScrollControlled = true,
    super.scrollControlDisabledMaxHeightRatio,
    super.settings,
    super.requestFocus,
    super.transitionAnimationController,
    super.anchorPoint,
    super.useSafeArea = true,
    super.sheetAnimationStyle = const AnimationStyle(
      duration: AppDimensions.durationSheetEnter,
      reverseDuration: AppDimensions.durationSheetExit,
    ),
  });
}

Future<T?> showSilarahBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  Color? backgroundColor,
  String? barrierLabel,
  String? barrierOnTapHint,
  double? elevation,
  ShapeBorder? shape,
  Clip? clipBehavior,
  BoxConstraints? constraints,
  Color? barrierColor,
  bool isDismissible = true,
  bool enableDrag = true,
  bool? showDragHandle,
  bool isScrollControlled = false,
  double scrollControlDisabledMaxHeightRatio = 9.0 / 16.0,
  bool useRootNavigator = false,
  bool useSafeArea = false,
  RouteSettings? routeSettings,
  AnimationController? transitionAnimationController,
  Offset? anchorPoint,
  AnimationStyle? sheetAnimationStyle,
  bool? requestFocus,
}) {
  final navigator = Navigator.of(context, rootNavigator: useRootNavigator);
  final capturedThemes = InheritedTheme.capture(
    from: context,
    to: navigator.context,
  );
  final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  return navigator.push<T>(
    SilarahBottomSheetRoute<T>(
      builder: builder,
      capturedThemes: capturedThemes,
      backgroundColor: backgroundColor,
      elevation: elevation,
      shape: shape,
      clipBehavior: clipBehavior,
      constraints: constraints,
      modalBarrierColor: barrierColor ?? AppColors.overlayBlack55,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      showDragHandle: showDragHandle,
      isScrollControlled: isScrollControlled,
      scrollControlDisabledMaxHeightRatio: scrollControlDisabledMaxHeightRatio,
      useSafeArea: useSafeArea,
      settings: routeSettings,
      transitionAnimationController: transitionAnimationController,
      anchorPoint: anchorPoint,
      requestFocus: requestFocus,
      barrierLabel: barrierLabel ??
          MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierOnTapHint: barrierOnTapHint,
      sheetAnimationStyle: reduceMotion
          ? AnimationStyle.noAnimation
          : sheetAnimationStyle ??
              const AnimationStyle(
                duration: AppDimensions.durationSheetEnter,
                reverseDuration: AppDimensions.durationSheetExit,
              ),
    ),
  );
}

class SilarahSheetHandle extends StatelessWidget {
  const SilarahSheetHandle({super.key});

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
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusCard),
        ),
        border: Border(
          top: BorderSide(
              color: AppColors.cardBorder, width: AppDimensions.borderThin),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: AppColors.active.mode.isDark ? .38 : .12,
            ),
            blurRadius: 30,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showHandle)
            const Center(
              child: SilarahSheetHandle(),
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
              child: UiText(title!, style: AppTypography.userName),
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
              child: UiText(subtitle!, style: AppTypography.bodyMuted),
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

// Report Options Sheet
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
    return SilarahPressable(
      onTap: onTap,
      semanticLabel: label,
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppDimensions.horizontalMargin,
          AppDimensions.space16,
          AppDimensions.horizontalMargin,
          AppDimensions.space16,
        ),
        decoration: BoxDecoration(
          border: Border(
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
              child: UiText(
                label,
                style: AppTypography.body.copyWith(
                  color: isSelected
                      ? AppColors.champagneGold
                      : AppColors.pearlWhite,
                ),
              ),
            ),
            if (isSelected)
              Icon(
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
