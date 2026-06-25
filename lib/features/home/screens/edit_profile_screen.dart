// lib/features/home/screens/edit_profile_screen.dart
// ============================================================
// MITHAQ — Edit Profile Screen
//
// Full editable profile with sections matching OnboardingData:
//   Photos · Basic Info · Islamic Identity · About
//   Education & Career · Family · Partner Preferences
//
// Reads current values from OnboardingCubit.
// Save triggers OnboardingCubit.saveAndAdvance and shows
// a success SnackBar before popping.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/cubits/onboarding/onboarding_cubit.dart';
import '../../../core/cubits/onboarding/onboarding_state.dart';
import '../../../core/models/onboarding_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../onboarding/screens/photo_upload_screen.dart';

// ── City data import — reuse same list from basic_identity_screen ──
// (Inline minimal wrapper to avoid cross-file private access)

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  // ── Local mutable copies of OnboardingData fields ─────────

  late TextEditingController _firstNameCtrl;
  late TextEditingController _lastNameCtrl;
  late TextEditingController _cityCtrl;
  late TextEditingController _professionCtrl;
  late TextEditingController _bioCtrl;

  // Islamic
  Sect?      _sect;
  DeenLevel? _deenLevel;
  bool       _praysFive      = false;
  String?    _hijabStyle;
  String?    _beardStyle;           // 'yes','no','prefer_not_to_say'

  // Education & career
  String?    _educationLabel;

  // Family
  FamilyType? _familyType;
  int         _siblingCount  = 0;
  String?     _parentsStatus;
  String?     _marriageTimeline;
  String?     _willingToRelocate;

  // Partner preferences
  double _partnerAgeMin = 22;
  double _partnerAgeMax = 35;
  bool   _openToDivorced   = false;
  bool   _openToWidowed    = false;
  bool   _openToHasChildren = false;

  // About
  List<String> _interests = [];

  Gender? _gender;

  @override
  void initState() {
    super.initState();
    final d = context.read<OnboardingCubit>().currentData;
    _firstNameCtrl  = TextEditingController(text: d.firstName ?? '');
    _lastNameCtrl   = TextEditingController(text: d.lastName ?? '');
    _cityCtrl       = TextEditingController(text: d.cityName ?? '');
    _professionCtrl = TextEditingController(text: d.profession ?? '');
    _bioCtrl        = TextEditingController(text: d.bio ?? '');

    _sect           = d.sect;
    _deenLevel      = d.deenLevel;
    _praysFive      = d.praysFiveDaily ?? false;
    _hijabStyle     = d.hijabStyle;
    _beardStyle     = d.beardStyle;
    _educationLabel = d.educationLabel;
    _familyType     = d.familyType;
    _siblingCount   = d.siblingCount ?? 0;
    _parentsStatus  = d.parentsStatus;
    _marriageTimeline  = d.marriageTimeline;
    _willingToRelocate = d.willingToRelocate;
    _partnerAgeMin  = (d.preferredAgeMin ?? 22).toDouble();
    _partnerAgeMax  = (d.preferredAgeMax ?? 35).toDouble();
    _openToDivorced    = d.openToDivorced ?? false;
    _openToWidowed     = d.openToWidowed ?? false;
    _openToHasChildren = d.openToWithChildren ?? false;
    _interests      = List<String>.from(d.interests ?? []);
    _gender         = d.gender;
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _cityCtrl.dispose();
    _professionCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  void _saveProfile() {
    HapticFeedback.mediumImpact();
    final cubit = context.read<OnboardingCubit>();
    final updated = cubit.currentData.copyWith(
      firstName:          _firstNameCtrl.text.trim(),
      lastName:           _lastNameCtrl.text.trim(),
      cityName:           _cityCtrl.text.trim(),
      profession:         _professionCtrl.text.trim(),
      bio:                _bioCtrl.text.trim(),
      sect:               _sect,
      deenLevel:          _deenLevel,
      praysFiveDaily:     _praysFive,
      hijabStyle:         _hijabStyle,
      beardStyle:         _beardStyle,
      educationLabel:     _educationLabel,
      familyType:         _familyType,
      siblingCount:       _siblingCount,
      parentsStatus:      _parentsStatus,
      marriageTimeline:   _marriageTimeline,
      willingToRelocate:  _willingToRelocate,
      preferredAgeMin:    _partnerAgeMin.round(),
      preferredAgeMax:    _partnerAgeMax.round(),
      openToDivorced:     _openToDivorced,
      openToWidowed:      _openToWidowed,
      openToWithChildren: _openToHasChildren,
      interests:          _interests,
    );
    // updateProfile stores data without advancing the step.
    cubit.updateProfile(updated);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(children: [
          Icon(Icons.check_circle_rounded,
              color: AppColors.champagneGold, size: 18),
          SizedBox(width: AppDimensions.space8),
          Text('Profile saved', style: AppTypography.body),
        ]),
        backgroundColor: AppColors.surfaceGlassHover,
        behavior:        SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          side: const BorderSide(color: AppColors.goldBorder),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OnboardingCubit, OnboardingState>(
      builder: (context, state) {
        return Scaffold(
          backgroundColor: AppColors.obsidianNight,
          appBar: AppBar(
            backgroundColor:  AppColors.obsidianNight,
            surfaceTintColor: Colors.transparent,
            elevation:        0,
            leading: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                margin: const EdgeInsets.all(AppDimensions.space8),
                decoration: BoxDecoration(
                  color:  AppColors.surfaceGlass,
                  shape:  BoxShape.circle,
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: const Icon(
                  Icons.arrow_back_rounded,
                  color: AppColors.pearlWhite,
                  size:  AppDimensions.iconSizeMedium,
                ),
              ),
            ),
            title: Text('Edit Profile',
                style: AppTypography.screenTitle.copyWith(fontSize: 20)),
            actions: [
              TextButton(
                onPressed: _saveProfile,
                child: Text(
                  'Save',
                  style: AppTypography.buttonSecondary.copyWith(fontSize: 15),
                ),
              ),
              const SizedBox(width: AppDimensions.space8),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppDimensions.space24, AppDimensions.space8,
              AppDimensions.space24, AppDimensions.space40,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ── Photos ──────────────────────────────────
                const _SectionHeader(label: 'Photos'),
                const SizedBox(height: AppDimensions.space12),
                _PhotoGrid(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<bool>(
                      builder: (_) => const PhotoUploadScreen(
                        returnToPreviousOnSave: true,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppDimensions.space28),

                // ── Basic Info ───────────────────────────────
                const _SectionHeader(label: 'Basic Info'),
                const SizedBox(height: AppDimensions.space12),
                _MithaqTextField(
                  label:        'First name',
                  controller:   _firstNameCtrl,
                  onChanged:    (_) => setState(() {}),
                ),
                const SizedBox(height: AppDimensions.space12),
                _MithaqTextField(
                  label:        'Last name',
                  controller:   _lastNameCtrl,
                  onChanged:    (_) => setState(() {}),
                ),
                const SizedBox(height: AppDimensions.space12),
                _MithaqTextField(
                  label:        'City',
                  hint:         'e.g. Dubai, London, Karachi',
                  controller:   _cityCtrl,
                  onChanged:    (_) => setState(() {}),
                ),
                const SizedBox(height: AppDimensions.space28),

                // ── Islamic Identity ─────────────────────────
                const _SectionHeader(label: 'Islamic Identity'),
                const SizedBox(height: AppDimensions.space12),
                _DropdownField(
                  label:    'Sect',
                  value:    _sectValue(_sect),
                  options:  const ['sunni', 'shia', 'preferNotToSay', 'other'],
                  optionLabels: const ['Sunni', 'Shia', 'Prefer not to say', 'Other'],
                  onChanged: (v) => setState(() => _sect = _parseSect(v)),
                ),
                const SizedBox(height: AppDimensions.space12),
                _DropdownField(
                  label:    'Deen Level',
                  value:    _deenLevelValue(_deenLevel),
                  options:  const ['practicing', 'moderate', 'cultural'],
                  optionLabels: const ['Practicing', 'Moderate', 'Cultural Muslim'],
                  onChanged: (v) => setState(() => _deenLevel = _parseDeenLevel(v)),
                ),
                const SizedBox(height: AppDimensions.space12),
                _ToggleRow(
                  label:     'Prays five times daily',
                  value:     _praysFive,
                  onChanged: (v) => setState(() => _praysFive = v),
                ),
                // Female-only: hijab dropdown
                if (_gender == Gender.female) ...[
                  const SizedBox(height: AppDimensions.space12),
                  _DropdownField(
                    label:    'Hijab style',
                    value:    _hijabStyle ?? 'No hijab',
                    options:  const [
                      'No hijab',
                      'Occasionally',
                      'Hijab',
                      'Niqab',
                    ],
                    onChanged: (v) => setState(() => _hijabStyle = v),
                  ),
                ],
                // Male-only: beard toggle
                if (_gender == Gender.male) ...[
                  const SizedBox(height: AppDimensions.space12),
                  _DropdownField(
                    label:    'Beard',
                    value:    _beardStyle ?? 'prefer_not_to_say',
                    options:  const ['yes', 'no', 'prefer_not_to_say'],
                    optionLabels: const ['Yes', 'No', 'Prefer not to say'],
                    onChanged: (v) => setState(() => _beardStyle = v),
                  ),
                ],
                const SizedBox(height: AppDimensions.space28),

                // ── About ────────────────────────────────────
                const _SectionHeader(label: 'About'),
                const SizedBox(height: AppDimensions.space12),
                _MithaqTextField(
                  label:      'Bio',
                  hint:       'Describe yourself with honesty and dignity.',
                  controller: _bioCtrl,
                  maxLines:   5,
                  maxLength:  300,
                  onChanged:  (_) => setState(() {}),
                ),
                const SizedBox(height: AppDimensions.space12),
                _InterestChips(
                  selected:  _interests,
                  onChanged: (v) => setState(() => _interests = v),
                ),
                const SizedBox(height: AppDimensions.space28),

                // ── Education & Career ───────────────────────
                const _SectionHeader(label: 'Education & Career'),
                const SizedBox(height: AppDimensions.space12),
                _DropdownField(
                  label:    'Education Level',
                  value:    _educationLabel ?? 'Bachelor\'s Degree',
                  options:  const [
                    'Below Secondary',
                    'Secondary / O-Level',
                    'Higher Secondary / A-Level',
                    'Diploma / Associate',
                    'Bachelor\'s Degree',
                    'Master\'s Degree',
                    'Doctorate / PhD',
                  ],
                  onChanged: (v) => setState(() => _educationLabel = v),
                ),
                const SizedBox(height: AppDimensions.space12),
                _MithaqTextField(
                  label:      'Profession',
                  hint:       'e.g. Software Engineer',
                  controller: _professionCtrl,
                  onChanged:  (_) => setState(() {}),
                ),
                const SizedBox(height: AppDimensions.space28),

                // ── Family ───────────────────────────────────
                const _SectionHeader(label: 'Family'),
                const SizedBox(height: AppDimensions.space12),
                _DropdownField(
                  label:    'Family Type',
                  value:    _familyTypeValue(_familyType),
                  options:  const ['nuclear', 'joint', 'extended'],
                  optionLabels: const ['Nuclear', 'Joint', 'Extended'],
                  onChanged: (v) => setState(() => _familyType = _parseFamilyType(v)),
                ),
                const SizedBox(height: AppDimensions.space12),
                _StepperRow(
                  label:     'Siblings',
                  value:     _siblingCount,
                  min:       0,
                  max:       15,
                  onChanged: (v) => setState(() => _siblingCount = v),
                ),
                const SizedBox(height: AppDimensions.space12),
                _DropdownField(
                  label:    'Parents\' Status',
                  value:    _parentsStatus ?? 'Both alive',
                  options:  const [
                    'Both alive',
                    'Father passed away',
                    'Mother passed away',
                    'Both passed away',
                  ],
                  onChanged: (v) => setState(() => _parentsStatus = v),
                ),
                const SizedBox(height: AppDimensions.space12),
                _DropdownField(
                  label:    'Marriage Timeline',
                  value:    _marriageTimeline ?? 'not_sure',
                  options:  const ['asap', '6_months', '1_year', '2_plus_years', 'not_sure'],
                  optionLabels: const ['ASAP', '6 Months', '1 Year', '2+ Years', 'Not Sure'],
                  onChanged: (v) => setState(() => _marriageTimeline = v),
                ),
                const SizedBox(height: AppDimensions.space12),
                _DropdownField(
                  label:    'Willing to Relocate',
                  value:    _willingToRelocate ?? 'open_to_discussion',
                  options:  const ['yes', 'no', 'open_to_discussion'],
                  optionLabels: const ['Yes', 'No', 'Open to Discussion'],
                  onChanged: (v) => setState(() => _willingToRelocate = v),
                ),
                const SizedBox(height: AppDimensions.space28),

                // ── Partner Preferences ──────────────────────
                const _SectionHeader(label: 'Partner Preferences'),
                const SizedBox(height: AppDimensions.space12),
                _AgeRangeField(
                  min:       _partnerAgeMin,
                  max:       _partnerAgeMax,
                  onChanged: (lo, hi) => setState(() {
                    _partnerAgeMin = lo;
                    _partnerAgeMax = hi;
                  }),
                ),
                const SizedBox(height: AppDimensions.space12),
                _ToggleRow(
                  label:     'Open to divorced',
                  value:     _openToDivorced,
                  onChanged: (v) => setState(() => _openToDivorced = v),
                ),
                const SizedBox(height: AppDimensions.space12),
                _ToggleRow(
                  label:     'Open to widowed',
                  value:     _openToWidowed,
                  onChanged: (v) => setState(() => _openToWidowed = v),
                ),
                const SizedBox(height: AppDimensions.space12),
                _ToggleRow(
                  label:     'Open to someone with children',
                  value:     _openToHasChildren,
                  onChanged: (v) => setState(() => _openToHasChildren = v),
                ),

                const SizedBox(height: AppDimensions.space40),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Enum helpers ───────────────────────────────────────────

  String _sectValue(Sect? s) {
    switch (s) {
      case Sect.sunni:          return 'sunni';
      case Sect.shia:           return 'shia';
      case Sect.preferNotToSay: return 'preferNotToSay';
      case Sect.other:          return 'other';
      case null:                return 'sunni';
    }
  }

  Sect _parseSect(String? v) {
    switch (v) {
      case 'shia':           return Sect.shia;
      case 'preferNotToSay': return Sect.preferNotToSay;
      case 'other':          return Sect.other;
      default:               return Sect.sunni;
    }
  }

  String _deenLevelValue(DeenLevel? d) {
    switch (d) {
      case DeenLevel.moderate:  return 'moderate';
      case DeenLevel.cultural:  return 'cultural';
      default:                  return 'practicing';
    }
  }

  DeenLevel _parseDeenLevel(String? v) {
    switch (v) {
      case 'moderate': return DeenLevel.moderate;
      case 'cultural': return DeenLevel.cultural;
      default:         return DeenLevel.practicing;
    }
  }

  String _familyTypeValue(FamilyType? f) {
    switch (f) {
      case FamilyType.joint:    return 'joint';
      case FamilyType.extended: return 'extended';
      default:                  return 'nuclear';
    }
  }

  FamilyType _parseFamilyType(String? v) {
    switch (v) {
      case 'joint':    return FamilyType.joint;
      case 'extended': return FamilyType.extended;
      default:         return FamilyType.nuclear;
    }
  }
}

// ── Photo Grid (4-slot) ───────────────────────────────────────

class _PhotoGrid extends StatelessWidget {
  const _PhotoGrid({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap:       true,
      physics:          const NeverScrollableScrollPhysics(),
      crossAxisCount:   4,
      crossAxisSpacing: AppDimensions.space8,
      mainAxisSpacing:  AppDimensions.space8,
      children: [
        _PhotoSlot(index: 0, isFilled: true,  isPrimary: true,  onTap: onTap),
        _PhotoSlot(index: 1, isFilled: false, isPrimary: false, onTap: onTap),
        _PhotoSlot(index: 2, isFilled: false, isPrimary: false, onTap: onTap),
        _PhotoSlot(index: 3, isFilled: false, isPrimary: false, onTap: onTap),
      ],
    );
  }
}

class _PhotoSlot extends StatelessWidget {
  const _PhotoSlot({
    required this.index,
    required this.isFilled,
    required this.onTap,
    this.isPrimary = false,
  });
  final int          index;
  final bool         isFilled;
  final bool         isPrimary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: Container(
          decoration: BoxDecoration(
            color:        AppColors.surfaceGlass,
            borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
            border: Border.all(
              color: isPrimary ? AppColors.champagneGold : AppColors.cardBorder,
            ),
          ),
          child: isFilled
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    const Center(
                      child: Icon(
                        Icons.person_outline_rounded,
                        color: AppColors.slateMist,
                        size:  36,
                      ),
                    ),
                    if (isPrimary)
                      Positioned(
                        bottom: 4, left: 0, right: 0,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color:        AppColors.champagneGold,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Main',
                              style: AppTypography.caption.copyWith(
                                color:      AppColors.obsidianNight,
                                fontSize:   10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                )
              : const Icon(Icons.add_rounded,
                  color: AppColors.slateMist, size: 24),
        ),
      ),
    );
  }
}

// ── Section Header ────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: AppTypography.sectionLabel),
        const SizedBox(height: AppDimensions.space8),
        const Divider(color: AppColors.divider, height: 1),
      ],
    );
  }
}

// ── MITHAQ Text Field ───────────────────────────────────────────

class _MithaqTextField extends StatefulWidget {
  const _MithaqTextField({
    required this.label,
    required this.controller,
    required this.onChanged,
    this.hint,
    this.maxLines  = 1,
    this.maxLength,
  });
  final String   label;
  final TextEditingController controller;
  final String?  hint;
  final int      maxLines;
  final int?     maxLength;
  final ValueChanged<String> onChanged;

  @override
  State<_MithaqTextField> createState() => _MithaqTextFieldState();
}

class _MithaqTextFieldState extends State<_MithaqTextField> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (f) => setState(() => _focused = f),
      child: AnimatedContainer(
        duration: AppDimensions.durationTransition,
        decoration: BoxDecoration(
          color:        AppColors.surfaceGlass,
          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          border: Border.all(
            color:  _focused ? AppColors.champagneGold : AppColors.cardBorder,
            width:  _focused
                ? AppDimensions.borderFocus
                : AppDimensions.borderThin,
          ),
        ),
        child: TextField(
          controller:    widget.controller,
          maxLines:      widget.maxLines,
          maxLength:     widget.maxLength,
          style:         AppTypography.inputText,
          onChanged:     widget.onChanged,
          decoration: InputDecoration(
            labelText:     widget.label,
            hintText:      widget.hint,
            labelStyle:    AppTypography.inputLabel,
            hintStyle:     AppTypography.inputLabel,
            border:        InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.space16,
              vertical:   AppDimensions.space14,
            ),
            counterStyle: AppTypography.caption,
          ),
        ),
      ),
    );
  }
}

