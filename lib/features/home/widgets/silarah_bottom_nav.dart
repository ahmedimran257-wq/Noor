// SILARAH — Bottom Navigation Bar
// 4 tabs: Discover / Interests / Chat / Profile
// Active: Champagne Gold icon + thin gold underline
// Inactive: Slate Mist
// Badges: Gold bubble on Interests (pending received count)
//         and Chat (total unread count)
import 'package:silarah/l10n/ui_copy.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/cubits/interests/interests_cubit.dart';
import '../../../core/cubits/interests/interests_state.dart';
import '../../../core/cubits/chat/chat_cubit.dart';
import '../../../core/cubits/chat/chat_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/buttons/silarah_pressable.dart';

class SilarahBottomNav extends StatelessWidget {
  const SilarahBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
  });

  final int currentIndex;
  final ValueChanged<int> onTabSelected;

  static const _items = [
    _NavItem(
        icon: Icons.explore_outlined,
        activeIcon: Icons.explore_rounded,
        label: 'Discover'),
    _NavItem(
        icon: Icons.favorite_outline_rounded,
        activeIcon: Icons.favorite_rounded,
        label: 'Interests'),
    _NavItem(
        icon: Icons.chat_bubble_outline_rounded,
        activeIcon: Icons.chat_bubble_rounded,
        label: 'Chat'),
    _NavItem(
        icon: Icons.person_outline_rounded,
        activeIcon: Icons.person_rounded,
        label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return BlocSelector<InterestsCubit, InterestsState, int>(
      selector: (state) => state.unreadCount,
      builder: (context, interestUnread) {
        return BlocSelector<ChatCubit, ChatState, int>(
          selector: (state) => state.totalUnread,
          builder: (context, chatUnread) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.noScaling,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.navBarSurface,
                border: Border(
                  top: BorderSide(
                    color: AppColors.navBarBorder,
                    width: AppDimensions.borderThin,
                  ),
                ),
              ),
              child: SafeArea(
                top: false,
                minimum: const EdgeInsets.only(bottom: 4),
                child: SizedBox(
                  height: 72,
                  child: Row(
                    children: List.generate(_items.length, (index) {
                      final badge = switch (index) {
                        1 => interestUnread,
                        2 => chatUnread,
                        _ => 0,
                      };
                      return Expanded(
                        child: RepaintBoundary(
                          child: _NavTab(
                            item: _items[index],
                            isActive: index == currentIndex,
                            badgeCount: badge,
                            accent: AppColors.spectrum(index),
                            secondaryAccent: AppColors.isChromatic
                                ? AppColors.spectrum(index + 1)
                                : AppColors.midnightPlum,
                            onTap: () {
                              if (index == currentIndex) return;
                              HapticFeedback.selectionClick();
                              onTabSelected(index);
                            },
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// Nav Item data
class _NavItem {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
  final IconData icon;
  final IconData activeIcon;
  final String label;
}

// Nav Tab
class _NavTab extends StatelessWidget {
  const _NavTab({
    required this.item,
    required this.isActive,
    required this.badgeCount,
    required this.accent,
    required this.secondaryAccent,
    required this.onTap,
  });

  final _NavItem item;
  final bool isActive;
  final int badgeCount;
  final Color accent;
  final Color secondaryAccent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SilarahPressable(
      onTap: onTap,
      haptic: false,
      child: AnimatedContainer(
        duration: AppDimensions.durationTransition,
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.symmetric(
          horizontal: 3,
          vertical: 4,
        ),
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppDimensions.radiusButton - 2),
          gradient: isActive
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    accent.withValues(alpha: 0.17),
                    secondaryAccent.withValues(alpha: 0.22),
                    AppColors.surfaceGlassHover,
                  ],
                )
              : null,
          border: Border.all(
            color: isActive
                ? accent.withValues(alpha: 0.68)
                : AppColors.transparent,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Gold underline indicator (top)
            AnimatedContainer(
              duration: AppDimensions.durationTransition,
              curve: Curves.easeOutCubic,
              width: isActive ? 18.0 : 4.0,
              height: 3.0,
              margin: const EdgeInsets.only(bottom: AppDimensions.space2),
              decoration: BoxDecoration(
                gradient: isActive
                    ? LinearGradient(
                        colors: [
                          accent,
                          AppColors.isChromatic
                              ? secondaryAccent
                              : AppColors.champagneLight,
                        ],
                      )
                    : null,
                color: isActive ? null : AppColors.transparent,
                borderRadius: BorderRadius.circular(AppDimensions.radiusTiny),
              ),
            ),

            // Icon + optional badge
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  isActive ? item.activeIcon : item.icon,
                  color: isActive
                      ? accent
                      : AppColors.isChromatic
                          ? accent.withValues(alpha: .68)
                          : AppColors.slateMist,
                  size: 22,
                ),

                // Badge — only visible when count > 0
                if (badgeCount > 0)
                  Positioned(
                    top: -4,
                    right: -6,
                    child: _Badge(count: badgeCount, accent: accent),
                  ),
              ],
            ),

            const SizedBox(height: 1),

            // Label
            AnimatedDefaultTextStyle(
              duration: AppDimensions.durationTransition,
              style: AppTypography.caption.copyWith(
                color: isActive ? accent : AppColors.slateMist,
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                height: 1.0,
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: UiText(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Badge bubble
class _Badge extends StatelessWidget {
  const _Badge({required this.count, required this.accent});
  final int count;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final label = count > 9 ? '9+' : '$count';
    return Container(
      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accent,
            AppColors.isChromatic
                ? AppColors.spectrum(4)
                : AppColors.champagneLight,
          ],
        ),
        borderRadius: BorderRadius.circular(AppDimensions.radiusTiny),
        border: Border.all(
          color: AppColors.obsidianNight,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.28),
            blurRadius: 8,
          ),
        ],
      ),
      child: Center(
        child: UiText(
          label,
          style: AppTypography.badge.copyWith(
            fontSize: 9,
            color: AppColors.obsidianNight,
            fontWeight: FontWeight.w800,
            height: 1.0,
          ),
        ),
      ),
    );
  }
}
