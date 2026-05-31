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
// Comprehensive list of ALL languages present across the app's
// 75+ country demographics. Sorted by global Muslim-speaker count.

const List<_Language> _kLanguages = [
  // ── Global / Major ─────────────────────────────────────
  _Language(code: 'ar', nativeName: 'العربية',           englishName: 'Arabic',               isRtl: true,  emoji: '🇸🇦'),
  _Language(code: 'en', nativeName: 'English',            englishName: 'English',              isRtl: false, emoji: '🌍'),
  _Language(code: 'ur', nativeName: 'اردو',               englishName: 'Urdu',                 isRtl: true,  emoji: '🇵🇰'),
  _Language(code: 'hi', nativeName: 'हिन्दी',               englishName: 'Hindi',                isRtl: false, emoji: '🇮🇳'),
  _Language(code: 'bn', nativeName: 'বাংলা',               englishName: 'Bengali',              isRtl: false, emoji: '🇧🇩'),
  _Language(code: 'id', nativeName: 'Bahasa Indonesia',   englishName: 'Indonesian',           isRtl: false, emoji: '🇮🇩'),
  _Language(code: 'ms', nativeName: 'Bahasa Melayu',      englishName: 'Malay',                isRtl: false, emoji: '🇲🇾'),
  _Language(code: 'tr', nativeName: 'Türkçe',             englishName: 'Turkish',              isRtl: false, emoji: '🇹🇷'),
  _Language(code: 'fa', nativeName: 'فارسی',              englishName: 'Persian',              isRtl: true,  emoji: '🇮🇷'),
  _Language(code: 'fr', nativeName: 'Français',           englishName: 'French',               isRtl: false, emoji: '🇫🇷'),

  // ── South Asian ────────────────────────────────────────
  _Language(code: 'ta', nativeName: 'தமிழ்',               englishName: 'Tamil',                isRtl: false, emoji: '🇮🇳'),
  _Language(code: 'te', nativeName: 'తెలుగు',              englishName: 'Telugu',               isRtl: false, emoji: '🇮🇳'),
  _Language(code: 'ml', nativeName: 'മലയാളം',              englishName: 'Malayalam',            isRtl: false, emoji: '🇮🇳'),
  _Language(code: 'kn', nativeName: 'ಕನ್ನಡ',               englishName: 'Kannada',              isRtl: false, emoji: '🇮🇳'),
  _Language(code: 'mr', nativeName: 'मराठी',               englishName: 'Marathi',              isRtl: false, emoji: '🇮🇳'),
  _Language(code: 'gu', nativeName: 'ગુજરાતી',             englishName: 'Gujarati',             isRtl: false, emoji: '🇮🇳'),
  _Language(code: 'pa', nativeName: 'ਪੰਜਾਬੀ',               englishName: 'Punjabi',              isRtl: false, emoji: '🇮🇳'),
  _Language(code: 'ks', nativeName: 'کٲشُر',              englishName: 'Kashmiri',             isRtl: true,  emoji: '🇮🇳'),
  _Language(code: 'sd', nativeName: 'سنڌي',               englishName: 'Sindhi',               isRtl: true,  emoji: '🇵🇰'),
  _Language(code: 'or', nativeName: 'ଓଡ଼ିଆ',               englishName: 'Odia',                 isRtl: false, emoji: '🇮🇳'),
  _Language(code: 'as', nativeName: 'অসমীয়া',             englishName: 'Assamese',             isRtl: false, emoji: '🇮🇳'),
  _Language(code: 'ne', nativeName: 'नेपाली',               englishName: 'Nepali',               isRtl: false, emoji: '🇳🇵'),
  _Language(code: 'si', nativeName: 'සිංහල',              englishName: 'Sinhala',              isRtl: false, emoji: '🇱🇰'),
  _Language(code: 'dv', nativeName: 'ދިވެހި',               englishName: 'Dhivehi',              isRtl: true,  emoji: '🇲🇻'),

  // ── South Asian regional ───────────────────────────────
  _Language(code: 'bh', nativeName: 'भोजपुरी',             englishName: 'Bhojpuri',             isRtl: false, emoji: '🇮🇳'),
  _Language(code: 'do', nativeName: 'डोगरी',              englishName: 'Dogri',                isRtl: false, emoji: '🇮🇳'),
  _Language(code: 'mt', nativeName: 'مائیتھلی',            englishName: 'Maithili',             isRtl: false, emoji: '🇮🇳'),
  _Language(code: 'tu', nativeName: 'ತುಳು',                englishName: 'Tulu',                 isRtl: false, emoji: '🇮🇳'),
  _Language(code: 'ko', nativeName: 'کونکنی',             englishName: 'Konkani',              isRtl: false, emoji: '🇮🇳'),
  _Language(code: 'sk', nativeName: 'سرائیکی',            englishName: 'Saraiki',              isRtl: true,  emoji: '🇵🇰'),
  _Language(code: 'hk', nativeName: 'ہندکو',              englishName: 'Hindko',               isRtl: true,  emoji: '🇵🇰'),
  _Language(code: 'bl', nativeName: 'بلوچی',              englishName: 'Balochi',              isRtl: true,  emoji: '🇵🇰'),
  _Language(code: 'br', nativeName: 'براہوئی',             englishName: 'Brahui',               isRtl: true,  emoji: '🇵🇰'),
  _Language(code: 'sn', nativeName: 'شینا',               englishName: 'Shina',                isRtl: true,  emoji: '🇵🇰'),
  _Language(code: 'bs2', nativeName: 'بروشسکی',           englishName: 'Burushaski',           isRtl: true,  emoji: '🇵🇰'),
  _Language(code: 'kh', nativeName: 'کھوار',              englishName: 'Khowar',               isRtl: true,  emoji: '🇵🇰'),
  _Language(code: 'po', nativeName: 'پوٹھوہاری',           englishName: 'Pothohari',            isRtl: true,  emoji: '🇵🇰'),
  _Language(code: 'ct', nativeName: 'চাটগাঁইয়া',           englishName: 'Chittagonian',         isRtl: false, emoji: '🇧🇩'),
  _Language(code: 'sy', nativeName: 'সিলেটি',              englishName: 'Sylheti',              isRtl: false, emoji: '🇧🇩'),

  // ── Pashto & Afghan ────────────────────────────────────
  _Language(code: 'ps', nativeName: 'پښتو',               englishName: 'Pashto',               isRtl: true,  emoji: '🇦🇫'),
  _Language(code: 'prs', nativeName: 'دری',               englishName: 'Dari',                 isRtl: true,  emoji: '🇦🇫'),

  // ── Central Asian ──────────────────────────────────────
  _Language(code: 'az', nativeName: 'Azərbaycan',         englishName: 'Azerbaijani',          isRtl: false, emoji: '🇦🇿'),
  _Language(code: 'uz', nativeName: 'O\'zbek',            englishName: 'Uzbek',                isRtl: false, emoji: '🇺🇿'),
  _Language(code: 'kk', nativeName: 'Қазақ',              englishName: 'Kazakh',               isRtl: false, emoji: '🇰🇿'),
  _Language(code: 'ky', nativeName: 'Кыргыз',             englishName: 'Kyrgyz',               isRtl: false, emoji: '🇰🇬'),
  _Language(code: 'tg', nativeName: 'Тоҷикӣ',             englishName: 'Tajik',                isRtl: false, emoji: '🇹🇯'),
  _Language(code: 'tk', nativeName: 'Türkmen',            englishName: 'Turkmen',              isRtl: false, emoji: '🇹🇲'),

  // ── MENA regional ─────────────────────────────────────
  _Language(code: 'ku', nativeName: 'کوردی',              englishName: 'Kurdish',              isRtl: true,  emoji: '🇮🇶'),
  _Language(code: 'ber', nativeName: 'ⵜⴰⵎⴰⵣⵉⵖⵜ',         englishName: 'Amazigh (Berber)',     isRtl: false, emoji: '🇩🇿'),
  _Language(code: 'tmz', nativeName: 'ⵜⴰⵎⴰⵣⵉⵖⵜ',         englishName: 'Tamazight',            isRtl: false, emoji: '🇲🇦'),
  _Language(code: 'nub', nativeName: 'Nobiin',            englishName: 'Nubian',               isRtl: false, emoji: '🇸🇩'),
  _Language(code: 'bej', nativeName: 'Beja',              englishName: 'Beja',                 isRtl: false, emoji: '🇸🇩'),
  _Language(code: 'fur', nativeName: 'Fur',               englishName: 'Fur',                  isRtl: false, emoji: '🇸🇩'),
  _Language(code: 'hs', nativeName: 'الحسانية',           englishName: 'Hassaniya',            isRtl: true,  emoji: '🇱🇾'),
  _Language(code: 'asy', nativeName: 'ܐܫܘܪܝܐ',           englishName: 'Assyrian',             isRtl: true,  emoji: '🇮🇶'),

  // ── African ────────────────────────────────────────────
  _Language(code: 'sw', nativeName: 'Kiswahili',          englishName: 'Swahili',              isRtl: false, emoji: '🇹🇿'),
  _Language(code: 'so', nativeName: 'Soomaali',           englishName: 'Somali',               isRtl: false, emoji: '🇸🇴'),
  _Language(code: 'ha', nativeName: 'Hausa',              englishName: 'Hausa',                isRtl: false, emoji: '🇳🇬'),
  _Language(code: 'yo', nativeName: 'Yorùbá',             englishName: 'Yoruba',               isRtl: false, emoji: '🇳🇬'),
  _Language(code: 'ff', nativeName: 'Fulfulde',           englishName: 'Fulfulde',             isRtl: false, emoji: '🇳🇬'),
  _Language(code: 'kr', nativeName: 'Kanuri',             englishName: 'Kanuri',               isRtl: false, emoji: '🇳🇬'),
  _Language(code: 'ig', nativeName: 'Igbo',               englishName: 'Igbo',                 isRtl: false, emoji: '🇳🇬'),
  _Language(code: 'nup', nativeName: 'Nupe',              englishName: 'Nupe',                 isRtl: false, emoji: '🇳🇬'),
  _Language(code: 'am', nativeName: 'አማርኛ',              englishName: 'Amharic',              isRtl: false, emoji: '🇪🇹'),
  _Language(code: 'om', nativeName: 'Oromoo',             englishName: 'Oromo',                isRtl: false, emoji: '🇪🇹'),
  _Language(code: 'aa', nativeName: 'Qafar',              englishName: 'Afar',                 isRtl: false, emoji: '🇪🇹'),
  _Language(code: 'wo', nativeName: 'Wolof',              englishName: 'Wolof',                isRtl: false, emoji: '🇸🇳'),
  _Language(code: 'mn', nativeName: 'Mandinka',           englishName: 'Mandinka',             isRtl: false, emoji: '🇸🇳'),
  _Language(code: 'sr2', nativeName: 'Serer',             englishName: 'Serer',                isRtl: false, emoji: '🇸🇳'),
  _Language(code: 'bm', nativeName: 'Bamanankan',         englishName: 'Bambara',              isRtl: false, emoji: '🇲🇱'),
  _Language(code: 'sg2', nativeName: 'Songhai',           englishName: 'Songhai',              isRtl: false, emoji: '🇲🇱'),
  _Language(code: 'tmq', nativeName: 'Tamasheq',          englishName: 'Tamasheq',             isRtl: false, emoji: '🇲🇱'),
  _Language(code: 'dg', nativeName: 'Dagbani',            englishName: 'Dagbani',              isRtl: false, emoji: '🇬🇭'),
  _Language(code: 'lg', nativeName: 'Luganda',            englishName: 'Luganda',              isRtl: false, emoji: '🇺🇬'),
  _Language(code: 'af', nativeName: 'Afrikaans',          englishName: 'Afrikaans',            isRtl: false, emoji: '🇿🇦'),

  // ── European ───────────────────────────────────────────
  _Language(code: 'de', nativeName: 'Deutsch',            englishName: 'German',               isRtl: false, emoji: '🇩🇪'),
  _Language(code: 'nl', nativeName: 'Nederlands',         englishName: 'Dutch',                isRtl: false, emoji: '🇳🇱'),
  _Language(code: 'sv', nativeName: 'Svenska',            englishName: 'Swedish',              isRtl: false, emoji: '🇸🇪'),
  _Language(code: 'no', nativeName: 'Norsk',              englishName: 'Norwegian',            isRtl: false, emoji: '🇳🇴'),
  _Language(code: 'ru', nativeName: 'Русский',            englishName: 'Russian',              isRtl: false, emoji: '🇷🇺'),
  _Language(code: 'bs', nativeName: 'Bosanski',           englishName: 'Bosnian',              isRtl: false, emoji: '🇧🇦'),
  _Language(code: 'hr', nativeName: 'Hrvatski',           englishName: 'Croatian',             isRtl: false, emoji: '🇭🇷'),
  _Language(code: 'sr', nativeName: 'Српски',             englishName: 'Serbian',              isRtl: false, emoji: '🇷🇸'),
  _Language(code: 'sq', nativeName: 'Shqip',              englishName: 'Albanian',             isRtl: false, emoji: '🇦🇱'),
  _Language(code: 'tt', nativeName: 'Татар',              englishName: 'Tatar',                isRtl: false, emoji: '🇷🇺'),
  _Language(code: 'ce', nativeName: 'Нохчийн',            englishName: 'Chechen',              isRtl: false, emoji: '🇷🇺'),
  _Language(code: 'av', nativeName: 'Авар',               englishName: 'Avar',                 isRtl: false, emoji: '🇷🇺'),
  _Language(code: 'kbd', nativeName: 'Адыгэбзэ',          englishName: 'Circassian',           isRtl: false, emoji: '🇷🇺'),
  _Language(code: 'ba', nativeName: 'Башҡорт',            englishName: 'Bashkir',              isRtl: false, emoji: '🇷🇺'),
  _Language(code: 'rom', nativeName: 'Romani',            englishName: 'Romani',               isRtl: false, emoji: '🌍'),

  // ── Southeast Asian ────────────────────────────────────
  _Language(code: 'jv', nativeName: 'Basa Jawa',          englishName: 'Javanese',             isRtl: false, emoji: '🇮🇩'),
  _Language(code: 'su', nativeName: 'Basa Sunda',         englishName: 'Sundanese',            isRtl: false, emoji: '🇮🇩'),
  _Language(code: 'mad', nativeName: 'Madhurâ',           englishName: 'Madurese',             isRtl: false, emoji: '🇮🇩'),
  _Language(code: 'ace', nativeName: 'Acèh',              englishName: 'Acehnese',             isRtl: false, emoji: '🇮🇩'),
  _Language(code: 'min', nativeName: 'Minangkabau',       englishName: 'Minangkabau',          isRtl: false, emoji: '🇮🇩'),
  _Language(code: 'bug', nativeName: 'ᨅᨔ ᨕᨘᨁᨗ',          englishName: 'Bugis',                isRtl: false, emoji: '🇮🇩'),
  _Language(code: 'bet', nativeName: 'Betawi',            englishName: 'Betawi',               isRtl: false, emoji: '🇮🇩'),
  _Language(code: 'tl', nativeName: 'Filipino',           englishName: 'Filipino',             isRtl: false, emoji: '🇵🇭'),
  _Language(code: 'mrw', nativeName: 'Maranao',           englishName: 'Maranao',              isRtl: false, emoji: '🇵🇭'),
  _Language(code: 'tsg', nativeName: 'Tausug',            englishName: 'Tausug',               isRtl: false, emoji: '🇵🇭'),
  _Language(code: 'mdh', nativeName: 'Maguindanao',       englishName: 'Maguindanao',          isRtl: false, emoji: '🇵🇭'),
  _Language(code: 'yka', nativeName: 'Yakan',             englishName: 'Yakan',                isRtl: false, emoji: '🇵🇭'),
  _Language(code: 'th', nativeName: 'ไทย',                englishName: 'Thai',                 isRtl: false, emoji: '🇹🇭'),
  _Language(code: 'my', nativeName: 'မြန်မာ',             englishName: 'Burmese',              isRtl: false, emoji: '🇲🇲'),
  _Language(code: 'rhg', nativeName: 'Rohingya',          englishName: 'Rohingya',             isRtl: false, emoji: '🇲🇲'),

  // ── Americas ───────────────────────────────────────────
  _Language(code: 'es', nativeName: 'Español',            englishName: 'Spanish',              isRtl: false, emoji: '🇪🇸'),
  _Language(code: 'pt', nativeName: 'Português',          englishName: 'Portuguese',           isRtl: false, emoji: '🇧🇷'),
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
    return _kLanguages.where((lang) =>
      lang.nativeName.toLowerCase().contains(q) ||
      lang.englishName.toLowerCase().contains(q) ||
      lang.code.toLowerCase().contains(q)
    ).toList();
  }

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
    await prefs.setBool('noor_intro_completed', true);
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
            center: Alignment(0, -0.5),  // slightly above center
            radius: 1.2,
            colors: [
              Color(0xFF151522),  // Deep premium navy-charcoal core
              AppColors.obsidianNight,  // Deep midnight edges
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
                        borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                        borderSide: const BorderSide(color: AppColors.cardBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                        borderSide: const BorderSide(color: AppColors.cardBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
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
                      itemCount:  _filteredLanguages.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppDimensions.space8),
                      itemBuilder: (context, i) {
                        final lang = _filteredLanguages[i];
                        return _LanguageTile(
                          language:   lang,
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
                  child: NoorPrimaryButton(
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
                      ? const _SelectedCheck(key: ValueKey('check'))
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
      decoration: const BoxDecoration(
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
