// lib/features/onboarding/screens/islamic_identity_screen.dart
// ============================================================
// NOOR — Islamic Identity Screen (Onboarding Step 2)
// Phase 2: CopyEngine for guardian-aware copy.
// Phase 2: Lifestyle & Diet section added.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/cubits/onboarding/onboarding_cubit.dart';
import '../../../core/cubits/onboarding/onboarding_state.dart';
import '../../../core/models/onboarding_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/copy_engine.dart';
import '../../../core/utils/validation_snackbar.dart';
import '../widgets/onboarding_scaffold.dart';
import '../widgets/step_header.dart';


class IslamicIdentityScreen extends StatefulWidget {
  const IslamicIdentityScreen({super.key});
  @override
  State<IslamicIdentityScreen> createState() => _IslamicIdentityScreenState();
}

class _IslamicIdentityScreenState extends State<IslamicIdentityScreen> {
  Sect?      _sect;
  String?    _subSect;
  DeenLevel? _deenLevel;
  bool?      _praysFive;
  String?    _hijab;
  String?    _beardStyle;  // 'yes','no','prefer_not_to_say' — maps to profiles.beard
  String?    _religiousLeadership; // male-only
  String?    _dietType;
  String?    _smokingHabit;
  String?    _vapingHabit;
  String?    _hookahHabit;
  String?    _isRevert; // Phase 1 addition

  @override
  void initState() {
    super.initState();
    final data = context.read<OnboardingCubit>().currentData;
    _sect = data.sect;
    _subSect = data.subSect;
    _deenLevel = data.deenLevel;
    _praysFive = data.praysFiveDaily;
    _hijab = data.hijabStyle;
    _beardStyle = data.beardStyle;
    _religiousLeadership = data.religiousLeadership;
    _dietType = data.dietType;
    _smokingHabit = data.smokingHabit;
    _vapingHabit = data.vapingHabit;
    _hookahHabit = data.hookahHabit;
    _isRevert = data.isRevert;
  }

