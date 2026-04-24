// lib/features/home/widgets/discovery_filter_bar.dart
// ============================================================
// NOOR — Discovery Filter Bar (Step 6 — Functional)
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

// ─────────────────────────────────────────────────────────────

class DiscoveryFilterBar extends StatelessWidget {
  const DiscoveryFilterBar({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DiscoveryFeedCubit, DiscoveryFeedState>(
      builder: (context, state) {
        final f = state.activeFilter;
        return SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.space24),
            children: [
              _Chip(
                icon:     Icons.tune_rounded,
                label:    f.activeCount > 0
                    ? 'Filters (${f.activeCount})'
                    : 'All Filters',
                isActive: f.isActive,
                onTap:    () => _showAllFilters(context, state),
              ),
              const SizedBox(width: AppDimensions.space8),
              _Chip(
                icon:     Icons.cake_outlined,
                label:    (f.ageMin != null || f.ageMax != null)
                    ? '${f.ageMin ?? 18}–${f.ageMax ?? 60}'
                    : 'Age Range',
                isActive: f.ageMin != null || f.ageMax != null,
                onTap:    () => _showAgeFilter(context, state),
              ),
              const SizedBox(width: AppDimensions.space8),
              _Chip(
                icon:     Icons.mosque_outlined,
                label:    f.sect ?? 'Sect',
                isActive: f.sect != null,
                onTap:    () => _showSectFilter(context, state),
              ),
              const SizedBox(width: AppDimensions.space8),
              _Chip(
                icon:     Icons.brightness_5_outlined,
                label:    f.deenLevel != null
                    ? _formatDeen(f.deenLevel!)
                    : 'Deen Level',
                isActive: f.deenLevel != null,
                onTap:    () => _showDeenFilter(context, state),
              ),
              const SizedBox(width: AppDimensions.space8),
              _Chip(
                icon:     Icons.verified_outlined,
                label:    'Verified Only',
                isActive: f.verifiedOnly,
                onTap:    () {
                  HapticFeedback.selectionClick();
                  context.read<DiscoveryFeedCubit>().applyFilter(
                    f.copyWith(verifiedOnly: !f.verifiedOnly),
                  );
                },
              ),
              const SizedBox(width: AppDimensions.space8),
              _Chip(
                icon:     Icons.people_outline_rounded,
                label:    f.familyType ?? 'Family Type',
                isActive: f.familyType != null,
                onTap:    () => _showFamilyFilter(context, state),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Filter openers ────────────────────────────────────────

  void _showAllFilters(BuildContext context, DiscoveryFeedState state) {
    showModalBottomSheet(
      context:            context,
      backgroundColor:    Colors.transparent,
      isScrollControlled: true,
      builder:            (_) => BlocProvider.value(
        value: context.read<DiscoveryFeedCubit>(),
        child: _AllFiltersSheet(initial: state.activeFilter),
      ),
    );
  }

  void _showAgeFilter(BuildContext context, DiscoveryFeedState state) {
    showModalBottomSheet(
      context:            context,
      backgroundColor:    Colors.transparent,
      isScrollControlled: true,
      builder:            (_) => BlocProvider.value(
        value: context.read<DiscoveryFeedCubit>(),
        child: _AgeRangeSheet(initial: state.activeFilter),
      ),
    );
  }

  void _showSectFilter(BuildContext context, DiscoveryFeedState state) {
    showModalBottomSheet(
      context:            context,
      backgroundColor:    Colors.transparent,
      isScrollControlled: true,
      builder:            (_) => BlocProvider.value(
        value: context.read<DiscoveryFeedCubit>(),
        child: _ChoiceSheet(
          title:    'Sect',
          options:  const ['Sunni', 'Shia', 'Ahmadiyya', 'Other'],
          selected: state.activeFilter.sect,
          onSelect: (v) => context.read<DiscoveryFeedCubit>().applyFilter(
                v == null
                    ? state.activeFilter.copyWith(clearSect: true)
                    : state.activeFilter.copyWith(sect: v),
              ),
        ),
      ),
    );
  }

  void _showDeenFilter(BuildContext context, DiscoveryFeedState state) {
    showModalBottomSheet(
      context:            context,
      backgroundColor:    Colors.transparent,
      isScrollControlled: true,
      builder:            (_) => BlocProvider.value(
        value: context.read<DiscoveryFeedCubit>(),
        child: _ChoiceSheet(
          title:    'Deen Level',
          options:  const ['practicing', 'moderate', 'cultural'],
          optionLabels: const ['Practicing', 'Moderate', 'Cultural'],
          selected: state.activeFilter.deenLevel,
          onSelect: (v) => context.read<DiscoveryFeedCubit>().applyFilter(
                v == null
                    ? state.activeFilter.copyWith(clearDeenLevel: true)
                    : state.activeFilter.copyWith(deenLevel: v),
              ),
        ),
      ),
    );
  }

  void _showFamilyFilter(BuildContext context, DiscoveryFeedState state) {
    showModalBottomSheet(
      context:            context,
      backgroundColor:    Colors.transparent,
      isScrollControlled: true,
      builder:            (_) => BlocProvider.value(
        value: context.read<DiscoveryFeedCubit>(),
        child: _ChoiceSheet(
          title:    'Family Type',
          options:  const ['Nuclear', 'Joint', 'Extended'],
          selected: state.activeFilter.familyType,
          onSelect: (v) => context.read<DiscoveryFeedCubit>().applyFilter(
                v == null
                    ? state.activeFilter.copyWith(clearFamilyType: true)
                    : state.activeFilter.copyWith(familyType: v),
              ),
        ),
      ),
    );
  }

  static String _formatDeen(String raw) {
    switch (raw) {
      case 'practicing': return 'Practicing';
      case 'moderate':   return 'Moderate';
      case 'cultural':   return 'Cultural';
      default:           return raw;
    }
  }
}

// ── Chip widget ───────────────────────────────────────────────

class _Chip extends StatelessWidget {
  const _Chip({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final IconData     icon;
  final String       label;
  final bool         isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
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
              icon,
              color: isActive ? AppColors.champagneGold : AppColors.slateMist,
              size:  AppDimensions.iconSizeSmall,
            ),
            const SizedBox(width: AppDimensions.space6),
            Text(
              label,
              style: AppTypography.chipLabel.copyWith(
                color: isActive
                    ? AppColors.champagneGold
                    : AppColors.slateMist,
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

  final String       title;
  final List<Widget> children;
  final VoidCallback? onReset;
  final VoidCallback? onApply;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin:  const EdgeInsets.fromLTRB(
          AppDimensions.space16, 0,
          AppDimensions.space16, AppDimensions.space16),
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
              width: 40, height: 4,
              decoration: BoxDecoration(
                color:        AppColors.cardBorder,
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
                      style: AppTypography.caption.copyWith(
                          color: AppColors.champagneGold)),
                ),
            ],
          ),
          const SizedBox(height: AppDimensions.space20),

          ...children,

          const SizedBox(height: AppDimensions.space20),
          if (onApply != null)
            SizedBox(
              width:  double.infinity,
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
            activeTrackColor:   AppColors.champagneGold,
            inactiveTrackColor: AppColors.surfaceGlassHover,
            thumbColor:         AppColors.champagneGold,
            overlayColor:       AppColors.champagneGold.withValues(alpha: 0.12),
            rangeThumbShape:    const RoundRangeSliderThumbShape(
                enabledThumbRadius: 10),
            trackHeight: 3,
          ),
          child: RangeSlider(
            values:   _values,
            min:      18,
            max:      60,
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
          horizontal: AppDimensions.space16,
          vertical:   AppDimensions.space8),
      decoration: BoxDecoration(
        color:        AppColors.champagneGold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
        border:       Border.all(color: AppColors.goldBorder),
      ),
      child: Text(
        '$age yrs',
        style: AppTypography.bodyMedium.copyWith(
            color: AppColors.champagneGold),
      ),
    );
  }
}

// ── Choice Sheet (Sect / Deen / Family) ──────────────────────

class _ChoiceSheet extends StatelessWidget {
  const _ChoiceSheet({
    required this.title,
    required this.options,
    this.optionLabels,
    required this.selected,
    required this.onSelect,
  });

  final String         title;
  final List<String>   options;
  final List<String>?  optionLabels;
  final String?        selected;
  final void Function(String?) onSelect;

  @override
  Widget build(BuildContext context) {
    return _SheetBase(
      title: title,
      onReset: () => onSelect(null),
      children: [
        // "Any" option
        _RadioTile(
          label:    'Any',
          isSelected: selected == null,
          onTap:    () {
            onSelect(null);
            Navigator.pop(context);
          },
        ),
        const Divider(color: AppColors.divider),
        ...List.generate(options.length, (i) {
          final val   = options[i];
          final label = optionLabels?[i] ?? val;
          return _RadioTile(
            label:    label,
            isSelected: selected == val,
            onTap:    () {
              onSelect(val);
              Navigator.pop(context);
            },
          );
        }),
      ],
    );
  }
}

class _RadioTile extends StatelessWidget {
  const _RadioTile({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String       label;
  final bool         isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppDimensions.space14),
        child: Row(
          children: [
            AnimatedContainer(
              duration: AppDimensions.durationTransition,
              width:  22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? AppColors.champagneGold
                    : Colors.transparent,
                border: Border.all(
                  color: isSelected
                      ? AppColors.champagneGold
                      : AppColors.slateMist,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check_rounded,
                      color: AppColors.obsidianNight, size: 14)
                  : null,
            ),
            const SizedBox(width: AppDimensions.space16),
            Text(label, style: AppTypography.body),
          ],
        ),
      ),
    );
  }
}

// ── All Filters Sheet (comprehensive) ────────────────────────

class _AllFiltersSheet extends StatefulWidget {
  const _AllFiltersSheet({required this.initial});
  final DiscoveryFilter initial;

