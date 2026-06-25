// lib/features/onboarding/screens/islamic_identity_screen.dart
// ============================================================
// MITHAQ — Islamic Identity Screen (Onboarding Step 2)
// Phase 2: CopyEngine for guardian-aware copy.
// Phase 2: Lifestyle & Diet section added.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mithaq/l10n/generated/app_localizations.dart';
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

  String _getLocalizedSubSect(AppLocalizations l10n, String raw) {
    if (l10n.localeName == 'ar') {
      switch (raw) {
        case 'Hanafi': return 'حنفي';
        case 'Shafi\'i': return 'شافعي';
        case 'Maliki': return 'مالكي';
        case 'Hanbali': return 'حنبلي';
        case 'Deobandi': return 'ديوبندي';
        case 'Barelvi': return 'بريلوي';
        case 'Ahle Hadith': return 'أهل الحديث';
        case 'Salafi': return 'سلفي';
        case 'Sufi': return 'صوفي';
        case 'Other': return 'أخرى';
        case 'Prefer not to say': return 'أفضل عدم الإجابة';
        case 'Ithna Ashari (Twelver)': return 'إثنا عشري (جعفري)';
        case 'Ismaili (Nizari)': return 'إسماعيلي (نزاري)';
        case 'Zaydi': return 'زيدي';
        case 'Jafari': return 'جعفري';
      }
    }
    return raw;
  }

  String _getLocalizedHijab(AppLocalizations l10n, String raw) {
    switch (raw) {
      case 'Always': return l10n.onboarding_hijab_always;
      case 'Sometimes': return l10n.onboarding_hijab_sometimes;
      case 'No': return l10n.onboarding_hijab_no;
      case 'Prefer not to say': return l10n.onboarding_label_preferNotToSay;
    }
    return raw;
  }

  String _getLocalizedHabit(AppLocalizations l10n, String raw) {
    switch (raw) {
      case 'Never': return l10n.onboarding_habit_never;
      case 'Occasionally': return l10n.onboarding_habit_occasionally;
      case 'Frequently': return l10n.onboarding_habit_frequently;
      case 'Prefer not to say': return l10n.onboarding_habit_preferNotToSay;
    }
    return raw;
  }

  String _getLocalizedDiet(AppLocalizations l10n, String key) {
    switch (key) {
      case 'zabiha_strict': return l10n.onboarding_diet_zabihaStrict;
      case 'halal_only': return l10n.onboarding_diet_halalOnly;
      case 'eats_anything': return l10n.onboarding_diet_eatsAnything;
      case 'vegetarian': return l10n.onboarding_diet_vegetarian;
      case 'vegan': return l10n.onboarding_diet_vegan;
    }
    return key;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final deenTooltips = {
      l10n.onboarding_label_practicing: l10n.onboarding_tooltip_practicing,
      l10n.onboarding_label_moderate:   l10n.onboarding_tooltip_moderate,
      l10n.onboarding_label_cultural:   l10n.onboarding_tooltip_cultural,
    };

    return BlocBuilder<OnboardingCubit, OnboardingState>(
      builder: (context, state) {
        final isLoading = state is OnboardingLoading;
        return OnboardingScaffold(
          ctaLabel: l10n.legal_button_continue, onCta: _advance,
          isCtaEnabled: _canProceed, isCtaLoading: isLoading,
          onCtaDisabledTap: _showValidation,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppDimensions.space32),
              StepHeader(title: l10n.onboarding_islamicIdentity_title, subtitle: l10n.onboarding_islamicIdentity_subtitle),
              const SizedBox(height: AppDimensions.space32),

              _SectionTitle(l10n.onboarding_label_sect.toUpperCase()),
              const SizedBox(height: AppDimensions.space12),
              _ChipGroup<Sect>(
                options: const [Sect.sunni, Sect.shia, Sect.preferNotToSay, Sect.other],
                selected: _sect,
                label: (s) {
                  switch (s) {
                    case Sect.sunni:          return l10n.onboarding_label_sunni;
                    case Sect.shia:           return l10n.onboarding_label_shia;
                    case Sect.preferNotToSay: return l10n.onboarding_label_preferNotToSay;
                    case Sect.other:          return l10n.localeName == 'ar' ? 'أخرى' : 'Other';
                  }
                },
                onSelected: (s) => setState(() { _sect = s; _subSect = null; }),
              ),
              const SizedBox(height: AppDimensions.space20),
              if (_sect == Sect.sunni || _sect == Sect.shia) ...[
                _SectionTitle(l10n.onboarding_label_subSect.toUpperCase()),
                const SizedBox(height: AppDimensions.space12),
                Wrap(
                  spacing: AppDimensions.space8, runSpacing: AppDimensions.space8,
                  children: _subSects.map((s) => _SelectChip(
                    label: _getLocalizedSubSect(l10n, s), isSelected: _subSect == s,
                    onTap: () => setState(() => _subSect = _subSect == s ? null : s),
                  )).toList(),
                ),
                const SizedBox(height: AppDimensions.space20),
              ],

              // ── REVERT / CONVERT STATUS ──────────────────
              _SectionTitle(l10n.onboarding_label_revert.toUpperCase()),
              const SizedBox(height: AppDimensions.space4),
              Text(l10n.onboarding_label_revertQuestion, style: AppTypography.caption),
              const SizedBox(height: AppDimensions.space12),
              Wrap(
                spacing: AppDimensions.space8, runSpacing: AppDimensions.space8,
                children: {
                  'yes': l10n.localeName == 'ar' ? 'نعم' : 'Yes',
                  'no': l10n.localeName == 'ar' ? 'لا' : 'No',
                  'prefer_not_to_say': l10n.onboarding_label_preferNotToSay,
                }.entries.map((e) => _SelectChip(
                  label: e.value,
                  isSelected: _isRevert == e.key,
                  onTap: () => setState(() => _isRevert = e.key),
                )).toList(),
              ),
              const SizedBox(height: AppDimensions.space20),

              _SectionTitle(l10n.onboarding_label_deenLevel.toUpperCase()),
              const SizedBox(height: AppDimensions.space12),
              Column(
                children: DeenLevel.values.map((d) {
                  final label = _deenLabel(l10n, d);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppDimensions.space8),
                    child: _DeenCard(
                      label: label, tooltip: deenTooltips[label] ?? '',
                      isSelected: _deenLevel == d,
                      onTap: () => setState(() => _deenLevel = d),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: AppDimensions.space20),

              _SectionTitle(CopyEngine.prayerQuestion(l10n, _relation).toUpperCase()),
              const SizedBox(height: AppDimensions.space12),
              Row(children: [
                Expanded(child: _TogglePill(label: l10n.localeName == 'ar' ? 'نعم' : 'Yes', isSelected: _praysFive == true,  onTap: () => setState(() => _praysFive = true))),
                const SizedBox(width: AppDimensions.space12),
                Expanded(child: _TogglePill(label: l10n.localeName == 'ar' ? 'لا' : 'No',  isSelected: _praysFive == false, onTap: () => setState(() => _praysFive = false))),
              ]),

              if (_gender == Gender.female) ...[
                const SizedBox(height: AppDimensions.space20),
                _SectionTitle(CopyEngine.hijabQuestion(l10n, _relation, 'female').toUpperCase()),
                const SizedBox(height: AppDimensions.space12),
                Wrap(
                  spacing: AppDimensions.space8, runSpacing: AppDimensions.space8,
                  children: _hijabOptions.map((o) => _SelectChip(
                    label: _getLocalizedHijab(l10n, o), isSelected: _hijab == o,
                    onTap: () => setState(() => _hijab = _hijab == o ? null : o),
                  )).toList(),
                ),
              ],

              if (_gender == Gender.male) ...[
                const SizedBox(height: AppDimensions.space20),
                _SectionTitle(CopyEngine.beardQuestion(l10n, _relation).toUpperCase()),
                const SizedBox(height: AppDimensions.space12),
                Wrap(
                  spacing: AppDimensions.space8, runSpacing: AppDimensions.space8,
                children: {
                  'yes': l10n.localeName == 'ar' ? 'نعم' : 'Yes',
                  'no': l10n.localeName == 'ar' ? 'لا' : 'No',
                  'prefer_not_to_say': l10n.onboarding_label_preferNotToSay,
                }.entries.map((e) => _SelectChip(
                    label: e.value,
                    isSelected: _beardStyle == e.key,
                    onTap: () => setState(() => _beardStyle = e.key),
                  )).toList(),
                ),
                const SizedBox(height: AppDimensions.space20),
                _SectionTitle(l10n.onboarding_label_leadership.toUpperCase()),
                const SizedBox(height: AppDimensions.space4),
                Text(l10n.onboarding_label_leadershipQuestion, style: AppTypography.caption),
                const SizedBox(height: AppDimensions.space12),
                Wrap(
                  spacing: AppDimensions.space8, runSpacing: AppDimensions.space8,
                  children: {
                    'leads_prayer': l10n.onboarding_leadership_leads,
                    'learning': l10n.onboarding_leadership_learning,
                    'not_yet': l10n.onboarding_leadership_notYet,
                    'prefer_not_to_say': l10n.onboarding_label_preferNotToSay,
                  }.entries.map((e) => _SelectChip(
                    label: e.value,
                    isSelected: _religiousLeadership == e.key,
                    onTap: () => setState(() => _religiousLeadership = e.key),
                  )).toList(),
                ),
              ],

              // ── LIFESTYLE & DIET ─────────────────────────
              const SizedBox(height: AppDimensions.space28),
              _SectionTitle(l10n.onboarding_label_lifestyleDiet.toUpperCase()),
              const SizedBox(height: AppDimensions.space6),
              Text(l10n.onboarding_label_lifestyleDietSub, style: AppTypography.caption),
              const SizedBox(height: AppDimensions.space16),

              _SectionTitle(l10n.onboarding_label_diet.toUpperCase()),
              const SizedBox(height: AppDimensions.space12),
              Wrap(
                spacing: AppDimensions.space8, runSpacing: AppDimensions.space8,
                children: _dietOptions.map((opt) => _SelectChip(
                  label: _getLocalizedDiet(l10n, opt.$2), isSelected: _dietType == opt.$2,
                  onTap: () => setState(() => _dietType = opt.$2),
                )).toList(),
              ),
              const SizedBox(height: AppDimensions.space20),

              // ── SUBSTANCE USE ─────────────────────────────
              const SizedBox(height: AppDimensions.space20),
              _SectionTitle(l10n.onboarding_label_substanceUse.toUpperCase()),
              const SizedBox(height: AppDimensions.space12),

              Text(l10n.onboarding_label_smoking, style: AppTypography.caption),
              const SizedBox(height: AppDimensions.space8),
              Wrap(
                spacing: AppDimensions.space8, runSpacing: AppDimensions.space8,
                children: _habitOptions.map((o) => _SelectChip(
                  label: _getLocalizedHabit(l10n, o), isSelected: _smokingHabit == o,
                  onTap: () => setState(() => _smokingHabit = o),
                )).toList(),
              ),
              const SizedBox(height: AppDimensions.space16),

              Text(l10n.onboarding_label_vaping, style: AppTypography.caption),
              const SizedBox(height: AppDimensions.space8),
              Wrap(
                spacing: AppDimensions.space8, runSpacing: AppDimensions.space8,
                children: _habitOptions.map((o) => _SelectChip(
                  label: _getLocalizedHabit(l10n, o), isSelected: _vapingHabit == o,
                  onTap: () => setState(() => _vapingHabit = o),
                )).toList(),
              ),
              const SizedBox(height: AppDimensions.space16),

              Text(l10n.onboarding_label_hookah, style: AppTypography.caption),
              const SizedBox(height: AppDimensions.space8),
              Wrap(
                spacing: AppDimensions.space8, runSpacing: AppDimensions.space8,
                children: _habitOptions.map((o) => _SelectChip(
                  label: _getLocalizedHabit(l10n, o), isSelected: _hookahHabit == o,
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

  String _deenLabel(AppLocalizations l10n, DeenLevel d) {
    switch (d) {
      case DeenLevel.practicing: return l10n.onboarding_label_practicing;
      case DeenLevel.moderate:   return l10n.onboarding_label_moderate;
      case DeenLevel.cultural:   return l10n.onboarding_label_cultural;
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