  /// Country-aware sub-sects: returns expanded list based on user's country.
  List<String> get _subSects {
    final code = context.read<OnboardingCubit>().currentData.countryCode ?? '';
    // Common madhabs — universal across all Sunni regions
    const common = ['Hanafi', 'Shafi\'i', 'Maliki', 'Hanbali'];

    // ── Regional Sunni movements / schools ──────────────────
    const southAsia = [
      'Deobandi', 'Barelvi', 'Ahle Hadith', 'Salafi',
      'Tablighi Jamaat', 'Jamaat-e-Islami', 'Ahle Sunnat',
      'Minhaj-ul-Quran', 'Dawat-e-Islami',
      'Ahl-e-Quran', 'Jamiat Ulema-e-Hind',
      'Sufi (Chishti)', 'Sufi (Qadri)', 'Sufi (Naqshbandi)',
      'Sufi (Suhrawardi)', 'Sufi (Sabiri)',
    ];
    const mena = [
      'Salafi', 'Ash\'ari', 'Maturidi', 'Athari',
      'Sufi (Qadri)', 'Sufi (Naqshbandi)', 'Sufi (Shadhili)',
      'Sufi (Rifai)', 'Sufi (Badawi)',
      'Ibadi', 'Zahiri',
      'Muslim Brotherhood', 'Tabligh',
    ];
    const turkey = [
      'Maturidi', 'Ash\'ari',
      'Sufi (Naqshbandi)', 'Sufi (Mevlevi)',
      'Sufi (Qadri)', 'Sufi (Halveti)',
      'Gülen Movement', 'Süleymancı', 'İsmailağa',
      'Diyanet', 'Salafi',
    ];
    const seAsia = [
      'Nahdlatul Ulama', 'Muhammadiyah', 'Salafi',
      'Tabligh', 'Persis', 'Al-Irsyad',
      'Sufi (Qadri)', 'Sufi (Naqshbandi)',
      'LDII', 'Hidayatullah',
    ];
    const africa = [
      'Tijaniyyah', 'Mouridiyyah', 'Qadiriyyah',
      'Salafi', 'Izala', 'Sanusiyyah',
      'Sufi (Shadhili)', 'Sufi (Darqawi)',
      'Tablighi Jamaat', 'Ahmadiyya Muslim',
    ];
    const centralAsia = [
      'Maturidi', 'Sufi (Naqshbandi)', 'Sufi (Yasawi)',
      'Sufi (Qadri)', 'Salafi', 'Tabligh',
      'Hanafi (traditional)', 'Jadidism',
    ];
    const balkans = [
      'Maturidi', 'Ash\'ari',
      'Sufi (Naqshbandi)', 'Sufi (Bektashi)', 'Sufi (Halveti)',
      'Sufi (Qadri)', 'Sufi (Rifai)',
      'Salafi', 'Tabligh',
    ];
    const western = [
      'Salafi', 'Sufi', 'Ash\'ari', 'Maturidi', 'Athari',
      'Tablighi Jamaat', 'Muslim Brotherhood',
      'Progressive Muslim', 'Traditional Sunni',
    ];

    // ── Shia sub-sects ──────────────────────────────────────
    const shia = [
      'Ithna Ashari (Twelver)', 'Usuli', 'Akhbari',
      'Ismaili (Nizari)', 'Ismaili (Mustali)',
      'Bohra (Dawoodi)', 'Bohra (Sulaymani)', 'Bohra (Alavi)',
      'Zaydi',
      'Jafari', 'Alawi / Alevi',
      'Druze',
    ];

    final extras = <String>{};
    switch (code.toUpperCase()) {
      case 'PK': case 'IN': case 'BD': case 'LK': case 'AF': case 'NP':
        extras.addAll(southAsia);
      case 'SA': case 'AE': case 'QA': case 'KW': case 'BH': case 'OM':
      case 'EG': case 'JO': case 'LB': case 'SY': case 'IQ': case 'YE':
      case 'DZ': case 'MA': case 'TN': case 'LY': case 'SD':
      case 'IR': case 'PS':
        extras.addAll(mena);
      case 'TR':
        extras.addAll(turkey);
      case 'ID': case 'MY': case 'BN': case 'SG': case 'PH': case 'TH': case 'MM':
        extras.addAll(seAsia);
      case 'NG': case 'GH': case 'SN': case 'ML': case 'NE': case 'SO':
      case 'KE': case 'TZ': case 'ET': case 'ZA':
        extras.addAll(africa);
      case 'UZ': case 'TJ': case 'KZ': case 'KG': case 'TM': case 'AZ':
        extras.addAll(centralAsia);
      case 'BA': case 'XK': case 'AL': case 'MK':
        extras.addAll(balkans);
      case 'GB': case 'US': case 'CA': case 'AU': case 'NZ':
      case 'DE': case 'FR': case 'NL': case 'BE': case 'SE': case 'NO':
      case 'IE': case 'IT': case 'ES': case 'RU':
        extras.addAll(western);
      default:
        extras.addAll(western);
    }

    // If Shia selected, show shia sub-sects instead
    if (_sect == Sect.shia) return [...shia, 'Other', 'Prefer not to say'];

    return [...common, ...extras, 'Other', 'Prefer not to say'];
  }
  static const _hijabOptions = ['Always', 'Sometimes', 'No', 'Prefer not to say'];
  static const _deenTooltips = {
    'Practicing': 'Actively follows Islamic obligations: prayers, fasting, halal diet.',
    'Moderate':   'Identifies as Muslim and follows core practices but may not strictly observe all.',
    'Cultural':   'Muslim by identity and family heritage but less focused on religious practice.',
  };
  static const _habitOptions = ['Never', 'Occasionally', 'Frequently', 'Prefer not to say'];
  static const _dietOptions = [
    ('Strict Zabiha',       'zabiha_strict'),
    ('Halal only',          'halal_only'),
    ('Eats anything halal', 'eats_anything'),
    ('Vegetarian',          'vegetarian'),
    ('Vegan',               'vegan'),
  ];

  bool get _canProceed =>
      _deenLevel    != null && _praysFive != null &&
      _dietType     != null && _smokingHabit != null &&
      _vapingHabit  != null && _hookahHabit  != null;

  void _showValidation() {
    final missing = <String>[];
    if (_deenLevel == null) missing.add('Deen level');
    if (_praysFive == null) missing.add('Five daily prayers');
    if (_dietType == null) missing.add('Diet type');
    if (_smokingHabit == null) missing.add('Smoking habit');
    if (_vapingHabit == null) missing.add('Vaping habit');
    if (_hookahHabit == null) missing.add('Hookah habit');
    showValidationSnackbar(context, missing);
  }

