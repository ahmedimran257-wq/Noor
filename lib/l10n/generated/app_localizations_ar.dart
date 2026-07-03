// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get about_button_later => 'سأفعل هذا لاحقاً';

  @override
  String about_hint_bio_guardian(Object relation) {
    return 'صف $relation بصدق ووقار.';
  }

  @override
  String get about_hint_bio_self => 'صف نفسك بصدق ووقار.';

  @override
  String get about_label_bio_guardian => 'النبذة الشخصية';

  @override
  String get about_label_bio_self => 'نبذة عنك';

  @override
  String get about_label_interests => 'الاهتمامات';

  @override
  String get about_label_languages => 'اللغات التي تتحدثها';

  @override
  String about_label_selected_count(Object current, Object max) {
    return 'تم اختيار $current من $max';
  }

  @override
  String get about_subtitle => 'اكتب بصدق ووقار.';

  @override
  String about_title_guardian(Object relation) {
    return 'نبذة عن $relation';
  }

  @override
  String get about_title_self => 'نبذة عنك';

  @override
  String get appName => 'ميثاق';

  @override
  String get appTagline => 'ابدأ بسم الله';

  @override
  String get auth_button_resendOtp => 'إعادة إرسال رمز التحقق';

  @override
  String get auth_button_sendCode => 'إرسال رمز التحقق';

  @override
  String get auth_button_sendOtp => 'إرسال رمز التحقق';

  @override
  String get auth_button_verifyOtp => 'تحقق';

  @override
  String get auth_hint_phoneNumber => 'رقم الهاتف';

  @override
  String get auth_label_changeNumber => 'رقم خاطئ؟ قم بتغييره';

  @override
  String get auth_label_enterOtp =>
      'أدخل رمز التحقق المكوّن من 6 أرقام المرسل إلى';

  @override
  String get auth_label_phoneNumber => 'رقم الهاتف';

  @override
  String get auth_label_resendCode => 'إعادة إرسال رمز التحقق';

  @override
  String auth_label_resendCodeIn(Object seconds) {
    return 'إعادة إرسال رمز التحقق خلال $secondsث';
  }

  @override
  String auth_label_resendIn(int seconds) {
    return 'إعادة الإرسال خلال $secondsث';
  }

  @override
  String get auth_label_sentCodeTo =>
      'لقد أرسلنا رمز تحقق مكونًا من 6 أرقام إلى\n';

  @override
  String get auth_subtitle_verifyOtp => 'سوف نتحقق منه برمز لمرة واحدة.';

  @override
  String get auth_title_enterCode => 'أدخل رمز التحقق';

  @override
  String get auth_title_yourNumber => 'رقم هاتفك';

  @override
  String get background_edu_bachelors => 'درجة البكالوريوس';

  @override
  String get background_edu_below_secondary => 'أقل من الثانوي';

  @override
  String get background_edu_diploma => 'دبلوم / مشارك';

  @override
  String get background_edu_doctorate => 'الدكتوراه / PhD';

  @override
  String get background_edu_higher_secondary => 'ثانوي عام / A-Level';

  @override
  String get background_edu_masters => 'درجة الماجستير';

  @override
  String get background_edu_secondary => 'ثانوي / O-Level';

  @override
  String background_edu_subtitle_guardian(Object relation) {
    return 'أخبرنا عن تعليم وعمل $relation.';
  }

  @override
  String get background_edu_subtitle_self =>
      'يساعد في العثور على مطابقات متوافقة مهنيًا.';

  @override
  String get background_edu_title_guardian => 'خلفيتهم';

  @override
  String get background_edu_title_self => 'خلفيتك';

  @override
  String get background_emp_employed => 'موظف';

  @override
  String get background_emp_not_working => 'لا يعمل';

  @override
  String get background_emp_self_employed => 'أعمال حرة';

  @override
  String get background_emp_student => 'طالب';

  @override
  String get background_income_subtitle =>
      'يتخطى الكثير من الأشخاص هذا — فهو اختياري تمامًا.';

  @override
  String get background_label_eduLevel => 'مستوى التعليم';

  @override
  String get background_label_employment => 'الحالة الوظيفية';

  @override
  String background_label_income_bracket(Object currency) {
    return 'فئة الدخل ($currency)';
  }

  @override
  String get background_label_income_range => 'نطاق الدخل (اختياري)';

  @override
  String get background_label_profession => 'المهنة (اختياري)';

  @override
  String get background_label_study => 'مجال الدراسة (اختياري)';

  @override
  String get background_label_who_see => 'من يمكنه رؤية هذا؟';

  @override
  String get background_vis_everyone => 'عرض الفئة للجميع';

  @override
  String get background_vis_mutual => 'عرض فقط بعد الاهتمام المتبادل';

  @override
  String get background_vis_private => 'إبقاء خاص';

  @override
  String get ceremony_text_blessing => 'اسأل الله أن يبارك هذا بالخير';

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
  String get chat_endMatch_button => 'إرسال وإنهاء التطابق';

  @override
  String get chat_endMatch_subtitle =>
      'اختر رسالة محترمة لإغلاق هذه المحادثة. سيتم إخطار الشخص الآخر.';

  @override
  String get chat_endMatch_title => 'إنهاء هذا التطابق';

  @override
  String chat_label_probation(int hours) {
    return 'تُفتح المراسلة خلال $hours ساعة. يمكنك إرسال إشعارات الاهتمام الآن.';
  }

  @override
  String get chat_label_subscribeToMessage =>
      'اشترك لفتح المراسلة. تراسل النساء مجانًا دائمًا في ميثاق.';

  @override
  String get chat_matchClosed_banner => 'تم إغلاق هذا التطابق باحترام.';

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
  String get chat_placeholder_typeMessage => 'اكتب رسالة…';

  @override
  String get common_button_back => 'رجوع';

  @override
  String get common_button_cancel => 'إلغاء';

  @override
  String get common_button_done => 'تم';

  @override
  String get common_button_next => 'التالي';

  @override
  String get common_button_retry => 'حاول مرة أخرى';

  @override
  String get common_button_save => 'حفظ';

  @override
  String get common_button_skip => 'تخطي';

  @override
  String get common_button_submit => 'إرسال';

  @override
  String get common_error_generic => 'حدث خطأ ما. يرجى المحاولة مرة أخرى.';

  @override
  String get common_error_noInternet => 'لا يوجد اتصال بالإنترنت.';

  @override
  String get common_label_optional => 'اختياري';

  @override
  String get copy_beard_parent => 'هل يُطلق ابنك لحيته؟';

  @override
  String get copy_beard_self => 'هل تُطلق لحيتك؟';

  @override
  String get copy_beard_sibling => 'هل يُطلق أخوك لحيته؟';

  @override
  String get copy_hijab_parent => 'هل ترتدي ابنتك الحجاب؟';

  @override
  String get copy_hijab_self => 'هل ترتدين الحجاب؟';

  @override
  String get copy_hijab_sibling => 'هل ترتدي أختك الحجاب؟';

  @override
  String get copy_prayer_parent => 'هل يصلي طفلك خمس مرات يومياً؟';

  @override
  String get copy_prayer_self => 'هل تصلي خمس مرات يومياً؟';

  @override
  String get copy_prayer_sibling => 'هل يصلي أخوك/أختك خمس مرات يومياً؟';

  @override
  String get deleteAccount_title => 'حذف الحساب';

  @override
  String discovery_bookmark_removed(Object name) {
    return 'تم إزالة $name';
  }

  @override
  String discovery_bookmark_saved(Object name) {
    return 'تم حفظ $name';
  }

  @override
  String get discovery_button_sendInterest => 'إرسال إشعار الاهتمام';

  @override
  String get discovery_completeness_button => 'أكمل الملف الشخصي';

  @override
  String get discovery_completeness_subtitle =>
      'الملفات الشخصية التي تتجاوز ٤٠٪ تحصل على اهتمام أكثر بـ ٣ مرات.\nأكمل ملفك الشخصي لبدء التصفح.';

  @override
  String get discovery_completeness_title => 'أكمل ملفك الشخصي';

  @override
  String get discovery_empty_subtitle =>
      'حاول توسيع فلاتر البحث\nأو تحقق مجدداً غداً.';

  @override
  String get discovery_empty_title => 'لقد شاهدت الجميع بالقرب منك';

  @override
  String get discovery_header_title => 'ميثاق';

  @override
  String get discovery_label_interestSent => 'تم الإرسال ✓';

  @override
  String get discovery_label_outsidePrefs => 'شخص قد تتواصل معه';

  @override
  String discovery_label_profilesRemaining(int count) {
    return '$count ملفات متبقية اليوم';
  }

  @override
  String get discovery_limit_button => 'اشترك الآن';

  @override
  String get discovery_limit_subtitle =>
      'لقد تصفحت ١٥ ملفاً شخصياً اليوم.\nاشترك لفتح تصفح غير محدود.';

  @override
  String get discovery_limit_title => 'تم الوصول للحد اليومي';

  @override
  String discovery_remaining_profiles(Object count) {
    return 'متبقي $count ملفات شخصية';
  }

  @override
  String get discovery_wildcard_label => 'شخص قد تتوافق معه';

  @override
  String get family_children_no => 'لا';

  @override
  String get family_children_yes => 'نعم';

  @override
  String get family_label_children_guardian => 'هل لديهم أطفال؟';

  @override
  String get family_label_children_self => 'هل لديك أطفال؟';

  @override
  String get family_label_how_many => 'كم عددهم؟';

  @override
  String get family_label_parents => 'الحالة الاجتماعية للوالدين';

  @override
  String get family_label_polygamy_female_self => 'قبول التعدد (اختياري)';

  @override
  String get family_label_polygamy_male_self => 'الحالة التعددية (اختياري)';

  @override
  String get family_label_prev_married => 'هل سبق له/لها الزواج؟';

  @override
  String get family_label_relocate => 'الرغبة في الانتقال';

  @override
  String get family_label_siblings => 'عدد الإخوة';

  @override
  String get family_label_type => 'نوع العائلة';

  @override
  String get family_living_title => 'توقعات السكن بعد الزواج';

  @override
  String get family_parents_both_deceased => 'كلا الوالدين متوفيان';

  @override
  String get family_parents_divorced => 'مطلقان';

  @override
  String get family_parents_father_deceased => 'الأب متوفى';

  @override
  String get family_parents_mother_deceased => 'الأم متوفاة';

  @override
  String get family_parents_separated => 'منفصلان';

  @override
  String get family_parents_together => 'معاً';

  @override
  String get family_polygamy_female_discussion => 'قابل للنقاش';

  @override
  String get family_polygamy_female_no => 'لا';

  @override
  String get family_polygamy_female_prefer_not => 'أفضل عدم الإجابة';

  @override
  String family_polygamy_female_sub_guardian(Object relation) {
    return 'هل تفكر $relation في أن تكون زوجة ثانية؟';
  }

  @override
  String get family_polygamy_female_sub_self =>
      'هل تفكرين في أن تكوني زوجة ثانية؟';

  @override
  String get family_polygamy_female_yes => 'نعم';

  @override
  String family_polygamy_male_sub_guardian(Object relation) {
    return 'هل $relation متزوج حاليًا ويبحث عن زوجة أخرى؟';
  }

  @override
  String get family_polygamy_male_sub_self =>
      'هل أنت متزوج حاليًا وتبحث عن زوجة أخرى؟';

  @override
  String get family_polygamy_option_first => 'لا، هذا زواجي الأول';

  @override
  String get family_polygamy_option_married => 'نعم، متزوج حالياً';

  @override
  String get family_polygamy_option_prefer_not => 'أفضل عدم الإجابة';

  @override
  String get family_prev_divorced => 'مطلق/ة';

  @override
  String get family_prev_no => 'لا';

  @override
  String get family_prev_widowed => 'أرمل/ة';

  @override
  String get family_relocate_discussion => 'قابل للنقاش';

  @override
  String get family_relocate_no => 'لا';

  @override
  String family_relocate_subtitle_guardian(Object relation) {
    return 'هل يرغب $relation في الانتقال من أجل الزواج؟';
  }

  @override
  String get family_relocate_subtitle_self =>
      'هل ترغب في الانتقال من أجل الزواج؟';

  @override
  String get family_relocate_yes => 'نعم';

  @override
  String family_subtitle_guardian(Object relation) {
    return 'أخبرنا عن عائلة $relation.';
  }

  @override
  String get family_subtitle_self =>
      'التوافق العائلي أمر أساسي للزواج المستمر.';

  @override
  String get family_title_guardian => 'الخلفية العائلية';

  @override
  String get family_title_self => 'الخلفية العائلية';

  @override
  String get family_type_extended => 'أسرة ممتدة';

  @override
  String get family_type_joint => 'أسرة مشتركة';

  @override
  String get family_type_nuclear => 'أسرة نواة';

  @override
  String get filter_label_community => 'المجتمع / البيرادري';

  @override
  String get filter_label_livingExpectation => 'السكن بعد الزواج';

  @override
  String get filter_label_motherTongue => 'اللغة الأم';

  @override
  String get guardian_details_candidate_female =>
      'مرشحة أنثى • مراسلة النساء مجانية';

  @override
  String get guardian_details_candidate_label => 'إنشاء ملف شخصي لـ';

  @override
  String get guardian_details_candidate_male => 'مرشح ذكر';

  @override
  String guardian_details_candidate_relation(Object relation) {
    return 'لـ $relation';
  }

  @override
  String get guardian_details_involvement => 'مشاركة الولي / الوصي';

  @override
  String get guardian_details_involvement_subtitle =>
      'ما مدى رغبتك في المشاركة في المحادثات؟';

  @override
  String guardian_details_mode_active_sub(Object relation) {
    return 'رؤية الدردشات، والموافقة على المطابقات، وإرسال الرسائل نيابة عن $relation.';
  }

  @override
  String get guardian_details_mode_active_title => 'ولي أمر نشط';

  @override
  String guardian_details_mode_passive_sub(Object relation) {
    return 'رؤية جميع الدردشات في الوقت الفعلي، ولكن يمكن لـ $relation فقط إرسال الرسائل.';
  }

  @override
  String get guardian_details_mode_passive_title => 'مراقبة فقط';

  @override
  String get guardian_details_name_hint => 'الاسم الكامل';

  @override
  String get guardian_details_name_subtitle =>
      'اسمك كولي/وصي. يظهر هذا للمطابقات.';

  @override
  String guardian_details_notice(Object relation) {
    return 'أنت تقوم بإنشاء ملف شخصي لـ $relation. جميع تفاصيل الملف الشخصي في الشاشات التالية ستصفهم، وليس أنت.';
  }

  @override
  String get guardian_details_phone_hint => 'رقم الهاتف';

  @override
  String get guardian_details_phone_subtitle =>
      'للتحقق من الحساب. لا يظهر على الملف الشخصي.';

  @override
  String guardian_details_privacy_note(Object relation) {
    return 'رقم هاتفك مشفر ولا يظهر علنًا أبدًا. ستظهر عبارة \"ولي أمر $relation\" للمطابقات المحتملة على الملف الشخصي.';
  }

  @override
  String get guardian_details_search_hint => 'بحث';

  @override
  String get guardian_details_select_code => 'اختر رمز الدولة';

  @override
  String get guardian_details_subtitle =>
      'أخبرنا عن نفسك بصفتك الولي أو الوصي.';

  @override
  String get guardian_details_title => 'تفاصيل الولي / الوصي';

  @override
  String get guardian_details_your_name => 'اسمك';

  @override
  String get guardian_details_your_phone => 'رقم هاتفك';

  @override
  String get interest_cat_creative => 'الإبداع والفنون';

  @override
  String get interest_cat_faith => 'الإيمان والعبادات';

  @override
  String get interest_cat_learning => 'التعليم والمعرفة';

  @override
  String get interest_cat_lifestyle => 'نمط الحياة';

  @override
  String get interest_cat_social => 'الحياة الاجتماعية';

  @override
  String get interest_cat_sports => 'الرياضة';

  @override
  String get interest_tag_art => 'الفن';

  @override
  String get interest_tag_calligraphy => 'الخط العربي';

  @override
  String get interest_tag_community_work => 'العمل المجتمعي';

  @override
  String get interest_tag_cooking => 'الطبخ';

  @override
  String get interest_tag_crafts => 'الأعمال اليدوية';

  @override
  String get interest_tag_cricket => 'الكريكت';

  @override
  String get interest_tag_cycling => 'ركوب الدراجات';

  @override
  String get interest_tag_dawah => 'الدعوة';

  @override
  String get interest_tag_family_gatherings => 'التجمعات العائلية';

  @override
  String get interest_tag_fitness => 'اللياقة البدنية';

  @override
  String get interest_tag_football => 'كرة القدم';

  @override
  String get interest_tag_gardening => 'البستنة';

  @override
  String get interest_tag_graphic_design => 'تصميم الجرافيك';

  @override
  String get interest_tag_hiking => 'المشي الجبلي';

  @override
  String get interest_tag_history => 'التاريخ';

  @override
  String get interest_tag_islamic_lectures => 'المحاضرات الإسلامية';

  @override
  String get interest_tag_languages => 'اللغات';

  @override
  String get interest_tag_martial_arts => 'الفنون القتالية';

  @override
  String get interest_tag_mentoring => 'التوجيه والإرشاد';

  @override
  String get interest_tag_photography => 'التصوير';

  @override
  String get interest_tag_poetry => 'الشعر';

  @override
  String get interest_tag_quran_recitation => 'تلاوة القرآن';

  @override
  String get interest_tag_reading => 'القراءة';

  @override
  String get interest_tag_science => 'العلوم';

  @override
  String get interest_tag_swimming => 'السباحة';

  @override
  String get interest_tag_tahajjud => 'قيام الليل / التهجد';

  @override
  String get interest_tag_teaching => 'التعليم';

  @override
  String get interest_tag_technology => 'التكنولوجيا';

  @override
  String get interest_tag_travel => 'السفر';

  @override
  String get interest_tag_umrah_hajj => 'العمرة / الحج';

  @override
  String get interest_tag_voluntary_fasting => 'صيام التطوع';

  @override
  String get interest_tag_volunteering => 'العمل التطوعي';

  @override
  String get interest_tag_writing => 'الكتابة';

  @override
  String get interests_button_accept => 'قبول';

  @override
  String get interests_button_decline => 'رفض';

  @override
  String get interests_tab_received => 'المُستلَمة';

  @override
  String get interests_tab_sent => 'المُرسَلة';

  @override
  String get interests_title => 'الاهتمامات';

  @override
  String get lang_albanian => 'الألبانية';

  @override
  String get lang_amazigh => 'الأمازيغية';

  @override
  String get lang_amharic => 'الأمهرية';

  @override
  String get lang_arabic => 'العربية';

  @override
  String get lang_assamese => 'الآسامية';

  @override
  String get lang_balochi => 'البلوشية';

  @override
  String get lang_bengali => 'البنغالية';

  @override
  String get lang_bosnian => 'البوسنية';

  @override
  String get lang_burmese => 'البورمية';

  @override
  String get lang_chechen => 'الشيشانية';

  @override
  String get lang_chinese => 'الصينية (الماندرين)';

  @override
  String get lang_dari => 'الدرية';

  @override
  String get lang_dutch => 'الهولندية';

  @override
  String get lang_english => 'الإنجليزية';

  @override
  String get lang_french => 'الفرنسية';

  @override
  String get lang_fulani => 'الفولانية';

  @override
  String get lang_german => 'الألمانية';

  @override
  String get lang_gujarati => 'الغوجاراتية';

  @override
  String get lang_hausa => 'الهوسا';

  @override
  String get lang_hindi => 'الهندية';

  @override
  String get lang_igbo => 'الإيجبوية';

  @override
  String get lang_indonesian => 'الإندونيسية';

  @override
  String get lang_italian => 'الإيطالية';

  @override
  String get lang_japanese => 'اليابانية';

  @override
  String get lang_javanese => 'الجاوية';

  @override
  String get lang_kannada => 'الكانادية';

  @override
  String get lang_kazakh => 'الكازاخية';

  @override
  String get lang_korean => 'الكورية';

  @override
  String get lang_kurdish => 'الكردية';

  @override
  String get lang_kyrgyz => 'القيرغيزية';

  @override
  String get lang_malay => 'الملايوية';

  @override
  String get lang_malayalam => 'المليالمية';

  @override
  String get lang_mandinka => 'الماندينكوية';

  @override
  String get lang_marathi => 'الماراثية';

  @override
  String get lang_norwegian => 'النرويجية';

  @override
  String get lang_odia => 'الأودية';

  @override
  String get lang_other => 'أخرى';

  @override
  String get lang_pashto => 'البشتوية';

  @override
  String get lang_persian => 'الفارسية';

  @override
  String get lang_portuguese => 'البرتغالية';

  @override
  String get lang_punjabi => 'البنجابية';

  @override
  String get lang_rohingya => 'الروهينغية';

  @override
  String get lang_russian => 'الروسية';

  @override
  String get lang_saraiki => 'السرائيكية';

  @override
  String get lang_sindhi => 'السندية';

  @override
  String get lang_somali => 'الصومالية';

  @override
  String get lang_spanish => 'الإسبانية';

  @override
  String get lang_sundanese => 'السوندية';

  @override
  String get lang_swahili => 'السواحيلية';

  @override
  String get lang_swedish => 'السويدية';

  @override
  String get lang_tagalog => 'التاغالوغية';

  @override
  String get lang_tajik => 'الطاجيكية';

  @override
  String get lang_tamil => 'التاميلية';

  @override
  String get lang_tatar => 'التتارية';

  @override
  String get lang_telugu => 'التيلوغوية';

  @override
  String get lang_thai => 'التايلاندية';

  @override
  String get lang_tigrinya => 'التغرينية';

  @override
  String get lang_turkish => 'التركية';

  @override
  String get lang_urdu => 'الأردية';

  @override
  String get lang_uzbek => 'الأوزبكية';

  @override
  String get lang_wolof => 'الولوفية';

  @override
  String get lang_yoruba => 'اليوروبية';

  @override
  String get legal_button_continue => 'متابعة';

  @override
  String get legal_checkbox_age => 'أؤكد أنني بلغت 18 عامًا أو أكثر';

  @override
  String get legal_checkbox_terms => 'أوافق على شروط الخدمة وسياسة الخصوصية';

  @override
  String get legal_subtitle => 'يرجى القراءة والموافقة للمتابعة.';

  @override
  String get legal_summary_1 =>
      'بياناتك مشفرة ولا يتم مشاركتها أو بيعها لأطراف ثالثة.';

  @override
  String get legal_summary_2 => 'تتم مراجعة صورك يدويًا لضمان سلامة مجتمعنا.';

  @override
  String get legal_summary_3 =>
      'المضايقات، الحسابات المزيفة، أو السلوكيات غير اللائقة تؤدي للحظر الدائم.';

  @override
  String get legal_summary_4 =>
      'هذه المنصة مخصصة لنية الزواج فقط. الوقار هو معيارنا.';

  @override
  String get legal_summary_5 =>
      'يمكنك حذف حسابك وجميع بياناتك نهائيًا في أي وقت.';

  @override
  String get legal_title => 'قبل أن تبدأ';

  @override
  String get notifications_empty_subtitle => 'لا توجد إشعارات جديدة الآن.';

  @override
  String get notifications_empty_title => 'لا جديد لديك';

  @override
  String get notifications_markAllRead => 'تعليم الكل كمقروء';

  @override
  String get notifications_title => 'الإشعارات';

  @override
  String get onboarding_about_title => 'عن نفسك';

  @override
  String get onboarding_background_title => 'التعليم والمهنة';

  @override
  String onboarding_basicIdentity_guardianBanner(String relation) {
    return 'أنت تملأ هذه البيانات كولي أمر. هذه التفاصيل تخص $relation.';
  }

  @override
  String get onboarding_basicIdentity_subtitle_guardian =>
      'هذا ما سيراه الآخرون في ملفه/ملفها الشخصي.';

  @override
  String get onboarding_basicIdentity_subtitle_self =>
      'هذا ما سيراه الآخرون في ملفك الشخصي.';

  @override
  String get onboarding_basicIdentity_title => 'أخبرنا عن نفسك';

  @override
  String onboarding_basicIdentity_title_guardian(String relation) {
    return 'أخبرنا عن $relation';
  }

  @override
  String get onboarding_debt_manageable => 'ديون يمكن إدارتها';

  @override
  String get onboarding_debt_none => 'لا توجد ديون';

  @override
  String get onboarding_debt_significant => 'ديون كبيرة';

  @override
  String get onboarding_diet_eatsAnything => 'يأكل أي شيء حلال';

  @override
  String get onboarding_diet_halalOnly => 'حلال فقط';

  @override
  String get onboarding_diet_vegan => 'نباتي صارم';

  @override
  String get onboarding_diet_vegetarian => 'نباتي';

  @override
  String get onboarding_diet_zabihaStrict => 'ذبيحة إسلامية صارمة';

  @override
  String get onboarding_error_bioContactInfo =>
      'يرجى إزالة معلومات الاتصال من نبذتك. لا يُسمح بمعلومات الاتصال الخارجية لحمايتك.';

  @override
  String get onboarding_error_multipleFaces =>
      'لا يمكن أن تكون صورة جماعية هي صورتك الأساسية.';

  @override
  String get onboarding_error_noFace =>
      'يرجى استخدام صورة يظهر فيها وجهك بوضوح.';

  @override
  String get onboarding_error_under18 =>
      'ميثاق مخصص لمن هم في سن 18 عامًا أو أكثر.';

  @override
  String onboarding_error_under18_guardian(String relation) {
    return 'يجب أن يكون $relation بعمر 18 عامًا أو أكثر لاستخدام ميثاق.';
  }

  @override
  String get onboarding_error_under18_self =>
      'يجب أن تكون بعمر 18 عامًا أو أكثر لاستخدام ميثاق. نتطلع إلى الترحيب بك حينها.';

  @override
  String get onboarding_habit_frequently => 'كثيراً';

  @override
  String get onboarding_habit_never => 'أبداً';

  @override
  String get onboarding_habit_occasionally => 'أحياناً';

  @override
  String get onboarding_habit_preferNotToSay => 'أفضل عدم الإجابة';

  @override
  String get onboarding_hijab_always => 'دائماً';

  @override
  String get onboarding_hijab_no => 'لا';

  @override
  String get onboarding_hijab_sometimes => 'أحياناً';

  @override
  String get onboarding_hint_bio => 'صِف نفسك بصدق وكرامة.';

  @override
  String get onboarding_hint_profession => 'مثال: مهندس برمجيات، معلم، طبيب';

  @override
  String get onboarding_hint_searchCity => 'ابحث عن مدينتك…';

  @override
  String get onboarding_hint_selectCommunity => 'اختر المجتمع (اختياري)';

  @override
  String get onboarding_hint_selectCountry => 'اختر البلد';

  @override
  String get onboarding_hint_selectDateOfBirth => 'اختر تاريخ الميلاد';

  @override
  String get onboarding_hint_selectLanguage => 'اختر اللغة';

  @override
  String get onboarding_islamicIdentity_subtitle =>
      'هذا يساعد في مطابقتك مع شخص متوافق.';

  @override
  String get onboarding_islamicIdentity_title => 'هويتك الإسلامية';

  @override
  String onboarding_label_bioCount(int count) {
    return '$count/300';
  }

  @override
  String get onboarding_label_city => 'المدينة';

  @override
  String get onboarding_label_city_guardian => 'مدينتهم';

  @override
  String get onboarding_label_city_self => 'مدينتك';

  @override
  String get onboarding_label_community => 'مجتمعك / بيرادري';

  @override
  String get onboarding_label_community_parent => 'مجتمعهم / بيرادري';

  @override
  String get onboarding_label_complexion => 'البشرة (اختياري)';

  @override
  String get onboarding_label_country_guardian => 'بلدهم';

  @override
  String get onboarding_label_country_self => 'بلدك';

  @override
  String get onboarding_label_cultural => 'مسلم ثقافي';

  @override
  String get onboarding_label_dateOfBirth => 'تاريخ الميلاد';

  @override
  String get onboarding_label_debtStatus => 'حالة الديون';

  @override
  String get onboarding_label_debtStatusQuestion =>
      'التزاماتك المالية الحالية.';

  @override
  String get onboarding_label_deenLevel => 'مستوى التديّن';

  @override
  String get onboarding_label_diet => 'النظام الغذائي';

  @override
  String get onboarding_label_educationLevel => 'المستوى التعليمي';

  @override
  String get onboarding_label_female => 'أنثى';

  @override
  String get onboarding_label_firstName => 'الاسم الأول';

  @override
  String get onboarding_label_firstName_guardian => 'الاسم الأول للمرشح';

  @override
  String get onboarding_label_firstName_self => 'الاسم الأول';

  @override
  String get onboarding_label_gender => 'الجنس';

  @override
  String get onboarding_label_gender_guardian => 'جنس المرشح';

  @override
  String get onboarding_label_gender_self => 'الجنس';

  @override
  String get onboarding_label_height_guardian => 'طولهم';

  @override
  String get onboarding_label_height_self => 'طولك';

  @override
  String get onboarding_label_hookah => 'الشيشة';

  @override
  String get onboarding_label_housing => 'السكن';

  @override
  String get onboarding_label_housingQuestion => 'هل يمكنك توفير مسكن مستقل؟';

  @override
  String get onboarding_label_lastName => 'اسم العائلة';

  @override
  String get onboarding_label_leadership => 'الإمامة الدينية';

  @override
  String get onboarding_label_leadershipQuestion =>
      'هل يمكنك إمامة صلاة الجماعة؟';

  @override
  String get onboarding_label_lifestyleDiet => 'نمط الحياة والغذاء';

  @override
  String get onboarding_label_lifestyleDietSub =>
      'هذه حقول حاسمة للعديد من العائلات. يرجى الإجابة بصدق.';

  @override
  String get onboarding_label_livingExpectation => 'توقعات السكن بعد الزواج';

  @override
  String get onboarding_label_mahrBudget => 'ميزانية المهر';

  @override
  String get onboarding_label_mahrBudgetQuestion =>
      'ما هو نطاق المهر المستعد لتقديمه؟';

  @override
  String get onboarding_label_mahrExpectation => 'توقع المهر';

  @override
  String get onboarding_label_mahrExpectationQuestion => 'ما هو توقعك للمهر؟';

  @override
  String get onboarding_label_maintenance => 'النفقة المالية';

  @override
  String get onboarding_label_maintenanceQuestion =>
      'هل أنت قادر على إعالة زوجة ماليًا؟';

  @override
  String get onboarding_label_male => 'ذكر';

  @override
  String get onboarding_label_marriageTimeline => 'الجدول الزمني للزواج';

  @override
  String get onboarding_label_marriageTimelineQuestion => 'متى تتطلع للزواج؟';

  @override
  String get onboarding_label_moderate => 'معتدل';

  @override
  String get onboarding_label_motherTongue => 'اللغة الأم';

  @override
  String get onboarding_label_niqab => 'النقاب';

  @override
  String get onboarding_label_practicing => 'مُلتزم';

  @override
  String get onboarding_label_praysFiveDaily => 'أصلي الصلوات الخمس يوميًا';

  @override
  String get onboarding_label_preferNotToSay => 'أفضل عدم الإجابة';

  @override
  String get onboarding_label_preferredLiving => 'تفضيل ترتيب السكن';

  @override
  String get onboarding_label_profession => 'المهنة';

  @override
  String get onboarding_label_providerReadiness => 'الاستعداد للقوامة';

  @override
  String get onboarding_label_quranMemorization => 'حفظ القرآن';

  @override
  String get onboarding_label_religiousEducation => 'التعليم الديني';

  @override
  String get onboarding_label_residencyStatus => 'حالة الإقامة (اختياري)';

  @override
  String get onboarding_label_revert => 'حديث عهد بالإسلام (اختياري)';

  @override
  String get onboarding_label_revertQuestion => 'هل أنت مسلم جديد (مهتدٍ)؟';

  @override
  String get onboarding_label_sect => 'المذهب';

  @override
  String get onboarding_label_shia => 'شيعي';

  @override
  String get onboarding_label_smoking => 'التدخين';

  @override
  String get onboarding_label_specialNeeds => 'ذوو الاحتياجات الخاصة (اختياري)';

  @override
  String onboarding_label_step(int current, int total) {
    return 'الخطوة $current من $total';
  }

  @override
  String get onboarding_label_subSect => 'المذهب الفقهي (اختياري)';

  @override
  String get onboarding_label_substanceUse => 'تعاطي المؤثرات';

  @override
  String get onboarding_label_sunni => 'سني';

  @override
  String get onboarding_label_vaping => 'السجائر الإلكترونية';

  @override
  String get onboarding_label_workAfterMarriage => 'العمل بعد الزواج';

  @override
  String get onboarding_label_workAfterMarriageQuestion =>
      'هل تودين العمل بعد الزواج؟';

  @override
  String get onboarding_leadership_leads => 'يؤم المصلين';

  @override
  String get onboarding_leadership_learning => 'يتعلم';

  @override
  String get onboarding_leadership_notYet => 'ليس بعد';

  @override
  String get onboarding_living_openToDiscussion => 'قابل للنقاش';

  @override
  String get onboarding_living_openToDiscussionSub =>
      'أنا مرن وسعيد بمناقشة ما يناسب كلينا.';

  @override
  String get onboarding_living_separate => 'مسكن مستقل';

  @override
  String get onboarding_living_separateSub => 'أفضل أن يكون لنا مسكن مستقل.';

  @override
  String get onboarding_living_withInlaws => 'مع الأسرة';

  @override
  String get onboarding_living_withInlawsSub =>
      'أتوقع العيش مع عائلة الزوج/الزوجة أو مع عائلتي.';

  @override
  String get onboarding_location_confirmed => 'تم تأكيد الموقع';

  @override
  String get onboarding_mahr_generous => 'سخي';

  @override
  String get onboarding_mahr_moderate => 'معتدل';

  @override
  String get onboarding_mahr_modest => 'يسير';

  @override
  String get onboarding_mahr_noPreference => 'لا يوجد تفضيل';

  @override
  String get onboarding_mahr_toDiscuss => 'للنقاش';

  @override
  String get onboarding_marriageDeen_privacyNotice =>
      'هذه التفاصيل لا تظهر في ملفك الشخصي العام. يتم مشاركتها بشكل خاص أثناء مرحلة القبول.';

  @override
  String get onboarding_marriageDeen_subtitle =>
      'ساعدنا في فهم رحلتك ومدى استعدادك.';

  @override
  String get onboarding_marriageDeen_title => 'الزواج والدين';

  @override
  String get onboarding_niqab_dontWear => 'لا أرتدي النقاب';

  @override
  String get onboarding_niqab_open => 'متقبلة لارتدائه';

  @override
  String get onboarding_niqab_wear => 'أرتدي النقاب';

  @override
  String get onboarding_photo_subtitle =>
      'مطلوبة صورة واحدة على الأقل تظهر فيها وجهك بوضوح.';

  @override
  String get onboarding_photo_title => 'أضف صورك';

  @override
  String get onboarding_photo_verifySelfie => 'صورة التحقق';

  @override
  String get onboarding_photo_verifySelfieHint =>
      'التقط صورة مباشرة للتحقق من هويتك';

  @override
  String get onboarding_preferredLiving_noPreference => 'لا تفضيل';

  @override
  String get onboarding_profileForWhom_creatingFor =>
      'أنا أقوم بإنشاء هذا الملف لـ...';

  @override
  String get onboarding_profileForWhom_guardian => 'لابني أو ابنتي';

  @override
  String get onboarding_profileForWhom_guardianCardSub =>
      'أقوم بإنشاء هذا الملف الشخصي لشخص آخر';

  @override
  String get onboarding_profileForWhom_guardianCardTitle => 'ولي الأمر';

  @override
  String get onboarding_profileForWhom_guardianSub => 'أنا ولي أمر';

  @override
  String get onboarding_profileForWhom_myself => 'لنفسي';

  @override
  String get onboarding_profileForWhom_myselfSub => 'أبحث عن شريك/ة للزواج';

  @override
  String get onboarding_profileForWhom_relation_brother => 'أخي';

  @override
  String get onboarding_profileForWhom_relation_daughter => 'ابنتي';

  @override
  String get onboarding_profileForWhom_relation_sister => 'أختي';

  @override
  String get onboarding_profileForWhom_relation_son => 'ابني';

  @override
  String get onboarding_profileForWhom_selectOne => 'اختر خياراً للمتابعة';

  @override
  String get onboarding_profileForWhom_selectRelation =>
      'اختر صلة القرابة للمتابعة';

  @override
  String get onboarding_profileForWhom_sibling => 'لأخي أو أختي';

  @override
  String get onboarding_profileForWhom_siblingSub =>
      'أساعد شقيقي/شقيقتي في إيجاد شريك';

  @override
  String get onboarding_profileForWhom_subtitle =>
      'يمكنك تحديث هذا لاحقًا من الإعدادات.';

  @override
  String get onboarding_profileForWhom_title => 'لمن هذا الملف الشخصي؟';

  @override
  String get onboarding_profileForWhom_ward => 'لمن أرعاه';

  @override
  String get onboarding_profileForWhom_wardSub =>
      'أنا وصي وأدير هذا الملف الشخصي';

  @override
  String get onboarding_providerQuote =>
      '\"خياركم خياركم لنسائهم\" — الرسول محمد صلى الله عليه وسلم\n\nالصدق بشأن استعدادك يساعد في بناء أساس قوي.';

  @override
  String get onboarding_quran_hafiz => 'حافظ / حافظة';

  @override
  String get onboarding_quran_none => 'لا يوجد';

  @override
  String get onboarding_quran_partial => 'حفظ جزئي';

  @override
  String get onboarding_quran_some => 'بعض السور';

  @override
  String get onboarding_religiousEdu_alim => 'دورة عالم';

  @override
  String get onboarding_religiousEdu_islamicUni => 'جامعة إسلامية';

  @override
  String get onboarding_religiousEdu_madrasa => 'مدرسة دينية';

  @override
  String get onboarding_religiousEdu_selfTaught => 'تعلم ذاتي';

  @override
  String get onboarding_timeline_1year => 'خلال سنة';

  @override
  String get onboarding_timeline_2years => 'سنتين أو أكثر';

  @override
  String get onboarding_timeline_6months => 'خلال 6 أشهر';

  @override
  String get onboarding_timeline_asap => 'في أقرب وقت ممكن';

  @override
  String get onboarding_timeline_notSure => 'غير متأكد بعد';

  @override
  String get onboarding_tooltip_cultural =>
      'يعرّف نفسه كمسلم، يحتفل بالمناسبات، قد لا يصلي بانتظام';

  @override
  String get onboarding_tooltip_moderate =>
      'يقدّر المبادئ الإسلامية، يصلي بانتظام لكن ليس دائمًا، مسلم ثقافيًا';

  @override
  String get onboarding_tooltip_practicing =>
      'يلتزم بأركان الإسلام الخمسة، يصلي بانتظام، يعيش حياة حلال';

  @override
  String get onboarding_work_no => 'لا، أفضّل عدم العمل';

  @override
  String get onboarding_work_yes => 'نعم، أخطط للعمل';

  @override
  String get photo_add_main_required => 'إضافة الصورة الأساسية\n(مطلوبة)';

  @override
  String get photo_add_photo => 'إضافة صورة';

  @override
  String get photo_banner_text =>
      'حمّل صورة واضحة يظهر فيها وجهك. لا يُسمح بالصور التي تحتوي على محتوى صريح.';

  @override
  String get photo_error_no_face_detected =>
      'الوجه غير ظاهر — يرجى المحاولة مرة أخرى بصورة وجه واضحة';

  @override
  String photo_error_pick_failed(Object error) {
    return 'تعذر اختيار الصورة: $error';
  }

  @override
  String get photo_face_detected => 'تم اكتشاف الوجه ✓';

  @override
  String get photo_label_photo2 => 'الصورة ٢';

  @override
  String get photo_label_photo3 => 'الصورة ٣';

  @override
  String get photo_label_primary => 'الصورة الأساسية';

  @override
  String get photo_label_selfie => 'سيلفي التحقق';

  @override
  String get photo_no_face => 'الوجه غير ظاهر';

  @override
  String get photo_privacy_everyone => 'ظاهر للجميع';

  @override
  String get photo_privacy_everyone_sub => 'يمكن لجميع الأعضاء رؤية صورك.';

  @override
  String get photo_privacy_label => 'خصوصية الصور';

  @override
  String get photo_privacy_mutual => 'ظاهر بعد الاهتمام المتبادل';

  @override
  String get photo_privacy_mutual_sub =>
      'تظهر الصور فقط عندما يبدي الطرفان اهتمامًا.';

  @override
  String get photo_privacy_request => 'طلب للمشاهدة';

  @override
  String get photo_privacy_request_sub =>
      'تكون الصور غير واضحة حتى توافق على الطلب.';

  @override
  String get photo_sheet_camera => 'الكاميرا';

  @override
  String get photo_sheet_gallery => 'المعرض';

  @override
  String get photo_sheet_title => 'اختر مصدر الصورة';

  @override
  String get photo_slots_help => 'اضغط على الخانات للتحميل';

  @override
  String photo_subtitle_guardian(Object relation) {
    return 'أضف صور $relation. مطلوب صورة واحدة على الأقل.';
  }

  @override
  String get photo_subtitle_self =>
      'مطلوب صورة واحدة على الأقل. الحد الأقصى أربع.';

  @override
  String get photo_title_guardian => 'إضافة صورهم';

  @override
  String get photo_title_self => 'إضافة صورك';

  @override
  String get preferences_deen_any => 'أي مستوى';

  @override
  String get preferences_deen_cultural => 'مسلم ثقافي';

  @override
  String get preferences_deen_moderate => 'معتدل';

  @override
  String get preferences_deen_practicing => 'ملتزم';

  @override
  String get preferences_edu_any => 'أي مستوى';

  @override
  String get preferences_edu_bachelors => 'بكالوريوس أو أعلى';

  @override
  String get preferences_edu_diploma => 'دبلوم أو أعلى';

  @override
  String get preferences_edu_masters => 'ماجستير أو أعلى';

  @override
  String get preferences_edu_phd => 'دكتوراه فقط';

  @override
  String get preferences_edu_secondary => 'ثانوي أو أعلى';

  @override
  String get preferences_label_age => 'نطاق العمر';

  @override
  String get preferences_label_age_bounds => '١٨ – ٦٠';

  @override
  String preferences_label_age_range(Object max, Object min) {
    return '$min – $max سنة';
  }

  @override
  String get preferences_label_deen => 'تفضيل مستوى التدين';

  @override
  String get preferences_label_edu => 'الحد الأدنى للتعليم';

  @override
  String get preferences_label_living => 'تفضيل ترتيب السكن';

  @override
  String get preferences_label_location => 'الموقع';

  @override
  String get preferences_label_openness => 'التقبل';

  @override
  String get preferences_label_sect => 'تفضيل المذهب';

  @override
  String get preferences_living_discussion => 'قابل للنقاش';

  @override
  String get preferences_living_family => 'مع العائلة';

  @override
  String get preferences_living_no_pref => 'لا يوجد تفضيل';

  @override
  String get preferences_living_separate => 'مسكن مستقل';

  @override
  String get preferences_location_abroad => 'مفتوح للخارج';

  @override
  String get preferences_location_diaspora => 'وضع المغتربين';

  @override
  String get preferences_location_same_city => 'نفس المدينة';

  @override
  String get preferences_location_same_country => 'نفس البلد';

  @override
  String get preferences_open_children => 'متقبل للارتباط بشخص لديه أطفال';

  @override
  String get preferences_open_divorced => 'متقبل للارتباط بشخص مطلق';

  @override
  String get preferences_open_widowed => 'متقبل للارتباط بشخص أرمل';

  @override
  String get preferences_sect_any => 'أي مذهب';

  @override
  String get preferences_sect_same => 'مثل مذهبي';

  @override
  String get preferences_sect_shia => 'شيعي';

  @override
  String get preferences_sect_sunni => 'سني';

  @override
  String preferences_subtitle_guardian(Object relation) {
    return 'عيّن التفضيلات للمطابقة المثالية لـ $relation.';
  }

  @override
  String get preferences_subtitle_self => 'هذه تفضيلات، وليست فلاتر صارمة.';

  @override
  String get preferences_title => 'تفضيلات الشريك';

  @override
  String get preview_age_label => 'العمر';

  @override
  String get preview_background => 'الخلفية المهنية';

  @override
  String get preview_basic_info => 'معلومات أساسية';

  @override
  String get preview_city_label => 'المدينة';

  @override
  String get preview_community_label => 'المجتمع / بيرادري';

  @override
  String get preview_cowife_label => 'قبول أن تكون زوجة ثانية';

  @override
  String get preview_deen_label => 'مستوى التدين';

  @override
  String get preview_diet_label => 'النظام الغذائي';

  @override
  String get preview_edit => 'تعديل';

  @override
  String get preview_education_label => 'التعليم';

  @override
  String get preview_faith => 'الدين والالتزام';

  @override
  String get preview_family => 'العائلة';

  @override
  String get preview_family_type_label => 'نوع العائلة';

  @override
  String get preview_gender_label => 'الجنس';

  @override
  String get preview_hijab_label => 'الحجاب';

  @override
  String get preview_hookah_label => 'الشيشة';

  @override
  String get preview_leadership_label => 'إمامة الصلاة';

  @override
  String get preview_marital_label => 'الحالة الاجتماعية';

  @override
  String get preview_marriage_timeline_label => 'مخطط الزواج';

  @override
  String get preview_mother_tongue_label => 'اللغة الأم';

  @override
  String get preview_name_label => 'الاسم';

  @override
  String get preview_notice_guardian =>
      'هذا هو بالضبط كيف سيرى الآخرون ملفهم الشخصي.';

  @override
  String get preview_notice_self =>
      'هذا هو بالضبط كيف سيرى الآخرون ملفك الشخصي.';

  @override
  String get preview_polygamy_label => 'تعدد الزوجات';

  @override
  String get preview_post_marriage_living_label => 'السكن بعد الزواج';

  @override
  String get preview_prays_label => 'يصلي الصلوات الخمس';

  @override
  String get preview_profession_label => 'المهنة';

  @override
  String get preview_quran_label => 'حفظ القرآن';

  @override
  String get preview_religious_edu_label => 'التعليم الديني';

  @override
  String get preview_residency_label => 'الإقامة';

  @override
  String get preview_revert_label => 'مسلم جديد';

  @override
  String get preview_sect_label => 'المذهب';

  @override
  String get preview_siblings_label => 'الإخوة';

  @override
  String get preview_smoking_label => 'التدخين';

  @override
  String get preview_special_needs_label => 'الاحتياجات الخاصة';

  @override
  String get preview_submit_btn => 'تقديم الملف الشخصي';

  @override
  String get preview_title => 'معاينة';

  @override
  String get preview_vaping_label => 'السجائر الإلكترونية';

  @override
  String get preview_willing_relocate_label => 'الرغبة في الانتقال';

  @override
  String profile_label_completeness(int percent) {
    return 'الملف الشخصي مكتمل $percent%';
  }

  @override
  String get profile_nudge_completeness =>
      'الملفات الشخصية المكتملة بنسبة 80%+ تحصل على 3 أضعاف الاهتمامات.';

  @override
  String get settings_brand_credit => 'ميثاق (Mithaq) · لوجه الله';

  @override
  String get settings_button_deleteAccount => 'حذف الحساب';

  @override
  String get settings_guardian_mirror => 'نسخ الرسائل';

  @override
  String get settings_guardian_mirror_sub =>
      'إرسال نسخ من جميع الرسائل إلى ولي الأمر';

  @override
  String get settings_guardian_name_hint => 'اسم ولي الأمر';

  @override
  String get settings_guardian_phone_hint => 'هاتف ولي الأمر';

  @override
  String get settings_guardian_relationship => 'العلاقة';

  @override
  String get settings_guardian_reply => 'السماح لولي الأمر بالرد';

  @override
  String get settings_guardian_reply_sub =>
      'يمكن لولي الأمر المشاركة في المحادثات';

  @override
  String get settings_guardian_save => 'حفظ إعدادات ولي الأمر';

  @override
  String get settings_guardian_saved => 'تم الحفظ';

  @override
  String get settings_guardian_sub => 'تفعيل إشراف الولي على الرسائل';

  @override
  String get settings_guardian_title => 'وضع ولي الأمر';

  @override
  String get settings_label_blocked => 'الملفات الشخصية المحظورة';

  @override
  String settings_label_blocked_count(Object count) {
    return '$count محظور';
  }

  @override
  String get settings_label_blocked_none => 'لا يوجد';

  @override
  String get settings_label_deleteGrace =>
      'سيتم إخفاء ملفك الشخصي فورًا. سيتم حذف بياناتك نهائيًا بعد 30 يومًا.';

  @override
  String get settings_label_editProfile => 'تعديل الملف الشخصي';

  @override
  String get settings_label_language => 'اللغة';

  @override
  String get settings_label_phoneCannotChange =>
      'لا يمكن تغيير رقم الهاتف. اتصل بالدعم للمساعدة.';

  @override
  String get settings_label_phoneNumber => 'رقم الهاتف';

  @override
  String get settings_label_photoPrivacy => 'خصوصية الصور';

  @override
  String get settings_label_rate => 'قيم تطبيق ميثاق';

  @override
  String get settings_label_rate_snackbar =>
      'التقييم سيكون متاحًا بمجرد إطلاق ميثاق على متجر التطبيقات.';

  @override
  String get settings_label_reports => 'سجل البلاغات';

  @override
  String settings_label_reports_count(Object count) {
    return '$count بلاغات';
  }

  @override
  String get settings_label_reports_none => 'لم يتم تقديم أي بلاغات';

  @override
  String get settings_label_selfieChallenge => 'تحدي الصورة الشخصية';

  @override
  String get settings_label_verifyProfile => 'توثيق الحساب';

  @override
  String get settings_label_version => 'الإصدار';

  @override
  String get settings_notify_activityNudges => 'تنبيهات النشاط';

  @override
  String get settings_notify_activityNudgesSub =>
      'التذكير عند عدم النشاط لأكثر من ٧ أيام';

  @override
  String get settings_notify_boostReminders => 'تذكيرات الترويج';

  @override
  String get settings_notify_boostRemindersSub =>
      'التذكير عندما يكون ترويجك الأسبوعي جاهزًا';

  @override
  String get settings_notify_interestAccepted => 'قبول الاهتمام';

  @override
  String get settings_notify_interestExpiring =>
      'أوشكت صلاحية الاهتمام على الانتهاء';

  @override
  String get settings_notify_newInterest => 'اهتمامات جديدة';

  @override
  String get settings_notify_newMessage => 'رسائل جديدة';

  @override
  String get settings_notify_profileApproved => 'تمت الموافقة على الملف الشخصي';

  @override
  String get settings_notify_quietHours => 'ساعات الهدوء';

  @override
  String get settings_photo_privacy_accepted_interests =>
      'الاهتمامات المقبولة فقط';

  @override
  String get settings_photo_privacy_after_acceptance => 'بعد القبول';

  @override
  String get settings_photo_privacy_everyone => 'للجميع';

  @override
  String get settings_photo_privacy_public => 'عام';

  @override
  String get settings_photo_privacy_request_only => 'عند الطلب فقط';

  @override
  String get settings_photo_privacy_request_to_view => 'طلب للمشاهدة';

  @override
  String get settings_privacy_download_body =>
      'بموجب اللائحة العامة لحماية البيانات (GDPR) ولوائح الخصوصية الأخرى، يمكنك طلب تصدير كامل لملفك الشخصي وبيانات المطابقة والنشاط. سيتم إعداد الملف وإرساله إلى عنوانك المسجل.';

  @override
  String get settings_privacy_download_btn => 'طلب تصدير البيانات';

  @override
  String get settings_privacy_download_label => 'تنزيل بياناتي';

  @override
  String get settings_privacy_download_sub =>
      'تصدير نسخة من بياناتك الشخصية بموجب اللائحة العامة لحماية البيانات (GDPR)';

  @override
  String get settings_privacy_export_body =>
      'لقد تم استلام طلبك! نحن نعمل على تجميع أرشيف بياناتك الشخصية.';

  @override
  String get settings_privacy_export_btn_close => 'مفهوم';

  @override
  String get settings_privacy_export_subbody =>
      'سيتم إرسال رابط التنزيل إلى هاتفك/بريدك الإلكتروني المسجل في غضون ٤٨ ساعة امتثالاً لتوجيهات GDPR.';

  @override
  String get settings_privacy_export_title => 'تم طلب التصدير';

  @override
  String get settings_privacy_online_label => 'حالة الاتصال';

  @override
  String get settings_privacy_online_sub => 'إظهار آخر وقت كنت فيه نشطًا';

  @override
  String get settings_privacy_pause_label => 'إيقاف الملف الشخصي مؤقتًا';

  @override
  String get settings_privacy_pause_sub => 'إخفاء ملفك الشخصي من البحث';

  @override
  String get settings_privacy_pause_warning =>
      'ملفك الشخصي مخفي. لا يمكن لأحد العثور عليك.';

  @override
  String get settings_privacy_photo_label => 'ظهور الصور';

  @override
  String get settings_privacy_photo_sub => 'من يمكنه رؤية صورك';

  @override
  String get settings_privacy_visibility_all => 'جميع المستخدمين المسجلين';

  @override
  String get settings_privacy_visibility_label => 'من يمكنه رؤية ملفي الشخصي';

  @override
  String get settings_privacy_visibility_sub =>
      'التحكم في من يمكنه تصفح ملفك الشخصي';

  @override
  String get settings_privacy_visibility_subscribers => 'المشتركون فقط';

  @override
  String get settings_relation_brother => 'الأخ';

  @override
  String get settings_relation_father => 'الأب';

  @override
  String get settings_relation_mother => 'الأم';

  @override
  String get settings_relation_other => 'آخر';

  @override
  String get settings_relation_uncle => 'العم/الخال';

  @override
  String get settings_section_account => 'الحساب';

  @override
  String get settings_section_app => 'التطبيق';

  @override
  String get settings_section_dangerZone => 'منطقة الخطر';

  @override
  String get settings_section_guardian => 'الولي';

  @override
  String get settings_section_legal => 'القانونية';

  @override
  String get settings_section_notifications => 'الإشعارات';

  @override
  String get settings_section_privacy => 'الخصوصية';

  @override
  String get settings_section_safety => 'الأمان';

  @override
  String get settings_support_body => 'لأي أسئلة أو مخاوف أو ملاحظات:';

  @override
  String get settings_support_btn_close => 'إغلاق';

  @override
  String get settings_support_contact => 'الاتصال بالدعم';

  @override
  String get settings_support_note => 'نهدف إلى الرد في غضون ٤٨ ساعة.';

  @override
  String get settings_title => 'الإعدادات';

  @override
  String get splash_button_createProfile => 'إنشاء ملف شخصي';

  @override
  String get splash_button_signIn => 'تسجيل الدخول';

  @override
  String get splash_referral_button => 'تطبيق الرمز';

  @override
  String get splash_referral_hint => 'مثال: MITHAQXX';

  @override
  String get splash_referral_invalid => 'يرجى إدخال رمز صالح مكون من 6 أحرف.';

  @override
  String get splash_referral_question => 'لديك رمز إحالة؟';

  @override
  String get splash_referral_saved =>
      'تم حفظ رمز الإحالة! سيتم تطبيقه بعد تسجيل الدخول.';

  @override
  String get splash_referral_subtitle =>
      'إذا دعاك صديق إلى ميثاق، فأدخل رمز الإحالة المكون من 6 أحرف أدناه.';

  @override
  String get splash_referral_title => 'أدخل رمز الإحالة';

  @override
  String subscription_button_monthly(String price) {
    return 'اشترك — $price/شهر';
  }

  @override
  String get subscription_label_bestValue => 'أفضل قيمة';

  @override
  String get subscription_subtitle =>
      'تراسل النساء مجانًا. يشترك الرجال للتواصل.';

  @override
  String get subscription_title => 'افتح ميثاق';
}
