// lib/features/home/widgets/noor_bottom_nav.dart
// ============================================================
// NOOR — Bottom Navigation Bar
// 4 tabs: Discover / Interests / Chat / Profile
// Active: Champagne Gold icon + thin gold underline
// Inactive: Slate Mist
// Badges: Gold bubble on Interests (pending received count)
//         and Chat (total unread count)
// ============================================================

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

class NoorBottomNav extends StatelessWidget {
  const NoorBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
  });

  final int currentIndex;
  final ValueChanged<int> onTabSelected;

  static const _items = [
    _NavItem(icon: Icons.explore_outlined,            activeIcon: Icons.explore_rounded,         label: 'Discover'),
    _NavItem(icon: Icons.favorite_outline_rounded,    activeIcon: Icons.favorite_rounded,        label: 'Interests'),
    _NavItem(icon: Icons.chat_bubble_outline_rounded, activeIcon: Icons.chat_bubble_rounded,     label: 'Chat'),
    _NavItem(icon: Icons.person_outline_rounded,      activeIcon: Icons.person_rounded,          label: 'Profile'),
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

            return Container(
              decoration: const BoxDecoration(
                color: Color(0xCC0A0A0F), // Frosted obsidian
                border: Border(
                  top: BorderSide(
                    color: AppColors.cardBorder,
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
                      final item   = _items[index];
                      final active = index == currentIndex;
                      final badge  = badges[index] ?? 0;
                      return Expanded(
                        child: _NavTab(
                          item:     item,
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
  final String   label;
}

// ── Nav Tab ───────────────────────────────────────────────────

class _NavTab extends StatelessWidget {
  const _NavTab({
    required this.item,
    required this.isActive,
    required this.badgeCount,
    required this.onTap,
  });

  final _NavItem     item;
  final bool         isActive;
  final int          badgeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap:    onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Gold underline indicator (top)
          AnimatedContainer(
            duration: AppDimensions.durationTransition,
            width:  isActive ? 24.0 : 0.0,
            height: 2.0,
            margin: const EdgeInsets.only(bottom: AppDimensions.space6),
            decoration: BoxDecoration(
              color:        AppColors.champagneGold,
              borderRadius: BorderRadius.circular(AppDimensions.radiusTiny),
            ),
          ),

          // Icon + optional badge
          Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedSwitcher(
                duration: AppDimensions.durationTransition,
                child: Icon(
                  isActive ? item.activeIcon : item.icon,
                  key:   ValueKey(isActive),
                  color: isActive ? AppColors.champagneGold : AppColors.slateMist,
                  size:  AppDimensions.iconSizeLarge,
                ),
              ),

              // Badge — only visible when count > 0
              AnimatedPositioned(
                duration: AppDimensions.durationTransition,
                top:   -4,
                right: -6,
                child: AnimatedOpacity(
                  duration: AppDimensions.durationTransition,
                  opacity:  badgeCount > 0 ? 1.0 : 0.0,
                  child: AnimatedScale(
                    duration: AppDimensions.durationTransition,
                    scale:    badgeCount > 0 ? 1.0 : 0.0,
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
              color:      isActive ? AppColors.champagneGold : AppColors.slateMist,
              fontSize:   11,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            ),
            child: Text(item.label),
          ),
        ],
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
        color:  AppColors.champagneGold,
        borderRadius: BorderRadius.circular(AppDimensions.radiusTiny),
        border: Border.all(
          color: const Color(0xFF0A0A0F), // match nav background
          width: 1.5,
        ),
      ),
      child: Center(
        child: Text(
          label,
          style: AppTypography.badge.copyWith(
            fontSize:   9,
            color:      AppColors.obsidianNight,
            fontWeight: FontWeight.w800,
            height:     1.0,
          ),
        ),
      ),
    );
  }
}
