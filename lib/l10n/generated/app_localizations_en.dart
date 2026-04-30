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
  String get onboarding_label_vaping => 'Vaping / E-cigarettes';

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
}
