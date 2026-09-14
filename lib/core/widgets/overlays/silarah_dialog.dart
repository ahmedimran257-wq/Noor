import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_curves.dart';
import '../../theme/app_dimensions.dart';

/// Presents compact confirmations with the same measured motion language used
/// by navigation and modal sheets.
Future<T?> showSilarahDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color? barrierColor,
  String? barrierLabel,
  bool useSafeArea = true,
  bool useRootNavigator = true,
  RouteSettings? routeSettings,
  Offset? anchorPoint,
  TraversalEdgeBehavior? traversalEdgeBehavior,
  bool fullscreenDialog = false,
  bool? requestFocus,
  AnimationStyle? animationStyle,
}) {
  final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
  return showDialog<T>(
    context: context,
    builder: builder,
    barrierDismissible: barrierDismissible,
    barrierColor: barrierColor ?? AppColors.overlayBlack55,
    barrierLabel: barrierLabel,
    useSafeArea: useSafeArea,
    useRootNavigator: useRootNavigator,
    routeSettings: routeSettings,
    anchorPoint: anchorPoint,
    traversalEdgeBehavior: traversalEdgeBehavior,
    fullscreenDialog: fullscreenDialog,
    requestFocus: requestFocus,
    animationStyle: reduceMotion
        ? AnimationStyle.noAnimation
        : animationStyle ??
            const AnimationStyle(
              duration: AppDimensions.durationDialogEnter,
              reverseDuration: AppDimensions.durationDialogExit,
              curve: AppCurves.reveal,
              reverseCurve: AppCurves.dismiss,
            ),
  );
}
