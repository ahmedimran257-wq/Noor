// lib/features/onboarding/screens/language_selection_screen.dart
// ============================================================
// MITHAQ — Language Selection Screen
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
import '../../../core/widgets/buttons/mithaq_primary_button.dart';
import '../../../core/widgets/buttons/mithaq_pressable.dart';
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

  final String code; // BCP-47 language code
  final String nativeName; // Name in its own script (large)
  final String englishName; // English name (small, below)
  final bool isRtl;
  final String emoji; // Region flag
}

// ── Language list ─────────────────────────────────────────────
// Comprehensive list of ALL languages present across the app's
// 75+ country demographics. Sorted by global Muslim-speaker count.

const List<_Language> _kLanguages = [
  // ── Global / Major ─────────────────────────────────────
  _Language(
      code: 'ar',
      nativeName: 'العربية',
      englishName: 'Arabic',
      isRtl: true,
      emoji: '🇸🇦'),
  _Language(
      code: 'en',
      nativeName: 'English',
      englishName: 'English',
      isRtl: false,
      emoji: '🌍'),
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
  String _searchQuery = '';

  /// Filtered languages based on search query.
  List<_Language> get _filteredLanguages {
    if (_searchQuery.isEmpty) return _kLanguages;
    final q = _searchQuery.toLowerCase();
    return _kLanguages
        .where((lang) =>
            lang.nativeName.toLowerCase().contains(q) ||
            lang.englishName.toLowerCase().contains(q) ||
            lang.code.toLowerCase().contains(q))
        .toList();
  }

  // Entry animation — list slides up from bottom, header fades in.
  late final AnimationController _enterCtrl;
  late final Animation<double> _headerFade;
  late final Animation<Offset> _listSlide;
  late final Animation<double> _listFade;
  late final Animation<double> _buttonFade;

  @override
  void initState() {
    super.initState();
    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();

    _headerFade = CurvedAnimation(
      parent: _enterCtrl,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    );
    _listSlide = Tween<Offset>(
      begin: const Offset(0.0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _enterCtrl,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
      ),
    );
    _listFade = CurvedAnimation(
      parent: _enterCtrl,
      curve: const Interval(0.2, 0.8, curve: Curves.easeOut),
    );
    _buttonFade = CurvedAnimation(
      parent: _enterCtrl,
      curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _enterCtrl.dispose();
    super.dispose();
  }

  final TextEditingController _searchController = TextEditingController();

  // ── Continue action ───────────────────────────────────────────

  Future<void> _onContinue() async {
    context.read<LocaleCubit>().setLocale(Locale(_selectedCode));
    // Mark intro as completed so it never shows again.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('mithaq_intro_completed', true);
    if (mounted) context.go(AppRoutes.splash);
  }

  // ── Build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.5), // slightly above center
            radius: 1.2,
            colors: [
              AppColors.navyCharcoal, // Deep premium navy-charcoal core
              AppColors.obsidianNight, // Deep midnight edges
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ── Header ────────────────────────────────────────
              FadeTransition(
                opacity: _headerFade,
                child: _buildHeader(),
              ),

              // ── Search bar ─────────────────────────────────────
              FadeTransition(
                opacity: _listFade,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimensions.horizontalMargin,
                    0,
                    AppDimensions.horizontalMargin,
                    AppDimensions.space12,
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    onTapOutside: (_) =>
                        FocusManager.instance.primaryFocus?.unfocus(),
                    style: const TextStyle(
                      color: AppColors.pearlWhite,
                      fontSize: 15,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search languages...',
                      hintStyle: TextStyle(
                        color: AppColors.slateMist.withValues(alpha: 0.6),
                        fontSize: 15,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: AppColors.slateMist.withValues(alpha: 0.6),
                        size: 20,
                      ),
                      filled: true,
                      fillColor: AppColors.surfaceGlass,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusButton),
                        borderSide:
                            const BorderSide(color: AppColors.cardBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusButton),
                        borderSide:
                            const BorderSide(color: AppColors.cardBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusButton),
                        borderSide: BorderSide(
                          color: AppColors.champagneGold.withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
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
                      itemCount: _filteredLanguages.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppDimensions.space8),
                      itemBuilder: (context, i) {
                        final lang = _filteredLanguages[i];
                        return _LanguageTile(
                          language: lang,
                          isSelected: _selectedCode == lang.code,
                          onTap: () => setState(
                            () => _selectedCode = lang.code,
                          ),
                        );
                      },
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
                  child: MithaqPrimaryButton(
                    label: 'Continue',
                    onTap: _onContinue,
                  ),
                ),
              ),
            ],
          ),
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
          // Subtle ميثاق mark above the title
          Text(
            'ميثاق',
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.champagneGold.withValues(alpha: 0.85),
              shadows: [
                Shadow(
                  color: AppColors.champagneGold.withValues(alpha: 0.45),
                  blurRadius: 14,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.space12),
          Text(
            'Choose your\nlanguage',
            style: AppTypography.screenTitle.copyWith(
              height: 1.15,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: AppDimensions.space8),
          const Text(
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
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.champagneGold.withValues(alpha: 0.08)
            : AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
        border: Border.all(
          color: isSelected
              ? AppColors.champagneGold.withValues(alpha: 0.55)
              : AppColors.cardBorder,
          width: isSelected ? 1.5 : 1.0,
        ),
      ),
      child: MithaqPressable(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.space16,
            vertical: AppDimensions.space14,
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
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: isSelected
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
                    ? const _SelectedCheck(key: ValueKey('check'))
                    : const SizedBox(
                        key: ValueKey('empty'),
                        width: 22,
                        height: 22,
                      ),
              ),
            ],
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
      width: 22,
      height: 22,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.champagneGold,
      ),
      child: const Icon(
        Icons.check_rounded,
        size: 14,
        color: Color(0xFF0A0A0F), // obsidianNight
      ),
    );
  }
}