// ── Dropdown Field ────────────────────────────────────────────

class _DropdownField extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.value,
    required this.options,
    this.optionLabels,
    required this.onChanged,
  });
  final String        label;
  final String        value;
  final List<String>  options;
  final List<String>? optionLabels;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final safeValue = options.contains(value) ? value : options.first;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space16,
        vertical:   AppDimensions.space4,
      ),
      decoration: BoxDecoration(
        color:        AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
        border:       Border.all(color: AppColors.cardBorder),
      ),
      child: DropdownButtonFormField<String>(
        initialValue:         safeValue,
        style:         AppTypography.inputText,
        dropdownColor: AppColors.surfaceElevated,
        decoration: InputDecoration(
          labelText:  label,
          labelStyle: AppTypography.inputLabel,
          border:     InputBorder.none,
        ),
        icon: const Icon(
          Icons.expand_more_rounded,
          color: AppColors.slateMist,
        ),
        items: List.generate(options.length, (i) {
          final val   = options[i];
          final lbl   = optionLabels?[i] ?? val;
          return DropdownMenuItem(
            value: val,
            child: Text(lbl, style: AppTypography.body),
          );
        }),
        onChanged: onChanged,
      ),
    );
  }
}

// ── Toggle Row ────────────────────────────────────────────────

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String          label;
  final bool            value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space16,
        vertical:   AppDimensions.space12,
      ),
      decoration: BoxDecoration(
        color:        AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
        border:       Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: AppTypography.body)),
          Switch(
            value:             value,
            onChanged:         onChanged,
            activeThumbColor:       AppColors.champagneGold,
            activeTrackColor:  AppColors.champagneGold.withValues(alpha: 0.3),
            inactiveThumbColor: AppColors.slateMist,
            inactiveTrackColor: AppColors.surfaceGlassHover,
          ),
        ],
      ),
    );
  }
}

