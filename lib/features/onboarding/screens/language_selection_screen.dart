import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/cubits/locale/locale_cubit.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/buttons/silarah_pressable.dart';
import '../../../core/widgets/buttons/silarah_primary_button.dart';
import '../../../core/widgets/animations/silarah_motion.dart';

class _Language {
  const _Language({
    required this.code,
    required this.nativeName,
    required this.englishName,
    required this.isRtl,
    required this.mark,
    required this.title,
    required this.subtitle,
    required this.continueLabel,
  });

  final String code;
  final String nativeName;
  final String englishName;
  final bool isRtl;
  final String mark;
  final String title;
  final String subtitle;
  final String continueLabel;
}

const _completeLanguages = [
  _Language(
    code: 'en',
    nativeName: 'English',
    englishName: 'English',
    isRtl: false,
    mark: 'EN',
    title: 'Choose your language',
    subtitle: 'You can change this later in settings.',
    continueLabel: 'Continue',
  ),
  _Language(
    code: 'ar',
    nativeName: 'العربية',
    englishName: 'Arabic',
    isRtl: true,
    mark: 'ع',
    title: 'اختر اللغة',
    subtitle: 'يمكنك تغييرها لاحقًا من الإعدادات.',
    continueLabel: 'متابعة',
  ),
  _Language(
    code: 'ur',
    nativeName: 'اردو',
    englishName: 'Urdu',
    isRtl: true,
    mark: 'ا',
    title: 'اپنی زبان منتخب کریں',
    subtitle: 'آپ اسے بعد میں ترتیبات میں تبدیل کر سکتے ہیں۔',
    continueLabel: 'جاری رکھیں',
  ),
  _Language(
    code: 'hi',
    nativeName: 'हिन्दी',
    englishName: 'Hindi',
    isRtl: false,
    mark: 'हि',
    title: 'अपनी भाषा चुनें',
    subtitle: 'आप इसे बाद में सेटिंग्स में बदल सकते हैं।',
    continueLabel: 'जारी रखें',
  ),
  _Language(
    code: 'bn',
    nativeName: 'বাংলা',
    englishName: 'Bengali',
    isRtl: false,
    mark: 'বাং',
    title: 'আপনার ভাষা নির্বাচন করুন',
    subtitle: 'আপনি পরে সেটিংসে এটি পরিবর্তন করতে পারবেন।',
    continueLabel: 'চালিয়ে যান',
  ),
  _Language(
    code: 'id',
    nativeName: 'Bahasa Indonesia',
    englishName: 'Indonesian',
    isRtl: false,
    mark: 'ID',
    title: 'Pilih bahasa Anda',
    subtitle: 'Anda dapat mengubahnya nanti di pengaturan.',
    continueLabel: 'Lanjutkan',
  ),
  _Language(
    code: 'ms',
    nativeName: 'Bahasa Melayu',
    englishName: 'Malay',
    isRtl: false,
    mark: 'MS',
    title: 'Pilih bahasa anda',
    subtitle: 'Anda boleh menukarnya kemudian dalam tetapan.',
    continueLabel: 'Teruskan',
  ),
  _Language(
    code: 'tr',
    nativeName: 'Türkçe',
    englishName: 'Turkish',
    isRtl: false,
    mark: 'TR',
    title: 'Dilinizi seçin',
    subtitle: 'Bunu daha sonra ayarlardan değiştirebilirsiniz.',
    continueLabel: 'Devam et',
  ),
  _Language(
    code: 'fr',
    nativeName: 'Français',
    englishName: 'French',
    isRtl: false,
    mark: 'FR',
    title: 'Choisissez votre langue',
    subtitle: 'Vous pourrez la modifier plus tard dans les paramètres.',
    continueLabel: 'Continuer',
  ),
  _Language(
    code: 'de',
    nativeName: 'Deutsch',
    englishName: 'German',
    isRtl: false,
    mark: 'DE',
    title: 'Wählen Sie Ihre Sprache',
    subtitle: 'Sie können sie später in den Einstellungen ändern.',
    continueLabel: 'Weiter',
  ),
];

class LanguageSelectionScreen extends StatefulWidget {
  const LanguageSelectionScreen({super.key});

  @override
  State<LanguageSelectionScreen> createState() =>
      _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
  String _selectedCode = 'en';
  bool _didReadLocale = false;

