// lib/features/onboarding/screens/about_yourself_screen.dart
// ============================================================
// MITHAQ — About Yourself Screen (Onboarding Step 6)
// Bio (300 chars with content filter), interests (max 6), languages.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/cubits/onboarding/onboarding_cubit.dart';
import '../../../core/services/country_context_service.dart';
import '../../../core/cubits/onboarding/onboarding_state.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/content_filter.dart';
import '../../../core/utils/validation_snackbar.dart';
import '../../../core/widgets/inputs/mithaq_text_field.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../widgets/onboarding_scaffold.dart';
import '../widgets/step_header.dart';

// Content filter uses shared utility (see lib/core/utils/content_filter.dart)

// ── Interest categories ───────────────────────────────────────
const _kInterestCategories = [
  (name: 'Faith',     icon: Icons.mosque_outlined,     tags: ['Quran recitation', 'Islamic lectures', 'Dawah', 'Voluntary fasting', 'Tahajjud', 'Umrah/Hajj']),
  (name: 'Lifestyle', icon: Icons.spa_outlined,         tags: ['Cooking', 'Travel', 'Fitness', 'Gardening', 'Volunteering', 'Photography']),
  (name: 'Learning',  icon: Icons.auto_stories_outlined, tags: ['Reading', 'Technology', 'Science', 'History', 'Languages', 'Writing']),
  (name: 'Creative',  icon: Icons.palette_outlined,      tags: ['Calligraphy', 'Art', 'Poetry', 'Graphic design', 'Crafts']),
  (name: 'Sports',    icon: Icons.sports_soccer_outlined, tags: ['Cricket', 'Football', 'Swimming', 'Hiking', 'Martial arts', 'Cycling']),
  (name: 'Social',    icon: Icons.volunteer_activism_outlined, tags: ['Community work', 'Teaching', 'Mentoring', 'Family gatherings']),
];

// Fallback list — used while REST Countries API response loads
const _kLanguagesFallback = [
  'English', 'Arabic', 'Urdu', 'Hindi', 'Malay', 'Indonesian',
  'Turkish', 'French', 'German', 'Bengali', 'Punjabi', 'Tamil',
  'Persian', 'Swahili', 'Hausa', 'Pashto', 'Sindhi',
  'Somali', 'Kurdish', 'Dari', 'Javanese', 'Sundanese',
  'Tagalog', 'Thai', 'Burmese', 'Rohingya',
  'Wolof', 'Fulani', 'Amazigh (Berber)', 'Mandinka',
  'Uzbek', 'Kazakh', 'Tajik', 'Kyrgyz', 'Tatar',
  'Bosnian', 'Albanian', 'Chechen',
  'Dutch', 'Swedish', 'Norwegian', 'Italian', 'Spanish', 'Portuguese',
  'Gujarati', 'Marathi', 'Malayalam', 'Telugu', 'Kannada',
  'Assamese', 'Odia', 'Saraiki', 'Balochi',
  'Amharic', 'Tigrinya', 'Yoruba', 'Igbo',
  'Chinese (Mandarin)', 'Russian', 'Japanese', 'Korean',
  'Other',
];

class AboutYourselfScreen extends StatefulWidget {
  const AboutYourselfScreen({super.key});

  @override
  State<AboutYourselfScreen> createState() => _AboutYourselfScreenState();
}

class _AboutYourselfScreenState extends State<AboutYourselfScreen> {
  final _bioCtrl = TextEditingController();
  String _bioError = '';
  final Set<String> _interests = {};
  final Set<String> _languages = {};

  /// Dynamic language list — loaded from REST Countries API based on user's country
  List<String> _availableLanguages = _kLanguagesFallback;

  @override
  void initState() {
    super.initState();
    final data = context.read<OnboardingCubit>().currentData;
    _bioCtrl.text = data.bio ?? '';
    _interests.addAll(data.interests ?? []);
    _languages.addAll(data.languages ?? []);
    _loadDynamicLanguages(data.countryCode);
  }

  /// Fetch real languages from REST Countries for the user's selected country.
  /// Merges with global fallback so user always sees a comprehensive list.
  Future<void> _loadDynamicLanguages(String? countryCode) async {
    if (countryCode == null || countryCode.isEmpty) return;
    try {
      final apiLangs = await CountryContextService.instance.getLanguages(countryCode);
      // Merge: API languages first (country-relevant), then global fallback (deduped)
      final merged = <String>[...apiLangs];
      for (final lang in _kLanguagesFallback) {
        if (!merged.contains(lang)) merged.add(lang);
      }
      if (mounted) setState(() => _availableLanguages = merged);
    } catch (_) {
      // Keep fallback on error
    }
  }

