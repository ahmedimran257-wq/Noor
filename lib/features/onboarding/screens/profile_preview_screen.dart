// lib/features/onboarding/screens/profile_preview_screen.dart
// ============================================================
// NOOR — Profile Preview Screen (Onboarding Step 9)
// Read-only rendering of the full profile as others will see it.
// Tappable "Edit" labels navigate back to specific steps.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/cubits/onboarding/onboarding_cubit.dart';
import '../../../core/cubits/onboarding/onboarding_state.dart';
import '../../../core/models/onboarding_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/buttons/noor_primary_button.dart';
import '../../../l10n/generated/app_localizations.dart';

class ProfilePreviewScreen extends StatelessWidget {
  const ProfilePreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocBuilder<OnboardingCubit, OnboardingState>(
      builder: (context, state) {
        final cubit    = context.read<OnboardingCubit>();
        final data     = cubit.currentData;
        final isLoading = state is OnboardingLoading;
        final isGuardian = data.isGuardianMode;

        String getLocalizedLanguage(BuildContext context, String langName) {
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

        String getLocalizedInterestTag(BuildContext context, String tagName) {
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

        String getLocalizedHijab(AppLocalizations l10n, String raw) {
          switch (raw) {
            case 'Always': return l10n.onboarding_hijab_always;
            case 'Sometimes': return l10n.onboarding_hijab_sometimes;
            case 'No': return l10n.onboarding_hijab_no;
            case 'Prefer not to say': return l10n.onboarding_label_preferNotToSay;
            default: return raw;
          }
        }

        String getLocalizedHabit(AppLocalizations l10n, String raw) {
          switch (raw) {
            case 'Never': return l10n.onboarding_habit_never;
            case 'Occasionally': return l10n.onboarding_habit_occasionally;
            case 'Frequently': return l10n.onboarding_habit_frequently;
            case 'Prefer not to say': return l10n.onboarding_habit_preferNotToSay;
            default: return raw;
          }
        }

        return Scaffold(
          backgroundColor: AppColors.obsidianNight,
          body: SafeArea(
            child: Column(
              children: [
                // ── Header ─────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimensions.space24,
                    AppDimensions.space20,
                    AppDimensions.space24,
                    0,
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => cubit.goBack(),
                        child: Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color:  AppColors.surfaceGlass,
                            shape:  BoxShape.circle,
                            border: Border.all(color: AppColors.cardBorder),
                          ),
                          child: Icon(
                            Directionality.of(context) == TextDirection.rtl
                                ? Icons.arrow_forward_ios_rounded
                                : Icons.arrow_back_ios_new_rounded,
                            color: AppColors.pearlWhite,
                            size:  16,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(l10n.preview_title, style: AppTypography.wordmark.copyWith(
                        fontSize: 18,
                      )),
                      const Spacer(),
                      const SizedBox(width: 40),
                    ],
                  ),
                ),

                // ── Scrollable profile ─────────────────────
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.space24,
                      vertical:   AppDimensions.space24,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Photo card mock
                        _PhotoPreviewCard(data: data),
                        const SizedBox(height: AppDimensions.space24),

                        // Sections
                        _PreviewSection(
                          title:   l10n.preview_basic_info,
                          editStep: 1,
                          rows: [
                            _PreviewRow(l10n.preview_name_label,      data.displayName.isNotEmpty ? data.displayName : '—'),
                            _PreviewRow(l10n.preview_age_label,       data.age?.toString() ?? '—'),
                            _PreviewRow(l10n.preview_city_label,      data.cityName ?? '—'),
                            _PreviewRow(l10n.preview_gender_label,    data.gender == Gender.male ? l10n.onboarding_label_male : l10n.onboarding_label_female),
                            if (data.community != null)
                              _PreviewRow(l10n.preview_community_label, data.community!),
                            if (data.motherTongue != null)
                              _PreviewRow(l10n.preview_mother_tongue_label, getLocalizedLanguage(context, data.motherTongue!)),
                            if (data.residencyStatus != null)
                              _PreviewRow(l10n.preview_residency_label, _getLocalizedResidency(l10n, data.residencyStatus!)),
                            if (data.specialNeeds != null && data.specialNeeds != 'none')
                              _PreviewRow(l10n.preview_special_needs_label, _getLocalizedSpecialNeeds(l10n, data.specialNeeds!)),
                          ],
                        ),
                        const SizedBox(height: AppDimensions.space16),

                        _PreviewSection(
                          title:   l10n.preview_faith,
                          editStep: 2,
                          rows: [
                            _PreviewRow(l10n.preview_sect_label,       _sectLabel(l10n, data.sect)),
                            _PreviewRow(l10n.preview_deen_label, _deenLabel(l10n, data.deenLevel)),
                            if (data.isRevert != null && data.isRevert != 'no')
                              _PreviewRow(l10n.preview_revert_label, data.isRevert == 'yes' ? (l10n.localeName == 'ar' ? 'نعم' : 'Yes') : (l10n.localeName == 'ar' ? 'أفضل عدم الإجابة' : 'Prefer not to say')),
                            _PreviewRow(l10n.preview_prays_label,   data.praysFiveDaily == null ? '—'
                                : (data.praysFiveDaily! ? (l10n.localeName == 'ar' ? 'نعم' : 'Yes') : (l10n.localeName == 'ar' ? 'لا' : 'No'))),
                            if (data.gender == Gender.female)
                              _PreviewRow(l10n.preview_hijab_label, data.hijabStyle == null ? '—' : getLocalizedHijab(l10n, data.hijabStyle!)),
                            if (data.quranMemorization != null)
                              _PreviewRow(l10n.preview_quran_label, _quranLabel(l10n, data.quranMemorization!)),
                            if (data.religiousEducation != null)
                              _PreviewRow(l10n.preview_religious_edu_label, _religiousEduLabel(l10n, data.religiousEducation!)),
                            if (data.gender == Gender.male && data.religiousLeadership != null)
                              _PreviewRow(l10n.preview_leadership_label, _leadershipLabel(l10n, data.religiousLeadership!)),
                            if (data.dietType != null)
                              _PreviewRow(l10n.preview_diet_label, _dietLabel(l10n, data.dietType!)),
                            if (data.smokingHabit != null)
                              _PreviewRow(l10n.preview_smoking_label, getLocalizedHabit(l10n, data.smokingHabit!)),
                            if (data.vapingHabit != null)
                              _PreviewRow(l10n.preview_vaping_label, getLocalizedHabit(l10n, data.vapingHabit!)),
                            if (data.hookahHabit != null)
                              _PreviewRow(l10n.preview_hookah_label, getLocalizedHabit(l10n, data.hookahHabit!)),
                          ],
                        ),
                        const SizedBox(height: AppDimensions.space16),

                        _PreviewSection(
                          title:   l10n.preview_background,
                          editStep: 4,
                          rows: [
                            _PreviewRow(l10n.preview_education_label, data.educationLabel == null ? '—' : getLocalizedEducation(l10n, data.educationLabel!)),
                            _PreviewRow(l10n.preview_profession_label, data.profession ?? '—'),
                          ],
                        ),
                        const SizedBox(height: AppDimensions.space16),

                        _PreviewSection(
                          title:   l10n.preview_family,
                          editStep: 5,
                          rows: [
                            _PreviewRow(l10n.preview_family_type_label, _familyLabel(l10n, data.familyType)),
                            _PreviewRow(l10n.preview_siblings_label,    data.siblingCount?.toString() ?? '—'),
                            _PreviewRow(l10n.preview_marital_label,     _maritalLabel(l10n, data.maritalStatus)),
                            if (data.livingExpectation != null)
                              _PreviewRow(l10n.preview_post_marriage_living_label, _livingLabel(l10n, data.livingExpectation!)),
                            if (data.willingToRelocate != null)
                              _PreviewRow(l10n.preview_willing_relocate_label, _relocateLabel(l10n, data.willingToRelocate!)),
                            if (data.marriageTimeline != null)
                              _PreviewRow(l10n.preview_marriage_timeline_label, _timelineLabel(l10n, data.marriageTimeline!)),
                            if (data.gender == Gender.male && data.polygamyStatus != null)
                              _PreviewRow(l10n.preview_polygamy_label, _polygamyLabel(l10n, data.polygamyStatus!)),
                            if (data.gender == Gender.female && data.polygamyAcceptance != null)
                              _PreviewRow(l10n.preview_cowife_label, _cowifeLabel(l10n, data.polygamyAcceptance!)),
                          ],
                        ),
                        const SizedBox(height: AppDimensions.space16),

                        if (data.bio != null && data.bio!.isNotEmpty) ...[
                          _SectionHeader(title: l10n.localeName == 'ar' ? 'النبذة الشخصية' : 'Bio', editStep: 6, context: context),
                          const SizedBox(height: AppDimensions.space8),
                          Text(data.bio!, style: AppTypography.bio),
                          const SizedBox(height: AppDimensions.space16),
                        ],

                        if (data.interests != null && data.interests!.isNotEmpty) ...[
                          Text(l10n.about_label_interests, style: AppTypography.sectionLabel),
                          const SizedBox(height: AppDimensions.space8),
                          Wrap(
                            spacing:    AppDimensions.space6,
                            runSpacing: AppDimensions.space6,
                            children: data.interests!.map((tag) =>
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppDimensions.space12,
                                  vertical:   AppDimensions.space6,
                                ),
                                decoration: BoxDecoration(
                                  color:        AppColors.surfaceGlass,
                                  borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
                                  border:       Border.all(color: AppColors.cardBorder),
                                ),
                                child: Text(getLocalizedInterestTag(context, tag), style: AppTypography.chipLabel),
                              ),
                            ).toList(),
                          ),
                          const SizedBox(height: AppDimensions.space24),
                        ],

                        // Notice
                        Container(
                          padding: const EdgeInsets.all(AppDimensions.space16),
                          decoration: BoxDecoration(
                            color:        AppColors.surfaceGlass,
                            borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                            border:       Border.all(color: AppColors.cardBorder),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.visibility_outlined,
                                  color: AppColors.slateMist, size: 18),
                              const SizedBox(width: AppDimensions.space12),
                              Expanded(
                                child: Text(
                                  isGuardian ? l10n.preview_notice_guardian : l10n.preview_notice_self,
                                  style: AppTypography.caption,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppDimensions.space32),
                      ],
                    ),
                  ),
                ),

                // ── CTA ────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimensions.space24,
                    AppDimensions.space16,
                    AppDimensions.space24,
                    AppDimensions.space32,
                  ),
                  child: NoorPrimaryButton(
                    label:     l10n.preview_submit_btn,
                    isLoading: isLoading,
                    onTap:     isLoading ? null : () => cubit.saveAndAdvance(data),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _sectLabel(AppLocalizations l10n, Sect? s) {
    switch (s) {
      case Sect.sunni:          return l10n.onboarding_label_sunni;
      case Sect.shia:           return l10n.onboarding_label_shia;
      case Sect.preferNotToSay: return l10n.onboarding_label_preferNotToSay;
      case Sect.other:          return l10n.localeName == 'ar' ? 'أخرى' : 'Other';
      case null:                return '—';
    }
  }

  String _deenLabel(AppLocalizations l10n, DeenLevel? d) {
    switch (d) {
      case DeenLevel.practicing: return l10n.onboarding_label_practicing;
      case DeenLevel.moderate:   return l10n.onboarding_label_moderate;
      case DeenLevel.cultural:   return l10n.onboarding_label_cultural;
      case null:                 return '—';
    }
  }

  String _familyLabel(AppLocalizations l10n, FamilyType? f) {
    switch (f) {
      case FamilyType.nuclear:  return l10n.family_type_nuclear;
      case FamilyType.joint:    return l10n.family_type_joint;
      case FamilyType.extended: return l10n.family_type_extended;
      case null:                return '—';
    }
  }

  String _maritalLabel(AppLocalizations l10n, MaritalStatus? m) {
    switch (m) {
      case MaritalStatus.neverMarried:
        return l10n.localeName == 'ar' ? 'لم يسبق له الزواج' : 'Never married';
      case MaritalStatus.divorced:
        return l10n.family_prev_divorced;
      case MaritalStatus.widowed:
        return l10n.family_prev_widowed;
      case null:
        return '—';
    }
  }

  String _dietLabel(AppLocalizations l10n, String code) {
    switch (code) {
      case 'zabiha_strict':  return l10n.onboarding_diet_zabihaStrict;
      case 'halal_only':     return l10n.onboarding_diet_halalOnly;
      case 'eats_anything':  return l10n.onboarding_diet_eatsAnything;
      case 'vegetarian':     return l10n.onboarding_diet_vegetarian;
      case 'vegan':          return l10n.onboarding_diet_vegan;
      default:               return code;
    }
  }

  String _livingLabel(AppLocalizations l10n, String code) {
    switch (code) {
      case 'with_inlaws':        return l10n.onboarding_living_withInlaws;
      case 'separate':           return l10n.onboarding_living_separate;
      case 'open_to_discussion': return l10n.onboarding_living_openToDiscussion;
      default:                   return code;
    }
  }

  String _quranLabel(AppLocalizations l10n, String code) {
    if (l10n.localeName == 'ar') {
      switch (code) {
        case 'none': return 'لا يوجد';
        case 'some_surahs': return 'بعض السور';
        case 'partial': return 'حفظ جزئي';
        case 'hafiz': return 'حافظ للقرآن';
      }
    }
    switch (code) {
      case 'none':        return 'None';
      case 'some_surahs': return 'Some Surahs';
      case 'partial':     return 'Partial';
      case 'hafiz':       return 'Hafiz';
      default:            return code;
    }
  }

  String _religiousEduLabel(AppLocalizations l10n, String code) {
    if (l10n.localeName == 'ar') {
      switch (code) {
        case 'self_taught': return 'تعليم ذاتي';
        case 'madrasa': return 'مدرسة دينية';
        case 'islamic_uni': return 'جامعة إسلامية';
        case 'alim_course': return 'دورة عالم';
        case 'none': return 'لا يوجد';
      }
    }
    switch (code) {
      case 'self_taught':   return 'Self-taught';
      case 'madrasa':       return 'Madrasa';
      case 'islamic_uni':   return 'Islamic University';
      case 'alim_course':   return 'Alim Course';
      case 'none':          return 'None';
      default:              return code;
    }
  }

  String _leadershipLabel(AppLocalizations l10n, String code) {
    if (l10n.localeName == 'ar') {
      switch (code) {
        case 'leads_prayer': return 'يؤم المصلين';
        case 'learning': return 'يتعلم';
        case 'not_yet': return 'ليس بعد';
        case 'prefer_not_to_say': return 'أفضل عدم الإجابة';
      }
    }
    switch (code) {
      case 'leads_prayer':      return 'Leads Prayer';
      case 'learning':          return 'Learning';
      case 'not_yet':           return 'Not Yet';
      case 'prefer_not_to_say': return 'Prefer Not to Say';
      default:                  return code;
    }
  }

  String _relocateLabel(AppLocalizations l10n, String code) {
    switch (code) {
      case 'yes':                return l10n.family_relocate_yes;
      case 'no':                 return l10n.family_relocate_no;
      case 'open_to_discussion': return l10n.family_relocate_discussion;
      default:                   return code;
    }
  }

  String _timelineLabel(AppLocalizations l10n, String code) {
    if (l10n.localeName == 'ar') {
      switch (code) {
        case 'asap': return 'في أقرب وقت ممكن';
        case '6_months': return 'خلال ٦ أشهر';
        case '1_year': return 'خلال سنة';
        case '2_plus_years': return 'سنتين أو أكثر';
        case 'not_sure': return 'غير متأكد بعد';
      }
    }
    switch (code) {
      case 'asap':          return 'As soon as possible';
      case '6_months':      return 'Within 6 months';
      case '1_year':        return 'Within a year';
      case '2_plus_years':  return '2+ years';
      case 'not_sure':      return 'Not sure yet';
      default:              return code;
    }
  }

  String _polygamyLabel(AppLocalizations l10n, String code) {
    if (l10n.localeName == 'ar') {
      switch (code) {
        case 'No, this is my first': return 'لا، هذا زواجي الأول';
        case 'Yes, currently married': return 'نعم، متزوج حالياً';
        case 'Prefer not to say': return 'أفضل عدم الإجابة';
      }
    }
    return code;
  }

  String _cowifeLabel(AppLocalizations l10n, String code) {
    if (l10n.localeName == 'ar') {
      switch (code) {
        case 'Yes': return 'نعم';
        case 'No': return 'لا';
        case 'Open to discussion': return 'قابل للنقاش';
        case 'Prefer not to say': return 'أفضل عدم الإجابة';
      }
    }
    return code;
  }

  String getLocalizedEducation(AppLocalizations l10n, String raw) {
    switch (raw) {
      case "Below Secondary": return l10n.background_edu_below_secondary;
      case "Secondary / O-Level": return l10n.background_edu_secondary;
      case "Higher Secondary / A-Level": return l10n.background_edu_higher_secondary;
      case "Diploma / Associate": return l10n.background_edu_diploma;
      case "Bachelor's Degree": return l10n.background_edu_bachelors;
      case "Master's Degree": return l10n.background_edu_masters;
      case "Doctorate / PhD": return l10n.background_edu_doctorate;
      default: return raw;
    }
  }

  String _getLocalizedResidency(AppLocalizations l10n, String raw) {
    if (l10n.localeName == 'ar') {
      switch (raw) {
        case 'Citizen': return 'مواطن';
        case 'Permanent Resident': return 'مقيم دائم';
        case 'Work Visa': return 'تأشيرة عمل';
        case 'Student Visa': return 'تأشيرة طالب';
        case 'Other': return 'أخرى';
        case 'Prefer not to say': return 'أفضل عدم الإجابة';
      }
    }
    return raw;
  }

  String _getLocalizedSpecialNeeds(AppLocalizations l10n, String raw) {
    if (l10n.localeName == 'ar') {
      switch (raw) {
        case 'None': return 'لا يوجد';
        case 'Physical disability': return 'إعاقة جسدية';
        case 'Hearing impairment': return 'ضعف السمع';
        case 'Visual impairment': return 'ضعف البصر';
        case 'Other': return 'أخرى';
        case 'Prefer not to say': return 'أفضل عدم الإجابة';
      }
    }
    return raw;
  }
}

// ── Sub-widgets ───────────────────────────────────────────────

class _PhotoPreviewCard extends StatelessWidget {
  const _PhotoPreviewCard({required this.data});
  final OnboardingData data;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hasPhoto = data.photoLocalPaths?.isNotEmpty == true;
    return AspectRatio(
      aspectRatio: 3 / 4,
      child: Container(
        decoration: BoxDecoration(
          color:        AppColors.surfaceGlass,
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
          border:       Border.all(color: AppColors.cardBorder),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end:   Alignment.bottomCenter,
            colors: [Color(0xFF1A1A2F), Color(0xFF0A0A0F)],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: Icon(
                hasPhoto ? Icons.check_circle_outline : Icons.person_outline_rounded,
                color: hasPhoto ? AppColors.verifiedTeal : AppColors.slateMist,
                size:  80,
              ),
            ),
            Positioned(
              left: 20, right: 20, bottom: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    data.displayName.isNotEmpty ? data.displayName : (data.isGuardianMode ? (l10n.localeName == 'ar' ? 'الاسم' : 'Their Name') : (l10n.localeName == 'ar' ? 'اسمك' : 'Your Name')),
                    style: AppTypography.userName,
                  ),
                  if (data.age != null && data.cityName != null)
                    Text(
                      '${data.age} · ${data.cityName}',
                      style: AppTypography.cardLocation,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.editStep,
    required this.context,
  });
  final String title;
  final int editStep;
  final BuildContext context;

  @override
  Widget build(BuildContext _) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Text(title.toUpperCase(), style: AppTypography.sectionLabel),
        const Spacer(),
        GestureDetector(
          onTap: () {
            // In production: navigate back to editStep
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.localeName == 'ar' ? 'انتقال إلى الخطوة $editStep' : 'Navigate to step $editStep'),
                backgroundColor: AppColors.surfaceGlassHover,
                duration: const Duration(seconds: 1),
              ),
            );
          },
          child: Text(
            l10n.preview_edit,
            style: AppTypography.caption.copyWith(
              color: AppColors.champagneGold,
            ),
          ),
        ),
      ],
    );
  }
}

