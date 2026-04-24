// lib/features/home/screens/edit_profile_screen.dart
// ============================================================
// NOOR — Edit Profile Screen (Step 6)
//
// Blueprint (Part 8, My Profile Screen):
//   "Tap any section to edit that section."
//   Each section opens an inline editor with the same
//   fields from onboarding, pre-filled with current values.
//
// For Phase 1 mock: values are stored locally in state.
// Live Supabase sync is wired in Step 8 (Profile CRUD).
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';

// ── Simple in-memory profile state for mock editing ──────────

class _EditableProfile {
  String   displayName   = 'Your Name';
  String   city          = '';
  String   occupation    = '';
  String   education     = '';
  String   bio           = '';
  String   sect          = 'Sunni';
  String   deenLevel     = 'moderate';
  String   maritalStatus = 'Never Married';
  String   familyType    = 'Nuclear';
  String   photoPrivacy  = 'After Acceptance';
  bool     praysFiveDaily = true;
}

// Shared instance (survives navigation for this session)
final _profile = _EditableProfile();

// ─────────────────────────────────────────────────────────────

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  // Counts filled sections for the completeness nudge
  int get _completeness {
    int score = 0;
    if (_profile.displayName.isNotEmpty) score += 15;
    if (_profile.city.isNotEmpty)        score += 10;
    if (_profile.occupation.isNotEmpty)  score += 10;
    if (_profile.education.isNotEmpty)   score += 10;
    if (_profile.bio.length >= 50)       score += 15;
    if (_profile.praysFiveDaily)         score += 15;
    score += 25; // photo placeholder credit
    return score.clamp(0, 100);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.obsidianNight,
      appBar: AppBar(
        backgroundColor:    AppColors.obsidianNight,
        surfaceTintColor:   Colors.transparent,
        elevation:          0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(AppDimensions.space8),
            decoration: BoxDecoration(
              color:        AppColors.surfaceGlass,
              shape:        BoxShape.circle,
              border:       Border.all(color: AppColors.cardBorder),
            ),
            child: const Icon(
              Icons.arrow_back_rounded,
              color: AppColors.pearlWhite,
              size:  AppDimensions.iconSizeMedium,
            ),
          ),
        ),
        title: Text('Edit Profile', style: AppTypography.screenTitle.copyWith(fontSize: 20)),
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
            // ── Completeness bar ─────────────────────────────
            _CompletenessCard(percentage: _completeness / 100),
            const SizedBox(height: AppDimensions.space28),

            // ── Photo section ─────────────────────────────────
            _SectionHeader(label: 'Photos'),
            const SizedBox(height: AppDimensions.space12),
            _PhotoGrid(),
            const SizedBox(height: AppDimensions.space28),

            // ── Basic Info ────────────────────────────────────
            _SectionHeader(label: 'Basic Info'),
            const SizedBox(height: AppDimensions.space12),
            _NoorTextField(
              label:        'Display Name',
              initialValue: _profile.displayName,
              onChanged:    (v) => setState(() => _profile.displayName = v),
            ),
            const SizedBox(height: AppDimensions.space12),
            _NoorTextField(
              label:        'City',
              initialValue: _profile.city,
              hint:         'e.g. Dubai, London, Karachi',
              onChanged:    (v) => setState(() => _profile.city = v),
            ),
            const SizedBox(height: AppDimensions.space28),

            // ── About ─────────────────────────────────────────
            _SectionHeader(label: 'About'),
            const SizedBox(height: AppDimensions.space12),
            _NoorTextField(
              label:        'Bio',
              initialValue: _profile.bio,
              hint:         'Describe yourself with honesty and dignity.',
              maxLines:     5,
              maxLength:    300,
              onChanged:    (v) => setState(() => _profile.bio = v),
            ),
            const SizedBox(height: AppDimensions.space28),

            // ── Islamic Identity ──────────────────────────────
            _SectionHeader(label: 'Islamic Identity'),
            const SizedBox(height: AppDimensions.space12),
            _DropdownField(
              label:    'Sect',
              value:    _profile.sect,
              options:  const ['Sunni', 'Shia', 'Ahmadiyya', 'Other', 'Prefer not to say'],
              onChanged: (v) => setState(() => _profile.sect = v!),
            ),
            const SizedBox(height: AppDimensions.space12),
            _DropdownField(
              label:    'Deen Level',
              value:    _profile.deenLevel,
              options:  const ['practicing', 'moderate', 'cultural'],
              optionLabels: const ['Practicing', 'Moderate', 'Cultural Muslim'],
              onChanged: (v) => setState(() => _profile.deenLevel = v!),
            ),
            const SizedBox(height: AppDimensions.space12),
            _ToggleRow(
              label:     'Prays five times daily',
              value:     _profile.praysFiveDaily,
              onChanged: (v) => setState(() => _profile.praysFiveDaily = v),
            ),
            const SizedBox(height: AppDimensions.space28),

            // ── Education & Career ────────────────────────────
            _SectionHeader(label: 'Education & Career'),
            const SizedBox(height: AppDimensions.space12),
            _NoorTextField(
              label:        'Occupation',
              initialValue: _profile.occupation,
              hint:         'e.g. Software Engineer',
              onChanged:    (v) => setState(() => _profile.occupation = v),
            ),
            const SizedBox(height: AppDimensions.space12),
            _DropdownField(
              label:    'Education Level',
              value:    _profile.education.isEmpty ? 'Bachelor\'s Degree' : _profile.education,
              options:  const [
                'Below Secondary',
                'Secondary / O-Level',
                'Higher Secondary / A-Level',
                'Diploma / Associate',
                'Bachelor\'s Degree',
                'Master\'s Degree',
                'Doctorate / PhD',
              ],
              onChanged: (v) => setState(() => _profile.education = v!),
            ),
            const SizedBox(height: AppDimensions.space28),

            // ── Family ────────────────────────────────────────
            _SectionHeader(label: 'Family'),
            const SizedBox(height: AppDimensions.space12),
            _DropdownField(
              label:    'Family Type',
              value:    _profile.familyType,
              options:  const ['Nuclear', 'Joint', 'Extended'],
              onChanged: (v) => setState(() => _profile.familyType = v!),
            ),
            const SizedBox(height: AppDimensions.space12),
            _DropdownField(
              label:    'Marital Status',
              value:    _profile.maritalStatus,
              options:  const ['Never Married', 'Divorced', 'Widowed'],
              onChanged: (v) => setState(() => _profile.maritalStatus = v!),
            ),
            const SizedBox(height: AppDimensions.space28),

            // ── Privacy ───────────────────────────────────────
            _SectionHeader(label: 'Privacy'),
            const SizedBox(height: AppDimensions.space12),
            _DropdownField(
              label:    'Photo Privacy',
              value:    _profile.photoPrivacy,
              options:  const ['Public', 'After Acceptance'],
              onChanged: (v) => setState(() => _profile.photoPrivacy = v!),
            ),
          ],
        ),
      ),
    );
  }

  void _saveProfile() {
    HapticFeedback.mediumImpact();
    // Show snackbar BEFORE pop() — after pop() the context is unmounted.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle_rounded,
              color: AppColors.champagneGold, size: 18),
          const SizedBox(width: AppDimensions.space8),
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
}

