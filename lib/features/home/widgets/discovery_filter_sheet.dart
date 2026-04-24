// lib/features/home/widgets/discovery_filter_sheet.dart
// ============================================================
// NOOR — Full Filter Bottom Sheet (Feature 8 + 9)
//
// Sections (scrollable):
//   Gender · Age Range · Sect · Deen Level · Education
//   Family Type · Marital Status · Has Children
//   Verified Only · Distance
//
// Presets (Feature 9):
//   "Save this filter" → name + persist via FilterPresetService
//   Horizontal preset chips above sections
//   Long-press preset chip → confirm delete
//
// Bottom: "Clear All" + "Apply Filters" buttons.
// Show via showModalBottomSheet from DiscoveryFilterBar chips.
// ============================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/cubits/discovery/discovery_feed_cubit.dart';
import '../../../core/cubits/discovery/discovery_filter.dart';
import '../../../core/services/filter_preset_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';

// ── Sheet entry point (called from DiscoveryFilterBar) ────────

Future<void> showDiscoveryFilterSheet(
  BuildContext context, {
  DiscoveryFilter? initial,
  String? scrollToSection,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetCtx) => BlocProvider.value(
      value: context.read<DiscoveryFeedCubit>(),
      child: DiscoveryFilterSheet(
        initial:         initial ?? context.read<DiscoveryFeedCubit>().state.activeFilter,
        scrollToSection: scrollToSection,
      ),
    ),
  );
}

// ── Main widget ───────────────────────────────────────────────

class DiscoveryFilterSheet extends StatefulWidget {
  const DiscoveryFilterSheet({
    super.key,
    required this.initial,
    this.scrollToSection,
  });

  final DiscoveryFilter initial;
  final String?         scrollToSection;

  @override
  State<DiscoveryFilterSheet> createState() => _DiscoveryFilterSheetState();
}

class _DiscoveryFilterSheetState extends State<DiscoveryFilterSheet> {
  late DiscoveryFilter _draft;
  final _scrollCtrl  = ScrollController();
  List<FilterPreset> _presets = [];
  bool _showSaveField = false;
  final _presetNameCtrl = TextEditingController();

  // Section GlobalKeys for scroll-to
  final _genderKey    = GlobalKey();
  final _ageKey       = GlobalKey();
  final _sectKey      = GlobalKey();
  final _deenKey      = GlobalKey();
  final _eduKey       = GlobalKey();
  final _familyKey    = GlobalKey();
  final _maritalKey   = GlobalKey();
  final _childrenKey  = GlobalKey();
  final _verifiedKey  = GlobalKey();
  final _distanceKey  = GlobalKey();

  @override
  void initState() {
    super.initState();
    _draft = widget.initial;
    _loadPresets();
    if (widget.scrollToSection != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollTo(widget.scrollToSection!));
    }
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _presetNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPresets() async {
    final p = await FilterPresetService.load();
    if (mounted) setState(() => _presets = p);
  }

