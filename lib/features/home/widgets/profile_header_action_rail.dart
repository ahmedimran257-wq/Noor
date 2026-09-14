import 'package:flutter/material.dart';
import 'package:silarah/l10n/ui_copy.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/buttons/silarah_pressable.dart';
import 'notification_bell_button.dart';

/// A restrained, theme-native home for private profile activity, ordinary
/// notifications and settings. Each action retains a 48dp target while the
/// shared surface avoids a row of competing floating buttons.
class ProfileHeaderActionRail extends StatelessWidget {
  const ProfileHeaderActionRail({
    super.key,
    required this.unseenViewCount,
    required this.onProfileViews,
    required this.onNotifications,
    required this.onSettings,
  });

  final int unseenViewCount;
  final VoidCallback onProfileViews;
  final VoidCallback onNotifications;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('profile-header-action-rail'),
      decoration: BoxDecoration(
        color: AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
        border: Border.all(color: AppColors.cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ProfileViewsAction(
            unseenCount: unseenViewCount,
            onTap: onProfileViews,
          ),
          const _ActionDivider(),
          NotificationBellButton(
            key: const ValueKey('profile-notification-action'),
            onTap: onNotifications,
            embedded: true,
          ),
          const _ActionDivider(),
          _RailIconAction(
            key: const ValueKey('profile-settings-action'),
            semanticLabel: context.uiCopy('Settings'),
            icon: Icons.settings_outlined,
            onTap: onSettings,
          ),
        ],
      ),
    );
  }
}

class _ProfileViewsAction extends StatelessWidget {
  const _ProfileViewsAction({
    required this.unseenCount,
    required this.onTap,
  });

  final int unseenCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final count = unseenCount < 0 ? 0 : unseenCount;
    final hasUnseen = count > 0;
    final countLabel = count > 99 ? '99+' : '$count';
    final accent = hasUnseen ? AppColors.champagneGold : AppColors.slateMist;

    return SilarahPressable(
      semanticLabel: hasUnseen
          ? '${context.uiCopy('Profile views')}, $count ${context.uiCopy('new')}'
          : context.uiCopy('Profile views'),
      onTap: onTap,
      child: AnimatedContainer(
        key: const ValueKey('profile-views-action'),
        duration: AppDimensions.durationTransition,
        curve: Curves.easeOutCubic,
        constraints: const BoxConstraints(
          minWidth: AppDimensions.minTouchTarget,
          minHeight: AppDimensions.minTouchTarget,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: hasUnseen ? AppDimensions.space10 : AppDimensions.space14,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: AppDimensions.durationTransition,
              child: Icon(
                Icons.visibility_outlined,
                key: ValueKey(hasUnseen),
                color: accent,
                size: AppDimensions.iconSizeMedium,
              ),
            ),
            AnimatedSize(
              duration: AppDimensions.durationTransition,
              curve: Curves.easeOutCubic,
              child: hasUnseen
                  ? Padding(
                      padding: const EdgeInsetsDirectional.only(
                        start: AppDimensions.space4,
                      ),
                      child: UiText(
                        countLabel,
                        key: const ValueKey('profile-views-unseen-count'),
                        style: AppTypography.chipLabel.copyWith(
                          color: accent,
                          fontWeight: FontWeight.w700,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    )
                  : const SizedBox.shrink(
                      key: ValueKey('profile-views-read-state'),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RailIconAction extends StatelessWidget {
  const _RailIconAction({
    super.key,
    required this.semanticLabel,
    required this.icon,
    required this.onTap,
  });

  final String semanticLabel;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SilarahPressable(
      semanticLabel: semanticLabel,
      onTap: onTap,
      child: SizedBox.square(
        dimension: AppDimensions.minTouchTarget,
        child: Icon(
          icon,
          color: AppColors.slateMist,
          size: AppDimensions.iconSizeLarge,
        ),
      ),
    );
  }
}

class _ActionDivider extends StatelessWidget {
  const _ActionDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppDimensions.borderThin,
      height: AppDimensions.iconSizeMedium,
      color: AppColors.divider,
    );
  }
}
