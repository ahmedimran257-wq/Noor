// lib/features/onboarding/screens/language_selection_screen.dart
// ============================================================
// NOOR — Language Selection Screen
//
// First interactive screen after the assalam animation.
// Lets the user pick their preferred language before anything else.
// Persists to LocaleCubit + SharedPreferences.
//
// Flow:
//   AssalamAnimationScreen → (this) → SplashBrandScreen
//
// Shown only once — after selection, skipped forever.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/cubits/locale/locale_cubit.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/buttons/noor_primary_button.dart';
import '../../../core/router/app_router.dart';

// ── Language data ─────────────────────────────────────────────

class _Language {
  const _Language({
    required this.code,
    required this.nativeName,
    required this.englishName,
    required this.isRtl,
    required this.emoji,
  });

  final String code;         // BCP-47 language code
  final String nativeName;   // Name in its own script (large)
  final String englishName;  // English name (small, below)
  final bool   isRtl;
  final String emoji;        // Region flag
}

// ── Language list ─────────────────────────────────────────────

const List<_Language> _kLanguages = [
  _Language(
    code:        'en',
    nativeName:  'English',
    englishName: 'English',
    isRtl:       false,
    emoji:       '🌍',
  ),
  _Language(
    code:        'ar',
    nativeName:  'العربية',
    englishName: 'Arabic',
    isRtl:       true,
    emoji:       '🇸🇦',
  ),
  _Language(
    code:        'ur',
    nativeName:  'اردو',
    englishName: 'Urdu',
    isRtl:       true,
    emoji:       '🇵🇰',
  ),
  _Language(
    code:        'tr',
    nativeName:  'Türkçe',
    englishName: 'Turkish',
    isRtl:       false,
    emoji:       '🇹🇷',
  ),
  _Language(
    code:        'ms',
    nativeName:  'Bahasa Melayu',
    englishName: 'Malay',
    isRtl:       false,
    emoji:       '🇲🇾',
  ),
  _Language(
    code:        'bn',
    nativeName:  'বাংলা',
    englishName: 'Bengali',
    isRtl:       false,
    emoji:       '🇧🇩',
  ),
  _Language(
    code:        'id',
    nativeName:  'Bahasa Indonesia',
    englishName: 'Indonesian',
    isRtl:       false,
    emoji:       '🇮🇩',
  ),
  _Language(
    code:        'fr',
    nativeName:  'Français',
    englishName: 'French',
    isRtl:       false,
    emoji:       '🇫🇷',
  ),
];

// ── Screen ────────────────────────────────────────────────────

class LanguageSelectionScreen extends StatefulWidget {
  const LanguageSelectionScreen({super.key});

  @override
  State<LanguageSelectionScreen> createState() =>
      _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen>
    with SingleTickerProviderStateMixin {

  String _selectedCode = 'en';

  // Entry animation — list slides up from bottom, header fades in.
  late final AnimationController _enterCtrl;
  late final Animation<double>   _headerFade;
  late final Animation<Offset>   _listSlide;
  late final Animation<double>   _listFade;
  late final Animation<double>   _buttonFade;

  @override
  void initState() {
    super.initState();
    _enterCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 700),
    )..forward();