  static const _maxBio       = 300;
  static const _maxInterests = 6;

  bool get _canProceed => _bioError.isEmpty && _bioCtrl.text.trim().isNotEmpty;

  void _showValidation() {
    final missing = <String>[];
    if (_bioCtrl.text.trim().isEmpty) missing.add('Bio');
    if (_bioError.isNotEmpty) missing.add('Fix bio content issue');
    showValidationSnackbar(context, missing);
  }

  @override
  void dispose() {
    _bioCtrl.dispose();
    super.dispose();
  }

  void _onBioChanged(String text) {
    setState(() {
      _bioError = ContentFilter.validate(text) ?? '';
    });
  }

  void _toggleInterest(String tag) {
    setState(() {
      if (_interests.contains(tag)) {
        _interests.remove(tag);
      } else if (_interests.length < _maxInterests) {
        _interests.add(tag);
      }
    });
  }

  void _toggleLanguage(String lang) {
    setState(() {
      if (_languages.contains(lang)) {
        _languages.remove(lang);
      } else {
        _languages.add(lang);
      }
    });
  }

  void _advance() {
    final data = context.read<OnboardingCubit>().currentData.copyWith(
      bio:       _bioCtrl.text.trim(),
      interests: _interests.toList(),
      languages: _languages.toList(),
    );
    context.read<OnboardingCubit>().saveAndAdvance(data);
  }

  void _skip() => context.read<OnboardingCubit>().skipStep();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    String getRelationString() {
      final data = context.read<OnboardingCubit>().currentData;
      final relation = data.profileCreatorRelation ?? 'ward';
      switch (relation) {
        case 'son':
          return l10n.onboarding_profileForWhom_relation_son.toLowerCase();
        case 'daughter':
          return l10n.onboarding_profileForWhom_relation_daughter.toLowerCase();
        case 'brother':
          return l10n.onboarding_profileForWhom_relation_brother.toLowerCase();
        case 'sister':
          return l10n.onboarding_profileForWhom_relation_sister.toLowerCase();
        default:
          return l10n.onboarding_profileForWhom_ward.toLowerCase();
      }
    }

