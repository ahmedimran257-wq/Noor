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
  String get onboarding_profileForWhom_sibling => 'میرے بھائی یا بہن کے لیے';

  @override
  String get onboarding_profileForWhom_siblingSub =>
      'میں اپنے بہن/بھائی کا رشتہ ڈھونڈ رہا/رہی ہوں';

  @override
  String get onboarding_profileForWhom_ward => 'میرے زیرِ کفالت کے لیے';

  @override
  String get onboarding_profileForWhom_wardSub =>
      'میں سرپرست ہوں اور یہ پروفائل منظم کر رہا/رہی ہوں';

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
  String get onboarding_label_community => 'آپ کی برادری / قوم';

  @override
  String get onboarding_label_community_parent => 'ان کی برادری / قوم';

  @override
  String get onboarding_label_motherTongue => 'مادری زبان';

  @override
  String get onboarding_label_diet => 'غذائی ترجیح';

  @override
  String get onboarding_diet_zabihaStrict => 'پکی ذبیحہ';

  @override
  String get onboarding_diet_halalOnly => 'صرف حلال';

  @override
  String get onboarding_diet_eatsAnything => 'کوئی بھی حلال چیز';

  @override
  String get onboarding_diet_vegetarian => 'سبزی خور';

  @override
  String get onboarding_diet_vegan => 'خالص سبزی خور';

  @override
  String get onboarding_label_smoking => 'تمباکو نوشی';

  @override
  String get onboarding_label_vaping => 'ویپنگ / ای سگریٹ';

  @override
  String get onboarding_label_hookah => 'حقہ / شیشہ';

  @override
  String get onboarding_habit_never => 'کبھی نہیں';

  @override
  String get onboarding_habit_occasionally => 'کبھی کبھار';

  @override
  String get onboarding_habit_frequently => 'اکثر';

  @override
  String get onboarding_habit_preferNotToSay => 'بتانا نہیں چاہتا/چاہتی';

  @override
  String get onboarding_label_livingExpectation => 'شادی کے بعد رہائش کی توقع';

  @override
  String get onboarding_living_withInlaws => 'سسرال کے ساتھ';

  @override
  String get onboarding_living_withInlawsSub =>
      'میں سسرال یا اپنے گھر والوں کے ساتھ رہنے کا ارادہ رکھتا/رکھتی ہوں۔';

  @override
  String get onboarding_living_separate => 'الگ گھر';

  @override
  String get onboarding_living_separateSub =>
      'میں چاہتا/چاہتی ہوں کہ ہمارا اپنا الگ گھر ہو۔';

  @override
  String get onboarding_living_openToDiscussion => 'بات چیت سے طے کریں';

  @override
  String get onboarding_living_openToDiscussionSub =>
      'میں لچکدار ہوں اور دونوں کے لیے مناسب حل پر بات کرنے کو تیار ہوں۔';

  @override
  String get onboarding_label_preferredLiving => 'رہائش کی ترجیح';

  @override
  String get onboarding_preferredLiving_noPreference => 'کوئی ترجیح نہیں';

  @override
  String get copy_prayer_self => 'کیا آپ پانچ وقت نماز پڑھتے/پڑھتی ہیں؟';

  @override
  String get copy_prayer_parent => 'کیا آپ کا بچہ پانچ وقت نماز پڑھتا ہے؟';

  @override
  String get copy_prayer_sibling =>
      'کیا آپ کا بہن/بھائی پانچ وقت نماز پڑھتا ہے؟';

  @override
  String get copy_hijab_self => 'کیا آپ حجاب کرتی ہیں؟';

  @override
  String get copy_hijab_parent => 'کیا آپ کی بیٹی حجاب کرتی ہے؟';

  @override
  String get copy_hijab_sibling => 'کیا آپ کی بہن حجاب کرتی ہے؟';

  @override
  String get copy_beard_self => 'کیا آپ داڑھی رکھتے ہیں؟';

  @override
  String get copy_beard_parent => 'کیا آپ کے بیٹے کی داڑھی ہے؟';

  @override
  String get copy_beard_sibling => 'کیا آپ کے بھائی کی داڑھی ہے؟';

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
  String get chat_endMatch_title => 'یہ میچ ختم کریں';

  @override
  String get chat_endMatch_subtitle =>
      'ایک باعزت پیغام منتخب کریں۔ دوسرے شخص کو مطلع کیا جائے گا۔';

  @override
  String get chat_endMatch_button => 'بھیجیں اور میچ ختم کریں';

  @override
  String get chat_matchClosed_banner =>
      'یہ میچ باعزت طریقے سے بند کر دیا گیا ہے۔';

  @override
  String get chat_closure_1 =>
      'السلام علیکم۔ گہرے غور و فکر کے بعد میں محسوس کرتا/کرتی ہوں کہ یہ ہمارے لیے مناسب رشتہ نہیں ہے۔ اللہ آپ کو بہترین شریکِ حیات عطا فرمائے۔ جزاک اللہ خیراً۔';

  @override
  String get chat_closure_2 =>
      'السلام علیکم۔ میں آپ سے ایمانداری اور احترام کے ساتھ بات کرنا چاہتا/چاہتی تھا/تھی۔ مجھے نہیں لگتا ہم مناسب جوڑ ہیں، لیکن اللہ سے دعا ہے کہ آپ کے لیے بہتر دروازے کھولے۔';

  @override
  String get chat_closure_3 =>
      'السلام علیکم۔ سچے غور کے بعد محسوس ہوتا ہے کہ ہم شاید مطابقت نہیں رکھتے۔ آپ کے لیے دعا ہے۔ وقت دینے پر جزاک اللہ خیراً۔';

  @override
  String get chat_closure_4 =>
      'السلام علیکم۔ میں نے ہماری گفتگو پر غور کیا اور یہ میچ بند کرنا بہتر سمجھتا/سمجھتی ہوں۔ آپ کے لیے بہترین کی دعا کرتا/کرتی ہوں۔';

  @override
  String get chat_closure_5 =>
      'السلام علیکم۔ غائب ہونے کی بجائے شفاف رہنا چاہتا/چاہتی تھا/تھی۔ اللہ آپ کو ہر خوشی عطا فرمائے۔';

  @override
  String get filter_label_motherTongue => 'مادری زبان';

  @override
  String get filter_label_community => 'برادری / قوم';

  @override
  String get filter_label_livingExpectation => 'شادی کے بعد رہائش';

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

  @override
  String get settings_section_notifications => 'Notifications';

  @override
  String get settings_section_guardian => 'Guardian';

  @override
  String get settings_section_privacy => 'Privacy';

  @override
  String get notifications_title => 'Notifications';

  @override
  String get notifications_markAllRead => 'Mark all read';

  @override
  String get notifications_empty_title => 'You\'re all caught up';

  @override
  String get notifications_empty_subtitle => 'No new notifications right now.';

  @override
  String get deleteAccount_title => 'Delete Account';

  @override
  String get interests_title => 'Interests';
}