  void _scrollTo(String section) {
    final key = switch (section) {
      'gender'    => _genderKey,
      'age'       => _ageKey,
      'sect'      => _sectKey,
      'deen'      => _deenKey,
      'education' => _eduKey,
      'family'    => _familyKey,
      'marital'   => _maritalKey,
      'children'  => _childrenKey,
      'verified'  => _verifiedKey,
      'distance'  => _distanceKey,
      _           => _genderKey,
    };
    final ctx = key.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx,
          duration: const Duration(milliseconds: 400), curve: Curves.easeOutCubic);
    }
  }

  Future<void> _savePreset() async {
    final name = _presetNameCtrl.text.trim();
    if (name.isEmpty) return;
    final updated = [..._presets, FilterPreset(name: name, filter: _draft)];
    await FilterPresetService.save(updated);
    if (mounted) {
      setState(() {
        _presets        = updated.take(FilterPresetService.maxPresets).toList();
        _showSaveField  = false;
        _presetNameCtrl.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:          Text('Preset "$name" saved', style: AppTypography.body),
          backgroundColor:  AppColors.surfaceGlassHover,
          behavior:         SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _deletePreset(int index) async {
    final preset = _presets[index];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF12121A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete preset?',
            style: AppTypography.screenTitle.copyWith(fontSize: 18)),
        content: Text(
          'Remove "${preset.name}"?',
          style: AppTypography.bodyMuted,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: AppTypography.body),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete',
                style: AppTypography.body.copyWith(color: AppColors.softCoral)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final updated = List<FilterPreset>.from(_presets)..removeAt(index);
      await FilterPresetService.save(updated);
      if (mounted) setState(() => _presets = updated);
    }
  }

  void _applyPreset(FilterPreset preset) {
    setState(() => _draft = preset.filter);
  }

  void _apply() {
    context.read<DiscoveryFeedCubit>().applyFilter(_draft);
    Navigator.pop(context);
  }

  void _clearAll() {
    setState(() => _draft = DiscoveryFilter.empty);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewInsets.bottom +
        MediaQuery.of(context).padding.bottom;
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize:     0.5,
      maxChildSize:     0.97,
      builder: (ctx, scrollCtrl) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF12121A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(top: BorderSide(color: AppColors.cardBorder)),
          ),
          child: Column(
            children: [
              // Handle
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color:        AppColors.cardBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 16, 8),
                child: Row(
                  children: [
                    Text('Filters',
                        style: AppTypography.screenTitle.copyWith(fontSize: 20)),
                    const Spacer(),
                    TextButton(
                      onPressed: () => setState(() => _showSaveField = !_showSaveField),
                      child: Text('Save preset',
                          style: AppTypography.caption.copyWith(
                              color: AppColors.champagneGold)),
                    ),
                  ],
                ),
              ),

              // Save preset field
              if (_showSaveField)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                  child: Row(children: [
                    Expanded(
                      child: _SheetTextField(
                        controller: _presetNameCtrl,
                        hint: 'Preset name (e.g. UK Sisters)',
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _savePreset,
                      child: Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color:        AppColors.champagneGold,
                          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                        ),
                        child: const Icon(Icons.check_rounded,
                            color: AppColors.obsidianNight, size: 20),
                      ),
                    ),
                  ]),
                ),

              // Preset chips
              if (_presets.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                  child: SizedBox(
                    height: 36,
                    child: ListView.separated(
                      scrollDirection:  Axis.horizontal,
                      itemCount:        _presets.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final p = _presets[i];
                        return GestureDetector(
                          onTap:      () => _applyPreset(p),
                          onLongPress: () => _deletePreset(i),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.champagneGold.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
                              border: Border.all(color: AppColors.goldBorder),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.bookmark_rounded,
                                    color: AppColors.champagneGold, size: 14),
                                const SizedBox(width: 4),
                                Text(p.name,
                                    style: AppTypography.chipLabel.copyWith(
                                        color: AppColors.champagneGold)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

              const Divider(color: AppColors.divider, height: 1),

              // Scrollable content
              Expanded(
                child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  children: [

                    // ── GENDER PREFERENCE ──────────────────────
                    _SectionLabel(key: _genderKey, label: 'GENDER PREFERENCE'),
                    const SizedBox(height: 8),
                    _RadioGroup<String?>(
                      options: const [null, 'Male', 'Female'],
                      labels:  const ['Any', 'Male', 'Female'],
                      value:   _draft.genderPref,
                      onChanged: (v) => setState(() =>
                          _draft = _draft.copyWith(genderPref: v, clearGenderPref: v == null)),
                    ),
                    const SizedBox(height: 20),

                    // ── AGE RANGE ──────────────────────────────
                    _SectionLabel(key: _ageKey, label: 'AGE RANGE'),
                    const SizedBox(height: 8),
                    _AgeRangeField(
                      min: (_draft.ageMin ?? 22).toDouble(),
                      max: (_draft.ageMax ?? 35).toDouble(),
                      onChanged: (lo, hi) => setState(() => _draft = _draft.copyWith(
                        ageMin: lo.round(), ageMax: hi.round(),
                      )),
                    ),
                    const SizedBox(height: 20),

                    // ── SECT ───────────────────────────────────
                    _SectionLabel(key: _sectKey, label: 'SECT'),
                    const SizedBox(height: 8),
                    _MultiChipGroup(
                      options: const ['Any', 'Sunni', 'Shia', 'Prefer not to say'],
                      selected: _draft.sect,
                      onChanged: (v) => setState(() => _draft =
                          _draft.copyWith(sect: v, clearSect: v == null)),
                    ),
                    const SizedBox(height: 20),

                    // ── DEEN LEVEL ─────────────────────────────
                    _SectionLabel(key: _deenKey, label: 'DEEN LEVEL'),
                    const SizedBox(height: 8),
                    _MultiChipGroup(
                      options:      const ['Any', 'practicing', 'moderate', 'cultural'],
                      optionLabels: const ['Any', 'Practicing', 'Moderate', 'Cultural'],
                      selected: _draft.deenLevel,
                      onChanged: (v) => setState(() => _draft =
                          _draft.copyWith(deenLevel: v, clearDeenLevel: v == null)),
                    ),
                    const SizedBox(height: 20),

                    // ── EDUCATION MINIMUM ──────────────────────
                    _SectionLabel(key: _eduKey, label: 'EDUCATION MINIMUM'),
                    const SizedBox(height: 8),
                    _DropdownRow(
                      value: _draft.educationMin ?? 'Any',
                      options: const [
                        'Any', 'Matric', 'Intermediate',
                        "Bachelor's", "Master's", 'PhD',
                      ],
                      onChanged: (v) => setState(() => _draft = _draft.copyWith(
                        educationMin: v == 'Any' ? null : v,
                        clearEducationMin: v == 'Any',
                      )),
                    ),
                    const SizedBox(height: 20),

                    // ── FAMILY TYPE ────────────────────────────
                    _SectionLabel(key: _familyKey, label: 'FAMILY TYPE'),
                    const SizedBox(height: 8),
                    _MultiChipGroup(
                      options: const ['Any', 'Nuclear', 'Joint', 'Extended'],
                      selected: _draft.familyType,
                      onChanged: (v) => setState(() => _draft = _draft.copyWith(
                        familyType: v, clearFamilyType: v == null,
                      )),
                    ),
                    const SizedBox(height: 20),

                    // ── MARITAL STATUS ─────────────────────────
                    _SectionLabel(key: _maritalKey, label: 'MARITAL STATUS'),
                    const SizedBox(height: 8),
                    _MultiChipGroup(
                      options: const ['Never Married', 'Divorced', 'Widowed', 'Any'],
                      selected: _draft.maritalStatus,
                      onChanged: (v) => setState(() => _draft = _draft.copyWith(
                        maritalStatus: v, clearMaritalStatus: v == null,
                      )),
                    ),
                    const SizedBox(height: 20),

                    // ── HAS CHILDREN ───────────────────────────
                    _SectionLabel(key: _childrenKey, label: 'HAS CHILDREN'),
                    const SizedBox(height: 8),
                    _RadioGroup<String?>(
                      options: const [null, 'No', 'Yes'],
                      labels:  const ["Doesn't matter", 'No', 'Yes'],
                      value:   _draft.hasChildren,
                      onChanged: (v) => setState(() => _draft = _draft.copyWith(
                        hasChildren: v, clearHasChildren: v == null,
                      )),
                    ),
                    const SizedBox(height: 20),

                    // ── VERIFIED ONLY ──────────────────────────
                    _SectionLabel(key: _verifiedKey, label: 'VERIFIED ONLY'),
                    const SizedBox(height: 8),
                    _ToggleRow(
                      label:     'Show verified profiles only',
                      value:     _draft.verifiedOnly,
                      onChanged: (v) => setState(() =>
                          _draft = _draft.copyWith(verifiedOnly: v)),
                    ),
                    const SizedBox(height: 20),

                    // ── DISTANCE ───────────────────────────────
                    _SectionLabel(key: _distanceKey, label: 'DISTANCE'),
                    const SizedBox(height: 8),
                    _MultiChipGroup(
                      options: const [
                        'Same City', '50km', '100km',
                        'Same Country', 'Anywhere',
                      ],
                      selected: _draft.distanceLabel,
                      onChanged: (v) => setState(() => _draft = _draft.copyWith(
                        distanceLabel: v, clearDistanceLabel: v == null,
                      )),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),

              // Bottom buttons
              Padding(
                padding: EdgeInsets.fromLTRB(24, 0, 24, 16 + bottomPad),
                child: Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: AppDimensions.buttonHeight,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.cardBorder),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                            ),
                          ),
                          onPressed: _clearAll,
                          child: Text('Clear All', style: AppTypography.body),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: AppDimensions.buttonHeight,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.champagneGold,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                            ),
                          ),
                          onPressed: _apply,
                          child: Text('Apply Filters',
                              style: AppTypography.button),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.sectionLabel),
        const SizedBox(height: 4),
        const Divider(color: AppColors.divider, height: 1),
      ],
    );
  }
}