    _headerFade = CurvedAnimation(
      parent: _enterCtrl,
      curve:  const Interval(0.0, 0.5, curve: Curves.easeOut),
    );
    _listSlide = Tween<Offset>(
      begin: const Offset(0.0, 0.08),
      end:   Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _enterCtrl,
        curve:  const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
      ),
    );
    _listFade = CurvedAnimation(
      parent: _enterCtrl,
      curve:  const Interval(0.2, 0.8, curve: Curves.easeOut),
    );
    _buttonFade = CurvedAnimation(
      parent: _enterCtrl,
      curve:  const Interval(0.5, 1.0, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    super.dispose();
  }

  // ── Continue action ───────────────────────────────────────────

  Future<void> _onContinue() async {
    context.read<LocaleCubit>().setLocale(Locale(_selectedCode));
    // Mark intro as completed so it never shows again.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('noor_intro_completed', true);
    if (mounted) context.go(AppRoutes.splash);
  }

  // ── Build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.obsidianNight,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ────────────────────────────────────────
            FadeTransition(
              opacity: _headerFade,
              child: _buildHeader(),
            ),

            // ── Language list ──────────────────────────────────
            Expanded(
              child: SlideTransition(
                position: _listSlide,
                child: FadeTransition(
                  opacity: _listFade,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      AppDimensions.horizontalMargin,
                      0,
                      AppDimensions.horizontalMargin,
                      AppDimensions.space16,
                    ),
                    itemCount:  _kLanguages.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppDimensions.space8),
                    itemBuilder: (context, i) =>
                        _LanguageTile(
                          language:   _kLanguages[i],
                          isSelected: _selectedCode == _kLanguages[i].code,
                          onTap: () => setState(
                            () => _selectedCode = _kLanguages[i].code,
                          ),
                        ),
                  ),
                ),
              ),
            ),

            // ── Continue button ────────────────────────────────
            FadeTransition(
              opacity: _buttonFade,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimensions.horizontalMargin,
                  AppDimensions.space8,
                  AppDimensions.horizontalMargin,
                  AppDimensions.space48,
                ),
                child: NoorPrimaryButton(
                  label: 'Continue',
                  onTap: _onContinue,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.horizontalMargin,
        AppDimensions.space32,
        AppDimensions.horizontalMargin,
        AppDimensions.space28,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Subtle نور mark above the title
          Text(
            'نور',
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontSize:      22,
              fontWeight:    FontWeight.w700,
              color:         AppColors.champagneGold.withValues(alpha: 0.85),
              shadows: [
                Shadow(
                  color:      AppColors.champagneGold.withValues(alpha: 0.45),
                  blurRadius: 14,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.space12),
          Text(
            'Choose your\nlanguage',
            style: AppTypography.screenTitle.copyWith(
              height:      1.15,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: AppDimensions.space8),
          Text(
            'You can change this at any time in settings.',
            style: AppTypography.caption,
          ),
          const SizedBox(height: AppDimensions.space20),
          // Gold divider line
          Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.champagneGold.withValues(alpha: 0.6),
                  AppColors.champagneGold.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Language Tile ─────────────────────────────────────────────

class _LanguageTile extends StatelessWidget {
  const _LanguageTile({
    required this.language,
    required this.isSelected,
    required this.onTap,
  });

  final _Language language;
  final bool      isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve:    Curves.easeOutCubic,
      decoration: BoxDecoration(
        color:        isSelected
            ? AppColors.champagneGold.withValues(alpha: 0.08)
            : AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
        border:       Border.all(
          color: isSelected
              ? AppColors.champagneGold.withValues(alpha: 0.55)
              : AppColors.cardBorder,
          width: isSelected ? 1.5 : 1.0,
        ),
      ),
      child: Material(
        color:        Colors.transparent,
        borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
        child: InkWell(
          onTap:        onTap,
          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          splashColor:  AppColors.goldGlow,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.space16,
              vertical:   AppDimensions.space14,
            ),
            child: Row(
              children: [
                // Emoji flag
                Text(
                  language.emoji,
                  style: const TextStyle(fontSize: 24),
                ),

                const SizedBox(width: AppDimensions.space16),

                // Names
                Expanded(
                  child: Column(
                    crossAxisAlignment: language.isRtl
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        language.nativeName,
                        textDirection: language.isRtl
                            ? TextDirection.rtl
                            : TextDirection.ltr,
                        style: TextStyle(
                          fontSize:   18,
                          fontWeight: FontWeight.w600,
                          color:      isSelected
                              ? AppColors.champagneGold
                              : AppColors.pearlWhite,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        language.englishName,
                        style: AppTypography.caption.copyWith(
                          color: isSelected
                              ? AppColors.champagneGold.withValues(alpha: 0.75)
                              : AppColors.slateMist,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: AppDimensions.space12),

                // Selection indicator
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: isSelected
                      ? _SelectedCheck(key: const ValueKey('check'))
                      : const SizedBox(
                          key:    ValueKey('empty'),
                          width:  22,
                          height: 22,
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Animated gold checkmark for selected state
class _SelectedCheck extends StatelessWidget {
  const _SelectedCheck({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width:  22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.champagneGold,
      ),
      child: const Icon(
        Icons.check_rounded,
        size:  14,
        color: Color(0xFF0A0A0F), // obsidianNight
      ),
    );
  }
}