class _PreviewSection extends StatelessWidget {
  const _PreviewSection({
    required this.title,
    required this.editStep,
    required this.rows,
  });
  final String title;
  final int editStep;
  final List<_PreviewRow> rows;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(
        color:        AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
        border:       Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: [
          // Section header
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimensions.space16,
              AppDimensions.space12,
              AppDimensions.space16,
              AppDimensions.space12,
            ),
            child: Row(
              children: [
                Text(title.toUpperCase(), style: AppTypography.sectionLabel),
                const Spacer(),
                GestureDetector(
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        l10n.localeName == 'ar'
                            ? 'تعديل $title'
                            : 'Edit $title',
                      ),
                      backgroundColor: AppColors.surfaceGlassHover,
                      duration: const Duration(seconds: 1),
                    ),
                  ),
                  child: Text(
                    l10n.preview_edit,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.champagneGold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 1,
            color: AppColors.divider,
          ),

          // Rows
          ...rows.map((row) => Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.space16,
              vertical:   AppDimensions.space12,
            ),
            child: Row(
              children: [
                Text(row.label, style: AppTypography.bodyMuted),
                const Spacer(),
                Text(row.value, style: AppTypography.bodyMedium),
              ],
            ),
          )),
        ],
      ),
    );
  }
}

class _PreviewRow {
  const _PreviewRow(this.label, this.value);
  final String label;
  final String value;
}