class _RadioGroup<T> extends StatelessWidget {
  const _RadioGroup({
    required this.options,
    required this.labels,
    required this.value,
    required this.onChanged,
  });
  final List<T>         options;
  final List<String>    labels;
  final T               value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing:    AppDimensions.space8,
      runSpacing: AppDimensions.space8,
      children: List.generate(options.length, (i) {
        final opt      = options[i];
        final isSelected = opt == value;
        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            onChanged(opt);
          },
          child: AnimatedContainer(
            duration: AppDimensions.durationTransition,
            padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.space14, vertical: AppDimensions.space8),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.champagneGold.withValues(alpha: 0.15)
                  : AppColors.surfaceGlass,
              borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
              border: Border.all(
                color: isSelected ? AppColors.champagneGold : AppColors.cardBorder,
                width: isSelected ? AppDimensions.borderFocus : AppDimensions.borderThin,
              ),
            ),
            child: Text(labels[i],
                style: AppTypography.chipLabel.copyWith(
                  color: isSelected ? AppColors.champagneGold : AppColors.slateMist,
                )),
          ),
        );
      }),
    );
  }
}

class _MultiChipGroup extends StatelessWidget {
  const _MultiChipGroup({
    required this.options,
    this.optionLabels,
    required this.selected,
    required this.onChanged,
  });
  final List<String>   options;
  final List<String>?  optionLabels;
  final String?        selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing:    AppDimensions.space8,
      runSpacing: AppDimensions.space8,
      children: List.generate(options.length, (i) {
        final val   = options[i];
        final label = optionLabels?[i] ?? val;
        final isAny = val == 'Any';
        final isSelected = isAny ? selected == null : selected == val;
        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            onChanged(isAny ? null : (selected == val ? null : val));
          },
          child: AnimatedContainer(
            duration: AppDimensions.durationTransition,
            padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.space14, vertical: AppDimensions.space8),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.champagneGold.withValues(alpha: 0.15)
                  : AppColors.surfaceGlass,
              borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
              border: Border.all(
                color: isSelected ? AppColors.champagneGold : AppColors.cardBorder,
                width: isSelected ? AppDimensions.borderFocus : AppDimensions.borderThin,
              ),
            ),
            child: Text(label,
                style: AppTypography.chipLabel.copyWith(
                  color: isSelected ? AppColors.champagneGold : AppColors.slateMist,
                )),
          ),
        );
      }),
    );
  }
}