  @override
  State<_AllFiltersSheet> createState() => _AllFiltersSheetState();
}

class _AllFiltersSheetState extends State<_AllFiltersSheet> {
  late DiscoveryFilter _draft;

  @override
  void initState() {
    super.initState();
    _draft = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    return _SheetBase(
      title: 'Filters',
      onReset: () {
        context.read<DiscoveryFeedCubit>().clearFilters();
      },
      onApply: () {
        context.read<DiscoveryFeedCubit>().applyFilter(_draft);
      },
      children: [
        // ── Age Range ─────────────────────────────────────────
        Text('Age Range', style: AppTypography.sectionLabel),
        const SizedBox(height: AppDimensions.space12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _AgeLabel(age: _draft.ageMin ?? 18),
            _AgeLabel(age: _draft.ageMax ?? 50),
          ],
        ),
        const SizedBox(height: AppDimensions.space8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor:   AppColors.champagneGold,
            inactiveTrackColor: AppColors.surfaceGlassHover,
            thumbColor:         AppColors.champagneGold,
            overlayColor:       AppColors.champagneGold.withValues(alpha: 0.12),
            rangeThumbShape: const RoundRangeSliderThumbShape(
                enabledThumbRadius: 10),
            trackHeight: 3,
          ),
          child: RangeSlider(
            values: RangeValues(
              (_draft.ageMin ?? 18).toDouble(),
              (_draft.ageMax ?? 50).toDouble(),
            ),
            min: 18,
            max: 60,
            divisions: 42,
            onChanged: (v) => setState(() {
              _draft = _draft.copyWith(
                ageMin: v.start.round(),
                ageMax: v.end.round(),
              );
            }),
          ),
        ),
        const SizedBox(height: AppDimensions.space20),

        // ── Sect ──────────────────────────────────────────────
        Text('Sect', style: AppTypography.sectionLabel),
        const SizedBox(height: AppDimensions.space8),
        _HorizontalChipGroup(
          options:  const ['Sunni', 'Shia', 'Other'],
          selected: _draft.sect,
          onSelect: (v) => setState(() =>
              _draft = _draft.copyWith(sect: v, clearSect: v == null)),
        ),
        const SizedBox(height: AppDimensions.space20),

        // ── Deen Level ────────────────────────────────────────
        Text('Deen Level', style: AppTypography.sectionLabel),
        const SizedBox(height: AppDimensions.space8),
        _HorizontalChipGroup(
          options:       const ['practicing', 'moderate', 'cultural'],
          optionLabels:  const ['Practicing', 'Moderate', 'Cultural'],
          selected:      _draft.deenLevel,
          onSelect: (v) => setState(() =>
              _draft = _draft.copyWith(
                  deenLevel: v, clearDeenLevel: v == null)),
        ),
        const SizedBox(height: AppDimensions.space20),

        // ── Family Type ───────────────────────────────────────
        Text('Family Type', style: AppTypography.sectionLabel),
        const SizedBox(height: AppDimensions.space8),
        _HorizontalChipGroup(
          options:  const ['Nuclear', 'Joint', 'Extended'],
          selected: _draft.familyType,
          onSelect: (v) => setState(() =>
              _draft = _draft.copyWith(
                  familyType: v, clearFamilyType: v == null)),
        ),
        const SizedBox(height: AppDimensions.space20),

        // ── Toggles ───────────────────────────────────────────
        Text('Other', style: AppTypography.sectionLabel),
        const SizedBox(height: AppDimensions.space12),
        _ToggleTile(
          label:  'Verified profiles only',
          value:  _draft.verifiedOnly,
          onChanged: (v) => setState(() =>
              _draft = _draft.copyWith(verifiedOnly: v)),
        ),
        _ToggleTile(
          label:  'Active in last 7 days',
          value:  _draft.activeRecentlyOnly,
          onChanged: (v) => setState(() =>
              _draft = _draft.copyWith(activeRecentlyOnly: v)),
        ),
        _ToggleTile(
          label:  'Open to divorced / widowed',
          value:  _draft.openToDivorced,
          onChanged: (v) => setState(() =>
              _draft = _draft.copyWith(openToDivorced: v)),
        ),
      ],
    );
  }
}

