// lib/features/home/widgets/noor_bottom_nav.dart
// ============================================================
// NOOR — Bottom Navigation Bar
// 4 tabs: Discover / Interests / Chat / Profile
// Active: Champagne Gold icon + thin gold underline
// Inactive: Slate Mist
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    _NavItem(icon: Icons.explore_outlined,       activeIcon: Icons.explore_rounded,         label: 'Discover'),
    _NavItem(icon: Icons.favorite_outline_rounded, activeIcon: Icons.favorite_rounded,       label: 'Interests'),
    _NavItem(icon: Icons.chat_bubble_outline_rounded, activeIcon: Icons.chat_bubble_rounded, label: 'Chat'),
    _NavItem(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded,           label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xCC0A0A0F), // Frosted obsidian
        border: Border(
          top: BorderSide(color: AppColors.cardBorder, width: AppDimensions.borderThin),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: List.generate(_items.length, (index) {
              final item    = _items[index];
              final active  = index == currentIndex;
              return Expanded(
                child: _NavTab(
                  item:     item,
                  isActive: active,
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
  }
}

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

class _NavTab extends StatelessWidget {
  const _NavTab({
    required this.item,
    required this.isActive,
    required this.onTap,
  });

  final _NavItem item;
  final bool     isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap:       onTap,
      behavior:    HitTestBehavior.opaque,
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

          // Icon
          AnimatedSwitcher(
            duration: AppDimensions.durationTransition,
            child: Icon(
              isActive ? item.activeIcon : item.icon,
              key:   ValueKey(isActive),
              color: isActive ? AppColors.champagneGold : AppColors.slateMist,
              size:  AppDimensions.iconSizeLarge,
            ),
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
