import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en')
  ];

  /// App name
  ///
  /// In en, this message translates to:
  /// **'NOOR'**
  String get appName;

  /// Brand tagline on splash screen
  ///
  /// In en, this message translates to:
  /// **'Begin with bismillah'**
  String get appTagline;

  /// No description provided for @common_button_next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get common_button_next;

  /// No description provided for @common_button_back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get common_button_back;

  /// No description provided for @common_button_skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get common_button_skip;

  /// No description provided for @common_button_save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get common_button_save;

  /// No description provided for @common_button_cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get common_button_cancel;

  /// No description provided for @common_button_submit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get common_button_submit;

  /// No description provided for @common_button_done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get common_button_done;

  /// No description provided for @common_button_retry.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get common_button_retry;

  /// No description provided for @common_label_optional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get common_label_optional;

  /// No description provided for @common_error_generic.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get common_error_generic;

  /// No description provided for @common_error_noInternet.
  ///
  /// In en, this message translates to:
  /// **'No internet connection. Please check your connection.'**
  String get common_error_noInternet;

  /// Primary CTA on splash screen
  ///
  /// In en, this message translates to:
  /// **'Create Profile'**
  String get splash_button_createProfile;

  /// Secondary action on splash screen
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get splash_button_signIn;

  /// No description provided for @legal_title.
  ///
  /// In en, this message translates to:
  /// **'Before you begin'**
  String get legal_title;

  /// No description provided for @legal_checkbox_age.
  ///
  /// In en, this message translates to:
  /// **'I confirm I am 18 years or older'**
  String get legal_checkbox_age;

  /// No description provided for @legal_checkbox_terms.
  ///
  /// In en, this message translates to:
  /// **'I agree to the Terms of Service and Privacy Policy'**
  String get legal_checkbox_terms;

  /// No description provided for @legal_button_continue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get legal_button_continue;

  /// No description provided for @auth_label_phoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get auth_label_phoneNumber;

  /// No description provided for @auth_hint_phoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter your phone number'**
  String get auth_hint_phoneNumber;

  /// No description provided for @auth_button_sendOtp.
  ///
  /// In en, this message translates to:
  /// **'Send Verification Code'**
  String get auth_button_sendOtp;

  /// No description provided for @auth_label_enterOtp.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code sent to'**
  String get auth_label_enterOtp;

  /// No description provided for @auth_button_verifyOtp.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get auth_button_verifyOtp;

  /// No description provided for @auth_button_resendOtp.
  ///
  /// In en, this message translates to:
  /// **'Resend Code'**
  String get auth_button_resendOtp;

  /// No description provided for @auth_label_resendIn.
  ///
  /// In en, this message translates to:
  /// **'Resend in {seconds}s'**
  String auth_label_resendIn(int seconds);

  /// No description provided for @onboarding_label_step.
  ///
  /// In en, this message translates to:
  /// **'Step {current} of {total}'**
  String onboarding_label_step(int current, int total);

  /// No description provided for @onboarding_profileForWhom_title.
  ///
  /// In en, this message translates to:
  /// **'Who is this profile for?'**
  String get onboarding_profileForWhom_title;

  /// No description provided for @onboarding_profileForWhom_myself.
  ///
  /// In en, this message translates to:
  /// **'Myself'**
  String get onboarding_profileForWhom_myself;

  /// No description provided for @onboarding_profileForWhom_myselfSub.
  ///
  /// In en, this message translates to:
  /// **'I am looking for a spouse'**
  String get onboarding_profileForWhom_myselfSub;

  /// No description provided for @onboarding_profileForWhom_guardian.
  ///
  /// In en, this message translates to:
  /// **'My son or daughter'**
  String get onboarding_profileForWhom_guardian;

  /// No description provided for @onboarding_profileForWhom_guardianSub.
  ///
  /// In en, this message translates to:
  /// **'I am a parent or guardian'**
  String get onboarding_profileForWhom_guardianSub;

  /// No description provided for @onboarding_profileForWhom_sibling.
  ///
  /// In en, this message translates to:
  /// **'My brother or sister'**
  String get onboarding_profileForWhom_sibling;

  /// No description provided for @onboarding_profileForWhom_siblingSub.
  ///
  /// In en, this message translates to:
  /// **'I am helping my sibling find a match'**
  String get onboarding_profileForWhom_siblingSub;

  /// No description provided for @onboarding_profileForWhom_ward.
  ///
  /// In en, this message translates to:
  /// **'My ward'**
  String get onboarding_profileForWhom_ward;

  /// No description provided for @onboarding_profileForWhom_wardSub.
  ///
  /// In en, this message translates to:
  /// **'I am a guardian managing this profile'**
  String get onboarding_profileForWhom_wardSub;

  /// No description provided for @onboarding_basicIdentity_title.
  ///
  /// In en, this message translates to:
  /// **'Tell us about yourself'**
  String get onboarding_basicIdentity_title;

  /// No description provided for @onboarding_label_firstName.
  ///
  /// In en, this message translates to:
  /// **'First Name'**
  String get onboarding_label_firstName;

  /// No description provided for @onboarding_label_lastName.
  ///
  /// In en, this message translates to:
  /// **'Last Name'**
  String get onboarding_label_lastName;

  /// No description provided for @onboarding_label_dateOfBirth.
  ///
  /// In en, this message translates to:
  /// **'Date of Birth'**
  String get onboarding_label_dateOfBirth;

  /// No description provided for @onboarding_label_gender.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get onboarding_label_gender;

  /// No description provided for @onboarding_label_male.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get onboarding_label_male;

  /// No description provided for @onboarding_label_female.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get onboarding_label_female;

  /// No description provided for @onboarding_label_city.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get onboarding_label_city;

  /// No description provided for @onboarding_hint_searchCity.
  ///
  /// In en, this message translates to:
  /// **'Search your city…'**
  String get onboarding_hint_searchCity;

  /// No description provided for @onboarding_error_under18.
  ///
  /// In en, this message translates to:
  /// **'NOOR is for those 18 and older. We\'ve made this requirement to protect everyone in our community.'**
  String get onboarding_error_under18;

  /// No description provided for @onboarding_islamicIdentity_title.
  ///
  /// In en, this message translates to:
  /// **'Your Islamic identity'**
  String get onboarding_islamicIdentity_title;

  /// No description provided for @onboarding_label_sect.
  ///
  /// In en, this message translates to:
  /// **'Sect'**
  String get onboarding_label_sect;

  /// No description provided for @onboarding_label_sunni.
  ///
  /// In en, this message translates to:
  /// **'Sunni'**
  String get onboarding_label_sunni;

  /// No description provided for @onboarding_label_shia.
  ///
  /// In en, this message translates to:
  /// **'Shia'**
  String get onboarding_label_shia;

  /// No description provided for @onboarding_label_preferNotToSay.
  ///
  /// In en, this message translates to:
  /// **'Prefer not to say'**
  String get onboarding_label_preferNotToSay;

  /// No description provided for @onboarding_label_deenLevel.
  ///
  /// In en, this message translates to:
  /// **'Deen Level'**
  String get onboarding_label_deenLevel;

  /// No description provided for @onboarding_label_practicing.
  ///
  /// In en, this message translates to:
  /// **'Practicing'**
  String get onboarding_label_practicing;

  /// No description provided for @onboarding_tooltip_practicing.
  ///
  /// In en, this message translates to:
  /// **'Follows all five pillars, prays regularly, halal lifestyle'**
  String get onboarding_tooltip_practicing;

  /// No description provided for @onboarding_label_moderate.
  ///
  /// In en, this message translates to:
  /// **'Moderate'**
  String get onboarding_label_moderate;

  /// No description provided for @onboarding_tooltip_moderate.
  ///
  /// In en, this message translates to:
  /// **'Values Islamic principles, prays regularly but not always, culturally Muslim'**
  String get onboarding_tooltip_moderate;

  /// No description provided for @onboarding_label_cultural.
  ///
  /// In en, this message translates to:
  /// **'Cultural Muslim'**
  String get onboarding_label_cultural;

  /// No description provided for @onboarding_tooltip_cultural.
  ///
  /// In en, this message translates to:
  /// **'Identifies as Muslim, celebrates occasions, may not pray regularly'**
  String get onboarding_tooltip_cultural;

  /// No description provided for @onboarding_label_praysFiveDaily.
  ///
  /// In en, this message translates to:
  /// **'I pray five times daily'**
  String get onboarding_label_praysFiveDaily;

  /// No description provided for @onboarding_label_community.
  ///
  /// In en, this message translates to:
  /// **'Your community / biradari'**
  String get onboarding_label_community;

  /// No description provided for @onboarding_label_community_parent.
  ///
  /// In en, this message translates to:
  /// **'Their community / biradari'**
  String get onboarding_label_community_parent;

  /// No description provided for @onboarding_label_motherTongue.
  ///
  /// In en, this message translates to:
  /// **'Mother tongue'**
  String get onboarding_label_motherTongue;

  /// No description provided for @onboarding_label_diet.
  ///
  /// In en, this message translates to:
  /// **'Diet'**
  String get onboarding_label_diet;

  /// No description provided for @onboarding_diet_zabihaStrict.
  ///
  /// In en, this message translates to:
  /// **'Strict Zabiha'**
  String get onboarding_diet_zabihaStrict;

  /// No description provided for @onboarding_diet_halalOnly.
  ///
  /// In en, this message translates to:
  /// **'Halal only'**
  String get onboarding_diet_halalOnly;

  /// No description provided for @onboarding_diet_eatsAnything.
  ///
  /// In en, this message translates to:
  /// **'Eats anything halal'**
  String get onboarding_diet_eatsAnything;

  /// No description provided for @onboarding_diet_vegetarian.
  ///
  /// In en, this message translates to:
  /// **'Vegetarian'**
  String get onboarding_diet_vegetarian;

  /// No description provided for @onboarding_diet_vegan.
  ///
  /// In en, this message translates to:
  /// **'Vegan'**
  String get onboarding_diet_vegan;

  /// No description provided for @onboarding_label_smoking.
  ///
  /// In en, this message translates to:
  /// **'Smoking'**
  String get onboarding_label_smoking;

  /// No description provided for @onboarding_label_vaping.
  ///
  /// In en, this message translates to:
  /// **'Vaping / E-cigarettes'**
  String get onboarding_label_vaping;

  /// No description provided for @onboarding_label_hookah.
  ///
  /// In en, this message translates to:
  /// **'Hookah / Shisha'**
  String get onboarding_label_hookah;

  /// No description provided for @onboarding_habit_never.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get onboarding_habit_never;

  /// No description provided for @onboarding_habit_occasionally.
  ///
  /// In en, this message translates to:
  /// **'Occasionally'**
  String get onboarding_habit_occasionally;

  /// No description provided for @onboarding_habit_frequently.
  ///
  /// In en, this message translates to:
  /// **'Frequently'**
  String get onboarding_habit_frequently;

  /// No description provided for @onboarding_habit_preferNotToSay.
  ///
  /// In en, this message translates to:
  /// **'Prefer not to say'**
  String get onboarding_habit_preferNotToSay;

  /// No description provided for @onboarding_label_livingExpectation.
  ///
  /// In en, this message translates to:
  /// **'Post-marriage living expectations'**
  String get onboarding_label_livingExpectation;

  /// No description provided for @onboarding_living_withInlaws.
  ///
  /// In en, this message translates to:
  /// **'With In-Laws'**
  String get onboarding_living_withInlaws;

  /// No description provided for @onboarding_living_withInlawsSub.
  ///
  /// In en, this message translates to:
  /// **'I expect to live with my spouse\'s or my own family.'**
  String get onboarding_living_withInlawsSub;

  /// No description provided for @onboarding_living_separate.
  ///
  /// In en, this message translates to:
  /// **'Separate Home'**
  String get onboarding_living_separate;

  /// No description provided for @onboarding_living_separateSub.
  ///
  /// In en, this message translates to:
  /// **'I prefer we have our own independent home.'**
  String get onboarding_living_separateSub;

  /// No description provided for @onboarding_living_openToDiscussion.
  ///
  /// In en, this message translates to:
  /// **'Open to Discussion'**
  String get onboarding_living_openToDiscussion;

  /// No description provided for @onboarding_living_openToDiscussionSub.
  ///
  /// In en, this message translates to:
  /// **'I am flexible and happy to discuss what works for both.'**
  String get onboarding_living_openToDiscussionSub;

  /// No description provided for @onboarding_label_preferredLiving.
  ///
  /// In en, this message translates to:
  /// **'Living arrangement preference'**
  String get onboarding_label_preferredLiving;

  /// No description provided for @onboarding_preferredLiving_noPreference.
  ///
  /// In en, this message translates to:
  /// **'No Preference'**
  String get onboarding_preferredLiving_noPreference;

  /// No description provided for @copy_prayer_self.
  ///
  /// In en, this message translates to:
  /// **'Do you pray five times daily?'**
  String get copy_prayer_self;

  /// No description provided for @copy_prayer_parent.
  ///
  /// In en, this message translates to:
  /// **'Does your child pray five times daily?'**
  String get copy_prayer_parent;

  /// No description provided for @copy_prayer_sibling.
  ///
  /// In en, this message translates to:
  /// **'Does your sibling pray five times daily?'**
  String get copy_prayer_sibling;

  /// No description provided for @copy_hijab_self.
  ///
  /// In en, this message translates to:
  /// **'Do you observe hijab?'**
  String get copy_hijab_self;

  /// No description provided for @copy_hijab_parent.
  ///
  /// In en, this message translates to:
  /// **'Does your daughter observe hijab?'**
  String get copy_hijab_parent;

  /// No description provided for @copy_hijab_sibling.
  ///
  /// In en, this message translates to:
  /// **'Does your sister observe hijab?'**
  String get copy_hijab_sibling;

  /// No description provided for @copy_beard_self.
  ///
  /// In en, this message translates to:
  /// **'Do you have a beard?'**
  String get copy_beard_self;

  /// No description provided for @copy_beard_parent.
  ///
  /// In en, this message translates to:
  /// **'Does your son have a beard?'**
  String get copy_beard_parent;

  /// No description provided for @copy_beard_sibling.
  ///
  /// In en, this message translates to:
  /// **'Does your brother have a beard?'**
  String get copy_beard_sibling;

  /// No description provided for @onboarding_background_title.
  ///
  /// In en, this message translates to:
  /// **'Education & Career'**
  String get onboarding_background_title;

  /// No description provided for @onboarding_label_educationLevel.
  ///
  /// In en, this message translates to:
  /// **'Education Level'**
  String get onboarding_label_educationLevel;

  /// No description provided for @onboarding_label_profession.
  ///
  /// In en, this message translates to:
  /// **'Profession'**
  String get onboarding_label_profession;

  /// No description provided for @onboarding_hint_profession.
  ///
  /// In en, this message translates to:
  /// **'e.g. Software Engineer, Teacher, Doctor'**
  String get onboarding_hint_profession;

  /// No description provided for @onboarding_about_title.
  ///
  /// In en, this message translates to:
  /// **'About yourself'**
  String get onboarding_about_title;

  /// No description provided for @onboarding_hint_bio.
  ///
  /// In en, this message translates to:
  /// **'Describe yourself with honesty and dignity.'**
  String get onboarding_hint_bio;

  /// No description provided for @onboarding_label_bioCount.
  ///
  /// In en, this message translates to:
  /// **'{count}/300'**
  String onboarding_label_bioCount(int count);

  /// No description provided for @onboarding_error_bioContactInfo.
  ///
  /// In en, this message translates to:
  /// **'Please remove contact information from your bio. External contact details are not allowed for your safety.'**
  String get onboarding_error_bioContactInfo;

  /// No description provided for @onboarding_photo_title.
  ///
  /// In en, this message translates to:
  /// **'Add your photos'**
  String get onboarding_photo_title;

  /// No description provided for @onboarding_photo_subtitle.
  ///
  /// In en, this message translates to:
  /// **'At least one photo is required. Your primary photo must include your face clearly.'**
  String get onboarding_photo_subtitle;

  /// No description provided for @onboarding_photo_verifySelfie.
  ///
  /// In en, this message translates to:
  /// **'Verification Selfie'**
  String get onboarding_photo_verifySelfie;

  /// No description provided for @onboarding_photo_verifySelfieHint.
  ///
  /// In en, this message translates to:
  /// **'Take a live photo to verify you are real'**
  String get onboarding_photo_verifySelfieHint;

  /// No description provided for @onboarding_error_noFace.
  ///
  /// In en, this message translates to:
  /// **'Please use a photo where your face is clearly visible.'**
  String get onboarding_error_noFace;

  /// No description provided for @onboarding_error_multipleFaces.
  ///
  /// In en, this message translates to:
  /// **'Group photos cannot be your primary photo.'**
  String get onboarding_error_multipleFaces;

  /// No description provided for @discovery_header_title.
  ///
  /// In en, this message translates to:
  /// **'NOOR'**
  String get discovery_header_title;

  /// No description provided for @discovery_label_profilesRemaining.
  ///
  /// In en, this message translates to:
  /// **'{count} profiles remaining today'**
  String discovery_label_profilesRemaining(int count);

  /// No description provided for @discovery_button_sendInterest.
  ///
  /// In en, this message translates to:
  /// **'Send Interest'**
  String get discovery_button_sendInterest;

  /// No description provided for @discovery_label_interestSent.
  ///
  /// In en, this message translates to:
  /// **'Interest Sent ✓'**
  String get discovery_label_interestSent;

  /// No description provided for @discovery_label_outsidePrefs.
  ///
  /// In en, this message translates to:
  /// **'Someone you might connect with'**
  String get discovery_label_outsidePrefs;

  /// No description provided for @ceremony_text_blessing.
  ///
  /// In en, this message translates to:
  /// **'May Allah bless this with goodness'**
  String get ceremony_text_blessing;

  /// No description provided for @chat_placeholder_typeMessage.
  ///
  /// In en, this message translates to:
  /// **'Type a message…'**
  String get chat_placeholder_typeMessage;

  /// No description provided for @chat_label_probation.
  ///
  /// In en, this message translates to:
  /// **'Messaging unlocks in {hours} hours. You can send Interests now.'**
  String chat_label_probation(int hours);

  /// No description provided for @chat_label_subscribeToMessage.
  ///
  /// In en, this message translates to:
  /// **'Subscribe to unlock messaging. Women always message free on NOOR.'**
  String get chat_label_subscribeToMessage;

  /// No description provided for @chat_opener_1.
  ///
  /// In en, this message translates to:
  /// **'Assalamu Alaikum! I came across your profile and was genuinely impressed. May I introduce myself?'**
  String get chat_opener_1;

  /// No description provided for @chat_opener_2.
  ///
  /// In en, this message translates to:
  /// **'Bismillah. Your profile caught my attention. I would love to learn more about you.'**
  String get chat_opener_2;

  /// No description provided for @chat_opener_3.
  ///
  /// In en, this message translates to:
  /// **'Assalamu Alaikum. I believe we share similar values. Would you be open to getting to know each other?'**
  String get chat_opener_3;

  /// No description provided for @chat_endMatch_title.
  ///
  /// In en, this message translates to:
  /// **'End this match'**
  String get chat_endMatch_title;

  /// No description provided for @chat_endMatch_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a respectful message to close this conversation. The other person will be notified.'**
  String get chat_endMatch_subtitle;

  /// No description provided for @chat_endMatch_button.
  ///
  /// In en, this message translates to:
  /// **'Send & End Match'**
  String get chat_endMatch_button;

  /// No description provided for @chat_matchClosed_banner.
  ///
  /// In en, this message translates to:
  /// **'This match has been respectfully closed.'**
  String get chat_matchClosed_banner;

  /// No description provided for @chat_closure_1.
  ///
  /// In en, this message translates to:
  /// **'Assalamu Alaikum. After thoughtful reflection, I feel this may not be the right match for us. I sincerely wish you all the best and pray that Allah blesses you with a wonderful partner. JazakAllah khair.'**
  String get chat_closure_1;

  /// No description provided for @chat_closure_2.
  ///
  /// In en, this message translates to:
  /// **'Assalamu Alaikum. I wanted to be honest and respectful with you. I do not think we are the right match, but I pray that Allah opens better doors for you. Wishing you all the best.'**
  String get chat_closure_2;

  /// No description provided for @chat_closure_3.
  ///
  /// In en, this message translates to:
  /// **'Assalamu Alaikum. After sincere consideration, I feel we may not be compatible. I hope you find someone truly right for you. May Allah make it easy for you. JazakAllah khair for your time.'**
  String get chat_closure_3;

  /// No description provided for @chat_closure_4.
  ///
  /// In en, this message translates to:
  /// **'Assalamu Alaikum. I have reflected on our conversations and feel it is best to close this match at this time. I have nothing but respect for you and I make dua that Allah blesses you with the best.'**
  String get chat_closure_4;

  /// No description provided for @chat_closure_5.
  ///
  /// In en, this message translates to:
  /// **'Assalamu Alaikum. I wanted to be transparent with you rather than fade away. I do not see this progressing further, but I truly appreciate your time and wish you every happiness. May Allah bless you.'**
  String get chat_closure_5;

  /// No description provided for @filter_label_motherTongue.
  ///
  /// In en, this message translates to:
  /// **'Mother Tongue'**
  String get filter_label_motherTongue;

  /// No description provided for @filter_label_community.
  ///
  /// In en, this message translates to:
  /// **'Community / Biradari'**
  String get filter_label_community;

  /// No description provided for @filter_label_livingExpectation.
  ///
  /// In en, this message translates to:
  /// **'Post-Marriage Living'**
  String get filter_label_livingExpectation;

  /// No description provided for @subscription_title.
  ///
  /// In en, this message translates to:
  /// **'Unlock NOOR'**
  String get subscription_title;

  /// No description provided for @subscription_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Women message free. Men subscribe to connect.'**
  String get subscription_subtitle;

  /// No description provided for @subscription_button_monthly.
  ///
  /// In en, this message translates to:
  /// **'Subscribe — {price}/month'**
  String subscription_button_monthly(String price);

  /// No description provided for @subscription_label_bestValue.
  ///
  /// In en, this message translates to:
  /// **'Best Value'**
  String get subscription_label_bestValue;

  /// No description provided for @profile_label_completeness.
  ///
  /// In en, this message translates to:
  /// **'Profile {percent}% complete'**
  String profile_label_completeness(int percent);

  /// No description provided for @profile_nudge_completeness.
  ///
  /// In en, this message translates to:
  /// **'Profiles with 80%+ completeness receive 3× more interests.'**
  String get profile_nudge_completeness;

  /// No description provided for @interests_tab_received.
  ///
  /// In en, this message translates to:
  /// **'Received'**
  String get interests_tab_received;

  /// No description provided for @interests_tab_sent.
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get interests_tab_sent;

  /// No description provided for @interests_button_accept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get interests_button_accept;

  /// No description provided for @interests_button_decline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get interests_button_decline;

  /// No description provided for @settings_title.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings_title;

  /// No description provided for @settings_section_account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settings_section_account;

  /// No description provided for @settings_section_safety.
  ///
  /// In en, this message translates to:
  /// **'Safety'**
  String get settings_section_safety;

  /// No description provided for @settings_section_app.
  ///
  /// In en, this message translates to:
  /// **'App'**
  String get settings_section_app;

  /// No description provided for @settings_section_legal.
  ///
  /// In en, this message translates to:
  /// **'Legal'**
  String get settings_section_legal;

  /// No description provided for @settings_section_dangerZone.
  ///
  /// In en, this message translates to:
  /// **'Danger Zone'**
  String get settings_section_dangerZone;

  /// No description provided for @settings_button_deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get settings_button_deleteAccount;

  /// No description provided for @settings_label_deleteGrace.
  ///
  /// In en, this message translates to:
  /// **'Your profile will be hidden immediately. Your data will be permanently deleted after 30 days.'**
  String get settings_label_deleteGrace;

  /// No description provided for @settings_section_notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settings_section_notifications;

  /// No description provided for @settings_section_guardian.
  ///
  /// In en, this message translates to:
  /// **'Guardian'**
  String get settings_section_guardian;

  /// No description provided for @settings_section_privacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get settings_section_privacy;

  /// No description provided for @notifications_title.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications_title;

  /// No description provided for @notifications_markAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all read'**
  String get notifications_markAllRead;

  /// No description provided for @notifications_empty_title.
  ///
  /// In en, this message translates to:
  /// **'You\'re all caught up'**
  String get notifications_empty_title;

  /// No description provided for @notifications_empty_subtitle.
  ///
  /// In en, this message translates to:
  /// **'No new notifications right now.'**
  String get notifications_empty_subtitle;

  /// No description provided for @deleteAccount_title.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccount_title;

  /// No description provided for @interests_title.
  ///
  /// In en, this message translates to:
  /// **'Interests'**
  String get interests_title;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