class _AgeRangeField extends StatelessWidget {
  const _AgeRangeField({
    required this.min,
    required this.max,
    required this.onChanged,
  });
  final double min;
  final double max;
  final void Function(double, double) onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _AgeLabel(age: min.round()),
            _AgeLabel(age: max.round()),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor:   AppColors.champagneGold,
            inactiveTrackColor: AppColors.surfaceGlassHover,
            thumbColor:         AppColors.champagneGold,
            overlayColor:       AppColors.champagneGold.withValues(alpha: 0.12),
            rangeThumbShape:
                const RoundRangeSliderThumbShape(enabledThumbRadius: 10),
            trackHeight: 3,
          ),
          child: RangeSlider(
            values:    RangeValues(min, max),
            min:       18,
            max:       65,
            divisions: 47,
            labels: RangeLabels('${min.round()}', '${max.round()}'),
            onChanged: (v) => onChanged(v.start, v.end),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('18', style: AppTypography.caption),
            Text('65', style: AppTypography.caption),
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
        color:        AppColors.champagneGold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
        border:       Border.all(color: AppColors.goldBorder),
      ),
      child: Text('$age yrs',
          style: AppTypography.bodyMedium.copyWith(
              color: AppColors.champagneGold)),
    );
  }
}

class _DropdownRow extends StatelessWidget {
  const _DropdownRow({
    required this.value,
    required this.options,
    required this.onChanged,
  });
  final String       value;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final safe = options.contains(value) ? value : options.first;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.space16, vertical: AppDimensions.space4),
      decoration: BoxDecoration(
        color:        AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
        border:       Border.all(color: AppColors.cardBorder),
      ),
      child: DropdownButtonFormField<String>(
        initialValue:  safe,
        style:         AppTypography.inputText,
        dropdownColor: const Color(0xFF13131A),
        decoration: const InputDecoration(border: InputBorder.none),
        icon: const Icon(Icons.expand_more_rounded, color: AppColors.slateMist),
        items: options.map((o) => DropdownMenuItem(
          value: o,
          child: Text(o, style: AppTypography.body),
        )).toList(),
        onChanged: onChanged,
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String             label;
  final bool               value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.space16, vertical: AppDimensions.space12),
      decoration: BoxDecoration(
        color:        AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
        border:       Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: AppTypography.body)),
          Switch(
            value:              value,
            onChanged:          onChanged,
            activeThumbColor:   AppColors.obsidianNight,
            activeTrackColor:   AppColors.champagneGold,
            inactiveThumbColor: AppColors.slateMist,
            inactiveTrackColor: AppColors.surfaceGlassHover,
          ),
        ],
      ),
    );
  }
}

class _SheetTextField extends StatelessWidget {
  const _SheetTextField({required this.controller, required this.hint});
  final TextEditingController controller;
  final String                hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color:        AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
        border:       Border.all(color: AppColors.cardBorder),
      ),
      alignment: Alignment.centerLeft,
      child: TextField(
        controller: controller,
        style:      AppTypography.body,
        decoration: InputDecoration(
          hintText:       hint,
          hintStyle:      AppTypography.bodyMuted,
          border:         InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.space12, vertical: 0),
        ),
      ),
    );
  }
}
