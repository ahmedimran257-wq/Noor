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
