// lib/features/home/widgets/mithaq_bottom_nav.dart
// ============================================================
// MITHAQ — Bottom Navigation Bar
// 4 tabs: Discover / Interests / Chat / Profile
// Active: Champagne Gold icon + thin gold underline
// Inactive: Slate Mist
// Badges: Gold bubble on Interests (pending received count)
//         and Chat (total unread count)
// ============================================================

import 'dart:ui';
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
import '../../../core/theme/mithaq_spring.dart';

class MithaqBottomNav extends StatelessWidget {
  const MithaqBottomNav({
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
    // Read badge counts once at the nav level so both builders stay in sync.
    return BlocBuilder<InterestsCubit, InterestsState>(
      builder: (context, interestsState) {
        return BlocBuilder<ChatCubit, ChatState>(
          builder: (context, chatState) {
            // Badge counts per tab index (null = no badge)
            final badges = <int, int>{
              1: interestsState.unreadCount,
              2: chatState.totalUnread,
            };

            return ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
                child: Container(
                  decoration: const BoxDecoration(
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
                    child: SizedBox(
                      height: 64,
                      child: Row(
                        children: List.generate(_items.length, (index) {
                          final item = _items[index];
                          final active = index == currentIndex;
                          final badge = badges[index] ?? 0;
                          return Expanded(
                            child: _NavTab(
                              item: item,
                              isActive: active,
                              badgeCount: badge,
                              onTap: () {
                                HapticFeedback.selectionClick();
                                onTabSelected(index);
                              },
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
      },
    );
  }
}

// ── Nav Item data ─────────────────────────────────────────────

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

// ── Nav Tab ───────────────────────────────────────────────────

class _NavTab extends StatelessWidget {
  const _NavTab({
    required this.item,
    required this.isActive,
    required this.badgeCount,
    required this.onTap,
  });

  final _NavItem item;
  final bool isActive;
  final int badgeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: const SpringCurve(
          spring: MithaqSpring.snappy,
          duration: Duration(milliseconds: 320),
        ),
        margin: const EdgeInsets.symmetric(
          horizontal: AppDimensions.space6,
          vertical: AppDimensions.space6,
        ),
        padding: const EdgeInsets.symmetric(vertical: AppDimensions.space6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          gradient: isActive
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.champagneGold.withValues(alpha: 0.16),
                    AppColors.inkTeal.withValues(alpha: 0.12),
                    AppColors.surfaceGlassHover,
                  ],
                )
              : null,
          border: Border.all(
            color: isActive ? AppColors.goldBorder : AppColors.transparent,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Gold underline indicator (top)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: const SpringCurve(
                spring: MithaqSpring.snappy,
                duration: Duration(milliseconds: 300),
              ),
              width: isActive ? 18.0 : 4.0,
              height: 3.0,
              margin: const EdgeInsets.only(bottom: AppDimensions.space4),
              decoration: BoxDecoration(
                gradient: isActive
                    ? const LinearGradient(
                        colors: [
                          AppColors.champagneLight,
                          AppColors.champagneGold,
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
                AnimatedScale(
                  duration: AppDimensions.durationTransition,
                  scale: isActive ? 1.08 : 1,
                  child: AnimatedSwitcher(
                    duration: AppDimensions.durationTransition,
                    child: Icon(
                      isActive ? item.activeIcon : item.icon,
                      key: ValueKey(isActive),
                      color: isActive
                          ? AppColors.champagneLight
                          : AppColors.slateMist,
                      size: AppDimensions.iconSizeLarge,
                    ),
                  ),
                ),

                // Badge — only visible when count > 0
                AnimatedPositioned(
                  duration: AppDimensions.durationTransition,
                  top: -4,
                  right: -6,
                  child: AnimatedOpacity(
                    duration: AppDimensions.durationTransition,
                    opacity: badgeCount > 0 ? 1.0 : 0.0,
                    child: AnimatedScale(
                      duration: AppDimensions.durationTransition,
                      scale: badgeCount > 0 ? 1.0 : 0.0,
                      child: _Badge(count: badgeCount),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppDimensions.space4),

            // Label
            AnimatedDefaultTextStyle(
              duration: AppDimensions.durationTransition,
              style: AppTypography.caption.copyWith(
                color:
                    isActive ? AppColors.champagneLight : AppColors.slateMist,
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
              ),
              child: Text(item.label),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Badge bubble ──────────────────────────────────────────────

class _Badge extends StatelessWidget {
  const _Badge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final label = count > 9 ? '9+' : '$count';
    return Container(
      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            AppColors.champagneLight,
            AppColors.champagneGold,
          ],
        ),
        borderRadius: BorderRadius.circular(AppDimensions.radiusTiny),
        border: Border.all(
          color: AppColors.obsidianNight,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.champagneGold.withValues(alpha: 0.28),
            blurRadius: 8,
          ),
        ],
      ),
      child: Center(
        child: Text(
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
