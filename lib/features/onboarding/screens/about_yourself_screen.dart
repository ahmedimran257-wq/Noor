// lib/features/onboarding/screens/about_yourself_screen.dart
// ============================================================
// NOOR — About Yourself Screen (Onboarding Step 6)
// Bio (300 chars with content filter), interests (max 6), languages.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/cubits/onboarding/onboarding_cubit.dart';
import '../../../core/cubits/onboarding/onboarding_state.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/inputs/noor_text_field.dart';
import '../widgets/onboarding_scaffold.dart';
import '../widgets/step_header.dart';

// ── Content filter ────────────────────────────────────────────
class _ContentFilter {
  static final _phone  = RegExp(r'(\+?\d[\d\s\-]{7,}\d)');
  static final _email  = RegExp(r'[\w.+-]+@[\w-]+\.[\w.]+');
  static final _url    = RegExp(r'(https?://|www\.)\S+');
  static final _social = RegExp(
    r'(@[\w.]+|(?:instagram|insta|snap|snapchat|whatsapp|telegram|'
    r'facebook|fb|twitter|tiktok|linkedin)[\s.:/@]*[\w.]+)',
    caseSensitive: false,
  );

  static String? validate(String text) {
    if (_phone.hasMatch(text))  return 'Phone numbers cannot be shared in the bio.';
    if (_email.hasMatch(text))  return 'Email addresses cannot be shared in the bio.';
    if (_url.hasMatch(text))    return 'External links cannot be shared in the bio.';
    if (_social.hasMatch(text)) return 'Social media handles cannot be shared in the bio.';
    return null;
  }
}

// ── Interest categories ───────────────────────────────────────
const _kInterestCategories = [
  (name: 'Faith',     icon: Icons.mosque_outlined,     tags: ['Quran recitation', 'Islamic lectures', 'Dawah', 'Voluntary fasting', 'Tahajjud', 'Umrah/Hajj']),
  (name: 'Lifestyle', icon: Icons.spa_outlined,         tags: ['Cooking', 'Travel', 'Fitness', 'Gardening', 'Volunteering', 'Photography']),
  (name: 'Learning',  icon: Icons.auto_stories_outlined, tags: ['Reading', 'Technology', 'Science', 'History', 'Languages', 'Writing']),
  (name: 'Creative',  icon: Icons.palette_outlined,      tags: ['Calligraphy', 'Art', 'Poetry', 'Graphic design', 'Crafts']),
  (name: 'Sports',    icon: Icons.sports_soccer_outlined, tags: ['Cricket', 'Football', 'Swimming', 'Hiking', 'Martial arts', 'Cycling']),
  (name: 'Social',    icon: Icons.volunteer_activism_outlined, tags: ['Community work', 'Teaching', 'Mentoring', 'Family gatherings']),
];

const _kLanguages = [
  'English', 'Arabic', 'Urdu', 'Hindi', 'Malay', 'Indonesian',
  'Turkish', 'French', 'German', 'Bengali', 'Punjabi', 'Tamil',
  'Persian', 'Swahili', 'Hausa', 'Pashto', 'Sindhi',
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

  static const _maxBio       = 300;
  static const _maxInterests = 6;

  bool get _canProceed => _bioError.isEmpty && _bioCtrl.text.trim().isNotEmpty;

  @override
  void dispose() {
    _bioCtrl.dispose();
    super.dispose();
  }

  void _onBioChanged(String text) {
    setState(() {
      _bioError = _ContentFilter.validate(text) ?? '';
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

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OnboardingCubit, OnboardingState>(
      builder: (context, state) {
        final isLoading = state is OnboardingLoading;
        return OnboardingScaffold(
          step:         6,
          ctaLabel:     'Continue',
          onCta:        _advance,
          isCtaEnabled: _canProceed,
          isCtaLoading: isLoading,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppDimensions.space32),
              const StepHeader(
                title:    'About you',
                subtitle: 'Write with honesty and dignity.',
              ),
              const SizedBox(height: AppDimensions.space32),

              // Bio field
              Text('YOUR BIO', style: AppTypography.sectionLabel),
              const SizedBox(height: AppDimensions.space8),
              NoorTextField(
                controller:      _bioCtrl,
                hint:            'Describe yourself with honesty and dignity.',
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
                  Text('INTERESTS', style: AppTypography.sectionLabel),
                  const Spacer(),
                  Text(
                    '${_interests.length}/$_maxInterests selected',
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
                          Text(cat.name.toUpperCase(),
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
                              child: Text(tag,
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
              Text('LANGUAGES SPOKEN', style: AppTypography.sectionLabel),
              const SizedBox(height: AppDimensions.space12),
              Wrap(
                spacing:    AppDimensions.space8,
                runSpacing: AppDimensions.space8,
                children: _kLanguages.map((lang) {
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
                      child: Text(lang,
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
}


