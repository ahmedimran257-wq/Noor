// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Urdu (`ur`).
class AppLocalizationsUr extends AppLocalizations {
  AppLocalizationsUr([String locale = 'ur']) : super(locale);

  @override
  String get appName => 'نور';

  @override
  String get appTagline => 'بسم اللہ سے شروع کریں';

  @override
  String get common_button_next => 'اگلا';

  @override
  String get common_button_back => 'واپس';

  @override
  String get common_button_skip => 'چھوڑیں';

  @override
  String get common_button_save => 'محفوظ کریں';

  @override
  String get common_button_cancel => 'منسوخ';

  @override
  String get common_button_submit => 'جمع کریں';

  @override
  String get common_button_done => 'مکمل';

  @override
  String get common_button_retry => 'دوبارہ کوشش کریں';

  @override
  String get common_label_optional => 'اختیاری';

  @override
  String get common_error_generic =>
      'کچھ غلط ہوگیا۔ براہ کرم دوبارہ کوشش کریں۔';

  @override
  String get common_error_noInternet => 'انٹرنیٹ کنکشن نہیں ہے۔';

  @override
  String get splash_button_createProfile => 'پروفائل بنائیں';

  @override
  String get splash_button_signIn => 'سائن ان کریں';

  @override
  String get legal_title => 'شروع کرنے سے پہلے';

  @override
  String get legal_checkbox_age =>
      'میں تصدیق کرتا/کرتی ہوں کہ میری عمر 18 سال یا اس سے زیادہ ہے';

  @override
  String get legal_checkbox_terms =>
      'میں سروس کی شرائط اور رازداری کی پالیسی سے متفق ہوں';

  @override
  String get legal_button_continue => 'جاری رکھیں';

  @override
  String get auth_label_phoneNumber => 'فون نمبر';

  @override
  String get auth_hint_phoneNumber => 'اپنا فون نمبر درج کریں';

  @override
  String get auth_button_sendOtp => 'تصدیقی کوڈ بھیجیں';

  @override
  String get auth_label_enterOtp => '6 ہندسوں کا کوڈ درج کریں جو بھیجا گیا';

  @override
  String get auth_button_verifyOtp => 'تصدیق کریں';

  @override
  String get auth_button_resendOtp => 'کوڈ دوبارہ بھیجیں';

  @override
  String auth_label_resendIn(int seconds) {
    return '$seconds سیکنڈ میں دوبارہ بھیجیں';
  }

  @override
  String onboarding_label_step(int current, int total) {
    return 'مرحلہ $current از $total';
  }

  @override
  String get onboarding_profileForWhom_title => 'یہ پروفائل کس کے لیے ہے؟';

  @override
  String get onboarding_profileForWhom_myself => 'میرے لیے';

  @override
  String get onboarding_profileForWhom_myselfSub =>
      'میں اپنے لیے شریکِ حیات ڈھونڈ رہا/رہی ہوں';

  @override
  String get onboarding_profileForWhom_guardian => 'میرے بیٹے یا بیٹی کے لیے';

  @override
  String get onboarding_profileForWhom_guardianSub =>
      'میں والدین یا سرپرست ہوں';

  @override
  String get onboarding_basicIdentity_title => 'اپنے بارے میں بتائیں';

  @override
  String get onboarding_label_firstName => 'پہلا نام';

  @override
  String get onboarding_label_lastName => 'آخری نام';

  @override
  String get onboarding_label_dateOfBirth => 'تاریخ پیدائش';

  @override
  String get onboarding_label_gender => 'جنس';

  @override
  String get onboarding_label_male => 'مرد';

  @override
  String get onboarding_label_female => 'عورت';

  @override
  String get onboarding_label_city => 'شہر';

  @override
  String get onboarding_hint_searchCity => 'اپنا شہر تلاش کریں…';

  @override
  String get onboarding_error_under18 =>
      'نور 18 سال یا اس سے زیادہ عمر کے لوگوں کے لیے ہے۔';

  @override
  String get onboarding_islamicIdentity_title => 'آپ کی اسلامی شناخت';

  @override
  String get onboarding_label_sect => 'Sect';

  @override
  String get onboarding_label_sunni => 'Sunni';

  @override
  String get onboarding_label_shia => 'Shia';

  @override
  String get onboarding_label_preferNotToSay => 'Prefer not to say';

  @override
  String get onboarding_label_deenLevel => 'دینداری کی سطح';

  @override
  String get onboarding_label_practicing => 'پابند نماز';

  @override
  String get onboarding_tooltip_practicing =>
      'Follows all five pillars, prays regularly, halal lifestyle';

  @override
  String get onboarding_label_moderate => 'معتدل';

  @override
  String get onboarding_tooltip_moderate =>
      'Values Islamic principles, prays regularly but not always, culturally Muslim';

  @override
  String get onboarding_label_cultural => 'کلچرل مسلمان';

  @override
  String get onboarding_tooltip_cultural =>
      'Identifies as Muslim, celebrates occasions, may not pray regularly';

  @override
  String get onboarding_label_praysFiveDaily =>
      'میں پانچ وقت نماز پڑھتا/پڑھتی ہوں';

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
  String get onboarding_about_title => 'اپنے بارے میں';

  @override
  String get onboarding_hint_bio =>
      'اپنے آپ کو ایمانداری اور وقار کے ساتھ بیان کریں۔';

  @override
  String onboarding_label_bioCount(int count) {
    return '$count/300';
  }

  @override
  String get onboarding_error_bioContactInfo =>
      'Please remove contact information from your bio. External contact details are not allowed for your safety.';

  @override
  String get onboarding_photo_title => 'اپنی تصاویر شامل کریں';

  @override
  String get onboarding_photo_subtitle =>
      'کم از کم ایک تصویر ضروری ہے جس میں آپ کا چہرہ واضح نظر آئے۔';

  @override
  String get onboarding_photo_verifySelfie => 'تصدیقی سیلفی';

  @override
  String get onboarding_photo_verifySelfieHint =>
      'اپنی شناخت کی تصدیق کے لیے لائیو تصویر لیں';

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
  String get discovery_button_sendInterest => 'دلچسپی بھیجیں';

  @override
  String get discovery_label_interestSent => 'بھیج دی گئی ✓';

  @override
  String get discovery_label_outsidePrefs => 'کوئی جس سے آپ جڑ سکتے ہیں';

  @override
  String get ceremony_text_blessing => 'اللہ اس میں برکت عطا فرمائے';

  @override
  String get chat_placeholder_typeMessage => 'پیغام لکھیں…';

  @override
  String chat_label_probation(int hours) {
    return 'Messaging unlocks in $hours hours. You can send Interests now.';
  }

  @override
  String get chat_label_subscribeToMessage =>
      'میسجنگ کھولنے کے لیے سبسکرائب کریں۔ خواتین ہمیشہ نور پر مفت میسج کرتی ہیں۔';

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
  String get subscription_title => 'نور کو کھولیں';

  @override
  String get subscription_subtitle =>
      'خواتین مفت میسج کرتی ہیں۔ مرد رابطے کے لیے سبسکرائب کریں۔';

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
  String get interests_tab_received => 'موصول ہوئیں';

  @override
  String get interests_tab_sent => 'بھیجی گئیں';

  @override
  String get interests_button_accept => 'قبول کریں';

  @override
  String get interests_button_decline => 'رد کریں';

  @override
  String get settings_title => 'ترتیبات';

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
  String get settings_button_deleteAccount => 'اکاؤنٹ حذف کریں';

  @override
  String get settings_label_deleteGrace =>
      'Your profile will be hidden immediately. Your data will be permanently deleted after 30 days.';
}