    return BlocBuilder<OnboardingCubit, OnboardingState>(
      builder: (context, state) {
        final isLoading = state is OnboardingLoading;
        final data = context.read<OnboardingCubit>().currentData;
        final isGuardian = data.isGuardianMode;
        return OnboardingScaffold(
          ctaLabel:     l10n.legal_button_continue,
          onCta:        _advance,
          isCtaEnabled: _canProceed,
          isCtaLoading: isLoading,
          onCtaDisabledTap: _showValidation,
          skipLabel:    l10n.about_button_later,
          onSkip:       _skip,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppDimensions.space32),
              StepHeader(
                title:    isGuardian ? l10n.about_title_guardian(getRelationString()) : l10n.about_title_self,
                subtitle: l10n.about_subtitle,
              ),
              const SizedBox(height: AppDimensions.space32),

              // Bio field
              Text(isGuardian ? l10n.about_label_bio_guardian : l10n.about_label_bio_self, style: AppTypography.sectionLabel),
              const SizedBox(height: AppDimensions.space8),
              MithaqTextField(
                controller:      _bioCtrl,
                hint:            isGuardian
                    ? l10n.about_hint_bio_guardian(getRelationString())
                    : l10n.about_hint_bio_self,
                maxLength:       _maxBio,
                maxLines:        5,
                minLines:        4,
                textCapitalization: TextCapitalization.sentences,
                onChanged:       _onBioChanged,
                errorText:       _bioError.isNotEmpty ? _bioError : null,
                showCounter:     true,
              ),

              const SizedBox(height: AppDimensions.space28),

              // Interests
              Row(
                children: [
                  Text(l10n.about_label_interests, style: AppTypography.sectionLabel),
                  const Spacer(),
                  Text(
                    l10n.about_label_selected_count(_interests.length.toString(), _maxInterests.toString()),
                    style: AppTypography.caption.copyWith(
                      color: _interests.length == _maxInterests
                          ? AppColors.champagneGold
                          : AppColors.slateMist,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.space12),

              ..._kInterestCategories.map((cat) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppDimensions.space16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(cat.icon,
                              color: AppColors.slateMist, size: 16),
                          const SizedBox(width: AppDimensions.space6),
                          Text(getLocalizedInterestCategory(context, cat.name).toUpperCase(),
                              style: AppTypography.caption),
                        ],
                      ),
                      const SizedBox(height: AppDimensions.space8),
                      Wrap(
                        spacing:    AppDimensions.space8,
                        runSpacing: AppDimensions.space8,
                        children: cat.tags.map((tag) {
                          final isSel = _interests.contains(tag);
                          final atMax = _interests.length >= _maxInterests && !isSel;
                          return GestureDetector(
                            onTap: atMax ? null : () => _toggleInterest(tag),
                            child: AnimatedContainer(
                              duration: AppDimensions.durationTransition,
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppDimensions.space12,
                                vertical:   AppDimensions.space8,
                              ),
                              decoration: BoxDecoration(
                                color: isSel
                                    ? AppColors.champagneGold.withValues(alpha: 0.12)
                                    : atMax
                                        ? AppColors.surfaceGlass.withValues(alpha: 0.5)
                                        : AppColors.surfaceGlass,
                                borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
                                border: Border.all(
                                  color: isSel
                                      ? AppColors.champagneGold
                                      : AppColors.cardBorder,
                                  width: isSel
                                      ? AppDimensions.borderFocus
                                      : AppDimensions.borderThin,
                                ),
                              ),
                              child: Text(getLocalizedInterestTag(context, tag),
                                  style: AppTypography.chipLabel.copyWith(
                                    color: isSel
                                        ? AppColors.champagneGold
                                        : atMax
                                            ? AppColors.slateMist
                                            : AppColors.pearlWhite,
                                  )),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                );
              }),

              const SizedBox(height: AppDimensions.space8),

              // Languages
              Text(l10n.about_label_languages, style: AppTypography.sectionLabel),
              const SizedBox(height: AppDimensions.space12),
              Wrap(
                spacing:    AppDimensions.space8,
                runSpacing: AppDimensions.space8,
                children: _availableLanguages.map((lang) {
                  final isSel = _languages.contains(lang);
                  return GestureDetector(
                    onTap: () => _toggleLanguage(lang),
                    child: AnimatedContainer(
                      duration: AppDimensions.durationTransition,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.space12,
                        vertical:   AppDimensions.space8,
                      ),
                      decoration: BoxDecoration(
                        color: isSel
                            ? AppColors.verifiedTeal.withValues(alpha: 0.08)
                            : AppColors.surfaceGlass,
                        borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
                        border: Border.all(
                          color: isSel ? AppColors.verifiedTeal : AppColors.cardBorder,
                          width: isSel ? AppDimensions.borderFocus : AppDimensions.borderThin,
                        ),
                      ),
                      child: Text(getLocalizedLanguage(context, lang),
                          style: AppTypography.chipLabel.copyWith(
                            color: isSel
                                ? AppColors.verifiedTeal
                                : AppColors.pearlWhite,
                          )),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: AppDimensions.space32),
            ],
          ),
        );
      },
    );
  }

  String getLocalizedInterestCategory(BuildContext context, String catName) {
    final l10n = AppLocalizations.of(context);
    switch (catName) {
      case 'Faith': return l10n.interest_cat_faith;
      case 'Lifestyle': return l10n.interest_cat_lifestyle;
      case 'Learning': return l10n.interest_cat_learning;
      case 'Creative': return l10n.interest_cat_creative;
      case 'Sports': return l10n.interest_cat_sports;
      case 'Social': return l10n.interest_cat_social;
      default: return catName;
    }
  }

  String getLocalizedInterestTag(BuildContext context, String tagName) {
    final l10n = AppLocalizations.of(context);
    switch (tagName) {
      case 'Quran recitation': return l10n.interest_tag_quran_recitation;
      case 'Islamic lectures': return l10n.interest_tag_islamic_lectures;
      case 'Dawah': return l10n.interest_tag_dawah;
      case 'Voluntary fasting': return l10n.interest_tag_voluntary_fasting;
      case 'Tahajjud': return l10n.interest_tag_tahajjud;
      case 'Umrah/Hajj': return l10n.interest_tag_umrah_hajj;
      case 'Cooking': return l10n.interest_tag_cooking;
      case 'Travel': return l10n.interest_tag_travel;
      case 'Fitness': return l10n.interest_tag_fitness;
      case 'Gardening': return l10n.interest_tag_gardening;
      case 'Volunteering': return l10n.interest_tag_volunteering;
      case 'Photography': return l10n.interest_tag_photography;
      case 'Reading': return l10n.interest_tag_reading;
      case 'Technology': return l10n.interest_tag_technology;
      case 'Science': return l10n.interest_tag_science;
      case 'History': return l10n.interest_tag_history;
      case 'Languages': return l10n.interest_tag_languages;
      case 'Writing': return l10n.interest_tag_writing;
      case 'Calligraphy': return l10n.interest_tag_calligraphy;
      case 'Art': return l10n.interest_tag_art;
      case 'Poetry': return l10n.interest_tag_poetry;
      case 'Graphic design': return l10n.interest_tag_graphic_design;
      case 'Crafts': return l10n.interest_tag_crafts;
      case 'Cricket': return l10n.interest_tag_cricket;
      case 'Football': return l10n.interest_tag_football;
      case 'Swimming': return l10n.interest_tag_swimming;
      case 'Hiking': return l10n.interest_tag_hiking;
      case 'Martial arts': return l10n.interest_tag_martial_arts;
      case 'Cycling': return l10n.interest_tag_cycling;
      case 'Community work': return l10n.interest_tag_community_work;
      case 'Teaching': return l10n.interest_tag_teaching;
      case 'Mentoring': return l10n.interest_tag_mentoring;
      case 'Family gatherings': return l10n.interest_tag_family_gatherings;
      default: return tagName;
    }
  }

  String getLocalizedLanguage(BuildContext context, String langName) {
    final l10n = AppLocalizations.of(context);
    switch (langName) {
      case 'English': return l10n.lang_english;
      case 'Arabic': return l10n.lang_arabic;
      case 'Urdu': return l10n.lang_urdu;
      case 'Hindi': return l10n.lang_hindi;
      case 'Malay': return l10n.lang_malay;
      case 'Indonesian': return l10n.lang_indonesian;
      case 'Turkish': return l10n.lang_turkish;
      case 'French': return l10n.lang_french;
      case 'German': return l10n.lang_german;
      case 'Bengali': return l10n.lang_bengali;
      case 'Punjabi': return l10n.lang_punjabi;
      case 'Tamil': return l10n.lang_tamil;
      case 'Persian': return l10n.lang_persian;
      case 'Swahili': return l10n.lang_swahili;
      case 'Hausa': return l10n.lang_hausa;
      case 'Pashto': return l10n.lang_pashto;
      case 'Sindhi': return l10n.lang_sindhi;
      case 'Somali': return l10n.lang_somali;
      case 'Kurdish': return l10n.lang_kurdish;
      case 'Dari': return l10n.lang_dari;
      case 'Javanese': return l10n.lang_javanese;
      case 'Sundanese': return l10n.lang_sundanese;
      case 'Tagalog': return l10n.lang_tagalog;
      case 'Thai': return l10n.lang_thai;
      case 'Burmese': return l10n.lang_burmese;
      case 'Rohingya': return l10n.lang_rohingya;
      case 'Wolof': return l10n.lang_wolof;
      case 'Fulani': return l10n.lang_fulani;
      case 'Amazigh (Berber)': return l10n.lang_amazigh;
      case 'Mandinka': return l10n.lang_mandinka;
      case 'Uzbek': return l10n.lang_uzbek;
      case 'Kazakh': return l10n.lang_kazakh;
      case 'Tajik': return l10n.lang_tajik;
      case 'Kyrgyz': return l10n.lang_kyrgyz;
      case 'Tatar': return l10n.lang_tatar;
      case 'Bosnian': return l10n.lang_bosnian;
      case 'Albanian': return l10n.lang_albanian;
      case 'Chechen': return l10n.lang_chechen;
      case 'Dutch': return l10n.lang_dutch;
      case 'Swedish': return l10n.lang_swedish;
      case 'Norwegian': return l10n.lang_norwegian;
      case 'Italian': return l10n.lang_italian;
      case 'Spanish': return l10n.lang_spanish;
      case 'Portuguese': return l10n.lang_portuguese;
      case 'Gujarati': return l10n.lang_gujarati;
      case 'Marathi': return l10n.lang_marathi;
      case 'Malayalam': return l10n.lang_malayalam;
      case 'Telugu': return l10n.lang_telugu;
      case 'Kannada': return l10n.lang_kannada;
      case 'Assamese': return l10n.lang_assamese;
      case 'Odia': return l10n.lang_odia;
      case 'Saraiki': return l10n.lang_saraiki;
      case 'Balochi': return l10n.lang_balochi;
      case 'Amharic': return l10n.lang_amharic;
      case 'Tigrinya': return l10n.lang_tigrinya;
      case 'Yoruba': return l10n.lang_yoruba;
      case 'Igbo': return l10n.lang_igbo;
      case 'Chinese (Mandarin)': return l10n.lang_chinese;
      case 'Russian': return l10n.lang_russian;
      case 'Japanese': return l10n.lang_japanese;
      case 'Korean': return l10n.lang_korean;
      case 'Other': return l10n.lang_other;
      default: return langName;
    }
  }
}