  Gender? get _gender => context.read<OnboardingCubit>().currentData.gender;

  // TODO (backend): read from Supabase profiles.profileCreatorRelation.
  String get _relation =>
      context.read<OnboardingCubit>().currentData.profileCreatorRelation ?? 'self';

  void _advance() {
    final data = context.read<OnboardingCubit>().currentData.copyWith(
      sect: _sect, subSect: _subSect, deenLevel: _deenLevel,
      praysFiveDaily: _praysFive, hijabStyle: _hijab, beardStyle: _beardStyle,
      religiousLeadership: _religiousLeadership,
      dietType: _dietType, smokingHabit: _smokingHabit,
      vapingHabit: _vapingHabit, hookahHabit: _hookahHabit,
      isRevert: _isRevert,
    );
    context.read<OnboardingCubit>().saveAndAdvance(data);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OnboardingCubit, OnboardingState>(
      builder: (context, state) {
        final isLoading = state is OnboardingLoading;
        return OnboardingScaffold(
          ctaLabel: 'Continue', onCta: _advance,
          isCtaEnabled: _canProceed, isCtaLoading: isLoading,
          onCtaDisabledTap: _showValidation,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppDimensions.space32),
              const StepHeader(title: 'Your faith', subtitle: 'This helps match you with someone compatible.'),
              const SizedBox(height: AppDimensions.space32),

              const _SectionTitle('SECT'),
              const SizedBox(height: AppDimensions.space12),
              _ChipGroup<Sect>(
                options: const [Sect.sunni, Sect.shia, Sect.preferNotToSay, Sect.other],
                selected: _sect,
                label: (s) {
                  switch (s) {
                    case Sect.sunni:          return 'Sunni';
                    case Sect.shia:           return 'Shia';
                    case Sect.preferNotToSay: return 'Prefer not to say';
                    case Sect.other:          return 'Other';
                  }
                },
                onSelected: (s) => setState(() { _sect = s; _subSect = null; }),
              ),
              const SizedBox(height: AppDimensions.space20),
              if (_sect == Sect.sunni || _sect == Sect.shia) ...[
                _SectionTitle(_sect == Sect.shia
                    ? 'SCHOOL OF THOUGHT  (Optional)'
                    : 'SCHOOL OF THOUGHT  (Optional)'),
                const SizedBox(height: AppDimensions.space12),
                Wrap(
                  spacing: AppDimensions.space8, runSpacing: AppDimensions.space8,
                  children: _subSects.map((s) => _SelectChip(
                    label: s, isSelected: _subSect == s,
                    onTap: () => setState(() => _subSect = _subSect == s ? null : s),
                  )).toList(),
                ),
                const SizedBox(height: AppDimensions.space20),
              ],

              // ── REVERT / CONVERT STATUS ──────────────────
              const _SectionTitle('REVERT / CONVERT  (Optional)'),
              const SizedBox(height: AppDimensions.space4),
              const Text('Are you a revert (convert) to Islam?', style: AppTypography.caption),
              const SizedBox(height: AppDimensions.space12),
              Wrap(
                spacing: AppDimensions.space8, runSpacing: AppDimensions.space8,
                children: {
                  'yes': 'Yes',
                  'no': 'No',
                  'prefer_not_to_say': 'Prefer not to say',
                }.entries.map((e) => _SelectChip(
                  label: e.value,
                  isSelected: _isRevert == e.key,
                  onTap: () => setState(() => _isRevert = e.key),
                )).toList(),
              ),
              const SizedBox(height: AppDimensions.space20),

              const _SectionTitle('DEEN LEVEL'),
              const SizedBox(height: AppDimensions.space12),
              Column(
                children: DeenLevel.values.map((d) {
                  final label = _deenLabel(d);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppDimensions.space8),
                    child: _DeenCard(
                      label: label, tooltip: _deenTooltips[label] ?? '',
                      isSelected: _deenLevel == d,
                      onTap: () => setState(() => _deenLevel = d),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: AppDimensions.space20),

              _SectionTitle(CopyEngine.prayerQuestion(_relation).toUpperCase()),
              const SizedBox(height: AppDimensions.space12),
              Row(children: [
                Expanded(child: _TogglePill(label: 'Yes', isSelected: _praysFive == true,  onTap: () => setState(() => _praysFive = true))),
                const SizedBox(width: AppDimensions.space12),
                Expanded(child: _TogglePill(label: 'No',  isSelected: _praysFive == false, onTap: () => setState(() => _praysFive = false))),
              ]),

              if (_gender == Gender.female) ...[
                const SizedBox(height: AppDimensions.space20),
                _SectionTitle(CopyEngine.hijabQuestion(_relation, 'female').toUpperCase()),
                const SizedBox(height: AppDimensions.space12),
                Wrap(
                  spacing: AppDimensions.space8, runSpacing: AppDimensions.space8,
                  children: _hijabOptions.map((o) => _SelectChip(
                    label: o, isSelected: _hijab == o,
                    onTap: () => setState(() => _hijab = _hijab == o ? null : o),
                  )).toList(),
                ),
              ],

              if (_gender == Gender.male) ...[
                const SizedBox(height: AppDimensions.space20),
                _SectionTitle(CopyEngine.beardQuestion(_relation).toUpperCase()),
                const SizedBox(height: AppDimensions.space12),
                Wrap(
                  spacing: AppDimensions.space8, runSpacing: AppDimensions.space8,
                children: {
                  'yes': 'Yes',
                  'no': 'No',
                  'prefer_not_to_say': 'Prefer not to say',
                }.entries.map((e) => _SelectChip(
                    label: e.value,
                    isSelected: _beardStyle == e.key,
                    onTap: () => setState(() => _beardStyle = e.key),
                  )).toList(),
                ),
                const SizedBox(height: AppDimensions.space20),
                const _SectionTitle('RELIGIOUS LEADERSHIP'),
                const SizedBox(height: AppDimensions.space4),
                const Text('Can you lead congregational prayers?', style: AppTypography.caption),
                const SizedBox(height: AppDimensions.space12),
                Wrap(
                  spacing: AppDimensions.space8, runSpacing: AppDimensions.space8,
                  children: {
                    'leads_prayer': 'Leads Prayer',
                    'learning': 'Learning',
                    'not_yet': 'Not Yet',
                    'prefer_not_to_say': 'Prefer Not to Say',
                  }.entries.map((e) => _SelectChip(
                    label: e.value,
                    isSelected: _religiousLeadership == e.key,
                    onTap: () => setState(() => _religiousLeadership = e.key),
                  )).toList(),
                ),
              ],

              // ── LIFESTYLE & DIET ─────────────────────────
              const SizedBox(height: AppDimensions.space28),
              const _SectionTitle('LIFESTYLE & DIET'),
              const SizedBox(height: AppDimensions.space6),
              const Text('These are dealbreaker fields for many families. Please answer honestly.', style: AppTypography.caption),
              const SizedBox(height: AppDimensions.space16),

              const _SectionTitle('DIET'),
              const SizedBox(height: AppDimensions.space12),
              Wrap(
                spacing: AppDimensions.space8, runSpacing: AppDimensions.space8,
                children: _dietOptions.map((opt) => _SelectChip(
                  label: opt.$1, isSelected: _dietType == opt.$2,
                  onTap: () => setState(() => _dietType = opt.$2),
                )).toList(),
              ),
              const SizedBox(height: AppDimensions.space20),

              // ── SUBSTANCE USE ─────────────────────────────
              const SizedBox(height: AppDimensions.space20),
              const _SectionTitle('SUBSTANCE USE'),
              const SizedBox(height: AppDimensions.space12),

              const Text('Smoking', style: AppTypography.caption),
              const SizedBox(height: AppDimensions.space8),
              Wrap(
                spacing: AppDimensions.space8, runSpacing: AppDimensions.space8,
                children: _habitOptions.map((o) => _SelectChip(
                  label: o, isSelected: _smokingHabit == o,
                  onTap: () => setState(() => _smokingHabit = o),
                )).toList(),
              ),
              const SizedBox(height: AppDimensions.space16),

              const Text('Vaping / E-Cigarettes', style: AppTypography.caption),
              const SizedBox(height: AppDimensions.space8),
              Wrap(
                spacing: AppDimensions.space8, runSpacing: AppDimensions.space8,
                children: _habitOptions.map((o) => _SelectChip(
                  label: o, isSelected: _vapingHabit == o,
                  onTap: () => setState(() => _vapingHabit = o),
                )).toList(),
              ),
              const SizedBox(height: AppDimensions.space16),

              const Text('Hookah / Shisha', style: AppTypography.caption),
              const SizedBox(height: AppDimensions.space8),
              Wrap(
                spacing: AppDimensions.space8, runSpacing: AppDimensions.space8,
                children: _habitOptions.map((o) => _SelectChip(
                  label: o, isSelected: _hookahHabit == o,
                  onTap: () => setState(() => _hookahHabit = o),
                )).toList(),
              ),

              const SizedBox(height: AppDimensions.space32),
            ],
          ),
        );
      },
    );
  }

  String _deenLabel(DeenLevel d) {
    switch (d) {
      case DeenLevel.practicing: return 'Practicing';
      case DeenLevel.moderate:   return 'Moderate';
      case DeenLevel.cultural:   return 'Cultural Muslim';
    }
  }
}

