// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'NOOR';

  @override
  String get appTagline => 'Begin with bismillah';

  @override
  String get common_button_next => 'Next';

  @override
  String get common_button_back => 'Back';

  @override
  String get common_button_skip => 'Skip';

  @override
  String get common_button_save => 'Save';

  @override
  String get common_button_cancel => 'Cancel';

  @override
  String get common_button_submit => 'Submit';

  @override
  String get common_button_done => 'Done';

  @override
  String get common_button_retry => 'Try Again';

  @override
  String get common_label_optional => 'Optional';

  @override
  String get common_error_generic => 'Something went wrong. Please try again.';

  @override
  String get common_error_noInternet =>
      'No internet connection. Please check your connection.';

  @override
  String get splash_button_createProfile => 'Create Profile';

  @override
  String get splash_button_signIn => 'Sign In';

  @override
  String get legal_title => 'Before you begin';

  @override
  String get legal_checkbox_age => 'I confirm I am 18 years or older';

  @override
  String get legal_checkbox_terms =>
      'I agree to the Terms of Service and Privacy Policy';

  @override
  String get legal_button_continue => 'Continue';

  @override
  String get auth_label_phoneNumber => 'Phone Number';

  @override
  String get auth_hint_phoneNumber => 'Enter your phone number';

  @override
  String get auth_button_sendOtp => 'Send Verification Code';

  @override
  String get auth_label_enterOtp => 'Enter the 6-digit code sent to';

  @override
  String get auth_button_verifyOtp => 'Verify';

  @override
  String get auth_button_resendOtp => 'Resend Code';

  @override
  String auth_label_resendIn(int seconds) {
    return 'Resend in ${seconds}s';
  }

  @override
  String onboarding_label_step(int current, int total) {
    return 'Step $current of $total';
  }

  @override
  String get onboarding_profileForWhom_title => 'Who is this profile for?';

  @override
  String get onboarding_profileForWhom_myself => 'Myself';

  @override
  String get onboarding_profileForWhom_myselfSub => 'I am looking for a spouse';

  @override
  String get onboarding_profileForWhom_guardian => 'My son or daughter';

  @override
  String get onboarding_profileForWhom_guardianSub =>
      'I am a parent or guardian';

  @override
  String get onboarding_profileForWhom_sibling => 'My brother or sister';

  @override
  String get onboarding_profileForWhom_siblingSub =>
      'I am helping my sibling find a match';

  @override
  String get onboarding_profileForWhom_ward => 'My ward';

  @override
  String get onboarding_profileForWhom_wardSub =>
      'I am a guardian managing this profile';

  @override
  String get onboarding_basicIdentity_title => 'Tell us about yourself';

  @override
  String get onboarding_label_firstName => 'First Name';

  @override
  String get onboarding_label_lastName => 'Last Name';

  @override
  String get onboarding_label_dateOfBirth => 'Date of Birth';

  @override
  String get onboarding_label_gender => 'Gender';

  @override
  String get onboarding_label_male => 'Male';

  @override
  String get onboarding_label_female => 'Female';

  @override
  String get onboarding_label_city => 'City';

  @override
  String get onboarding_hint_searchCity => 'Search your city…';

  @override
  String get onboarding_error_under18 =>
      'NOOR is for those 18 and older. We\'ve made this requirement to protect everyone in our community.';

  @override
  String get onboarding_islamicIdentity_title => 'Your Islamic identity';

  @override
  String get onboarding_label_sect => 'Sect';

  @override
  String get onboarding_label_sunni => 'Sunni';

  @override
  String get onboarding_label_shia => 'Shia';

  @override
  String get onboarding_label_preferNotToSay => 'Prefer not to say';

  @override
  String get onboarding_label_deenLevel => 'Deen Level';

  @override
  String get onboarding_label_practicing => 'Practicing';

  @override
  String get onboarding_tooltip_practicing =>
      'Follows all five pillars, prays regularly, halal lifestyle';

  @override
  String get onboarding_label_moderate => 'Moderate';

  @override
  String get onboarding_tooltip_moderate =>
      'Values Islamic principles, prays regularly but not always, culturally Muslim';

  @override
  String get onboarding_label_cultural => 'Cultural Muslim';

  @override
  String get onboarding_tooltip_cultural =>
      'Identifies as Muslim, celebrates occasions, may not pray regularly';

  @override
  String get onboarding_label_praysFiveDaily => 'I pray five times daily';

  @override
  String get onboarding_label_community => 'Your community / biradari';

  @override
  String get onboarding_label_community_parent => 'Their community / biradari';

  @override
  String get onboarding_label_motherTongue => 'Mother tongue';

  @override
  String get onboarding_label_diet => 'Diet';

  @override
  String get onboarding_diet_zabihaStrict => 'Strict Zabiha';

  @override
  String get onboarding_diet_halalOnly => 'Halal only';

  @override
  String get onboarding_diet_eatsAnything => 'Eats anything halal';

  @override
  String get onboarding_diet_vegetarian => 'Vegetarian';

  @override
  String get onboarding_diet_vegan => 'Vegan';

  @override
  String get onboarding_label_smoking => 'Smoking';

  @override
  String get onboarding_label_vaping => 'Vaping / E-Cigarettes';

  @override
  String get onboarding_label_hookah => 'Hookah / Shisha';

  @override
  String get onboarding_habit_never => 'Never';

  @override
  String get onboarding_habit_occasionally => 'Occasionally';

  @override
  String get onboarding_habit_frequently => 'Frequently';

  @override
  String get onboarding_habit_preferNotToSay => 'Prefer not to say';

  @override
  String get onboarding_label_livingExpectation =>
      'Post-marriage living expectations';

  @override
  String get onboarding_living_withInlaws => 'With In-Laws';

  @override
  String get onboarding_living_withInlawsSub =>
      'I expect to live with my spouse\'s or my own family.';

  @override
  String get onboarding_living_separate => 'Separate Home';

  @override
  String get onboarding_living_separateSub =>
      'I prefer we have our own independent home.';

  @override
  String get onboarding_living_openToDiscussion => 'Open to Discussion';

  @override
  String get onboarding_living_openToDiscussionSub =>
      'I am flexible and happy to discuss what works for both.';

  @override
  String get onboarding_label_preferredLiving =>
      'Living arrangement preference';

  @override
  String get onboarding_preferredLiving_noPreference => 'No Preference';

  @override
  String get copy_prayer_self => 'Do you pray five times daily?';

  @override
  String get copy_prayer_parent => 'Does your child pray five times daily?';

  @override
  String get copy_prayer_sibling => 'Does your sibling pray five times daily?';

  @override
  String get copy_hijab_self => 'Do you observe hijab?';

  @override
  String get copy_hijab_parent => 'Does your daughter observe hijab?';

  @override
  String get copy_hijab_sibling => 'Does your sister observe hijab?';

  @override
  String get copy_beard_self => 'Do you have a beard?';

  @override
  String get copy_beard_parent => 'Does your son have a beard?';

  @override
  String get copy_beard_sibling => 'Does your brother have a beard?';

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
  String get onboarding_about_title => 'About yourself';

  @override
  String get onboarding_hint_bio =>
      'Describe yourself with honesty and dignity.';

  @override
  String onboarding_label_bioCount(int count) {
    return '$count/300';
  }

  @override
  String get onboarding_error_bioContactInfo =>
      'Please remove contact information from your bio. External contact details are not allowed for your safety.';

  @override
  String get onboarding_photo_title => 'Add your photos';

  @override
  String get onboarding_photo_subtitle =>
      'At least one photo is required. Your primary photo must include your face clearly.';

  @override
  String get onboarding_photo_verifySelfie => 'Verification Selfie';

  @override
  String get onboarding_photo_verifySelfieHint =>
      'Take a live photo to verify you are real';

  @override
  String get onboarding_error_noFace =>
      'Please use a photo where your face is clearly visible.';

  @override
  String get onboarding_error_multipleFaces =>
      'Group photos cannot be your primary photo.';

  @override
  String get discovery_header_title => 'NOOR';

  @override
  String discovery_label_profilesRemaining(int count) {
    return '$count profiles remaining today';
  }

  @override
  String get discovery_button_sendInterest => 'Send Interest';

  @override
  String get discovery_label_interestSent => 'Interest Sent ✓';

  @override
  String get discovery_label_outsidePrefs => 'Someone you might connect with';

  @override
  String get ceremony_text_blessing => 'May Allah bless this with goodness';

  @override
  String get chat_placeholder_typeMessage => 'Type a message…';

  @override
  String chat_label_probation(int hours) {
    return 'Messaging unlocks in $hours hours. You can send Interests now.';
  }

  @override
  String get chat_label_subscribeToMessage =>
      'Subscribe to unlock messaging. Women always message free on NOOR.';

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
  String get chat_endMatch_title => 'End this match';

  @override
  String get chat_endMatch_subtitle =>
      'Choose a respectful message to close this conversation. The other person will be notified.';

  @override
  String get chat_endMatch_button => 'Send & End Match';

  @override
  String get chat_matchClosed_banner =>
      'This match has been respectfully closed.';

  @override
  String get chat_closure_1 =>
      'Assalamu Alaikum. After thoughtful reflection, I feel this may not be the right match for us. I sincerely wish you all the best and pray that Allah blesses you with a wonderful partner. JazakAllah khair.';

  @override
  String get chat_closure_2 =>
      'Assalamu Alaikum. I wanted to be honest and respectful with you. I do not think we are the right match, but I pray that Allah opens better doors for you. Wishing you all the best.';

  @override
  String get chat_closure_3 =>
      'Assalamu Alaikum. After sincere consideration, I feel we may not be compatible. I hope you find someone truly right for you. May Allah make it easy for you. JazakAllah khair for your time.';

  @override
  String get chat_closure_4 =>
      'Assalamu Alaikum. I have reflected on our conversations and feel it is best to close this match at this time. I have nothing but respect for you and I make dua that Allah blesses you with the best.';

  @override
  String get chat_closure_5 =>
      'Assalamu Alaikum. I wanted to be transparent with you rather than fade away. I do not see this progressing further, but I truly appreciate your time and wish you every happiness. May Allah bless you.';

  @override
  String get filter_label_motherTongue => 'Mother Tongue';

  @override
  String get filter_label_community => 'Community / Biradari';

  @override
  String get filter_label_livingExpectation => 'Post-Marriage Living';

  @override
  String get subscription_title => 'Unlock NOOR';

  @override
  String get subscription_subtitle =>
      'Women message free. Men subscribe to connect.';

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
  String get interests_tab_received => 'Received';

  @override
  String get interests_tab_sent => 'Sent';

  @override
  String get interests_button_accept => 'Accept';

  @override
  String get interests_button_decline => 'Decline';

  @override
  String get settings_title => 'Settings';

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
  String get settings_button_deleteAccount => 'Delete Account';

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

  @override
  String get onboarding_profileForWhom_subtitle =>
      'You can update this later from settings.';

  @override
  String get onboarding_profileForWhom_guardianCardTitle => 'Guardian';

  @override
  String get onboarding_profileForWhom_guardianCardSub =>
      'I am creating this profile for someone';

  @override
  String get onboarding_profileForWhom_creatingFor =>
      'I am creating this for my…';

  @override
  String get onboarding_profileForWhom_relation_son => 'Son';

  @override
  String get onboarding_profileForWhom_relation_daughter => 'Daughter';

  @override
  String get onboarding_profileForWhom_relation_brother => 'Brother';

  @override
  String get onboarding_profileForWhom_relation_sister => 'Sister';

  @override
  String get onboarding_profileForWhom_selectRelation =>
      'Select a relationship to continue';

  @override
  String get onboarding_profileForWhom_selectOne => 'Select one to continue';

  @override
  String onboarding_basicIdentity_guardianBanner(String relation) {
    return 'You are filling this as a guardian. These details are about your $relation.';
  }

  @override
  String onboarding_basicIdentity_title_guardian(String relation) {
    return 'Tell us about your $relation';
  }

  @override
  String get onboarding_basicIdentity_subtitle_self =>
      'This is what others will see on your profile.';

  @override
  String get onboarding_basicIdentity_subtitle_guardian =>
      'This is what others will see on their profile.';

  @override
  String get onboarding_label_firstName_self => 'First name';

  @override
  String get onboarding_label_firstName_guardian => 'Candidate\'s first name';

  @override
  String get onboarding_hint_selectDateOfBirth => 'Select date of birth';

  @override
  String onboarding_error_under18_guardian(String relation) {
    return 'Your $relation must be 18 or older to use NOOR.';
  }

  @override
  String get onboarding_error_under18_self =>
      'You must be 18 or older to use NOOR. We look forward to welcoming you then.';

  @override
  String get onboarding_label_gender_self => 'Gender';

  @override
  String get onboarding_label_gender_guardian => 'Candidate\'s gender';

  @override
  String get onboarding_label_country_self => 'Your country';

  @override
  String get onboarding_label_country_guardian => 'Their country';

  @override
  String get onboarding_hint_selectCountry => 'Select country';

  @override
  String get onboarding_label_city_self => 'Your city';

  @override
  String get onboarding_label_city_guardian => 'Their city';

  @override
  String get onboarding_location_confirmed => 'Confirmed Location';

  @override
  String get onboarding_hint_selectCommunity => 'Select community (optional)';

  @override
  String get onboarding_label_height_self => 'Your height';

  @override
  String get onboarding_label_height_guardian => 'Their height';

  @override
  String get onboarding_label_complexion => 'Complexion (Optional)';

  @override
  String get onboarding_hint_selectLanguage => 'Select language';

  @override
  String get onboarding_label_residencyStatus => 'Residency Status (Optional)';

  @override
  String get onboarding_label_specialNeeds => 'Special Needs (Optional)';

  @override
  String get onboarding_islamicIdentity_subtitle =>
      'This helps match you with someone compatible.';

  @override
  String get onboarding_label_subSect => 'School of thought (Optional)';

  @override
  String get onboarding_label_revert => 'Revert / Convert (Optional)';

  @override
  String get onboarding_label_revertQuestion =>
      'Are you a revert (convert) to Islam?';

  @override
  String get onboarding_hijab_always => 'Always';

  @override
  String get onboarding_hijab_sometimes => 'Sometimes';

  @override
  String get onboarding_hijab_no => 'No';

  @override
  String get onboarding_label_leadership => 'Religious Leadership';

  @override
  String get onboarding_label_leadershipQuestion =>
      'Can you lead congregational prayers?';

  @override
  String get onboarding_leadership_leads => 'Leads Prayer';

  @override
  String get onboarding_leadership_learning => 'Learning';

  @override
  String get onboarding_leadership_notYet => 'Not Yet';

  @override
  String get onboarding_label_lifestyleDiet => 'Lifestyle & Diet';

  @override
  String get onboarding_label_lifestyleDietSub =>
      'These are dealbreaker fields for many families. Please answer honestly.';

  @override
  String get onboarding_label_substanceUse => 'Substance Use';

  @override
  String get onboarding_marriageDeen_title => 'Marriage & Deen';

  @override
  String get onboarding_marriageDeen_subtitle =>
      'Help us understand your journey and readiness.';

  @override
  String get onboarding_label_quranMemorization => 'Quran Memorization';

  @override
  String get onboarding_quran_none => 'None';

  @override
  String get onboarding_quran_some => 'Some Surahs';

  @override
  String get onboarding_quran_partial => 'Partial Hifz';

  @override
  String get onboarding_quran_hafiz => 'Hafiz / Hafiza';

  @override
  String get onboarding_label_religiousEducation => 'Religious Education';

  @override
  String get onboarding_religiousEdu_selfTaught => 'Self-Taught';

  @override
  String get onboarding_religiousEdu_madrasa => 'Madrasa';

  @override
  String get onboarding_religiousEdu_islamicUni => 'Islamic University';

  @override
  String get onboarding_religiousEdu_alim => 'Alim Course';

  @override
  String get onboarding_label_marriageTimeline => 'Marriage Timeline';

  @override
  String get onboarding_label_marriageTimelineQuestion =>
      'When are you looking to get married?';

  @override
  String get onboarding_timeline_asap => 'As soon as possible';

  @override
  String get onboarding_timeline_6months => 'Within 6 months';

  @override
  String get onboarding_timeline_1year => 'Within a year';

  @override
  String get onboarding_timeline_2years => '2+ years';

  @override
  String get onboarding_timeline_notSure => 'Not sure yet';

  @override
  String get onboarding_label_niqab => 'Niqab';

  @override
  String get onboarding_niqab_wear => 'I wear niqab';

  @override
  String get onboarding_niqab_open => 'Open to wearing';

  @override
  String get onboarding_niqab_dontWear => 'I don\'t wear niqab';

  @override
  String get onboarding_label_mahrExpectation => 'Mahr Expectation';

  @override
  String get onboarding_label_mahrExpectationQuestion =>
      'What is your expectation for mahr?';

  @override
  String get onboarding_mahr_noPreference => 'No preference';

  @override
  String get onboarding_mahr_modest => 'Modest';

  @override
  String get onboarding_mahr_moderate => 'Moderate';

  @override
  String get onboarding_mahr_generous => 'Generous';

  @override
  String get onboarding_mahr_toDiscuss => 'To discuss';

  @override
  String get onboarding_label_workAfterMarriage => 'Work After Marriage';

  @override
  String get onboarding_label_workAfterMarriageQuestion =>
      'Would you like to work after marriage?';

  @override
  String get onboarding_work_yes => 'Yes, I plan to work';

  @override
  String get onboarding_work_no => 'No, I prefer not to';

  @override
  String get onboarding_label_mahrBudget => 'Mahr Budget';

  @override
  String get onboarding_label_mahrBudgetQuestion =>
      'What mahr range are you prepared to offer?';

  @override
  String get onboarding_label_providerReadiness => 'Provider Readiness';

  @override
  String get onboarding_providerQuote =>
      '\"The best of you are the best to your wives.\" — Prophet Muhammad ﷺ\n\nBeing honest about your readiness helps build a strong foundation.';

  @override
  String get onboarding_label_housing => 'Housing';

  @override
  String get onboarding_label_housingQuestion =>
      'Can you provide a separate living space?';

  @override
  String get onboarding_label_maintenance => 'Financial Maintenance';

  @override
  String get onboarding_label_maintenanceQuestion =>
      'Are you able to provide for a spouse financially?';

  @override
  String get onboarding_label_debtStatus => 'Debt Status';

  @override
  String get onboarding_label_debtStatusQuestion =>
      'Your current financial obligations.';

  @override
  String get onboarding_debt_none => 'No debt';

  @override
  String get onboarding_debt_manageable => 'Manageable debt';

  @override
  String get onboarding_debt_significant => 'Significant debt';

  @override
  String get onboarding_marriageDeen_privacyNotice =>
      'These details are not shown on your public profile. They are shared privately during the acceptance stage.';
}
