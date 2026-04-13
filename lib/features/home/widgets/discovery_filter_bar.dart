// lib/features/home/widgets/discovery_filter_bar.dart
// ============================================================
// NOOR — Discovery Filter Bar
// Horizontally scrollable chip row for filtering the feed.
// Active chip: gold border + gold text
// Inactive chip: surfaceGlass + slateMist
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';

class DiscoveryFilterBar extends StatefulWidget {
  const DiscoveryFilterBar({super.key});

  @override
  State<DiscoveryFilterBar> createState() => _DiscoveryFilterBarState();
}

class _DiscoveryFilterBarState extends State<DiscoveryFilterBar> {
  final Set<int> _activeFilters = {};

  static const _filters = [
    _Filter(icon: Icons.tune_rounded,            label: 'All Filters'),
    _Filter(icon: Icons.cake_outlined,           label: 'Age Range'),
    _Filter(icon: Icons.location_on_outlined,    label: 'Location'),
    _Filter(icon: Icons.mosque_outlined,         label: 'Sect'),
    _Filter(icon: Icons.brightness_5_outlined,   label: 'Deen Level'),
    _Filter(icon: Icons.verified_outlined,       label: 'Verified Only'),
  ];

  void _toggle(int index) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_activeFilters.contains(index)) {
        _activeFilters.remove(index);
      } else {
        _activeFilters.add(index);
      }
    });

    // Show bottom sheet for any filter
    _showFilterSheet(index);
  }

  void _showFilterSheet(int index) {
    final filter = _filters[index];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _FilterSheet(filterName: filter.label),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppDimensions.space24),
        itemCount: _filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppDimensions.space8),
        itemBuilder: (context, index) {
          final active = _activeFilters.contains(index);
          final filter = _filters[index];
          return _FilterChip(
            filter:   filter,
            isActive: active,
            onTap:    () => _toggle(index),
          );
        },
      ),
    );
  }
}

class _Filter {
  const _Filter({required this.icon, required this.label});
  final IconData icon;
  final String   label;
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.filter,
    required this.isActive,
    required this.onTap,
  });

  final _Filter  filter;
  final bool     isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppDimensions.durationTransition,
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.space12,
          vertical:   AppDimensions.space8,
        ),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.champagneGold.withValues(alpha: 0.12)
              : AppColors.surfaceGlass,
          borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
          border: Border.all(
            color: isActive ? AppColors.champagneGold : AppColors.cardBorder,
            width: isActive
                ? AppDimensions.borderFocus
                : AppDimensions.borderThin,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              filter.icon,
              color:  isActive ? AppColors.champagneGold : AppColors.slateMist,
              size:   AppDimensions.iconSizeSmall,
            ),
            const SizedBox(width: AppDimensions.space6),
            Text(
              filter.label,
              style: AppTypography.chipLabel.copyWith(
                color: isActive ? AppColors.champagneGold : AppColors.slateMist,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Filter Bottom Sheet ───────────────────────────────────────

class _FilterSheet extends StatelessWidget {
  const _FilterSheet({required this.filterName});
  final String filterName;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(AppDimensions.space16),
      padding: const EdgeInsets.all(AppDimensions.space24),
      decoration: BoxDecoration(
        color:        const Color(0xFF13131A),
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border:       Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width:  40,
              height: 4,
              decoration: BoxDecoration(
                color:        AppColors.cardBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.space24),

          Text(filterName, style: AppTypography.screenTitle.copyWith(fontSize: 22)),
          const SizedBox(height: AppDimensions.space12),
          Text(
            'Filter controls for "$filterName" will be available once the live backend is connected in Step 6.',
            style: AppTypography.bodyMuted,
          ),
          const SizedBox(height: AppDimensions.space32),

          // Close
          SizedBox(
            width: double.infinity,
            height: AppDimensions.buttonHeight,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.champagneGold,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                ),
              ),
              onPressed: () => Navigator.pop(context),
              child: Text('Close', style: AppTypography.button),
            ),
          ),
          const SizedBox(height: AppDimensions.space16),
        ],
      ),
    );
  }
}
