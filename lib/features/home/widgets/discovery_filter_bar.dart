// lib/features/home/widgets/discovery_filter_bar.dart
// ============================================================
// SILARAH — Discovery Filter Bar (Step 6 — Functional)
//
// Blueprint (Part 8, Search & Filters):
//   "A full-height bottom sheet with all available filters.
//    Age range with a dual slider. Sect and sub-sect.
//    Deen level. Verified only. Family type.
//    Active recently toggle."
//
// Each chip shows an active indicator when that filter is set.
// Tapping "All Filters" opens the comprehensive sheet.
// Tapping any individual chip opens that filter's mini-sheet.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/cubits/discovery/discovery_feed_cubit.dart';
import '../../../core/cubits/discovery/discovery_feed_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import 'discovery_filter_sheet.dart';

// ─────────────────────────────────────────────────────────────

class DiscoveryFilterBar extends StatelessWidget {
  const DiscoveryFilterBar({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<DiscoveryFeedCubit, DiscoveryFeedState,
        DiscoveryFilter>(
      selector: (state) => state.activeFilter,
      builder: (context, f) {
        return SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding:
                const EdgeInsets.symmetric(horizontal: AppDimensions.space24),
            children: [
              _Chip(
                icon: Icons.tune_rounded,
                accentSlot: 0,
                label: f.activeCount > 0
                    ? 'Filters (${f.activeCount})'
                    : 'All Filters',
                isActive: f.isActive,
                onTap: () => _showAllFilters(context, f),
              ),
              const SizedBox(width: AppDimensions.space8),
              _Chip(
                icon: Icons.cake_outlined,
                accentSlot: 1,
                label: (f.ageMin != null || f.ageMax != null)
                    ? '${f.ageMin ?? 18}–${f.ageMax ?? 60}'
                    : 'Age Range',
                isActive: f.ageMin != null || f.ageMax != null,
                onTap: () => _showAgeFilter(context, f),
              ),
              const SizedBox(width: AppDimensions.space8),
              _Chip(
                icon: Icons.mosque_outlined,
                accentSlot: 2,
                label: f.sect ?? 'Sect',
                isActive: f.sect != null,
                onTap: () => _showSectFilter(context, f),
              ),
              const SizedBox(width: AppDimensions.space8),
              _Chip(
                icon: Icons.brightness_5_outlined,
                accentSlot: 3,
                label: f.deenLevel != null
                    ? _formatDeen(f.deenLevel!)
                    : 'Deen Level',
                isActive: f.deenLevel != null,
                onTap: () => _showDeenFilter(context, f),
              ),
              const SizedBox(width: AppDimensions.space8),
              _Chip(
                icon: Icons.verified_outlined,
                accentSlot: 4,
                label: 'Verified Only',
                isActive: f.verifiedOnly,
                onTap: () {
                  HapticFeedback.selectionClick();
                  context.read<DiscoveryFeedCubit>().applyFilter(
                        f.copyWith(verifiedOnly: !f.verifiedOnly),
                      );
                },
              ),
              const SizedBox(width: AppDimensions.space8),
              _Chip(
                icon: Icons.people_outline_rounded,
                accentSlot: 5,
                label: f.familyType ?? 'Family Type',
                isActive: f.familyType != null,
                onTap: () => _showFamilyFilter(context, f),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Filter openers ────────────────────────────────────────

  void _showAllFilters(BuildContext context, DiscoveryFilter filter) {
    showDiscoveryFilterSheet(context, initial: filter);
  }

  void _showAgeFilter(BuildContext context, DiscoveryFilter filter) {
    showDiscoveryFilterSheet(context, initial: filter, scrollToSection: 'age');
  }

  void _showSectFilter(BuildContext context, DiscoveryFilter filter) {
    showDiscoveryFilterSheet(context, initial: filter, scrollToSection: 'sect');
  }

  void _showDeenFilter(BuildContext context, DiscoveryFilter filter) {
    showDiscoveryFilterSheet(context, initial: filter, scrollToSection: 'deen');
  }

  void _showFamilyFilter(BuildContext context, DiscoveryFilter filter) {
    showDiscoveryFilterSheet(context,
        initial: filter, scrollToSection: 'family');
  }

  static String _formatDeen(String raw) {
    switch (raw) {
      case 'practicing':
        return 'Practicing';
      case 'moderate':
        return 'Moderate';
      case 'cultural':
        return 'Cultural';
      default:
        return raw;
    }
  }
}

// ── Chip widget ───────────────────────────────────────────────

class _Chip extends StatelessWidget {
  const _Chip({
    required this.icon,
    required this.accentSlot,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final int accentSlot;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.spectrum(accentSlot);
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: AppDimensions.durationTransition,
        constraints: const BoxConstraints(
          minHeight: 44,
          maxWidth: 176,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.space12,
          vertical: AppDimensions.space8,
        ),
        decoration: BoxDecoration(
          color: isActive
              ? accent.withValues(alpha: 0.12)
              : AppColors.surfaceGlass,
          borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
          border: Border.all(
            color: isActive
                ? accent
                : AppColors.isChromatic
                    ? accent.withValues(alpha: .28)
                    : AppColors.cardBorder,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive
                  ? accent
                  : AppColors.isChromatic
                      ? accent.withValues(alpha: .78)
                      : AppColors.slateMist,
              size: AppDimensions.iconSizeSmall,
            ),
            const SizedBox(width: AppDimensions.space6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.chipLabel.copyWith(
                  color: isActive ? accent : AppColors.slateMist,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// FILTER BOTTOM SHEETS
// ═══════════════════════════════════════════════════════════════

/// Shared sheet chrome
class _SheetBase extends StatelessWidget {
  const _SheetBase({
    required this.title,
    required this.children,
    this.onReset,
    this.onApply,
  });

  final String title;
  final List<Widget> children;
  final VoidCallback? onReset;
  final VoidCallback? onApply;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(AppDimensions.space16, 0,
          AppDimensions.space16, AppDimensions.space16),
      padding: const EdgeInsets.all(AppDimensions.space24),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.cardBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.space20),

          // Header row
          Row(
            children: [
              Text(title,
                  style: AppTypography.screenTitle.copyWith(fontSize: 20)),
              const Spacer(),
              if (onReset != null)
                GestureDetector(
                  onTap: () {
                    onReset!();
                    Navigator.pop(context);
                  },
                  child: Text('Reset',
                      style: AppTypography.caption
                          .copyWith(color: AppColors.champagneGold)),
                ),
            ],
          ),
          const SizedBox(height: AppDimensions.space20),

          ...children,

          const SizedBox(height: AppDimensions.space20),
          if (onApply != null)
            SizedBox(
              width: double.infinity,
              height: AppDimensions.buttonHeight,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.champagneGold,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusButton),
                  ),
                ),
                onPressed: () {
                  onApply!();
                  Navigator.pop(context);
                },
                child: Text('Apply', style: AppTypography.button),
              ),
            ),
          const SizedBox(height: AppDimensions.space8),
        ],
      ),
    );
  }
}

// ── Age Range Sheet ───────────────────────────────────────────

class _AgeRangeSheet extends StatefulWidget {
  const _AgeRangeSheet({required this.initial});
  final DiscoveryFilter initial;

  @override
  State<_AgeRangeSheet> createState() => _AgeRangeSheetState();
}

class _AgeRangeSheetState extends State<_AgeRangeSheet> {
  late RangeValues _values;

  @override
  void initState() {
    super.initState();
    _values = RangeValues(
      (widget.initial.ageMin ?? 18).toDouble(),
      (widget.initial.ageMax ?? 50).toDouble(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _SheetBase(
      title: 'Age Range',
      onReset: () => context.read<DiscoveryFeedCubit>().applyFilter(
            widget.initial.copyWith(clearAgeRange: true),
          ),
      onApply: () => context.read<DiscoveryFeedCubit>().applyFilter(
            widget.initial.copyWith(
              ageMin: _values.start.round(),
              ageMax: _values.end.round(),
            ),
          ),
      children: [
        // Visual min/max labels
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _AgeLabel(age: _values.start.round()),
            _AgeLabel(age: _values.end.round()),
          ],
        ),
        const SizedBox(height: AppDimensions.space8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: AppColors.champagneGold,
            inactiveTrackColor: AppColors.surfaceGlassHover,
            thumbColor: AppColors.champagneGold,
            overlayColor: AppColors.champagneGold.withValues(alpha: 0.12),
            rangeThumbShape:
                const RoundRangeSliderThumbShape(enabledThumbRadius: 10),
            trackHeight: 3,
          ),
          child: RangeSlider(
            values: _values,
            min: 18,
            max: 60,
            divisions: 42,
            labels: RangeLabels(
              '${_values.start.round()}',
              '${_values.end.round()}',
            ),
            onChanged: (v) => setState(() => _values = v),
          ),
        ),
        const SizedBox(height: AppDimensions.space4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('18', style: AppTypography.caption),
            Text('60', style: AppTypography.caption),
          ],
        ),
      ],
    );
  }
}

class _AgeLabel extends StatelessWidget {
  const _AgeLabel({required this.age});
  final int age;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.space16, vertical: AppDimensions.space8),
      decoration: BoxDecoration(
        color: AppColors.champagneGold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
        border: Border.all(color: AppColors.goldBorder),
      ),
      child: Text(
        '$age yrs',
        style:
            AppTypography.bodyMedium.copyWith(color: AppColors.champagneGold),
      ),
    );
  }
}