// ── Shared sub-widgets ────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text, style: AppTypography.sectionLabel);
}

class _ChipGroup<T> extends StatelessWidget {
  const _ChipGroup({required this.options, required this.selected, required this.label, required this.onSelected});
  final List<T> options;
  final T? selected;
  final String Function(T) label;
  final ValueChanged<T> onSelected;
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppDimensions.space8, runSpacing: AppDimensions.space8,
      children: options.map((o) => _SelectChip(
        label: label(o), isSelected: selected == o, onTap: () => onSelected(o),
      )).toList(),
    );
  }
}

class _SelectChip extends StatelessWidget {
  const _SelectChip({required this.label, required this.isSelected, required this.onTap});
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppDimensions.durationTransition,
        padding: const EdgeInsets.symmetric(horizontal: AppDimensions.space16, vertical: AppDimensions.space10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.champagneGold.withValues(alpha: 0.12) : AppColors.surfaceGlass,
          borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
          border: Border.all(
            color: isSelected ? AppColors.champagneGold : AppColors.cardBorder,
            width: isSelected ? AppDimensions.borderFocus : AppDimensions.borderThin,
          ),
        ),
        child: Text(label, style: AppTypography.chipLabel.copyWith(
          color: isSelected ? AppColors.champagneGold : AppColors.pearlWhite,
        )),
      ),
    );
  }
}