// ── Stepper Row ───────────────────────────────────────────────

class _StepperRow extends StatelessWidget {
  const _StepperRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });
  final String label;
  final int    value;
  final int    min;
  final int    max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space16,
        vertical:   AppDimensions.space12,
      ),
      decoration: BoxDecoration(
        color:        AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
        border:       Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: AppTypography.body)),
          GestureDetector(
            onTap: value > min
                ? () => onChanged(value - 1)
                : null,
            child: Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color:  value > min
                    ? AppColors.champagneGold.withValues(alpha: 0.15)
                    : AppColors.surfaceGlassHover,
                shape: BoxShape.circle,
                border: Border.all(
                  color: value > min
                      ? AppColors.champagneGold.withValues(alpha: 0.5)
                      : AppColors.cardBorder,
                ),
              ),
              child: Icon(Icons.remove,
                  size: 16,
                  color: value > min
                      ? AppColors.champagneGold
                      : AppColors.slateMist),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.space12),
            child: Text(
              '$value',
              style: AppTypography.bodyMedium.copyWith(
                color:    AppColors.pearlWhite,
                fontSize: 16,
              ),
            ),
          ),
          GestureDetector(
            onTap: value < max
                ? () => onChanged(value + 1)
                : null,
            child: Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color:  value < max
                    ? AppColors.champagneGold.withValues(alpha: 0.15)
                    : AppColors.surfaceGlassHover,
                shape: BoxShape.circle,
                border: Border.all(
                  color: value < max
                      ? AppColors.champagneGold.withValues(alpha: 0.5)
                      : AppColors.cardBorder,
                ),
              ),
              child: Icon(Icons.add,
                  size: 16,
                  color: value < max
                      ? AppColors.champagneGold
                      : AppColors.slateMist),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Age Range Slider ──────────────────────────────────────────