// ── Completeness Card ─────────────────────────────────────────

class _CompletenessCard extends StatelessWidget {
  const _CompletenessCard({required this.percentage});
  final double percentage;

  @override
  Widget build(BuildContext context) {
    final pct = (percentage * 100).round();
    return Container(
      padding: const EdgeInsets.all(AppDimensions.space16),
      decoration: BoxDecoration(
        color:        AppColors.champagneGold.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
        border:       Border.all(color: AppColors.goldBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('$pct% complete',
                  style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.champagneGold)),
              const Spacer(),
              Text(
                pct >= 80 ? '✓ Great profile!' : 'Keep going!',
                style: AppTypography.caption.copyWith(
                    color: AppColors.champagneGold),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.space10),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value:            percentage,
              backgroundColor:  AppColors.progressBarBase,
              valueColor: const AlwaysStoppedAnimation(AppColors.champagneGold),
              minHeight: 4,
            ),
          ),
          const SizedBox(height: AppDimensions.space8),
          Text(
            'Profiles with 80%+ completeness receive 3× more interests.',
            style: AppTypography.caption,
          ),
        ],
      ),
    );
  }
}

// ── Photo Grid (4-slot) ───────────────────────────────────────

class _PhotoGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap:  true,
      physics:     const NeverScrollableScrollPhysics(),
      crossAxisCount: 4,
      crossAxisSpacing: AppDimensions.space8,
      mainAxisSpacing:  AppDimensions.space8,
      children: [
        // Slot 0: primary (filled with placeholder)
        _PhotoSlot(index: 0, isFilled: true, isPrimary: true),
        _PhotoSlot(index: 1, isFilled: false),
        _PhotoSlot(index: 2, isFilled: false),
        _PhotoSlot(index: 3, isFilled: false),
      ],
    );
  }
}

class _PhotoSlot extends StatelessWidget {
  const _PhotoSlot({
    required this.index,
    required this.isFilled,
    this.isPrimary = false,
  });
  final int  index;
  final bool isFilled;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => HapticFeedback.selectionClick(),
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
                              color: AppColors.champagneGold,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text('Main',
                                style: AppTypography.caption.copyWith(
                                    color: AppColors.obsidianNight,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700)),
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

// ── NOOR Text Field ───────────────────────────────────────────

class _NoorTextField extends StatefulWidget {
  const _NoorTextField({
    required this.label,
    required this.onChanged,
    this.initialValue = '',
    this.hint,
    this.maxLines = 1,
    this.maxLength,
  });
  final String   label;
  final String   initialValue;
  final String?  hint;
  final int      maxLines;
  final int?     maxLength;
  final ValueChanged<String> onChanged;

  @override
  State<_NoorTextField> createState() => _NoorTextFieldState();
}

class _NoorTextFieldState extends State<_NoorTextField> {
  late final TextEditingController _ctrl;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

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
          controller:  _ctrl,
          maxLines:    widget.maxLines,
          maxLength:   widget.maxLength,
          style:       AppTypography.inputText,
          onChanged:   widget.onChanged,
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
        value:     options.contains(value) ? value : options.first,
        style:     AppTypography.inputText,
        dropdownColor: const Color(0xFF13131A),
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
          final label = optionLabels?[i] ?? val;
          return DropdownMenuItem(
            value: val,
            child: Text(label, style: AppTypography.body),
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
            value:            value,
            onChanged:        onChanged,
            activeColor:      AppColors.champagneGold,
            activeTrackColor: AppColors.champagneGold.withValues(alpha: 0.3),
            inactiveThumbColor:  AppColors.slateMist,
            inactiveTrackColor:  AppColors.surfaceGlassHover,
          ),
        ],
      ),
    );
  }
}