// ── Horizontal chip group (toggle-select) ─────────────────────

class _HorizontalChipGroup extends StatelessWidget {
  const _HorizontalChipGroup({
    required this.options,
    this.optionLabels,
    required this.selected,
    required this.onSelect,
  });

  final List<String>   options;
  final List<String>?  optionLabels;
  final String?        selected;
  final void Function(String?) onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing:    AppDimensions.space8,
      runSpacing: AppDimensions.space8,
      children: [
        // "Any" chip
        _SmallChip(
          label:      'Any',
          isSelected: selected == null,
          onTap:      () => onSelect(null),
        ),
        ...List.generate(options.length, (i) {
          final val   = options[i];
          final label = optionLabels?[i] ?? val;
          return _SmallChip(
            label:      label,
            isSelected: selected == val,
            onTap:      () => onSelect(selected == val ? null : val),
          );
        }),
      ],
    );
  }
}

class _SmallChip extends StatelessWidget {
  const _SmallChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String       label;
  final bool         isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: AppDimensions.durationTransition,
        padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.space14,
            vertical:   AppDimensions.space8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.champagneGold.withValues(alpha: 0.15)
              : AppColors.surfaceGlass,
          borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
          border: Border.all(
            color: isSelected
                ? AppColors.champagneGold
                : AppColors.cardBorder,
            width: isSelected
                ? AppDimensions.borderFocus
                : AppDimensions.borderThin,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.chipLabel.copyWith(
            color: isSelected
                ? AppColors.champagneGold
                : AppColors.slateMist,
          ),
        ),
      ),
    );
  }
}

// ── Toggle tile ───────────────────────────────────────────────

class _ToggleTile extends StatelessWidget {
  const _ToggleTile({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String                label;
  final bool                  value;
  final ValueChanged<bool>    onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.space6),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: AppTypography.body),
          ),
          Switch(
            value:           value,
            onChanged:       onChanged,
            activeColor:     AppColors.champagneGold,
            activeTrackColor: AppColors.champagneGold.withValues(alpha: 0.3),
            inactiveThumbColor:  AppColors.slateMist,
            inactiveTrackColor:  AppColors.surfaceGlassHover,
          ),
        ],
      ),
    );
  }
}
