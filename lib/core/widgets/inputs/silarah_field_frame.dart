import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_dimensions.dart';

/// The only visual shell used around editable controls.
///
/// The stroke remains one physical pixel in every state. Keeping the geometry
/// fixed prevents the concentric focus rings and layout shimmer caused by a
/// decorated parent competing with an [InputDecoration] outline.
class SilarahFieldFrame extends StatelessWidget {
  const SilarahFieldFrame({
    super.key,
    required this.child,
    required this.focused,
    this.enabled = true,
    this.hasError = false,
    this.minHeight = AppDimensions.inputHeight,
    this.radius = AppDimensions.radiusButton,
  });

  final Widget child;
  final bool focused;
  final bool enabled;
  final bool hasError;
  final double minHeight;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final edgeColor = !enabled
        ? AppColors.cardBorder.withValues(alpha: 0.42)
        : hasError
            ? AppColors.softCoral.withValues(alpha: 0.84)
            : focused
                ? AppColors.champagneGold.withValues(alpha: 0.82)
                : AppColors.cardBorder;

    return AnimatedContainer(
      duration: reduceMotion ? Duration.zero : AppDimensions.durationTransition,
      curve: Curves.easeOutCubic,
      constraints: BoxConstraints(minHeight: minHeight),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: enabled
            ? AppColors.inputSurface
            : AppColors.inputSurface.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: edgeColor,
          width: AppDimensions.borderThin,
          strokeAlign: BorderSide.strokeAlignInside,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.obsidianNight.withValues(
              alpha: focused ? 0.34 : 0.22,
            ),
            blurRadius: focused ? 18 : 12,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: child,
    );
  }
}