  _Language get _selectedLanguage => _completeLanguages.firstWhere(
        (language) => language.code == _selectedCode,
        orElse: () => _completeLanguages.first,
      );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didReadLocale) return;
    final activeCode = context.read<LocaleCubit>().state.languageCode;
    if (LocaleCubit.supportedLanguageCodes.contains(activeCode)) {
      _selectedCode = activeCode;
    }
    _didReadLocale = true;
  }

  Future<void> _onContinue() async {
    await context.read<LocaleCubit>().setLocale(Locale(_selectedCode));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('silarah_intro_completed', true);
    if (mounted) context.go(AppRoutes.splash);
  }

  @override
  Widget build(BuildContext context) {
    final selectedLanguage = _selectedLanguage;

    return Scaffold(
      backgroundColor: AppColors.obsidianNight,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.55),
            radius: 1.18,
            colors: [
              AppColors.navyCharcoal,
              AppColors.obsidianNight,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimensions.horizontalMargin,
                  AppDimensions.space32,
                  AppDimensions.horizontalMargin,
                  AppDimensions.space24,
                ),
                child: SilarahEntrance(
                  child: _Header(language: selectedLanguage),
                ),
              ),
              Expanded(
                child: SilarahEntrance(
                  delay: const Duration(milliseconds: 55),
                  child: ListView.separated(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(
                      AppDimensions.horizontalMargin,
                      0,
                      AppDimensions.horizontalMargin,
                      AppDimensions.space16,
                    ),
                    physics: const BouncingScrollPhysics(),
                    itemCount: _completeLanguages.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppDimensions.space12),
                    itemBuilder: (context, index) {
                      final language = _completeLanguages[index];
                      return _LanguageTile(
                        language: language,
                        isSelected: _selectedCode == language.code,
                        onTap: () {
                          FocusManager.instance.primaryFocus?.unfocus();
                          setState(() => _selectedCode = language.code);
                        },
                      );
                    },
                  ),
                ),
              ),
              SilarahEntrance(
                delay: const Duration(milliseconds: 110),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.obsidianNight.withValues(alpha: 0),
                        AppColors.obsidianNight.withValues(alpha: 0.92),
                      ],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppDimensions.horizontalMargin,
                      AppDimensions.space12,
                      AppDimensions.horizontalMargin,
                      AppDimensions.space20,
                    ),
                    child: SilarahPrimaryButton(
                      label: selectedLanguage.continueLabel,
                      onTap: _onContinue,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.language});

  final _Language language;

  @override
  Widget build(BuildContext context) {
    final textDirection =
        language.isRtl ? TextDirection.rtl : TextDirection.ltr;
    return Column(
      crossAxisAlignment:
          language.isRtl ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          'سيلارا',
          textDirection: TextDirection.rtl,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.champagneGold.withValues(alpha: 0.88),
            shadows: [
              Shadow(
                color: AppColors.champagneGold.withValues(alpha: 0.42),
                blurRadius: 14,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppDimensions.space12),
        Text(
          language.title,
          textDirection: textDirection,
          style: AppTypography.screenTitle.copyWith(height: 1.14),
        ),
        const SizedBox(height: AppDimensions.space8),
        Text(
          language.subtitle,
          textDirection: textDirection,
          style: AppTypography.caption,
        ),
        const SizedBox(height: AppDimensions.space20),
        Container(
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin:
                  language.isRtl ? Alignment.centerRight : Alignment.centerLeft,
              end:
                  language.isRtl ? Alignment.centerLeft : Alignment.centerRight,
              colors: [
                AppColors.champagneGold.withValues(alpha: 0.62),
                AppColors.champagneGold.withValues(alpha: 0),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

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
            ? AppColors.champagneGold.withValues(alpha: 0.09)
            : AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
        border: Border.all(
          color: isSelected
              ? AppColors.champagneGold.withValues(alpha: 0.62)
              : AppColors.cardBorder,
          width: isSelected ? 1.5 : 1,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: AppColors.champagneGold.withValues(alpha: 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ]
            : null,
      ),
      child: SilarahPressable(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.space16,
            vertical: AppDimensions.space16,
          ),
          child: Row(
            children: [
              _LanguageMark(mark: language.mark, selected: isSelected),
              const SizedBox(width: AppDimensions.space16),
              Expanded(
                child: Column(
                  crossAxisAlignment: language.isRtl
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    Text(
                      language.nativeName,
                      textDirection: language.isRtl
                          ? TextDirection.rtl
                          : TextDirection.ltr,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: isSelected
                            ? AppColors.champagneGold
                            : AppColors.pearlWhite,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      language.englishName,
                      style: AppTypography.caption.copyWith(
                        color: isSelected
                            ? AppColors.champagneGold.withValues(alpha: 0.78)
                            : AppColors.slateMist,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppDimensions.space12),
              AnimatedScale(
                scale: isSelected ? 1 : 0.72,
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutBack,
                child: Icon(
                  isSelected
                      ? Icons.check_circle_rounded
                      : Icons.circle_outlined,
                  color: isSelected
                      ? AppColors.champagneGold
                      : AppColors.slateMist.withValues(alpha: 0.38),
                  size: 24,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LanguageMark extends StatelessWidget {
  const _LanguageMark({required this.mark, required this.selected});

  final String mark;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: 46,
      height: 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected
            ? AppColors.champagneGold.withValues(alpha: 0.14)
            : AppColors.obsidianNight.withValues(alpha: 0.44),
        border: Border.all(
          color: selected
              ? AppColors.champagneGold.withValues(alpha: 0.65)
              : AppColors.cardBorder,
        ),
      ),
      child: Text(
        mark,
        textDirection: (mark == 'ع' || mark == 'ا')
            ? TextDirection.rtl
            : TextDirection.ltr,
        style: TextStyle(
          color: selected ? AppColors.champagneGold : AppColors.slateMist,
          fontWeight: FontWeight.w800,
          fontSize: mark == 'ع' ? 20 : 14,
        ),
      ),
    );
  }
}
