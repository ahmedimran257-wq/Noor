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
  String get onboarding_profileForWhom_sibling => 'لأخي أو أختي';

  @override
  String get onboarding_profileForWhom_siblingSub =>
      'أساعد شقيقي/شقيقتي في إيجاد شريك';

  @override
  String get onboarding_profileForWhom_ward => 'لمن أرعاه';

  @override
  String get onboarding_profileForWhom_wardSub =>
      'أنا وصي وأدير هذا الملف الشخصي';

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
  String get onboarding_label_sect => 'المذهب';

  @override
  String get onboarding_label_sunni => 'سني';

  @override
  String get onboarding_label_shia => 'شيعي';

  @override
  String get onboarding_label_preferNotToSay => 'أفضل عدم الإجابة';

  @override
  String get onboarding_label_deenLevel => 'مستوى التديّن';

  @override
  String get onboarding_label_practicing => 'مُلتزم';

  @override
  String get onboarding_tooltip_practicing =>
      'يلتزم بأركان الإسلام الخمسة، يصلي بانتظام، يعيش حياة حلال';

  @override
  String get onboarding_label_moderate => 'معتدل';

  @override
  String get onboarding_tooltip_moderate =>
      'يقدّر المبادئ الإسلامية، يصلي بانتظام لكن ليس دائمًا، مسلم ثقافيًا';

  @override
  String get onboarding_label_cultural => 'مسلم ثقافي';

  @override
  String get onboarding_tooltip_cultural =>
      'يعرّف نفسه كمسلم، يحتفل بالمناسبات، قد لا يصلي بانتظام';

  @override
  String get onboarding_label_praysFiveDaily => 'أصلي الصلوات الخمس يوميًا';

  @override
  String get onboarding_label_community => 'مجتمعك / بيرادري';

  @override
  String get onboarding_label_community_parent => 'مجتمعهم / بيرادري';

  @override
  String get onboarding_label_motherTongue => 'اللغة الأم';

  @override
  String get onboarding_label_diet => 'النظام الغذائي';

  @override
  String get onboarding_diet_zabihaStrict => 'ذبيحة إسلامية صارمة';

  @override
  String get onboarding_diet_halalOnly => 'حلال فقط';

  @override
  String get onboarding_diet_eatsAnything => 'يأكل أي شيء حلال';

  @override
  String get onboarding_diet_vegetarian => 'نباتي';

  @override
  String get onboarding_diet_vegan => 'نباتي صارم';

  @override
  String get onboarding_label_smoking => 'التدخين';

  @override
  String get onboarding_label_vaping => 'السجائر الإلكترونية';

  @override
  String get onboarding_label_hookah => 'الشيشة';

  @override
  String get onboarding_habit_never => 'أبداً';

  @override
  String get onboarding_habit_occasionally => 'أحياناً';

  @override
  String get onboarding_habit_frequently => 'كثيراً';

  @override
  String get onboarding_habit_preferNotToSay => 'أفضل عدم الإجابة';

  @override
  String get onboarding_label_livingExpectation => 'توقعات السكن بعد الزواج';

  @override
  String get onboarding_living_withInlaws => 'مع الأسرة';

  @override
  String get onboarding_living_withInlawsSub =>
      'أتوقع العيش مع عائلة الزوج/الزوجة أو مع عائلتي.';

  @override
  String get onboarding_living_separate => 'مسكن مستقل';

  @override
  String get onboarding_living_separateSub => 'أفضل أن يكون لنا مسكن مستقل.';

  @override
  String get onboarding_living_openToDiscussion => 'قابل للنقاش';

  @override
  String get onboarding_living_openToDiscussionSub =>
      'أنا مرن وسعيد بمناقشة ما يناسب كلينا.';

  @override
  String get onboarding_label_preferredLiving => 'تفضيل ترتيب السكن';

  @override
  String get onboarding_preferredLiving_noPreference => 'لا تفضيل';

  @override
  String get copy_prayer_self => 'هل تصلي خمس مرات يومياً؟';

  @override
  String get copy_prayer_parent => 'هل يصلي طفلك خمس مرات يومياً؟';

  @override
  String get copy_prayer_sibling => 'هل يصلي أخوك/أختك خمس مرات يومياً؟';

  @override
  String get copy_hijab_self => 'هل ترتدين الحجاب؟';

  @override
  String get copy_hijab_parent => 'هل ترتدي ابنتك الحجاب؟';

  @override
  String get copy_hijab_sibling => 'هل ترتدي أختك الحجاب؟';

  @override
  String get copy_beard_self => 'هل تُطلق لحيتك؟';

  @override
  String get copy_beard_parent => 'هل يُطلق ابنك لحيته؟';

  @override
  String get copy_beard_sibling => 'هل يُطلق أخوك لحيته؟';

  @override
  String get onboarding_background_title => 'التعليم والمهنة';

  @override
  String get onboarding_label_educationLevel => 'المستوى التعليمي';

  @override
  String get onboarding_label_profession => 'المهنة';

  @override
  String get onboarding_hint_profession => 'مثال: مهندس برمجيات، معلم، طبيب';

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
      'يرجى إزالة معلومات الاتصال من نبذتك. لا يُسمح بمعلومات الاتصال الخارجية لحمايتك.';

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
      'يرجى استخدام صورة يظهر فيها وجهك بوضوح.';

  @override
  String get onboarding_error_multipleFaces =>
      'لا يمكن أن تكون صورة جماعية هي صورتك الأساسية.';

  @override
  String get discovery_header_title => 'نور';

  @override
  String discovery_label_profilesRemaining(int count) {
    return '$count ملفات متبقية اليوم';
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
    return 'تُفتح المراسلة خلال $hours ساعة. يمكنك إرسال إشعارات الاهتمام الآن.';
  }

  @override
  String get chat_label_subscribeToMessage =>
      'اشترك لفتح المراسلة. تراسل النساء مجانًا دائمًا في نور.';

  @override
  String get chat_opener_1 =>
      'السلام عليكم! لفت انتباهي ملفك الشخصي وأعجبني حقاً. هل تسمح لي بتقديم نفسي؟';

  @override
  String get chat_opener_2 =>
      'بسم الله. لفت ملفك الشخصي انتباهي. أود أن أعرف المزيد عنك.';

  @override
  String get chat_opener_3 =>
      'السلام عليكم. أعتقد أننا نتشارك قيمًا متشابهة. هل تقبل أن نتعرف على بعضنا البعض؟';

  @override
  String get chat_endMatch_title => 'إنهاء هذا التطابق';

  @override
  String get chat_endMatch_subtitle =>
      'اختر رسالة محترمة لإغلاق هذه المحادثة. سيتم إخطار الشخص الآخر.';

  @override
  String get chat_endMatch_button => 'إرسال وإنهاء التطابق';

  @override
  String get chat_matchClosed_banner => 'تم إغلاق هذا التطابق باحترام.';

  @override
  String get chat_closure_1 =>
      'السلام عليكم. بعد تأمل عميق، أشعر أن هذا قد لا يكون التطابق المناسب لنا. أتمنى لك كل التوفيق وأدعو الله أن يبارك لك في شريك رائع. جزاك الله خيرًا.';

  @override
  String get chat_closure_2 =>
      'السلام عليكم. أردت أن أكون صادقاً ومحترماً معك. لا أعتقد أننا التطابق المناسب، لكنني أدعو أن يفتح الله لك أبواباً أفضل. مع أطيب الأمنيات.';

  @override
  String get chat_closure_3 =>
      'السلام عليكم. بعد تفكير صادق، أشعر أننا قد لا نكون متوافقين. آمل أن تجد الشخص المناسب لك. جزاك الله خيرًا على وقتك.';

  @override
  String get chat_closure_4 =>
      'السلام عليكم. تأملت في محادثاتنا وأرى أنه من الأفضل إغلاق هذا التطابق. لدي كل الاحترام لك وأدعو الله أن يبارك لك بأفضل ما تستحق.';

  @override
  String get chat_closure_5 =>
      'السلام عليكم. أردت أن أكون شفافاً معك بدلاً من الاختفاء. لا أرى هذا يسير للأمام، لكنني أقدر وقتك وأتمنى لك كل السعادة. بارك الله فيك.';

  @override
  String get filter_label_motherTongue => 'اللغة الأم';

  @override
  String get filter_label_community => 'المجتمع / البيرادري';

  @override
  String get filter_label_livingExpectation => 'السكن بعد الزواج';

  @override
  String get subscription_title => 'افتح نور';

  @override
  String get subscription_subtitle =>
      'تراسل النساء مجانًا. يشترك الرجال للتواصل.';

  @override
  String subscription_button_monthly(String price) {
    return 'اشترك — $price/شهر';
  }

  @override
  String get subscription_label_bestValue => 'أفضل قيمة';

  @override
  String profile_label_completeness(int percent) {
    return 'الملف الشخصي مكتمل $percent%';
  }

  @override
  String get profile_nudge_completeness =>
      'الملفات الشخصية المكتملة بنسبة 80%+ تحصل على 3 أضعاف الاهتمامات.';

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
  String get settings_section_account => 'الحساب';

  @override
  String get settings_section_safety => 'الأمان';

  @override
  String get settings_section_app => 'التطبيق';

  @override
  String get settings_section_legal => 'القانونية';

  @override
  String get settings_section_dangerZone => 'منطقة الخطر';

  @override
  String get settings_button_deleteAccount => 'حذف الحساب';

  @override
  String get settings_label_deleteGrace =>
      'سيتم إخفاء ملفك الشخصي فورًا. سيتم حذف بياناتك نهائيًا بعد 30 يومًا.';

  @override
  String get settings_section_notifications => 'الإشعارات';

  @override
  String get settings_section_guardian => 'الولي';

  @override
  String get settings_section_privacy => 'الخصوصية';

  @override
  String get notifications_title => 'الإشعارات';

  @override
  String get notifications_markAllRead => 'تعليم الكل كمقروء';

  @override
  String get notifications_empty_title => 'لا جديد لديك';

  @override
  String get notifications_empty_subtitle => 'لا توجد إشعارات جديدة الآن.';

  @override
  String get deleteAccount_title => 'حذف الحساب';

  @override
  String get interests_title => 'الاهتمامات';

  @override
  String get onboarding_profileForWhom_subtitle =>
      'يمكنك تحديث هذا لاحقًا من الإعدادات.';

  @override
  String get onboarding_profileForWhom_guardianCardTitle => 'ولي الأمر';

  @override
  String get onboarding_profileForWhom_guardianCardSub =>
      'أقوم بإنشاء هذا الملف الشخصي لشخص آخر';

  @override
  String get onboarding_profileForWhom_creatingFor =>
      'أنا أقوم بإنشاء هذا الملف لـ...';

  @override
  String get onboarding_profileForWhom_relation_son => 'ابني';

  @override
  String get onboarding_profileForWhom_relation_daughter => 'ابنتي';

  @override
  String get onboarding_profileForWhom_relation_brother => 'أخي';

  @override
  String get onboarding_profileForWhom_relation_sister => 'أختي';

  @override
  String get onboarding_profileForWhom_selectRelation =>
      'اختر صلة القرابة للمتابعة';

  @override
  String get onboarding_profileForWhom_selectOne => 'اختر خياراً للمتابعة';

  @override
  String onboarding_basicIdentity_guardianBanner(String relation) {
    return 'أنت تملأ هذه البيانات كولي أمر. هذه التفاصيل تخص $relation.';
  }

  @override
  String onboarding_basicIdentity_title_guardian(String relation) {
    return 'أخبرنا عن $relation';
  }

  @override
  String get onboarding_basicIdentity_subtitle_self =>
      'هذا ما سيراه الآخرون في ملفك الشخصي.';

  @override
  String get onboarding_basicIdentity_subtitle_guardian =>
      'هذا ما سيراه الآخرون في ملفه/ملفها الشخصي.';

  @override
  String get onboarding_label_firstName_self => 'الاسم الأول';

  @override
  String get onboarding_label_firstName_guardian => 'الاسم الأول للمرشح';

  @override
  String get onboarding_hint_selectDateOfBirth => 'اختر تاريخ الميلاد';

  @override
  String onboarding_error_under18_guardian(String relation) {
    return 'يجب أن يكون $relation بعمر 18 عامًا أو أكثر لاستخدام نور.';
  }

  @override
  String get onboarding_error_under18_self =>
      'يجب أن تكون بعمر 18 عامًا أو أكثر لاستخدام نور. نتطلع إلى الترحيب بك حينها.';

  @override
  String get onboarding_label_gender_self => 'الجنس';

  @override
  String get onboarding_label_gender_guardian => 'جنس المرشح';

  @override
  String get onboarding_label_country_self => 'بلدك';

  @override
  String get onboarding_label_country_guardian => 'بلدهم';

  @override
  String get onboarding_hint_selectCountry => 'اختر البلد';

  @override
  String get onboarding_label_city_self => 'مدينتك';

  @override
  String get onboarding_label_city_guardian => 'مدينتهم';

  @override
  String get onboarding_location_confirmed => 'تم تأكيد الموقع';

  @override
  String get onboarding_hint_selectCommunity => 'اختر المجتمع (اختياري)';

  @override
  String get onboarding_label_height_self => 'طولك';

  @override
  String get onboarding_label_height_guardian => 'طولهم';

  @override
  String get onboarding_label_complexion => 'البشرة (اختياري)';

  @override
  String get onboarding_hint_selectLanguage => 'اختر اللغة';

  @override
  String get onboarding_label_residencyStatus => 'حالة الإقامة (اختياري)';

  @override
  String get onboarding_label_specialNeeds => 'ذوو الاحتياجات الخاصة (اختياري)';

  @override
  String get onboarding_islamicIdentity_subtitle =>
      'هذا يساعد في مطابقتك مع شخص متوافق.';

  @override
  String get onboarding_label_subSect => 'المذهب الفقهي (اختياري)';

  @override
  String get onboarding_label_revert => 'حديث عهد بالإسلام (اختياري)';

  @override
  String get onboarding_label_revertQuestion => 'هل أنت مسلم جديد (مهتدٍ)؟';

  @override
  String get onboarding_hijab_always => 'دائماً';

  @override
  String get onboarding_hijab_sometimes => 'أحياناً';

  @override
  String get onboarding_hijab_no => 'لا';

  @override
  String get onboarding_label_leadership => 'الإمامة الدينية';

  @override
  String get onboarding_label_leadershipQuestion =>
      'هل يمكنك إمامة صلاة الجماعة؟';

  @override
  String get onboarding_leadership_leads => 'يؤم المصلين';

  @override
  String get onboarding_leadership_learning => 'يتعلم';

  @override
  String get onboarding_leadership_notYet => 'ليس بعد';

  @override
  String get onboarding_label_lifestyleDiet => 'نمط الحياة والغذاء';

  @override
  String get onboarding_label_lifestyleDietSub =>
      'هذه حقول حاسمة للعديد من العائلات. يرجى الإجابة بصدق.';

  @override
  String get onboarding_label_substanceUse => 'تعاطي المؤثرات';

  @override
  String get onboarding_marriageDeen_title => 'الزواج والدين';

  @override
  String get onboarding_marriageDeen_subtitle =>
      'ساعدنا في فهم رحلتك ومدى استعدادك.';

  @override
  String get onboarding_label_quranMemorization => 'حفظ القرآن';

  @override
  String get onboarding_quran_none => 'لا يوجد';

  @override
  String get onboarding_quran_some => 'بعض السور';

  @override
  String get onboarding_quran_partial => 'حفظ جزئي';

  @override
  String get onboarding_quran_hafiz => 'حافظ / حافظة';

  @override
  String get onboarding_label_religiousEducation => 'التعليم الديني';

  @override
  String get onboarding_religiousEdu_selfTaught => 'تعلم ذاتي';

  @override
  String get onboarding_religiousEdu_madrasa => 'مدرسة دينية';

  @override
  String get onboarding_religiousEdu_islamicUni => 'جامعة إسلامية';

  @override
  String get onboarding_religiousEdu_alim => 'دورة عالم';

  @override
  String get onboarding_label_marriageTimeline => 'الجدول الزمني للزواج';

  @override
  String get onboarding_label_marriageTimelineQuestion => 'متى تتطلع للزواج؟';

  @override
  String get onboarding_timeline_asap => 'في أقرب وقت ممكن';

  @override
  String get onboarding_timeline_6months => 'خلال 6 أشهر';

  @override
  String get onboarding_timeline_1year => 'خلال سنة';

  @override
  String get onboarding_timeline_2years => 'سنتين أو أكثر';

  @override
  String get onboarding_timeline_notSure => 'غير متأكد بعد';

  @override
  String get onboarding_label_niqab => 'النقاب';

  @override
  String get onboarding_niqab_wear => 'أرتدي النقاب';

  @override
  String get onboarding_niqab_open => 'متقبلة لارتدائه';

  @override
  String get onboarding_niqab_dontWear => 'لا أرتدي النقاب';

  @override
  String get onboarding_label_mahrExpectation => 'توقع المهر';

  @override
  String get onboarding_label_mahrExpectationQuestion => 'ما هو توقعك للمهر؟';

  @override
  String get onboarding_mahr_noPreference => 'لا يوجد تفضيل';

  @override
  String get onboarding_mahr_modest => 'يسير';

  @override
  String get onboarding_mahr_moderate => 'معتدل';

  @override
  String get onboarding_mahr_generous => 'سخي';

  @override
  String get onboarding_mahr_toDiscuss => 'للنقاش';

  @override
  String get onboarding_label_workAfterMarriage => 'العمل بعد الزواج';

  @override
  String get onboarding_label_workAfterMarriageQuestion =>
      'هل تودين العمل بعد الزواج؟';

  @override
  String get onboarding_work_yes => 'نعم، أخطط للعمل';

  @override
  String get onboarding_work_no => 'لا، أفضّل عدم العمل';

  @override
  String get onboarding_label_mahrBudget => 'ميزانية المهر';

  @override
  String get onboarding_label_mahrBudgetQuestion =>
      'ما هو نطاق المهر المستعد لتقديمه؟';

  @override
  String get onboarding_label_providerReadiness => 'الاستعداد للقوامة';

  @override
  String get onboarding_providerQuote =>
      '\"خياركم خياركم لنسائهم\" — الرسول محمد صلى الله عليه وسلم\n\nالصدق بشأن استعدادك يساعد في بناء أساس قوي.';

  @override
  String get onboarding_label_housing => 'السكن';

  @override
  String get onboarding_label_housingQuestion => 'هل يمكنك توفير مسكن مستقل؟';

  @override
  String get onboarding_label_maintenance => 'النفقة المالية';

  @override
  String get onboarding_label_maintenanceQuestion =>
      'هل أنت قادر على إعالة زوجة ماليًا؟';

  @override
  String get onboarding_label_debtStatus => 'حالة الديون';

  @override
  String get onboarding_label_debtStatusQuestion =>
      'التزاماتك المالية الحالية.';

  @override
  String get onboarding_debt_none => 'لا توجد ديون';

  @override
  String get onboarding_debt_manageable => 'ديون يمكن إدارتها';

  @override
  String get onboarding_debt_significant => 'ديون كبيرة';

  @override
  String get onboarding_marriageDeen_privacyNotice =>
      'هذه التفاصيل لا تظهر في ملفك الشخصي العام. يتم مشاركتها بشكل خاص أثناء مرحلة القبول.';
}