class _AgeRangeField extends StatelessWidget {
  const _AgeRangeField({
    required this.min,
    required this.max,
    required this.onChanged,
  });
  final double min;
  final double max;
  final void Function(double lo, double hi) onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.space16,
        AppDimensions.space12,
        AppDimensions.space16,
        AppDimensions.space4,
      ),
      decoration: BoxDecoration(
        color:        AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
        border:       Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Partner age range', style: AppTypography.body),
              const Spacer(),
              Text(
                '${min.round()} – ${max.round()} yrs',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.champagneGold,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor:   AppColors.champagneGold,
              inactiveTrackColor: AppColors.progressBarBase,
              thumbColor:         AppColors.champagneGold,
              overlayColor:
                  AppColors.champagneGold.withValues(alpha: 0.15),
              rangeThumbShape:
                  const RoundRangeSliderThumbShape(enabledThumbRadius: 8),
            ),
            child: RangeSlider(
              values: RangeValues(min, max),
              min:    18,
              max:    60,
              divisions: 42,
              onChanged: (rv) => onChanged(rv.start, rv.end),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Interest Chips ────────────────────────────────────────────

const _kAllInterests = <String>[
  'Reading', 'Travel', 'Cooking', 'Fitness', 'Photography',
  'Technology', 'Art', 'Music', 'Hiking', 'Languages',
  'Calligraphy', 'Poetry', 'Finance', 'Medicine', 'Education',
  'Design', 'Architecture', 'Yoga', 'Running', 'Gaming',
];

class _InterestChips extends StatelessWidget {
  const _InterestChips({
    required this.selected,
    required this.onChanged,
  });
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Interests (up to 6)', style: AppTypography.sectionLabel),
        const SizedBox(height: AppDimensions.space8),
        Wrap(
          spacing: AppDimensions.space8,
          runSpacing: AppDimensions.space8,
          children: _kAllInterests.map((interest) {
            final isOn = selected.contains(interest);
            return GestureDetector(
              onTap: () {
                final next = List<String>.from(selected);
                if (isOn) {
                  next.remove(interest);
                } else {
                  if (next.length >= 6) return;
                  next.add(interest);
                }
                onChanged(next);
              },
              child: AnimatedContainer(
                duration: AppDimensions.durationTransition,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.space12,
                  vertical:   AppDimensions.space6,
                ),
                decoration: BoxDecoration(
                  color: isOn
                      ? AppColors.champagneGold.withValues(alpha: 0.12)
                      : AppColors.surfaceGlass,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isOn ? AppColors.champagneGold : AppColors.cardBorder,
                    width: isOn ? AppDimensions.borderFocus : AppDimensions.borderThin,
                  ),
                ),
                child: Text(
                  interest,
                  style: AppTypography.caption.copyWith(
                    color: isOn ? AppColors.champagneGold : AppColors.pearlWhite,
                    fontWeight: isOn ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        if (selected.length >= 6)
          Padding(
            padding: const EdgeInsets.only(top: AppDimensions.space8),
            child: Text(
              'Maximum 6 interests selected.',
              style: AppTypography.caption.copyWith(
                color: AppColors.champagneGold,
              ),
            ),
          ),
      ],
    );
  }
}
