// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appName => 'نور';

  @override
  String get appTagline => 'ابدأ بسم الله';

  @override
  String get common_button_next => 'التالي';

  @override
  String get common_button_back => 'رجوع';

  @override
  String get common_button_skip => 'تخطي';

  @override
  String get common_button_save => 'حفظ';

  @override
  String get common_button_cancel => 'إلغاء';

  @override
  String get common_button_submit => 'إرسال';

  @override
  String get common_button_done => 'تم';

  @override
  String get common_button_retry => 'حاول مرة أخرى';

  @override
  String get common_label_optional => 'اختياري';

  @override
  String get common_error_generic => 'حدث خطأ ما. يرجى المحاولة مرة أخرى.';

  @override
  String get common_error_noInternet => 'لا يوجد اتصال بالإنترنت.';

  @override
  String get splash_button_createProfile => 'إنشاء ملف شخصي';

  @override
  String get splash_button_signIn => 'تسجيل الدخول';

  @override
  String get legal_title => 'قبل أن تبدأ';

  @override
  String get legal_checkbox_age => 'أؤكد أنني بلغت 18 عامًا أو أكثر';

  @override
  String get legal_checkbox_terms => 'أوافق على شروط الخدمة وسياسة الخصوصية';

  @override
  String get legal_button_continue => 'متابعة';

  @override
  String get auth_label_phoneNumber => 'رقم الهاتف';

  @override
  String get auth_hint_phoneNumber => 'أدخل رقم هاتفك';

  @override
  String get auth_button_sendOtp => 'إرسال رمز التحقق';

  @override
  String get auth_label_enterOtp => 'أدخل الرمز المكوّن من 6 أرقام المرسل إلى';

  @override
  String get auth_button_verifyOtp => 'تحقق';

  @override
  String get auth_button_resendOtp => 'إعادة إرسال الرمز';

  @override
  String auth_label_resendIn(int seconds) {
    return 'إعادة الإرسال خلال $secondsث';
  }

  @override
  String onboarding_label_step(int current, int total) {
    return 'الخطوة $current من $total';
  }

  @override
  String get onboarding_profileForWhom_title => 'لمن هذا الملف الشخصي؟';

  @override
  String get onboarding_profileForWhom_myself => 'لنفسي';

  @override
  String get onboarding_profileForWhom_myselfSub => 'أبحث عن شريك/ة للزواج';

  @override
  String get onboarding_profileForWhom_guardian => 'لابني أو ابنتي';

  @override
  String get onboarding_profileForWhom_guardianSub => 'أنا ولي أمر';

  @override
  String get onboarding_basicIdentity_title => 'أخبرنا عن نفسك';

  @override
  String get onboarding_label_firstName => 'الاسم الأول';

  @override
  String get onboarding_label_lastName => 'اسم العائلة';

  @override
  String get onboarding_label_dateOfBirth => 'تاريخ الميلاد';

  @override
  String get onboarding_label_gender => 'الجنس';

  @override
  String get onboarding_label_male => 'ذكر';

  @override
  String get onboarding_label_female => 'أنثى';

  @override
  String get onboarding_label_city => 'المدينة';

  @override
  String get onboarding_hint_searchCity => 'ابحث عن مدينتك…';

  @override
  String get onboarding_error_under18 =>
      'نور مخصص لمن هم في سن 18 عامًا أو أكثر.';

  @override
  String get onboarding_islamicIdentity_title => 'هويتك الإسلامية';

  @override
  String get onboarding_label_sect => 'Sect';

  @override
  String get onboarding_label_sunni => 'Sunni';

  @override
  String get onboarding_label_shia => 'Shia';

  @override
  String get onboarding_label_preferNotToSay => 'Prefer not to say';

  @override
  String get onboarding_label_deenLevel => 'مستوى التديّن';

  @override
  String get onboarding_label_practicing => 'مُلتزم';

  @override
  String get onboarding_tooltip_practicing =>
      'Follows all five pillars, prays regularly, halal lifestyle';

  @override
  String get onboarding_label_moderate => 'معتدل';

  @override
  String get onboarding_tooltip_moderate =>
      'Values Islamic principles, prays regularly but not always, culturally Muslim';

  @override
  String get onboarding_label_cultural => 'مسلم ثقافي';

  @override
  String get onboarding_tooltip_cultural =>
      'Identifies as Muslim, celebrates occasions, may not pray regularly';

  @override
  String get onboarding_label_praysFiveDaily => 'أصلي الصلوات الخمس يوميًا';

  @override
  String get onboarding_background_title => 'Education & Career';

  @override
  String get onboarding_label_educationLevel => 'Education Level';

  @override
  String get onboarding_label_profession => 'Profession';

  @override
  String get onboarding_hint_profession =>
      'e.g. Software Engineer, Teacher, Doctor';

  @override
  String get onboarding_about_title => 'عن نفسك';

  @override
  String get onboarding_hint_bio => 'صِف نفسك بصدق وكرامة.';

  @override
  String onboarding_label_bioCount(int count) {
    return '$count/300';
  }

  @override
  String get onboarding_error_bioContactInfo =>
      'Please remove contact information from your bio. External contact details are not allowed for your safety.';

  @override
  String get onboarding_photo_title => 'أضف صورك';

  @override
  String get onboarding_photo_subtitle =>
      'مطلوبة صورة واحدة على الأقل تظهر فيها وجهك بوضوح.';

  @override
  String get onboarding_photo_verifySelfie => 'صورة التحقق';

  @override
  String get onboarding_photo_verifySelfieHint =>
      'التقط صورة مباشرة للتحقق من هويتك';

  @override
  String get onboarding_error_noFace =>
      'Please use a photo where your face is clearly visible.';

  @override
  String get onboarding_error_multipleFaces =>
      'Group photos cannot be your primary photo.';

  @override
  String get discovery_header_title => 'نور';

  @override
  String discovery_label_profilesRemaining(int count) {
    return '$count profiles remaining today';
  }

  @override
  String get discovery_button_sendInterest => 'إرسال إشعار الاهتمام';

  @override
  String get discovery_label_interestSent => 'تم الإرسال ✓';

  @override
  String get discovery_label_outsidePrefs => 'شخص قد تتواصل معه';

  @override
  String get ceremony_text_blessing => 'اسأل الله أن يبارك هذا بالخير';

  @override
  String get chat_placeholder_typeMessage => 'اكتب رسالة…';

  @override
  String chat_label_probation(int hours) {
    return 'Messaging unlocks in $hours hours. You can send Interests now.';
  }

  @override
  String get chat_label_subscribeToMessage =>
      'اشترك لفتح المراسلة. تراسل النساء مجانًا دائمًا في نور.';

  @override
  String get chat_opener_1 =>
      'Assalamu Alaikum! I came across your profile and was genuinely impressed. May I introduce myself?';

  @override
  String get chat_opener_2 =>
      'Bismillah. Your profile caught my attention. I would love to learn more about you.';

  @override
  String get chat_opener_3 =>
      'Assalamu Alaikum. I believe we share similar values. Would you be open to getting to know each other?';

  @override
  String get subscription_title => 'افتح نور';

  @override
  String get subscription_subtitle =>
      'تراسل النساء مجانًا. يشترك الرجال للتواصل.';

  @override
  String subscription_button_monthly(String price) {
    return 'Subscribe — $price/month';
  }

  @override
  String get subscription_label_bestValue => 'Best Value';

  @override
  String profile_label_completeness(int percent) {
    return 'Profile $percent% complete';
  }

  @override
  String get profile_nudge_completeness =>
      'Profiles with 80%+ completeness receive 3× more interests.';

  @override
  String get interests_tab_received => 'المُستلَمة';

  @override
  String get interests_tab_sent => 'المُرسَلة';

  @override
  String get interests_button_accept => 'قبول';

  @override
  String get interests_button_decline => 'رفض';

  @override
  String get settings_title => 'الإعدادات';

  @override
  String get settings_section_account => 'Account';

  @override
  String get settings_section_safety => 'Safety';

  @override
  String get settings_section_app => 'App';

  @override
  String get settings_section_legal => 'Legal';

  @override
  String get settings_section_dangerZone => 'Danger Zone';

  @override
  String get settings_button_deleteAccount => 'حذف الحساب';

  @override
  String get settings_label_deleteGrace =>
      'Your profile will be hidden immediately. Your data will be permanently deleted after 30 days.';
}