class _DeenCard extends StatelessWidget {
  const _DeenCard({required this.label, required this.tooltip, required this.isSelected, required this.onTap});
  final String label;
  final String tooltip;
  final bool isSelected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppDimensions.durationTransition,
        padding: const EdgeInsets.all(AppDimensions.space16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.champagneGold.withValues(alpha: 0.08) : AppColors.surfaceGlass,
          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          border: Border.all(
            color: isSelected ? AppColors.champagneGold : AppColors.cardBorder,
            width: isSelected ? AppDimensions.borderFocus : AppDimensions.borderThin,
          ),
        ),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: AppTypography.bodyMedium.copyWith(color: isSelected ? AppColors.champagneGold : AppColors.pearlWhite)),
            const SizedBox(height: AppDimensions.space4),
            Text(tooltip, style: AppTypography.caption),
          ])),
          if (isSelected) Container(
            width: 20, height: 20,
            decoration: const BoxDecoration(color: AppColors.champagneGold, shape: BoxShape.circle),
            child: const Icon(Icons.check_rounded, color: AppColors.obsidianNight, size: 14),
          ),
        ]),
      ),
    );
  }
}

class _TogglePill extends StatelessWidget {
  const _TogglePill({required this.label, required this.isSelected, required this.onTap});
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppDimensions.durationTransition,
        height: AppDimensions.buttonHeightSmall,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.champagneGold.withValues(alpha: 0.1) : AppColors.surfaceGlass,
          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          border: Border.all(
            color: isSelected ? AppColors.champagneGold : AppColors.cardBorder,
            width: isSelected ? AppDimensions.borderFocus : AppDimensions.borderThin,
          ),
        ),
        child: Center(child: Text(label, style: AppTypography.bodyMedium.copyWith(
          color: isSelected ? AppColors.champagneGold : AppColors.pearlWhite,
        ))),
      ),
    );
  }
}

// ── Expose _SelectChip and _TogglePill for reuse ─────────────
