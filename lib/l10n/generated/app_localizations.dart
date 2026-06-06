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
  /// **'Vaping / E-Cigarettes'**
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

  /// No description provided for @onboarding_profileForWhom_subtitle.
  ///
  /// In en, this message translates to:
  /// **'You can update this later from settings.'**
  String get onboarding_profileForWhom_subtitle;

  /// No description provided for @onboarding_profileForWhom_guardianCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Guardian'**
  String get onboarding_profileForWhom_guardianCardTitle;

  /// No description provided for @onboarding_profileForWhom_guardianCardSub.
  ///
  /// In en, this message translates to:
  /// **'I am creating this profile for someone'**
  String get onboarding_profileForWhom_guardianCardSub;

  /// No description provided for @onboarding_profileForWhom_creatingFor.
  ///
  /// In en, this message translates to:
  /// **'I am creating this for my…'**
  String get onboarding_profileForWhom_creatingFor;

  /// No description provided for @onboarding_profileForWhom_relation_son.
  ///
  /// In en, this message translates to:
  /// **'Son'**
  String get onboarding_profileForWhom_relation_son;

  /// No description provided for @onboarding_profileForWhom_relation_daughter.
  ///
  /// In en, this message translates to:
  /// **'Daughter'**
  String get onboarding_profileForWhom_relation_daughter;

  /// No description provided for @onboarding_profileForWhom_relation_brother.
  ///
  /// In en, this message translates to:
  /// **'Brother'**
  String get onboarding_profileForWhom_relation_brother;

  /// No description provided for @onboarding_profileForWhom_relation_sister.
  ///
  /// In en, this message translates to:
  /// **'Sister'**
  String get onboarding_profileForWhom_relation_sister;

  /// No description provided for @onboarding_profileForWhom_selectRelation.
  ///
  /// In en, this message translates to:
  /// **'Select a relationship to continue'**
  String get onboarding_profileForWhom_selectRelation;

  /// No description provided for @onboarding_profileForWhom_selectOne.
  ///
  /// In en, this message translates to:
  /// **'Select one to continue'**
  String get onboarding_profileForWhom_selectOne;

  /// No description provided for @onboarding_basicIdentity_guardianBanner.
  ///
  /// In en, this message translates to:
  /// **'You are filling this as a guardian. These details are about your {relation}.'**
  String onboarding_basicIdentity_guardianBanner(String relation);

  /// No description provided for @onboarding_basicIdentity_title_guardian.
  ///
  /// In en, this message translates to:
  /// **'Tell us about your {relation}'**
  String onboarding_basicIdentity_title_guardian(String relation);

  /// No description provided for @onboarding_basicIdentity_subtitle_self.
  ///
  /// In en, this message translates to:
  /// **'This is what others will see on your profile.'**
  String get onboarding_basicIdentity_subtitle_self;

  /// No description provided for @onboarding_basicIdentity_subtitle_guardian.
  ///
  /// In en, this message translates to:
  /// **'This is what others will see on their profile.'**
  String get onboarding_basicIdentity_subtitle_guardian;

  /// No description provided for @onboarding_label_firstName_self.
  ///
  /// In en, this message translates to:
  /// **'First name'**
  String get onboarding_label_firstName_self;

  /// No description provided for @onboarding_label_firstName_guardian.
  ///
  /// In en, this message translates to:
  /// **'Candidate\'s first name'**
  String get onboarding_label_firstName_guardian;

  /// No description provided for @onboarding_hint_selectDateOfBirth.
  ///
  /// In en, this message translates to:
  /// **'Select date of birth'**
  String get onboarding_hint_selectDateOfBirth;

  /// No description provided for @onboarding_error_under18_guardian.
  ///
  /// In en, this message translates to:
  /// **'Your {relation} must be 18 or older to use NOOR.'**
  String onboarding_error_under18_guardian(String relation);

  /// No description provided for @onboarding_error_under18_self.
  ///
  /// In en, this message translates to:
  /// **'You must be 18 or older to use NOOR. We look forward to welcoming you then.'**
  String get onboarding_error_under18_self;

  /// No description provided for @onboarding_label_gender_self.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get onboarding_label_gender_self;

  /// No description provided for @onboarding_label_gender_guardian.
  ///
  /// In en, this message translates to:
  /// **'Candidate\'s gender'**
  String get onboarding_label_gender_guardian;

  /// No description provided for @onboarding_label_country_self.
  ///
  /// In en, this message translates to:
  /// **'Your country'**
  String get onboarding_label_country_self;

  /// No description provided for @onboarding_label_country_guardian.
  ///
  /// In en, this message translates to:
  /// **'Their country'**
  String get onboarding_label_country_guardian;

  /// No description provided for @onboarding_hint_selectCountry.
  ///
  /// In en, this message translates to:
  /// **'Select country'**
  String get onboarding_hint_selectCountry;

  /// No description provided for @onboarding_label_city_self.
  ///
  /// In en, this message translates to:
  /// **'Your city'**
  String get onboarding_label_city_self;

  /// No description provided for @onboarding_label_city_guardian.
  ///
  /// In en, this message translates to:
  /// **'Their city'**
  String get onboarding_label_city_guardian;

  /// No description provided for @onboarding_location_confirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed Location'**
  String get onboarding_location_confirmed;

  /// No description provided for @onboarding_hint_selectCommunity.
  ///
  /// In en, this message translates to:
  /// **'Select community (optional)'**
  String get onboarding_hint_selectCommunity;

  /// No description provided for @onboarding_label_height_self.
  ///
  /// In en, this message translates to:
  /// **'Your height'**
  String get onboarding_label_height_self;

  /// No description provided for @onboarding_label_height_guardian.
  ///
  /// In en, this message translates to:
  /// **'Their height'**
  String get onboarding_label_height_guardian;

  /// No description provided for @onboarding_label_complexion.
  ///
  /// In en, this message translates to:
  /// **'Complexion (Optional)'**
  String get onboarding_label_complexion;

  /// No description provided for @onboarding_hint_selectLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select language'**
  String get onboarding_hint_selectLanguage;

  /// No description provided for @onboarding_label_residencyStatus.
  ///
  /// In en, this message translates to:
  /// **'Residency Status (Optional)'**
  String get onboarding_label_residencyStatus;

  /// No description provided for @onboarding_label_specialNeeds.
  ///
  /// In en, this message translates to:
  /// **'Special Needs (Optional)'**
  String get onboarding_label_specialNeeds;

  /// No description provided for @onboarding_islamicIdentity_subtitle.
  ///
  /// In en, this message translates to:
  /// **'This helps match you with someone compatible.'**
  String get onboarding_islamicIdentity_subtitle;

  /// No description provided for @onboarding_label_subSect.
  ///
  /// In en, this message translates to:
  /// **'School of thought (Optional)'**
  String get onboarding_label_subSect;

  /// No description provided for @onboarding_label_revert.
  ///
  /// In en, this message translates to:
  /// **'Revert / Convert (Optional)'**
  String get onboarding_label_revert;

  /// No description provided for @onboarding_label_revertQuestion.
  ///
  /// In en, this message translates to:
  /// **'Are you a revert (convert) to Islam?'**
  String get onboarding_label_revertQuestion;

  /// No description provided for @onboarding_hijab_always.
  ///
  /// In en, this message translates to:
  /// **'Always'**
  String get onboarding_hijab_always;

  /// No description provided for @onboarding_hijab_sometimes.
  ///
  /// In en, this message translates to:
  /// **'Sometimes'**
  String get onboarding_hijab_sometimes;

  /// No description provided for @onboarding_hijab_no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get onboarding_hijab_no;

  /// No description provided for @onboarding_label_leadership.
  ///
  /// In en, this message translates to:
  /// **'Religious Leadership'**
  String get onboarding_label_leadership;

  /// No description provided for @onboarding_label_leadershipQuestion.
  ///
  /// In en, this message translates to:
  /// **'Can you lead congregational prayers?'**
  String get onboarding_label_leadershipQuestion;

  /// No description provided for @onboarding_leadership_leads.
  ///
  /// In en, this message translates to:
  /// **'Leads Prayer'**
  String get onboarding_leadership_leads;

  /// No description provided for @onboarding_leadership_learning.
  ///
  /// In en, this message translates to:
  /// **'Learning'**
  String get onboarding_leadership_learning;

  /// No description provided for @onboarding_leadership_notYet.
  ///
  /// In en, this message translates to:
  /// **'Not Yet'**
  String get onboarding_leadership_notYet;

  /// No description provided for @onboarding_label_lifestyleDiet.
  ///
  /// In en, this message translates to:
  /// **'Lifestyle & Diet'**
  String get onboarding_label_lifestyleDiet;

  /// No description provided for @onboarding_label_lifestyleDietSub.
  ///
  /// In en, this message translates to:
  /// **'These are dealbreaker fields for many families. Please answer honestly.'**
  String get onboarding_label_lifestyleDietSub;

  /// No description provided for @onboarding_label_substanceUse.
  ///
  /// In en, this message translates to:
  /// **'Substance Use'**
  String get onboarding_label_substanceUse;

  /// No description provided for @onboarding_marriageDeen_title.
  ///
  /// In en, this message translates to:
  /// **'Marriage & Deen'**
  String get onboarding_marriageDeen_title;

  /// No description provided for @onboarding_marriageDeen_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Help us understand your journey and readiness.'**
  String get onboarding_marriageDeen_subtitle;

  /// No description provided for @onboarding_label_quranMemorization.
  ///
  /// In en, this message translates to:
  /// **'Quran Memorization'**
  String get onboarding_label_quranMemorization;

  /// No description provided for @onboarding_quran_none.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get onboarding_quran_none;

  /// No description provided for @onboarding_quran_some.
  ///
  /// In en, this message translates to:
  /// **'Some Surahs'**
  String get onboarding_quran_some;

  /// No description provided for @onboarding_quran_partial.
  ///
  /// In en, this message translates to:
  /// **'Partial Hifz'**
  String get onboarding_quran_partial;

  /// No description provided for @onboarding_quran_hafiz.
  ///
  /// In en, this message translates to:
  /// **'Hafiz / Hafiza'**
  String get onboarding_quran_hafiz;

  /// No description provided for @onboarding_label_religiousEducation.
  ///
  /// In en, this message translates to:
  /// **'Religious Education'**
  String get onboarding_label_religiousEducation;

  /// No description provided for @onboarding_religiousEdu_selfTaught.
  ///
  /// In en, this message translates to:
  /// **'Self-Taught'**
  String get onboarding_religiousEdu_selfTaught;

  /// No description provided for @onboarding_religiousEdu_madrasa.
  ///
  /// In en, this message translates to:
  /// **'Madrasa'**
  String get onboarding_religiousEdu_madrasa;

  /// No description provided for @onboarding_religiousEdu_islamicUni.
  ///
  /// In en, this message translates to:
  /// **'Islamic University'**
  String get onboarding_religiousEdu_islamicUni;

  /// No description provided for @onboarding_religiousEdu_alim.
  ///
  /// In en, this message translates to:
  /// **'Alim Course'**
  String get onboarding_religiousEdu_alim;

  /// No description provided for @onboarding_label_marriageTimeline.
  ///
  /// In en, this message translates to:
  /// **'Marriage Timeline'**
  String get onboarding_label_marriageTimeline;

  /// No description provided for @onboarding_label_marriageTimelineQuestion.
  ///
  /// In en, this message translates to:
  /// **'When are you looking to get married?'**
  String get onboarding_label_marriageTimelineQuestion;

  /// No description provided for @onboarding_timeline_asap.
  ///
  /// In en, this message translates to:
  /// **'As soon as possible'**
  String get onboarding_timeline_asap;

  /// No description provided for @onboarding_timeline_6months.
  ///
  /// In en, this message translates to:
  /// **'Within 6 months'**
  String get onboarding_timeline_6months;

  /// No description provided for @onboarding_timeline_1year.
  ///
  /// In en, this message translates to:
  /// **'Within a year'**
  String get onboarding_timeline_1year;

  /// No description provided for @onboarding_timeline_2years.
  ///
  /// In en, this message translates to:
  /// **'2+ years'**
  String get onboarding_timeline_2years;

  /// No description provided for @onboarding_timeline_notSure.
  ///
  /// In en, this message translates to:
  /// **'Not sure yet'**
  String get onboarding_timeline_notSure;

  /// No description provided for @onboarding_label_niqab.
  ///
  /// In en, this message translates to:
  /// **'Niqab'**
  String get onboarding_label_niqab;

  /// No description provided for @onboarding_niqab_wear.
  ///
  /// In en, this message translates to:
  /// **'I wear niqab'**
  String get onboarding_niqab_wear;

  /// No description provided for @onboarding_niqab_open.
  ///
  /// In en, this message translates to:
  /// **'Open to wearing'**
  String get onboarding_niqab_open;

  /// No description provided for @onboarding_niqab_dontWear.
  ///
  /// In en, this message translates to:
  /// **'I don\'t wear niqab'**
  String get onboarding_niqab_dontWear;

  /// No description provided for @onboarding_label_mahrExpectation.
  ///
  /// In en, this message translates to:
  /// **'Mahr Expectation'**
  String get onboarding_label_mahrExpectation;

  /// No description provided for @onboarding_label_mahrExpectationQuestion.
  ///
  /// In en, this message translates to:
  /// **'What is your expectation for mahr?'**
  String get onboarding_label_mahrExpectationQuestion;

  /// No description provided for @onboarding_mahr_noPreference.
  ///
  /// In en, this message translates to:
  /// **'No preference'**
  String get onboarding_mahr_noPreference;

  /// No description provided for @onboarding_mahr_modest.
  ///
  /// In en, this message translates to:
  /// **'Modest'**
  String get onboarding_mahr_modest;

  /// No description provided for @onboarding_mahr_moderate.
  ///
  /// In en, this message translates to:
  /// **'Moderate'**
  String get onboarding_mahr_moderate;

  /// No description provided for @onboarding_mahr_generous.
  ///
  /// In en, this message translates to:
  /// **'Generous'**
  String get onboarding_mahr_generous;

  /// No description provided for @onboarding_mahr_toDiscuss.
  ///
  /// In en, this message translates to:
  /// **'To discuss'**
  String get onboarding_mahr_toDiscuss;

  /// No description provided for @onboarding_label_workAfterMarriage.
  ///
  /// In en, this message translates to:
  /// **'Work After Marriage'**
  String get onboarding_label_workAfterMarriage;

  /// No description provided for @onboarding_label_workAfterMarriageQuestion.
  ///
  /// In en, this message translates to:
  /// **'Would you like to work after marriage?'**
  String get onboarding_label_workAfterMarriageQuestion;

  /// No description provided for @onboarding_work_yes.
  ///
  /// In en, this message translates to:
  /// **'Yes, I plan to work'**
  String get onboarding_work_yes;

  /// No description provided for @onboarding_work_no.
  ///
  /// In en, this message translates to:
  /// **'No, I prefer not to'**
  String get onboarding_work_no;

  /// No description provided for @onboarding_label_mahrBudget.
  ///
  /// In en, this message translates to:
  /// **'Mahr Budget'**
  String get onboarding_label_mahrBudget;

  /// No description provided for @onboarding_label_mahrBudgetQuestion.
  ///
  /// In en, this message translates to:
  /// **'What mahr range are you prepared to offer?'**
  String get onboarding_label_mahrBudgetQuestion;

  /// No description provided for @onboarding_label_providerReadiness.
  ///
  /// In en, this message translates to:
  /// **'Provider Readiness'**
  String get onboarding_label_providerReadiness;

  /// No description provided for @onboarding_providerQuote.
  ///
  /// In en, this message translates to:
  /// **'\"The best of you are the best to your wives.\" — Prophet Muhammad ﷺ\n\nBeing honest about your readiness helps build a strong foundation.'**
  String get onboarding_providerQuote;

  /// No description provided for @onboarding_label_housing.
  ///
  /// In en, this message translates to:
  /// **'Housing'**
  String get onboarding_label_housing;

  /// No description provided for @onboarding_label_housingQuestion.
  ///
  /// In en, this message translates to:
  /// **'Can you provide a separate living space?'**
  String get onboarding_label_housingQuestion;

  /// No description provided for @onboarding_label_maintenance.
  ///
  /// In en, this message translates to:
  /// **'Financial Maintenance'**
  String get onboarding_label_maintenance;

  /// No description provided for @onboarding_label_maintenanceQuestion.
  ///
  /// In en, this message translates to:
  /// **'Are you able to provide for a spouse financially?'**
  String get onboarding_label_maintenanceQuestion;

  /// No description provided for @onboarding_label_debtStatus.
  ///
  /// In en, this message translates to:
  /// **'Debt Status'**
  String get onboarding_label_debtStatus;

  /// No description provided for @onboarding_label_debtStatusQuestion.
  ///
  /// In en, this message translates to:
  /// **'Your current financial obligations.'**
  String get onboarding_label_debtStatusQuestion;

  /// No description provided for @onboarding_debt_none.
  ///
  /// In en, this message translates to:
  /// **'No debt'**
  String get onboarding_debt_none;

  /// No description provided for @onboarding_debt_manageable.
  ///
  /// In en, this message translates to:
  /// **'Manageable debt'**
  String get onboarding_debt_manageable;

  /// No description provided for @onboarding_debt_significant.
  ///
  /// In en, this message translates to:
  /// **'Significant debt'**
  String get onboarding_debt_significant;

  /// No description provided for @onboarding_marriageDeen_privacyNotice.
  ///
  /// In en, this message translates to:
  /// **'These details are not shown on your public profile. They are shared privately during the acceptance stage.'**
  String get onboarding_marriageDeen_privacyNotice;
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
