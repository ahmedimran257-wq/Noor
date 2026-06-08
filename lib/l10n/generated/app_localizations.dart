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

  /// No description provided for @about_button_later.
  ///
  /// In en, this message translates to:
  /// **'I\'ll do this later'**
  String get about_button_later;

  /// No description provided for @about_hint_bio_guardian.
  ///
  /// In en, this message translates to:
  /// **'Describe your {relation} with honesty and dignity.'**
  String about_hint_bio_guardian(Object relation);

  /// No description provided for @about_hint_bio_self.
  ///
  /// In en, this message translates to:
  /// **'Describe yourself with honesty and dignity.'**
  String get about_hint_bio_self;

  /// No description provided for @about_label_bio_guardian.
  ///
  /// In en, this message translates to:
  /// **'THEIR BIO'**
  String get about_label_bio_guardian;

  /// No description provided for @about_label_bio_self.
  ///
  /// In en, this message translates to:
  /// **'YOUR BIO'**
  String get about_label_bio_self;

  /// No description provided for @about_label_interests.
  ///
  /// In en, this message translates to:
  /// **'INTERESTS'**
  String get about_label_interests;

  /// No description provided for @about_label_languages.
  ///
  /// In en, this message translates to:
  /// **'LANGUAGES SPOKEN'**
  String get about_label_languages;

  /// No description provided for @about_label_selected_count.
  ///
  /// In en, this message translates to:
  /// **'{current}/{max} selected'**
  String about_label_selected_count(Object current, Object max);

  /// No description provided for @about_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Write with honesty and dignity.'**
  String get about_subtitle;

  /// No description provided for @about_title_guardian.
  ///
  /// In en, this message translates to:
  /// **'About your {relation}'**
  String about_title_guardian(Object relation);

  /// No description provided for @about_title_self.
  ///
  /// In en, this message translates to:
  /// **'About you'**
  String get about_title_self;

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

  /// No description provided for @auth_button_resendOtp.
  ///
  /// In en, this message translates to:
  /// **'Resend Code'**
  String get auth_button_resendOtp;

  /// No description provided for @auth_button_sendCode.
  ///
  /// In en, this message translates to:
  /// **'Send Code'**
  String get auth_button_sendCode;

  /// No description provided for @auth_button_sendOtp.
  ///
  /// In en, this message translates to:
  /// **'Send Verification Code'**
  String get auth_button_sendOtp;

  /// No description provided for @auth_button_verifyOtp.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get auth_button_verifyOtp;

  /// No description provided for @auth_hint_phoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get auth_hint_phoneNumber;

  /// No description provided for @auth_label_changeNumber.
  ///
  /// In en, this message translates to:
  /// **'Wrong number? Change it'**
  String get auth_label_changeNumber;

  /// No description provided for @auth_label_enterOtp.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code sent to'**
  String get auth_label_enterOtp;

  /// No description provided for @auth_label_phoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get auth_label_phoneNumber;

  /// No description provided for @auth_label_resendCode.
  ///
  /// In en, this message translates to:
  /// **'Resend code'**
  String get auth_label_resendCode;

  /// No description provided for @auth_label_resendCodeIn.
  ///
  /// In en, this message translates to:
  /// **'Resend code in {seconds}s'**
  String auth_label_resendCodeIn(Object seconds);

  /// No description provided for @auth_label_resendIn.
  ///
  /// In en, this message translates to:
  /// **'Resend in {seconds}s'**
  String auth_label_resendIn(int seconds);

  /// No description provided for @auth_label_sentCodeTo.
  ///
  /// In en, this message translates to:
  /// **'We sent a 6-digit code to\n'**
  String get auth_label_sentCodeTo;

  /// No description provided for @auth_subtitle_verifyOtp.
  ///
  /// In en, this message translates to:
  /// **'We\'ll verify it with a one-time code.'**
  String get auth_subtitle_verifyOtp;

  /// No description provided for @auth_title_enterCode.
  ///
  /// In en, this message translates to:
  /// **'Enter the code'**
  String get auth_title_enterCode;

  /// No description provided for @auth_title_yourNumber.
  ///
  /// In en, this message translates to:
  /// **'Your number'**
  String get auth_title_yourNumber;

  /// No description provided for @background_edu_bachelors.
  ///
  /// In en, this message translates to:
  /// **'Bachelor\'s Degree'**
  String get background_edu_bachelors;

  /// No description provided for @background_edu_below_secondary.
  ///
  /// In en, this message translates to:
  /// **'Below Secondary'**
  String get background_edu_below_secondary;

  /// No description provided for @background_edu_diploma.
  ///
  /// In en, this message translates to:
  /// **'Diploma / Associate'**
  String get background_edu_diploma;

  /// No description provided for @background_edu_doctorate.
  ///
  /// In en, this message translates to:
  /// **'Doctorate / PhD'**
  String get background_edu_doctorate;

  /// No description provided for @background_edu_higher_secondary.
  ///
  /// In en, this message translates to:
  /// **'Higher Secondary / A-Level'**
  String get background_edu_higher_secondary;

  /// No description provided for @background_edu_masters.
  ///
  /// In en, this message translates to:
  /// **'Master\'s Degree'**
  String get background_edu_masters;

  /// No description provided for @background_edu_secondary.
  ///
  /// In en, this message translates to:
  /// **'Secondary / O-Level'**
  String get background_edu_secondary;

  /// No description provided for @background_edu_subtitle_guardian.
  ///
  /// In en, this message translates to:
  /// **'Tell us about your {relation}\'s education and career.'**
  String background_edu_subtitle_guardian(Object relation);

  /// No description provided for @background_edu_subtitle_self.
  ///
  /// In en, this message translates to:
  /// **'Helps find professionally compatible matches.'**
  String get background_edu_subtitle_self;

  /// No description provided for @background_edu_title_guardian.
  ///
  /// In en, this message translates to:
  /// **'Their background'**
  String get background_edu_title_guardian;

  /// No description provided for @background_edu_title_self.
  ///
  /// In en, this message translates to:
  /// **'Your background'**
  String get background_edu_title_self;

  /// No description provided for @background_emp_employed.
  ///
  /// In en, this message translates to:
  /// **'Employed'**
  String get background_emp_employed;

  /// No description provided for @background_emp_not_working.
  ///
  /// In en, this message translates to:
  /// **'Not working'**
  String get background_emp_not_working;

  /// No description provided for @background_emp_self_employed.
  ///
  /// In en, this message translates to:
  /// **'Self-employed'**
  String get background_emp_self_employed;

  /// No description provided for @background_emp_student.
  ///
  /// In en, this message translates to:
  /// **'Student'**
  String get background_emp_student;

  /// No description provided for @background_income_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Many people skip this — it\'s entirely optional.'**
  String get background_income_subtitle;

  /// No description provided for @background_label_eduLevel.
  ///
  /// In en, this message translates to:
  /// **'EDUCATION LEVEL'**
  String get background_label_eduLevel;

  /// No description provided for @background_label_employment.
  ///
  /// In en, this message translates to:
  /// **'EMPLOYMENT STATUS'**
  String get background_label_employment;

  /// No description provided for @background_label_income_bracket.
  ///
  /// In en, this message translates to:
  /// **'INCOME BRACKET ({currency})'**
  String background_label_income_bracket(Object currency);

  /// No description provided for @background_label_income_range.
  ///
  /// In en, this message translates to:
  /// **'INCOME RANGE  (Optional)'**
  String get background_label_income_range;

  /// No description provided for @background_label_profession.
  ///
  /// In en, this message translates to:
  /// **'Profession  (Optional)'**
  String get background_label_profession;

  /// No description provided for @background_label_study.
  ///
  /// In en, this message translates to:
  /// **'Field of study  (Optional)'**
  String get background_label_study;

  /// No description provided for @background_label_who_see.
  ///
  /// In en, this message translates to:
  /// **'WHO CAN SEE THIS?'**
  String get background_label_who_see;

  /// No description provided for @background_vis_everyone.
  ///
  /// In en, this message translates to:
  /// **'Show bracket to everyone'**
  String get background_vis_everyone;

  /// No description provided for @background_vis_mutual.
  ///
  /// In en, this message translates to:
  /// **'Show only after mutual interest'**
  String get background_vis_mutual;

  /// No description provided for @background_vis_private.
  ///
  /// In en, this message translates to:
  /// **'Keep private'**
  String get background_vis_private;

  /// No description provided for @ceremony_text_blessing.
  ///
  /// In en, this message translates to:
  /// **'May Allah bless this with goodness'**
  String get ceremony_text_blessing;

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

  /// No description provided for @chat_endMatch_button.
  ///
  /// In en, this message translates to:
  /// **'Send & End Match'**
  String get chat_endMatch_button;

  /// No description provided for @chat_endMatch_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a respectful message to close this conversation. The other person will be notified.'**
  String get chat_endMatch_subtitle;

  /// No description provided for @chat_endMatch_title.
  ///
  /// In en, this message translates to:
  /// **'End this match'**
  String get chat_endMatch_title;

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

  /// No description provided for @chat_matchClosed_banner.
  ///
  /// In en, this message translates to:
  /// **'This match has been respectfully closed.'**
  String get chat_matchClosed_banner;

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

  /// No description provided for @chat_placeholder_typeMessage.
  ///
  /// In en, this message translates to:
  /// **'Type a message…'**
  String get chat_placeholder_typeMessage;

  /// No description provided for @common_button_back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get common_button_back;

  /// No description provided for @common_button_cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get common_button_cancel;

  /// No description provided for @common_button_done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get common_button_done;

  /// No description provided for @common_button_next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get common_button_next;

  /// No description provided for @common_button_retry.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get common_button_retry;

  /// No description provided for @common_button_save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get common_button_save;

  /// No description provided for @common_button_skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get common_button_skip;

  /// No description provided for @common_button_submit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get common_button_submit;

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

  /// No description provided for @common_label_optional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get common_label_optional;

  /// No description provided for @copy_beard_parent.
  ///
  /// In en, this message translates to:
  /// **'Does your son have a beard?'**
  String get copy_beard_parent;

  /// No description provided for @copy_beard_self.
  ///
  /// In en, this message translates to:
  /// **'Do you have a beard?'**
  String get copy_beard_self;

  /// No description provided for @copy_beard_sibling.
  ///
  /// In en, this message translates to:
  /// **'Does your brother have a beard?'**
  String get copy_beard_sibling;

  /// No description provided for @copy_hijab_parent.
  ///
  /// In en, this message translates to:
  /// **'Does your daughter observe hijab?'**
  String get copy_hijab_parent;

  /// No description provided for @copy_hijab_self.
  ///
  /// In en, this message translates to:
  /// **'Do you observe hijab?'**
  String get copy_hijab_self;

  /// No description provided for @copy_hijab_sibling.
  ///
  /// In en, this message translates to:
  /// **'Does your sister observe hijab?'**
  String get copy_hijab_sibling;

  /// No description provided for @copy_prayer_parent.
  ///
  /// In en, this message translates to:
  /// **'Does your child pray five times daily?'**
  String get copy_prayer_parent;

  /// No description provided for @copy_prayer_self.
  ///
  /// In en, this message translates to:
  /// **'Do you pray five times daily?'**
  String get copy_prayer_self;

  /// No description provided for @copy_prayer_sibling.
  ///
  /// In en, this message translates to:
  /// **'Does your sibling pray five times daily?'**
  String get copy_prayer_sibling;

  /// No description provided for @deleteAccount_title.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccount_title;

  /// No description provided for @discovery_bookmark_removed.
  ///
  /// In en, this message translates to:
  /// **'{name} removed'**
  String discovery_bookmark_removed(Object name);

  /// No description provided for @discovery_bookmark_saved.
  ///
  /// In en, this message translates to:
  /// **'{name} saved'**
  String discovery_bookmark_saved(Object name);

  /// No description provided for @discovery_button_sendInterest.
  ///
  /// In en, this message translates to:
  /// **'Send Interest'**
  String get discovery_button_sendInterest;

  /// No description provided for @discovery_completeness_button.
  ///
  /// In en, this message translates to:
  /// **'Complete Profile'**
  String get discovery_completeness_button;

  /// No description provided for @discovery_completeness_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Profiles above 40% get 3× more interests.\nComplete your profile to start browsing.'**
  String get discovery_completeness_subtitle;

  /// No description provided for @discovery_completeness_title.
  ///
  /// In en, this message translates to:
  /// **'Complete Your Profile'**
  String get discovery_completeness_title;

  /// No description provided for @discovery_empty_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Try expanding your search filters\nor check back tomorrow.'**
  String get discovery_empty_subtitle;

  /// No description provided for @discovery_empty_title.
  ///
  /// In en, this message translates to:
  /// **'You\'ve seen everyone nearby'**
  String get discovery_empty_title;

  /// No description provided for @discovery_header_title.
  ///
  /// In en, this message translates to:
  /// **'NOOR'**
  String get discovery_header_title;

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

  /// No description provided for @discovery_label_profilesRemaining.
  ///
  /// In en, this message translates to:
  /// **'{count} profiles remaining today'**
  String discovery_label_profilesRemaining(int count);

  /// No description provided for @discovery_limit_button.
  ///
  /// In en, this message translates to:
  /// **'Upgrade Now'**
  String get discovery_limit_button;

  /// No description provided for @discovery_limit_subtitle.
  ///
  /// In en, this message translates to:
  /// **'You\'ve browsed 15 profiles today.\nUpgrade to unlock unlimited browsing.'**
  String get discovery_limit_subtitle;

  /// No description provided for @discovery_limit_title.
  ///
  /// In en, this message translates to:
  /// **'Daily limit reached'**
  String get discovery_limit_title;

  /// No description provided for @discovery_remaining_profiles.
  ///
  /// In en, this message translates to:
  /// **'{count} profiles remaining'**
  String discovery_remaining_profiles(Object count);

  /// No description provided for @discovery_wildcard_label.
  ///
  /// In en, this message translates to:
  /// **'Someone you might connect with'**
  String get discovery_wildcard_label;

  /// No description provided for @family_children_no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get family_children_no;

  /// No description provided for @family_children_yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get family_children_yes;

  /// No description provided for @family_label_children_guardian.
  ///
  /// In en, this message translates to:
  /// **'DO THEY HAVE CHILDREN?'**
  String get family_label_children_guardian;

  /// No description provided for @family_label_children_self.
  ///
  /// In en, this message translates to:
  /// **'DO YOU HAVE CHILDREN?'**
  String get family_label_children_self;

  /// No description provided for @family_label_how_many.
  ///
  /// In en, this message translates to:
  /// **'HOW MANY?'**
  String get family_label_how_many;

  /// No description provided for @family_label_parents.
  ///
  /// In en, this message translates to:
  /// **'PARENTS\' MARITAL STATUS'**
  String get family_label_parents;

  /// No description provided for @family_label_polygamy_female_self.
  ///
  /// In en, this message translates to:
  /// **'POLYGAMY ACCEPTANCE  (Optional)'**
  String get family_label_polygamy_female_self;

  /// No description provided for @family_label_polygamy_male_self.
  ///
  /// In en, this message translates to:
  /// **'POLYGAMY STATUS  (Optional)'**
  String get family_label_polygamy_male_self;

  /// No description provided for @family_label_prev_married.
  ///
  /// In en, this message translates to:
  /// **'PREVIOUSLY MARRIED?'**
  String get family_label_prev_married;

  /// No description provided for @family_label_relocate.
  ///
  /// In en, this message translates to:
  /// **'WILLING TO RELOCATE'**
  String get family_label_relocate;

  /// No description provided for @family_label_siblings.
  ///
  /// In en, this message translates to:
  /// **'NUMBER OF SIBLINGS'**
  String get family_label_siblings;

  /// No description provided for @family_label_type.
  ///
  /// In en, this message translates to:
  /// **'FAMILY TYPE'**
  String get family_label_type;

  /// No description provided for @family_living_title.
  ///
  /// In en, this message translates to:
  /// **'POST-MARRIAGE LIVING EXPECTATIONS'**
  String get family_living_title;

  /// No description provided for @family_parents_both_deceased.
  ///
  /// In en, this message translates to:
  /// **'Both deceased'**
  String get family_parents_both_deceased;

  /// No description provided for @family_parents_divorced.
  ///
  /// In en, this message translates to:
  /// **'Divorced'**
  String get family_parents_divorced;

  /// No description provided for @family_parents_father_deceased.
  ///
  /// In en, this message translates to:
  /// **'Father deceased'**
  String get family_parents_father_deceased;

  /// No description provided for @family_parents_mother_deceased.
  ///
  /// In en, this message translates to:
  /// **'Mother deceased'**
  String get family_parents_mother_deceased;

  /// No description provided for @family_parents_separated.
  ///
  /// In en, this message translates to:
  /// **'Separated'**
  String get family_parents_separated;

  /// No description provided for @family_parents_together.
  ///
  /// In en, this message translates to:
  /// **'Together'**
  String get family_parents_together;

  /// No description provided for @family_polygamy_female_discussion.
  ///
  /// In en, this message translates to:
  /// **'Open to discussion'**
  String get family_polygamy_female_discussion;

  /// No description provided for @family_polygamy_female_no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get family_polygamy_female_no;

  /// No description provided for @family_polygamy_female_prefer_not.
  ///
  /// In en, this message translates to:
  /// **'Prefer not to say'**
  String get family_polygamy_female_prefer_not;

  /// No description provided for @family_polygamy_female_sub_guardian.
  ///
  /// In en, this message translates to:
  /// **'Would your {relation} consider being a co-wife?'**
  String family_polygamy_female_sub_guardian(Object relation);

  /// No description provided for @family_polygamy_female_sub_self.
  ///
  /// In en, this message translates to:
  /// **'Would you consider being a co-wife?'**
  String get family_polygamy_female_sub_self;

  /// No description provided for @family_polygamy_female_yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get family_polygamy_female_yes;

  /// No description provided for @family_polygamy_male_sub_guardian.
  ///
  /// In en, this message translates to:
  /// **'Is your {relation} currently married and looking for an additional spouse?'**
  String family_polygamy_male_sub_guardian(Object relation);

  /// No description provided for @family_polygamy_male_sub_self.
  ///
  /// In en, this message translates to:
  /// **'Are you currently married and looking for an additional spouse?'**
  String get family_polygamy_male_sub_self;

  /// No description provided for @family_polygamy_option_first.
  ///
  /// In en, this message translates to:
  /// **'No, this is my first'**
  String get family_polygamy_option_first;

  /// No description provided for @family_polygamy_option_married.
  ///
  /// In en, this message translates to:
  /// **'Yes, currently married'**
  String get family_polygamy_option_married;

  /// No description provided for @family_polygamy_option_prefer_not.
  ///
  /// In en, this message translates to:
  /// **'Prefer not to say'**
  String get family_polygamy_option_prefer_not;

  /// No description provided for @family_prev_divorced.
  ///
  /// In en, this message translates to:
  /// **'Divorced'**
  String get family_prev_divorced;

  /// No description provided for @family_prev_no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get family_prev_no;

  /// No description provided for @family_prev_widowed.
  ///
  /// In en, this message translates to:
  /// **'Widowed'**
  String get family_prev_widowed;

  /// No description provided for @family_relocate_discussion.
  ///
  /// In en, this message translates to:
  /// **'Open to Discussion'**
  String get family_relocate_discussion;

  /// No description provided for @family_relocate_no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get family_relocate_no;

  /// No description provided for @family_relocate_subtitle_guardian.
  ///
  /// In en, this message translates to:
  /// **'Would your {relation} relocate for marriage?'**
  String family_relocate_subtitle_guardian(Object relation);

  /// No description provided for @family_relocate_subtitle_self.
  ///
  /// In en, this message translates to:
  /// **'Would you relocate for marriage?'**
  String get family_relocate_subtitle_self;

  /// No description provided for @family_relocate_yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get family_relocate_yes;

  /// No description provided for @family_subtitle_guardian.
  ///
  /// In en, this message translates to:
  /// **'Tell us about your {relation}\'s family.'**
  String family_subtitle_guardian(Object relation);

  /// No description provided for @family_subtitle_self.
  ///
  /// In en, this message translates to:
  /// **'Family compatibility is central to lasting marriages.'**
  String get family_subtitle_self;

  /// No description provided for @family_title_guardian.
  ///
  /// In en, this message translates to:
  /// **'Family background'**
  String get family_title_guardian;

  /// No description provided for @family_title_self.
  ///
  /// In en, this message translates to:
  /// **'Family background'**
  String get family_title_self;

  /// No description provided for @family_type_extended.
  ///
  /// In en, this message translates to:
  /// **'Extended'**
  String get family_type_extended;

  /// No description provided for @family_type_joint.
  ///
  /// In en, this message translates to:
  /// **'Joint'**
  String get family_type_joint;

  /// No description provided for @family_type_nuclear.
  ///
  /// In en, this message translates to:
  /// **'Nuclear'**
  String get family_type_nuclear;

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

  /// No description provided for @filter_label_motherTongue.
  ///
  /// In en, this message translates to:
  /// **'Mother Tongue'**
  String get filter_label_motherTongue;

  /// No description provided for @guardian_details_candidate_female.
  ///
  /// In en, this message translates to:
  /// **'Female candidate • Women message free'**
  String get guardian_details_candidate_female;

  /// No description provided for @guardian_details_candidate_label.
  ///
  /// In en, this message translates to:
  /// **'CREATING PROFILE FOR'**
  String get guardian_details_candidate_label;

  /// No description provided for @guardian_details_candidate_male.
  ///
  /// In en, this message translates to:
  /// **'Male candidate'**
  String get guardian_details_candidate_male;

  /// No description provided for @guardian_details_candidate_relation.
  ///
  /// In en, this message translates to:
  /// **'My {relation}'**
  String guardian_details_candidate_relation(Object relation);

  /// No description provided for @guardian_details_involvement.
  ///
  /// In en, this message translates to:
  /// **'GUARDIAN INVOLVEMENT'**
  String get guardian_details_involvement;

  /// No description provided for @guardian_details_involvement_subtitle.
  ///
  /// In en, this message translates to:
  /// **'How involved do you want to be in conversations?'**
  String get guardian_details_involvement_subtitle;

  /// No description provided for @guardian_details_mode_active_sub.
  ///
  /// In en, this message translates to:
  /// **'See chats, approve matches, and send messages on behalf of your {relation}.'**
  String guardian_details_mode_active_sub(Object relation);

  /// No description provided for @guardian_details_mode_active_title.
  ///
  /// In en, this message translates to:
  /// **'Active guardian'**
  String get guardian_details_mode_active_title;

  /// No description provided for @guardian_details_mode_passive_sub.
  ///
  /// In en, this message translates to:
  /// **'See all chats in real-time, but only your {relation} can send messages.'**
  String guardian_details_mode_passive_sub(Object relation);

  /// No description provided for @guardian_details_mode_passive_title.
  ///
  /// In en, this message translates to:
  /// **'Observe only'**
  String get guardian_details_mode_passive_title;

  /// No description provided for @guardian_details_name_hint.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get guardian_details_name_hint;

  /// No description provided for @guardian_details_name_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Your name as the guardian. This is shown to matches.'**
  String get guardian_details_name_subtitle;

  /// No description provided for @guardian_details_notice.
  ///
  /// In en, this message translates to:
  /// **'You are creating a profile for your {relation}. All profile details on the next screens will describe them, not you.'**
  String guardian_details_notice(Object relation);

  /// No description provided for @guardian_details_phone_hint.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get guardian_details_phone_hint;

  /// No description provided for @guardian_details_phone_subtitle.
  ///
  /// In en, this message translates to:
  /// **'For account verification. Not shown on the profile.'**
  String get guardian_details_phone_subtitle;

  /// No description provided for @guardian_details_privacy_note.
  ///
  /// In en, this message translates to:
  /// **'Your phone number is encrypted and never shown publicly. Potential matches will see \"{relation}\'s Guardian\" on the profile.'**
  String guardian_details_privacy_note(Object relation);

  /// No description provided for @guardian_details_search_hint.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get guardian_details_search_hint;

  /// No description provided for @guardian_details_select_code.
  ///
  /// In en, this message translates to:
  /// **'Select country code'**
  String get guardian_details_select_code;

  /// No description provided for @guardian_details_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Tell us about yourself as the guardian.'**
  String get guardian_details_subtitle;

  /// No description provided for @guardian_details_title.
  ///
  /// In en, this message translates to:
  /// **'Your guardian details'**
  String get guardian_details_title;

  /// No description provided for @guardian_details_your_name.
  ///
  /// In en, this message translates to:
  /// **'YOUR NAME'**
  String get guardian_details_your_name;

  /// No description provided for @guardian_details_your_phone.
  ///
  /// In en, this message translates to:
  /// **'YOUR PHONE NUMBER'**
  String get guardian_details_your_phone;

  /// No description provided for @interest_cat_creative.
  ///
  /// In en, this message translates to:
  /// **'Creative'**
  String get interest_cat_creative;

  /// No description provided for @interest_cat_faith.
  ///
  /// In en, this message translates to:
  /// **'Faith'**
  String get interest_cat_faith;

  /// No description provided for @interest_cat_learning.
  ///
  /// In en, this message translates to:
  /// **'Learning'**
  String get interest_cat_learning;

  /// No description provided for @interest_cat_lifestyle.
  ///
  /// In en, this message translates to:
  /// **'Lifestyle'**
  String get interest_cat_lifestyle;

  /// No description provided for @interest_cat_social.
  ///
  /// In en, this message translates to:
  /// **'Social'**
  String get interest_cat_social;

  /// No description provided for @interest_cat_sports.
  ///
  /// In en, this message translates to:
  /// **'Sports'**
  String get interest_cat_sports;

  /// No description provided for @interest_tag_art.
  ///
  /// In en, this message translates to:
  /// **'Art'**
  String get interest_tag_art;

  /// No description provided for @interest_tag_calligraphy.
  ///
  /// In en, this message translates to:
  /// **'Calligraphy'**
  String get interest_tag_calligraphy;

  /// No description provided for @interest_tag_community_work.
  ///
  /// In en, this message translates to:
  /// **'Community work'**
  String get interest_tag_community_work;

  /// No description provided for @interest_tag_cooking.
  ///
  /// In en, this message translates to:
  /// **'Cooking'**
  String get interest_tag_cooking;

  /// No description provided for @interest_tag_crafts.
  ///
  /// In en, this message translates to:
  /// **'Crafts'**
  String get interest_tag_crafts;

  /// No description provided for @interest_tag_cricket.
  ///
  /// In en, this message translates to:
  /// **'Cricket'**
  String get interest_tag_cricket;

  /// No description provided for @interest_tag_cycling.
  ///
  /// In en, this message translates to:
  /// **'Cycling'**
  String get interest_tag_cycling;

  /// No description provided for @interest_tag_dawah.
  ///
  /// In en, this message translates to:
  /// **'Dawah'**
  String get interest_tag_dawah;

  /// No description provided for @interest_tag_family_gatherings.
  ///
  /// In en, this message translates to:
  /// **'Family gatherings'**
  String get interest_tag_family_gatherings;

  /// No description provided for @interest_tag_fitness.
  ///
  /// In en, this message translates to:
  /// **'Fitness'**
  String get interest_tag_fitness;

  /// No description provided for @interest_tag_football.
  ///
  /// In en, this message translates to:
  /// **'Football'**
  String get interest_tag_football;

  /// No description provided for @interest_tag_gardening.
  ///
  /// In en, this message translates to:
  /// **'Gardening'**
  String get interest_tag_gardening;

  /// No description provided for @interest_tag_graphic_design.
  ///
  /// In en, this message translates to:
  /// **'Graphic design'**
  String get interest_tag_graphic_design;

  /// No description provided for @interest_tag_hiking.
  ///
  /// In en, this message translates to:
  /// **'Hiking'**
  String get interest_tag_hiking;

  /// No description provided for @interest_tag_history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get interest_tag_history;

  /// No description provided for @interest_tag_islamic_lectures.
  ///
  /// In en, this message translates to:
  /// **'Islamic lectures'**
  String get interest_tag_islamic_lectures;

  /// No description provided for @interest_tag_languages.
  ///
  /// In en, this message translates to:
  /// **'Languages'**
  String get interest_tag_languages;

  /// No description provided for @interest_tag_martial_arts.
  ///
  /// In en, this message translates to:
  /// **'Martial arts'**
  String get interest_tag_martial_arts;

  /// No description provided for @interest_tag_mentoring.
  ///
  /// In en, this message translates to:
  /// **'Mentoring'**
  String get interest_tag_mentoring;

  /// No description provided for @interest_tag_photography.
  ///
  /// In en, this message translates to:
  /// **'Photography'**
  String get interest_tag_photography;

  /// No description provided for @interest_tag_poetry.
  ///
  /// In en, this message translates to:
  /// **'Poetry'**
  String get interest_tag_poetry;

  /// No description provided for @interest_tag_quran_recitation.
  ///
  /// In en, this message translates to:
  /// **'Quran recitation'**
  String get interest_tag_quran_recitation;

  /// No description provided for @interest_tag_reading.
  ///
  /// In en, this message translates to:
  /// **'Reading'**
  String get interest_tag_reading;

  /// No description provided for @interest_tag_science.
  ///
  /// In en, this message translates to:
  /// **'Science'**
  String get interest_tag_science;

  /// No description provided for @interest_tag_swimming.
  ///
  /// In en, this message translates to:
  /// **'Swimming'**
  String get interest_tag_swimming;

  /// No description provided for @interest_tag_tahajjud.
  ///
  /// In en, this message translates to:
  /// **'Tahajjud'**
  String get interest_tag_tahajjud;

  /// No description provided for @interest_tag_teaching.
  ///
  /// In en, this message translates to:
  /// **'Teaching'**
  String get interest_tag_teaching;

  /// No description provided for @interest_tag_technology.
  ///
  /// In en, this message translates to:
  /// **'Technology'**
  String get interest_tag_technology;

  /// No description provided for @interest_tag_travel.
  ///
  /// In en, this message translates to:
  /// **'Travel'**
  String get interest_tag_travel;

  /// No description provided for @interest_tag_umrah_hajj.
  ///
  /// In en, this message translates to:
  /// **'Umrah/Hajj'**
  String get interest_tag_umrah_hajj;

  /// No description provided for @interest_tag_voluntary_fasting.
  ///
  /// In en, this message translates to:
  /// **'Voluntary fasting'**
  String get interest_tag_voluntary_fasting;

  /// No description provided for @interest_tag_volunteering.
  ///
  /// In en, this message translates to:
  /// **'Volunteering'**
  String get interest_tag_volunteering;

  /// No description provided for @interest_tag_writing.
  ///
  /// In en, this message translates to:
  /// **'Writing'**
  String get interest_tag_writing;

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

  /// No description provided for @interests_title.
  ///
  /// In en, this message translates to:
  /// **'Interests'**
  String get interests_title;

  /// No description provided for @lang_albanian.
  ///
  /// In en, this message translates to:
  /// **'Albanian'**
  String get lang_albanian;

  /// No description provided for @lang_amazigh.
  ///
  /// In en, this message translates to:
  /// **'Amazigh (Berber)'**
  String get lang_amazigh;

  /// No description provided for @lang_amharic.
  ///
  /// In en, this message translates to:
  /// **'Amharic'**
  String get lang_amharic;

  /// No description provided for @lang_arabic.
  ///
  /// In en, this message translates to:
  /// **'Arabic'**
  String get lang_arabic;

  /// No description provided for @lang_assamese.
  ///
  /// In en, this message translates to:
  /// **'Assamese'**
  String get lang_assamese;

  /// No description provided for @lang_balochi.
  ///
  /// In en, this message translates to:
  /// **'Balochi'**
  String get lang_balochi;

  /// No description provided for @lang_bengali.
  ///
  /// In en, this message translates to:
  /// **'Bengali'**
  String get lang_bengali;

  /// No description provided for @lang_bosnian.
  ///
  /// In en, this message translates to:
  /// **'Bosnian'**
  String get lang_bosnian;

  /// No description provided for @lang_burmese.
  ///
  /// In en, this message translates to:
  /// **'Burmese'**
  String get lang_burmese;

  /// No description provided for @lang_chechen.
  ///
  /// In en, this message translates to:
  /// **'Chechen'**
  String get lang_chechen;

  /// No description provided for @lang_chinese.
  ///
  /// In en, this message translates to:
  /// **'Chinese (Mandarin)'**
  String get lang_chinese;

  /// No description provided for @lang_dari.
  ///
  /// In en, this message translates to:
  /// **'Dari'**
  String get lang_dari;

  /// No description provided for @lang_dutch.
  ///
  /// In en, this message translates to:
  /// **'Dutch'**
  String get lang_dutch;

  /// No description provided for @lang_english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get lang_english;

  /// No description provided for @lang_french.
  ///
  /// In en, this message translates to:
  /// **'French'**
  String get lang_french;

  /// No description provided for @lang_fulani.
  ///
  /// In en, this message translates to:
  /// **'Fulani'**
  String get lang_fulani;

  /// No description provided for @lang_german.
  ///
  /// In en, this message translates to:
  /// **'German'**
  String get lang_german;

  /// No description provided for @lang_gujarati.
  ///
  /// In en, this message translates to:
  /// **'Gujarati'**
  String get lang_gujarati;

  /// No description provided for @lang_hausa.
  ///
  /// In en, this message translates to:
  /// **'Hausa'**
  String get lang_hausa;

  /// No description provided for @lang_hindi.
  ///
  /// In en, this message translates to:
  /// **'Hindi'**
  String get lang_hindi;

  /// No description provided for @lang_igbo.
  ///
  /// In en, this message translates to:
  /// **'Igbo'**
  String get lang_igbo;

  /// No description provided for @lang_indonesian.
  ///
  /// In en, this message translates to:
  /// **'Indonesian'**
  String get lang_indonesian;

  /// No description provided for @lang_italian.
  ///
  /// In en, this message translates to:
  /// **'Italian'**
  String get lang_italian;

  /// No description provided for @lang_japanese.
  ///
  /// In en, this message translates to:
  /// **'Japanese'**
  String get lang_japanese;

  /// No description provided for @lang_javanese.
  ///
  /// In en, this message translates to:
  /// **'Javanese'**
  String get lang_javanese;

  /// No description provided for @lang_kannada.
  ///
  /// In en, this message translates to:
  /// **'Kannada'**
  String get lang_kannada;

  /// No description provided for @lang_kazakh.
  ///
  /// In en, this message translates to:
  /// **'Kazakh'**
  String get lang_kazakh;

  /// No description provided for @lang_korean.
  ///
  /// In en, this message translates to:
  /// **'Korean'**
  String get lang_korean;

  /// No description provided for @lang_kurdish.
  ///
  /// In en, this message translates to:
  /// **'Kurdish'**
  String get lang_kurdish;

  /// No description provided for @lang_kyrgyz.
  ///
  /// In en, this message translates to:
  /// **'Kyrgyz'**
  String get lang_kyrgyz;

  /// No description provided for @lang_malay.
  ///
  /// In en, this message translates to:
  /// **'Malay'**
  String get lang_malay;

  /// No description provided for @lang_malayalam.
  ///
  /// In en, this message translates to:
  /// **'Malayalam'**
  String get lang_malayalam;

  /// No description provided for @lang_mandinka.
  ///
  /// In en, this message translates to:
  /// **'Mandinka'**
  String get lang_mandinka;

  /// No description provided for @lang_marathi.
  ///
  /// In en, this message translates to:
  /// **'Marathi'**
  String get lang_marathi;

  /// No description provided for @lang_norwegian.
  ///
  /// In en, this message translates to:
  /// **'Norwegian'**
  String get lang_norwegian;

  /// No description provided for @lang_odia.
  ///
  /// In en, this message translates to:
  /// **'Odia'**
  String get lang_odia;

  /// No description provided for @lang_other.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get lang_other;

  /// No description provided for @lang_pashto.
  ///
  /// In en, this message translates to:
  /// **'Pashto'**
  String get lang_pashto;

  /// No description provided for @lang_persian.
  ///
  /// In en, this message translates to:
  /// **'Persian'**
  String get lang_persian;

  /// No description provided for @lang_portuguese.
  ///
  /// In en, this message translates to:
  /// **'Portuguese'**
  String get lang_portuguese;

  /// No description provided for @lang_punjabi.
  ///
  /// In en, this message translates to:
  /// **'Punjabi'**
  String get lang_punjabi;

  /// No description provided for @lang_rohingya.
  ///
  /// In en, this message translates to:
  /// **'Rohingya'**
  String get lang_rohingya;

  /// No description provided for @lang_russian.
  ///
  /// In en, this message translates to:
  /// **'Russian'**
  String get lang_russian;

  /// No description provided for @lang_saraiki.
  ///
  /// In en, this message translates to:
  /// **'Saraiki'**
  String get lang_saraiki;

  /// No description provided for @lang_sindhi.
  ///
  /// In en, this message translates to:
  /// **'Sindhi'**
  String get lang_sindhi;

  /// No description provided for @lang_somali.
  ///
  /// In en, this message translates to:
  /// **'Somali'**
  String get lang_somali;

  /// No description provided for @lang_spanish.
  ///
  /// In en, this message translates to:
  /// **'Spanish'**
  String get lang_spanish;

  /// No description provided for @lang_sundanese.
  ///
  /// In en, this message translates to:
  /// **'Sundanese'**
  String get lang_sundanese;

  /// No description provided for @lang_swahili.
  ///
  /// In en, this message translates to:
  /// **'Swahili'**
  String get lang_swahili;

  /// No description provided for @lang_swedish.
  ///
  /// In en, this message translates to:
  /// **'Swedish'**
  String get lang_swedish;

  /// No description provided for @lang_tagalog.
  ///
  /// In en, this message translates to:
  /// **'Tagalog'**
  String get lang_tagalog;

  /// No description provided for @lang_tajik.
  ///
  /// In en, this message translates to:
  /// **'Tajik'**
  String get lang_tajik;

  /// No description provided for @lang_tamil.
  ///
  /// In en, this message translates to:
  /// **'Tamil'**
  String get lang_tamil;

  /// No description provided for @lang_tatar.
  ///
  /// In en, this message translates to:
  /// **'Tatar'**
  String get lang_tatar;

  /// No description provided for @lang_telugu.
  ///
  /// In en, this message translates to:
  /// **'Telugu'**
  String get lang_telugu;

  /// No description provided for @lang_thai.
  ///
  /// In en, this message translates to:
  /// **'Thai'**
  String get lang_thai;

  /// No description provided for @lang_tigrinya.
  ///
  /// In en, this message translates to:
  /// **'Tigrinya'**
  String get lang_tigrinya;

  /// No description provided for @lang_turkish.
  ///
  /// In en, this message translates to:
  /// **'Turkish'**
  String get lang_turkish;

  /// No description provided for @lang_urdu.
  ///
  /// In en, this message translates to:
  /// **'Urdu'**
  String get lang_urdu;

  /// No description provided for @lang_uzbek.
  ///
  /// In en, this message translates to:
  /// **'Uzbek'**
  String get lang_uzbek;

  /// No description provided for @lang_wolof.
  ///
  /// In en, this message translates to:
  /// **'Wolof'**
  String get lang_wolof;

  /// No description provided for @lang_yoruba.
  ///
  /// In en, this message translates to:
  /// **'Yoruba'**
  String get lang_yoruba;

  /// No description provided for @legal_button_continue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get legal_button_continue;

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

  /// No description provided for @legal_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Please read and agree to continue.'**
  String get legal_subtitle;

  /// No description provided for @legal_summary_1.
  ///
  /// In en, this message translates to:
  /// **'Your data is encrypted and never sold to third parties.'**
  String get legal_summary_1;

  /// No description provided for @legal_summary_2.
  ///
  /// In en, this message translates to:
  /// **'Your photos are reviewed before your profile goes live.'**
  String get legal_summary_2;

  /// No description provided for @legal_summary_3.
  ///
  /// In en, this message translates to:
  /// **'Harassment, fake profiles, and scams result in permanent bans.'**
  String get legal_summary_3;

  /// No description provided for @legal_summary_4.
  ///
  /// In en, this message translates to:
  /// **'This platform is for marriage intentions only. Dignity is the standard.'**
  String get legal_summary_4;

  /// No description provided for @legal_summary_5.
  ///
  /// In en, this message translates to:
  /// **'You may delete your account and all data at any time.'**
  String get legal_summary_5;

  /// No description provided for @legal_title.
  ///
  /// In en, this message translates to:
  /// **'Before you begin'**
  String get legal_title;

  /// No description provided for @notifications_empty_subtitle.
  ///
  /// In en, this message translates to:
  /// **'No new notifications right now.'**
  String get notifications_empty_subtitle;

  /// No description provided for @notifications_empty_title.
  ///
  /// In en, this message translates to:
  /// **'You\'re all caught up'**
  String get notifications_empty_title;

  /// No description provided for @notifications_markAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all read'**
  String get notifications_markAllRead;

  /// No description provided for @notifications_title.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications_title;

  /// No description provided for @onboarding_about_title.
  ///
  /// In en, this message translates to:
  /// **'About yourself'**
  String get onboarding_about_title;

  /// No description provided for @onboarding_background_title.
  ///
  /// In en, this message translates to:
  /// **'Education & Career'**
  String get onboarding_background_title;

  /// No description provided for @onboarding_basicIdentity_guardianBanner.
  ///
  /// In en, this message translates to:
  /// **'You are filling this as a guardian. These details are about your {relation}.'**
  String onboarding_basicIdentity_guardianBanner(String relation);

  /// No description provided for @onboarding_basicIdentity_subtitle_guardian.
  ///
  /// In en, this message translates to:
  /// **'This is what others will see on their profile.'**
  String get onboarding_basicIdentity_subtitle_guardian;

  /// No description provided for @onboarding_basicIdentity_subtitle_self.
  ///
  /// In en, this message translates to:
  /// **'This is what others will see on your profile.'**
  String get onboarding_basicIdentity_subtitle_self;

  /// No description provided for @onboarding_basicIdentity_title.
  ///
  /// In en, this message translates to:
  /// **'Tell us about yourself'**
  String get onboarding_basicIdentity_title;

  /// No description provided for @onboarding_basicIdentity_title_guardian.
  ///
  /// In en, this message translates to:
  /// **'Tell us about your {relation}'**
  String onboarding_basicIdentity_title_guardian(String relation);

  /// No description provided for @onboarding_debt_manageable.
  ///
  /// In en, this message translates to:
  /// **'Manageable debt'**
  String get onboarding_debt_manageable;

  /// No description provided for @onboarding_debt_none.
  ///
  /// In en, this message translates to:
  /// **'No debt'**
  String get onboarding_debt_none;

  /// No description provided for @onboarding_debt_significant.
  ///
  /// In en, this message translates to:
  /// **'Significant debt'**
  String get onboarding_debt_significant;

  /// No description provided for @onboarding_diet_eatsAnything.
  ///
  /// In en, this message translates to:
  /// **'Eats anything halal'**
  String get onboarding_diet_eatsAnything;

  /// No description provided for @onboarding_diet_halalOnly.
  ///
  /// In en, this message translates to:
  /// **'Halal only'**
  String get onboarding_diet_halalOnly;

  /// No description provided for @onboarding_diet_vegan.
  ///
  /// In en, this message translates to:
  /// **'Vegan'**
  String get onboarding_diet_vegan;

  /// No description provided for @onboarding_diet_vegetarian.
  ///
  /// In en, this message translates to:
  /// **'Vegetarian'**
  String get onboarding_diet_vegetarian;

  /// No description provided for @onboarding_diet_zabihaStrict.
  ///
  /// In en, this message translates to:
  /// **'Strict Zabiha'**
  String get onboarding_diet_zabihaStrict;

  /// No description provided for @onboarding_error_bioContactInfo.
  ///
  /// In en, this message translates to:
  /// **'Please remove contact information from your bio. External contact details are not allowed for your safety.'**
  String get onboarding_error_bioContactInfo;

  /// No description provided for @onboarding_error_multipleFaces.
  ///
  /// In en, this message translates to:
  /// **'Group photos cannot be your primary photo.'**
  String get onboarding_error_multipleFaces;

  /// No description provided for @onboarding_error_noFace.
  ///
  /// In en, this message translates to:
  /// **'Please use a photo where your face is clearly visible.'**
  String get onboarding_error_noFace;

  /// No description provided for @onboarding_error_under18.
  ///
  /// In en, this message translates to:
  /// **'NOOR is for those 18 and older. We\'ve made this requirement to protect everyone in our community.'**
  String get onboarding_error_under18;

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

  /// No description provided for @onboarding_habit_frequently.
  ///
  /// In en, this message translates to:
  /// **'Frequently'**
  String get onboarding_habit_frequently;

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

  /// No description provided for @onboarding_habit_preferNotToSay.
  ///
  /// In en, this message translates to:
  /// **'Prefer not to say'**
  String get onboarding_habit_preferNotToSay;

  /// No description provided for @onboarding_hijab_always.
  ///
  /// In en, this message translates to:
  /// **'Always'**
  String get onboarding_hijab_always;

  /// No description provided for @onboarding_hijab_no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get onboarding_hijab_no;

  /// No description provided for @onboarding_hijab_sometimes.
  ///
  /// In en, this message translates to:
  /// **'Sometimes'**
  String get onboarding_hijab_sometimes;

  /// No description provided for @onboarding_hint_bio.
  ///
  /// In en, this message translates to:
  /// **'Describe yourself with honesty and dignity.'**
  String get onboarding_hint_bio;

  /// No description provided for @onboarding_hint_profession.
  ///
  /// In en, this message translates to:
  /// **'e.g. Software Engineer, Teacher, Doctor'**
  String get onboarding_hint_profession;

  /// No description provided for @onboarding_hint_searchCity.
  ///
  /// In en, this message translates to:
  /// **'Search your city…'**
  String get onboarding_hint_searchCity;

  /// No description provided for @onboarding_hint_selectCommunity.
  ///
  /// In en, this message translates to:
  /// **'Select community (optional)'**
  String get onboarding_hint_selectCommunity;

  /// No description provided for @onboarding_hint_selectCountry.
  ///
  /// In en, this message translates to:
  /// **'Select country'**
  String get onboarding_hint_selectCountry;

  /// No description provided for @onboarding_hint_selectDateOfBirth.
  ///
  /// In en, this message translates to:
  /// **'Select date of birth'**
  String get onboarding_hint_selectDateOfBirth;

  /// No description provided for @onboarding_hint_selectLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select language'**
  String get onboarding_hint_selectLanguage;

  /// No description provided for @onboarding_islamicIdentity_subtitle.
  ///
  /// In en, this message translates to:
  /// **'This helps match you with someone compatible.'**
  String get onboarding_islamicIdentity_subtitle;

  /// No description provided for @onboarding_islamicIdentity_title.
  ///
  /// In en, this message translates to:
  /// **'Your Islamic identity'**
  String get onboarding_islamicIdentity_title;

  /// No description provided for @onboarding_label_bioCount.
  ///
  /// In en, this message translates to:
  /// **'{count}/300'**
  String onboarding_label_bioCount(int count);

  /// No description provided for @onboarding_label_city.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get onboarding_label_city;

  /// No description provided for @onboarding_label_city_guardian.
  ///
  /// In en, this message translates to:
  /// **'Their city'**
  String get onboarding_label_city_guardian;

  /// No description provided for @onboarding_label_city_self.
  ///
  /// In en, this message translates to:
  /// **'Your city'**
  String get onboarding_label_city_self;

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

  /// No description provided for @onboarding_label_complexion.
  ///
  /// In en, this message translates to:
  /// **'Complexion (Optional)'**
  String get onboarding_label_complexion;

  /// No description provided for @onboarding_label_country_guardian.
  ///
  /// In en, this message translates to:
  /// **'Their country'**
  String get onboarding_label_country_guardian;

  /// No description provided for @onboarding_label_country_self.
  ///
  /// In en, this message translates to:
  /// **'Your country'**
  String get onboarding_label_country_self;

  /// No description provided for @onboarding_label_cultural.
  ///
  /// In en, this message translates to:
  /// **'Cultural Muslim'**
  String get onboarding_label_cultural;

  /// No description provided for @onboarding_label_dateOfBirth.
  ///
  /// In en, this message translates to:
  /// **'Date of Birth'**
  String get onboarding_label_dateOfBirth;

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

  /// No description provided for @onboarding_label_deenLevel.
  ///
  /// In en, this message translates to:
  /// **'Deen Level'**
  String get onboarding_label_deenLevel;

  /// No description provided for @onboarding_label_diet.
  ///
  /// In en, this message translates to:
  /// **'Diet'**
  String get onboarding_label_diet;

  /// No description provided for @onboarding_label_educationLevel.
  ///
  /// In en, this message translates to:
  /// **'Education Level'**
  String get onboarding_label_educationLevel;

  /// No description provided for @onboarding_label_female.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get onboarding_label_female;

  /// No description provided for @onboarding_label_firstName.
  ///
  /// In en, this message translates to:
  /// **'First Name'**
  String get onboarding_label_firstName;

  /// No description provided for @onboarding_label_firstName_guardian.
  ///
  /// In en, this message translates to:
  /// **'Candidate\'s first name'**
  String get onboarding_label_firstName_guardian;

  /// No description provided for @onboarding_label_firstName_self.
  ///
  /// In en, this message translates to:
  /// **'First name'**
  String get onboarding_label_firstName_self;

  /// No description provided for @onboarding_label_gender.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get onboarding_label_gender;

  /// No description provided for @onboarding_label_gender_guardian.
  ///
  /// In en, this message translates to:
  /// **'Candidate\'s gender'**
  String get onboarding_label_gender_guardian;

  /// No description provided for @onboarding_label_gender_self.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get onboarding_label_gender_self;

  /// No description provided for @onboarding_label_height_guardian.
  ///
  /// In en, this message translates to:
  /// **'Their height'**
  String get onboarding_label_height_guardian;

  /// No description provided for @onboarding_label_height_self.
  ///
  /// In en, this message translates to:
  /// **'Your height'**
  String get onboarding_label_height_self;

  /// No description provided for @onboarding_label_hookah.
  ///
  /// In en, this message translates to:
  /// **'Hookah / Shisha'**
  String get onboarding_label_hookah;

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

  /// No description provided for @onboarding_label_lastName.
  ///
  /// In en, this message translates to:
  /// **'Last Name'**
  String get onboarding_label_lastName;

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

  /// No description provided for @onboarding_label_livingExpectation.
  ///
  /// In en, this message translates to:
  /// **'Post-marriage living expectations'**
  String get onboarding_label_livingExpectation;

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

  /// No description provided for @onboarding_label_male.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get onboarding_label_male;

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

  /// No description provided for @onboarding_label_moderate.
  ///
  /// In en, this message translates to:
  /// **'Moderate'**
  String get onboarding_label_moderate;

  /// No description provided for @onboarding_label_motherTongue.
  ///
  /// In en, this message translates to:
  /// **'Mother tongue'**
  String get onboarding_label_motherTongue;

  /// No description provided for @onboarding_label_niqab.
  ///
  /// In en, this message translates to:
  /// **'Niqab'**
  String get onboarding_label_niqab;

  /// No description provided for @onboarding_label_practicing.
  ///
  /// In en, this message translates to:
  /// **'Practicing'**
  String get onboarding_label_practicing;

  /// No description provided for @onboarding_label_praysFiveDaily.
  ///
  /// In en, this message translates to:
  /// **'I pray five times daily'**
  String get onboarding_label_praysFiveDaily;

  /// No description provided for @onboarding_label_preferNotToSay.
  ///
  /// In en, this message translates to:
  /// **'Prefer not to say'**
  String get onboarding_label_preferNotToSay;

  /// No description provided for @onboarding_label_preferredLiving.
  ///
  /// In en, this message translates to:
  /// **'Living arrangement preference'**
  String get onboarding_label_preferredLiving;

  /// No description provided for @onboarding_label_profession.
  ///
  /// In en, this message translates to:
  /// **'Profession'**
  String get onboarding_label_profession;

  /// No description provided for @onboarding_label_providerReadiness.
  ///
  /// In en, this message translates to:
  /// **'Provider Readiness'**
  String get onboarding_label_providerReadiness;

  /// No description provided for @onboarding_label_quranMemorization.
  ///
  /// In en, this message translates to:
  /// **'Quran Memorization'**
  String get onboarding_label_quranMemorization;

  /// No description provided for @onboarding_label_religiousEducation.
  ///
  /// In en, this message translates to:
  /// **'Religious Education'**
  String get onboarding_label_religiousEducation;

  /// No description provided for @onboarding_label_residencyStatus.
  ///
  /// In en, this message translates to:
  /// **'Residency Status (Optional)'**
  String get onboarding_label_residencyStatus;

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

  /// No description provided for @onboarding_label_sect.
  ///
  /// In en, this message translates to:
  /// **'Sect'**
  String get onboarding_label_sect;

  /// No description provided for @onboarding_label_shia.
  ///
  /// In en, this message translates to:
  /// **'Shia'**
  String get onboarding_label_shia;

  /// No description provided for @onboarding_label_smoking.
  ///
  /// In en, this message translates to:
  /// **'Smoking'**
  String get onboarding_label_smoking;

  /// No description provided for @onboarding_label_specialNeeds.
  ///
  /// In en, this message translates to:
  /// **'Special Needs (Optional)'**
  String get onboarding_label_specialNeeds;

  /// No description provided for @onboarding_label_step.
  ///
  /// In en, this message translates to:
  /// **'Step {current} of {total}'**
  String onboarding_label_step(int current, int total);

  /// No description provided for @onboarding_label_subSect.
  ///
  /// In en, this message translates to:
  /// **'School of thought (Optional)'**
  String get onboarding_label_subSect;

  /// No description provided for @onboarding_label_substanceUse.
  ///
  /// In en, this message translates to:
  /// **'Substance Use'**
  String get onboarding_label_substanceUse;

  /// No description provided for @onboarding_label_sunni.
  ///
  /// In en, this message translates to:
  /// **'Sunni'**
  String get onboarding_label_sunni;

  /// No description provided for @onboarding_label_vaping.
  ///
  /// In en, this message translates to:
  /// **'Vaping / E-Cigarettes'**
  String get onboarding_label_vaping;

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

  /// No description provided for @onboarding_location_confirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed Location'**
  String get onboarding_location_confirmed;

  /// No description provided for @onboarding_mahr_generous.
  ///
  /// In en, this message translates to:
  /// **'Generous'**
  String get onboarding_mahr_generous;

  /// No description provided for @onboarding_mahr_moderate.
  ///
  /// In en, this message translates to:
  /// **'Moderate'**
  String get onboarding_mahr_moderate;

  /// No description provided for @onboarding_mahr_modest.
  ///
  /// In en, this message translates to:
  /// **'Modest'**
  String get onboarding_mahr_modest;

  /// No description provided for @onboarding_mahr_noPreference.
  ///
  /// In en, this message translates to:
  /// **'No preference'**
  String get onboarding_mahr_noPreference;

  /// No description provided for @onboarding_mahr_toDiscuss.
  ///
  /// In en, this message translates to:
  /// **'To discuss'**
  String get onboarding_mahr_toDiscuss;

  /// No description provided for @onboarding_marriageDeen_privacyNotice.
  ///
  /// In en, this message translates to:
  /// **'These details are not shown on your public profile. They are shared privately during the acceptance stage.'**
  String get onboarding_marriageDeen_privacyNotice;

  /// No description provided for @onboarding_marriageDeen_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Help us understand your journey and readiness.'**
  String get onboarding_marriageDeen_subtitle;

  /// No description provided for @onboarding_marriageDeen_title.
  ///
  /// In en, this message translates to:
  /// **'Marriage & Deen'**
  String get onboarding_marriageDeen_title;

  /// No description provided for @onboarding_niqab_dontWear.
  ///
  /// In en, this message translates to:
  /// **'I don\'t wear niqab'**
  String get onboarding_niqab_dontWear;

  /// No description provided for @onboarding_niqab_open.
  ///
  /// In en, this message translates to:
  /// **'Open to wearing'**
  String get onboarding_niqab_open;

  /// No description provided for @onboarding_niqab_wear.
  ///
  /// In en, this message translates to:
  /// **'I wear niqab'**
  String get onboarding_niqab_wear;

  /// No description provided for @onboarding_photo_subtitle.
  ///
  /// In en, this message translates to:
  /// **'At least one photo is required. Your primary photo must include your face clearly.'**
  String get onboarding_photo_subtitle;

  /// No description provided for @onboarding_photo_title.
  ///
  /// In en, this message translates to:
  /// **'Add your photos'**
  String get onboarding_photo_title;

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

  /// No description provided for @onboarding_preferredLiving_noPreference.
  ///
  /// In en, this message translates to:
  /// **'No Preference'**
  String get onboarding_preferredLiving_noPreference;

  /// No description provided for @onboarding_profileForWhom_creatingFor.
  ///
  /// In en, this message translates to:
  /// **'I am creating this for my…'**
  String get onboarding_profileForWhom_creatingFor;

  /// No description provided for @onboarding_profileForWhom_guardian.
  ///
  /// In en, this message translates to:
  /// **'My son or daughter'**
  String get onboarding_profileForWhom_guardian;

  /// No description provided for @onboarding_profileForWhom_guardianCardSub.
  ///
  /// In en, this message translates to:
  /// **'I am creating this profile for someone'**
  String get onboarding_profileForWhom_guardianCardSub;

  /// No description provided for @onboarding_profileForWhom_guardianCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Guardian'**
  String get onboarding_profileForWhom_guardianCardTitle;

  /// No description provided for @onboarding_profileForWhom_guardianSub.
  ///
  /// In en, this message translates to:
  /// **'I am a parent or guardian'**
  String get onboarding_profileForWhom_guardianSub;

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

  /// No description provided for @onboarding_profileForWhom_relation_brother.
  ///
  /// In en, this message translates to:
  /// **'Brother'**
  String get onboarding_profileForWhom_relation_brother;

  /// No description provided for @onboarding_profileForWhom_relation_daughter.
  ///
  /// In en, this message translates to:
  /// **'Daughter'**
  String get onboarding_profileForWhom_relation_daughter;

  /// No description provided for @onboarding_profileForWhom_relation_sister.
  ///
  /// In en, this message translates to:
  /// **'Sister'**
  String get onboarding_profileForWhom_relation_sister;

  /// No description provided for @onboarding_profileForWhom_relation_son.
  ///
  /// In en, this message translates to:
  /// **'Son'**
  String get onboarding_profileForWhom_relation_son;

  /// No description provided for @onboarding_profileForWhom_selectOne.
  ///
  /// In en, this message translates to:
  /// **'Select one to continue'**
  String get onboarding_profileForWhom_selectOne;

  /// No description provided for @onboarding_profileForWhom_selectRelation.
  ///
  /// In en, this message translates to:
  /// **'Select a relationship to continue'**
  String get onboarding_profileForWhom_selectRelation;

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

  /// No description provided for @onboarding_profileForWhom_subtitle.
  ///
  /// In en, this message translates to:
  /// **'You can update this later from settings.'**
  String get onboarding_profileForWhom_subtitle;

  /// No description provided for @onboarding_profileForWhom_title.
  ///
  /// In en, this message translates to:
  /// **'Who is this profile for?'**
  String get onboarding_profileForWhom_title;

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

  /// No description provided for @onboarding_providerQuote.
  ///
  /// In en, this message translates to:
  /// **'\"The best of you are the best to your wives.\" — Prophet Muhammad ﷺ\n\nBeing honest about your readiness helps build a strong foundation.'**
  String get onboarding_providerQuote;

  /// No description provided for @onboarding_quran_hafiz.
  ///
  /// In en, this message translates to:
  /// **'Hafiz / Hafiza'**
  String get onboarding_quran_hafiz;

  /// No description provided for @onboarding_quran_none.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get onboarding_quran_none;

  /// No description provided for @onboarding_quran_partial.
  ///
  /// In en, this message translates to:
  /// **'Partial Hifz'**
  String get onboarding_quran_partial;

  /// No description provided for @onboarding_quran_some.
  ///
  /// In en, this message translates to:
  /// **'Some Surahs'**
  String get onboarding_quran_some;

  /// No description provided for @onboarding_religiousEdu_alim.
  ///
  /// In en, this message translates to:
  /// **'Alim Course'**
  String get onboarding_religiousEdu_alim;

  /// No description provided for @onboarding_religiousEdu_islamicUni.
  ///
  /// In en, this message translates to:
  /// **'Islamic University'**
  String get onboarding_religiousEdu_islamicUni;

  /// No description provided for @onboarding_religiousEdu_madrasa.
  ///
  /// In en, this message translates to:
  /// **'Madrasa'**
  String get onboarding_religiousEdu_madrasa;

  /// No description provided for @onboarding_religiousEdu_selfTaught.
  ///
  /// In en, this message translates to:
  /// **'Self-Taught'**
  String get onboarding_religiousEdu_selfTaught;

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

  /// No description provided for @onboarding_timeline_6months.
  ///
  /// In en, this message translates to:
  /// **'Within 6 months'**
  String get onboarding_timeline_6months;

  /// No description provided for @onboarding_timeline_asap.
  ///
  /// In en, this message translates to:
  /// **'As soon as possible'**
  String get onboarding_timeline_asap;

  /// No description provided for @onboarding_timeline_notSure.
  ///
  /// In en, this message translates to:
  /// **'Not sure yet'**
  String get onboarding_timeline_notSure;

  /// No description provided for @onboarding_tooltip_cultural.
  ///
  /// In en, this message translates to:
  /// **'Identifies as Muslim, celebrates occasions, may not pray regularly'**
  String get onboarding_tooltip_cultural;

  /// No description provided for @onboarding_tooltip_moderate.
  ///
  /// In en, this message translates to:
  /// **'Values Islamic principles, prays regularly but not always, culturally Muslim'**
  String get onboarding_tooltip_moderate;

  /// No description provided for @onboarding_tooltip_practicing.
  ///
  /// In en, this message translates to:
  /// **'Follows all five pillars, prays regularly, halal lifestyle'**
  String get onboarding_tooltip_practicing;

  /// No description provided for @onboarding_work_no.
  ///
  /// In en, this message translates to:
  /// **'No, I prefer not to'**
  String get onboarding_work_no;

  /// No description provided for @onboarding_work_yes.
  ///
  /// In en, this message translates to:
  /// **'Yes, I plan to work'**
  String get onboarding_work_yes;

  /// No description provided for @photo_add_main_required.
  ///
  /// In en, this message translates to:
  /// **'Add main photo\n(required)'**
  String get photo_add_main_required;

  /// No description provided for @photo_add_photo.
  ///
  /// In en, this message translates to:
  /// **'Add photo'**
  String get photo_add_photo;

  /// No description provided for @photo_banner_text.
  ///
  /// In en, this message translates to:
  /// **'Each photo is scanned to ensure a visible face. Group photos are not allowed as your primary photo.'**
  String get photo_banner_text;

  /// No description provided for @photo_error_no_face_detected.
  ///
  /// In en, this message translates to:
  /// **'No face visible — please retry with a clear face photo'**
  String get photo_error_no_face_detected;

  /// No description provided for @photo_error_pick_failed.
  ///
  /// In en, this message translates to:
  /// **'Could not pick photo: {error}'**
  String photo_error_pick_failed(Object error);

  /// No description provided for @photo_face_detected.
  ///
  /// In en, this message translates to:
  /// **'Face detected ✓'**
  String get photo_face_detected;

  /// No description provided for @photo_label_photo2.
  ///
  /// In en, this message translates to:
  /// **'Photo 2'**
  String get photo_label_photo2;

  /// No description provided for @photo_label_photo3.
  ///
  /// In en, this message translates to:
  /// **'Photo 3'**
  String get photo_label_photo3;

  /// No description provided for @photo_label_primary.
  ///
  /// In en, this message translates to:
  /// **'Primary photo'**
  String get photo_label_primary;

  /// No description provided for @photo_label_selfie.
  ///
  /// In en, this message translates to:
  /// **'Verification selfie'**
  String get photo_label_selfie;

  /// No description provided for @photo_no_face.
  ///
  /// In en, this message translates to:
  /// **'No face visible'**
  String get photo_no_face;

  /// No description provided for @photo_privacy_everyone.
  ///
  /// In en, this message translates to:
  /// **'Visible to everyone'**
  String get photo_privacy_everyone;

  /// No description provided for @photo_privacy_everyone_sub.
  ///
  /// In en, this message translates to:
  /// **'All members can see your photos.'**
  String get photo_privacy_everyone_sub;

  /// No description provided for @photo_privacy_label.
  ///
  /// In en, this message translates to:
  /// **'PHOTO PRIVACY'**
  String get photo_privacy_label;

  /// No description provided for @photo_privacy_mutual.
  ///
  /// In en, this message translates to:
  /// **'Visible after mutual interest'**
  String get photo_privacy_mutual;

  /// No description provided for @photo_privacy_mutual_sub.
  ///
  /// In en, this message translates to:
  /// **'Photos only reveal when both parties express interest.'**
  String get photo_privacy_mutual_sub;

  /// No description provided for @photo_privacy_request.
  ///
  /// In en, this message translates to:
  /// **'Request to view'**
  String get photo_privacy_request;

  /// No description provided for @photo_privacy_request_sub.
  ///
  /// In en, this message translates to:
  /// **'Photos are blurred until you approve a request.'**
  String get photo_privacy_request_sub;

  /// No description provided for @photo_sheet_camera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get photo_sheet_camera;

  /// No description provided for @photo_sheet_gallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get photo_sheet_gallery;

  /// No description provided for @photo_sheet_title.
  ///
  /// In en, this message translates to:
  /// **'Select Photo Source'**
  String get photo_sheet_title;

  /// No description provided for @photo_slots_help.
  ///
  /// In en, this message translates to:
  /// **'TAP SLOTS TO UPLOAD'**
  String get photo_slots_help;

  /// No description provided for @photo_subtitle_guardian.
  ///
  /// In en, this message translates to:
  /// **'Add photos of your {relation}. At least one is required.'**
  String photo_subtitle_guardian(Object relation);

  /// No description provided for @photo_subtitle_self.
  ///
  /// In en, this message translates to:
  /// **'At least one photo is required. Maximum four.'**
  String get photo_subtitle_self;

  /// No description provided for @photo_title_guardian.
  ///
  /// In en, this message translates to:
  /// **'Add their photos'**
  String get photo_title_guardian;

  /// No description provided for @photo_title_self.
  ///
  /// In en, this message translates to:
  /// **'Add your photos'**
  String get photo_title_self;

  /// No description provided for @preferences_deen_any.
  ///
  /// In en, this message translates to:
  /// **'Any'**
  String get preferences_deen_any;

  /// No description provided for @preferences_deen_cultural.
  ///
  /// In en, this message translates to:
  /// **'Cultural Muslim'**
  String get preferences_deen_cultural;

  /// No description provided for @preferences_deen_moderate.
  ///
  /// In en, this message translates to:
  /// **'Moderate'**
  String get preferences_deen_moderate;

  /// No description provided for @preferences_deen_practicing.
  ///
  /// In en, this message translates to:
  /// **'Practicing'**
  String get preferences_deen_practicing;

  /// No description provided for @preferences_edu_any.
  ///
  /// In en, this message translates to:
  /// **'Any'**
  String get preferences_edu_any;

  /// No description provided for @preferences_edu_bachelors.
  ///
  /// In en, this message translates to:
  /// **'Bachelor\'s +'**
  String get preferences_edu_bachelors;

  /// No description provided for @preferences_edu_diploma.
  ///
  /// In en, this message translates to:
  /// **'Diploma +'**
  String get preferences_edu_diploma;

  /// No description provided for @preferences_edu_masters.
  ///
  /// In en, this message translates to:
  /// **'Master\'s +'**
  String get preferences_edu_masters;

  /// No description provided for @preferences_edu_phd.
  ///
  /// In en, this message translates to:
  /// **'PhD only'**
  String get preferences_edu_phd;

  /// No description provided for @preferences_edu_secondary.
  ///
  /// In en, this message translates to:
  /// **'Secondary +'**
  String get preferences_edu_secondary;

  /// No description provided for @preferences_label_age.
  ///
  /// In en, this message translates to:
  /// **'AGE RANGE'**
  String get preferences_label_age;

  /// No description provided for @preferences_label_age_bounds.
  ///
  /// In en, this message translates to:
  /// **'18 – 60'**
  String get preferences_label_age_bounds;

  /// No description provided for @preferences_label_age_range.
  ///
  /// In en, this message translates to:
  /// **'{min} – {max} years'**
  String preferences_label_age_range(Object max, Object min);

  /// No description provided for @preferences_label_deen.
  ///
  /// In en, this message translates to:
  /// **'DEEN LEVEL PREFERENCE'**
  String get preferences_label_deen;

  /// No description provided for @preferences_label_edu.
  ///
  /// In en, this message translates to:
  /// **'MINIMUM EDUCATION'**
  String get preferences_label_edu;

  /// No description provided for @preferences_label_living.
  ///
  /// In en, this message translates to:
  /// **'LIVING ARRANGEMENT PREFERENCE'**
  String get preferences_label_living;

  /// No description provided for @preferences_label_location.
  ///
  /// In en, this message translates to:
  /// **'LOCATION'**
  String get preferences_label_location;

  /// No description provided for @preferences_label_openness.
  ///
  /// In en, this message translates to:
  /// **'OPENNESS'**
  String get preferences_label_openness;

  /// No description provided for @preferences_label_sect.
  ///
  /// In en, this message translates to:
  /// **'SECT PREFERENCE'**
  String get preferences_label_sect;

  /// No description provided for @preferences_living_discussion.
  ///
  /// In en, this message translates to:
  /// **'Open to Discussion'**
  String get preferences_living_discussion;

  /// No description provided for @preferences_living_family.
  ///
  /// In en, this message translates to:
  /// **'With Family'**
  String get preferences_living_family;

  /// No description provided for @preferences_living_no_pref.
  ///
  /// In en, this message translates to:
  /// **'No Preference'**
  String get preferences_living_no_pref;

  /// No description provided for @preferences_living_separate.
  ///
  /// In en, this message translates to:
  /// **'Separate Home'**
  String get preferences_living_separate;

  /// No description provided for @preferences_location_abroad.
  ///
  /// In en, this message translates to:
  /// **'Open to abroad'**
  String get preferences_location_abroad;

  /// No description provided for @preferences_location_diaspora.
  ///
  /// In en, this message translates to:
  /// **'Diaspora mode'**
  String get preferences_location_diaspora;

  /// No description provided for @preferences_location_same_city.
  ///
  /// In en, this message translates to:
  /// **'Same city'**
  String get preferences_location_same_city;

  /// No description provided for @preferences_location_same_country.
  ///
  /// In en, this message translates to:
  /// **'Same country'**
  String get preferences_location_same_country;

  /// No description provided for @preferences_open_children.
  ///
  /// In en, this message translates to:
  /// **'Open to someone with children'**
  String get preferences_open_children;

  /// No description provided for @preferences_open_divorced.
  ///
  /// In en, this message translates to:
  /// **'Open to someone previously divorced'**
  String get preferences_open_divorced;

  /// No description provided for @preferences_open_widowed.
  ///
  /// In en, this message translates to:
  /// **'Open to someone previously widowed'**
  String get preferences_open_widowed;

  /// No description provided for @preferences_sect_any.
  ///
  /// In en, this message translates to:
  /// **'Any'**
  String get preferences_sect_any;

  /// No description provided for @preferences_sect_same.
  ///
  /// In en, this message translates to:
  /// **'Same as mine'**
  String get preferences_sect_same;

  /// No description provided for @preferences_sect_shia.
  ///
  /// In en, this message translates to:
  /// **'Shia'**
  String get preferences_sect_shia;

  /// No description provided for @preferences_sect_sunni.
  ///
  /// In en, this message translates to:
  /// **'Sunni'**
  String get preferences_sect_sunni;

  /// No description provided for @preferences_subtitle_guardian.
  ///
  /// In en, this message translates to:
  /// **'Set preferences for your {relation}\'s ideal match.'**
  String preferences_subtitle_guardian(Object relation);

  /// No description provided for @preferences_subtitle_self.
  ///
  /// In en, this message translates to:
  /// **'These are preferences, not hard filters.'**
  String get preferences_subtitle_self;

  /// No description provided for @preferences_title.
  ///
  /// In en, this message translates to:
  /// **'Partner preferences'**
  String get preferences_title;

  /// No description provided for @preview_age_label.
  ///
  /// In en, this message translates to:
  /// **'Age'**
  String get preview_age_label;

  /// No description provided for @preview_background.
  ///
  /// In en, this message translates to:
  /// **'Background'**
  String get preview_background;

  /// No description provided for @preview_basic_info.
  ///
  /// In en, this message translates to:
  /// **'Basic Info'**
  String get preview_basic_info;

  /// No description provided for @preview_city_label.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get preview_city_label;

  /// No description provided for @preview_community_label.
  ///
  /// In en, this message translates to:
  /// **'Community'**
  String get preview_community_label;

  /// No description provided for @preview_cowife_label.
  ///
  /// In en, this message translates to:
  /// **'Co-wife Acceptance'**
  String get preview_cowife_label;

  /// No description provided for @preview_deen_label.
  ///
  /// In en, this message translates to:
  /// **'Deen Level'**
  String get preview_deen_label;

  /// No description provided for @preview_diet_label.
  ///
  /// In en, this message translates to:
  /// **'Diet'**
  String get preview_diet_label;

  /// No description provided for @preview_edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get preview_edit;

  /// No description provided for @preview_education_label.
  ///
  /// In en, this message translates to:
  /// **'Education'**
  String get preview_education_label;

  /// No description provided for @preview_faith.
  ///
  /// In en, this message translates to:
  /// **'Faith'**
  String get preview_faith;

  /// No description provided for @preview_family.
  ///
  /// In en, this message translates to:
  /// **'Family'**
  String get preview_family;

  /// No description provided for @preview_family_type_label.
  ///
  /// In en, this message translates to:
  /// **'Family type'**
  String get preview_family_type_label;

  /// No description provided for @preview_gender_label.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get preview_gender_label;

  /// No description provided for @preview_hijab_label.
  ///
  /// In en, this message translates to:
  /// **'Hijab'**
  String get preview_hijab_label;

  /// No description provided for @preview_hookah_label.
  ///
  /// In en, this message translates to:
  /// **'Hookah'**
  String get preview_hookah_label;

  /// No description provided for @preview_leadership_label.
  ///
  /// In en, this message translates to:
  /// **'Leadership'**
  String get preview_leadership_label;

  /// No description provided for @preview_marital_label.
  ///
  /// In en, this message translates to:
  /// **'Marital'**
  String get preview_marital_label;

  /// No description provided for @preview_marriage_timeline_label.
  ///
  /// In en, this message translates to:
  /// **'Marriage Timeline'**
  String get preview_marriage_timeline_label;

  /// No description provided for @preview_mother_tongue_label.
  ///
  /// In en, this message translates to:
  /// **'Mother Tongue'**
  String get preview_mother_tongue_label;

  /// No description provided for @preview_name_label.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get preview_name_label;

  /// No description provided for @preview_notice_guardian.
  ///
  /// In en, this message translates to:
  /// **'This is exactly how others will see their profile.'**
  String get preview_notice_guardian;

  /// No description provided for @preview_notice_self.
  ///
  /// In en, this message translates to:
  /// **'This is exactly how others will see your profile.'**
  String get preview_notice_self;

  /// No description provided for @preview_polygamy_label.
  ///
  /// In en, this message translates to:
  /// **'Polygamy'**
  String get preview_polygamy_label;

  /// No description provided for @preview_post_marriage_living_label.
  ///
  /// In en, this message translates to:
  /// **'Post-Marriage Living'**
  String get preview_post_marriage_living_label;

  /// No description provided for @preview_prays_label.
  ///
  /// In en, this message translates to:
  /// **'Prays 5x'**
  String get preview_prays_label;

  /// No description provided for @preview_profession_label.
  ///
  /// In en, this message translates to:
  /// **'Profession'**
  String get preview_profession_label;

  /// No description provided for @preview_quran_label.
  ///
  /// In en, this message translates to:
  /// **'Quran'**
  String get preview_quran_label;

  /// No description provided for @preview_religious_edu_label.
  ///
  /// In en, this message translates to:
  /// **'Religious Education'**
  String get preview_religious_edu_label;

  /// No description provided for @preview_residency_label.
  ///
  /// In en, this message translates to:
  /// **'Residency'**
  String get preview_residency_label;

  /// No description provided for @preview_revert_label.
  ///
  /// In en, this message translates to:
  /// **'Revert'**
  String get preview_revert_label;

  /// No description provided for @preview_sect_label.
  ///
  /// In en, this message translates to:
  /// **'Sect'**
  String get preview_sect_label;

  /// No description provided for @preview_siblings_label.
  ///
  /// In en, this message translates to:
  /// **'Siblings'**
  String get preview_siblings_label;

  /// No description provided for @preview_smoking_label.
  ///
  /// In en, this message translates to:
  /// **'Smoking'**
  String get preview_smoking_label;

  /// No description provided for @preview_special_needs_label.
  ///
  /// In en, this message translates to:
  /// **'Special Needs'**
  String get preview_special_needs_label;

  /// No description provided for @preview_submit_btn.
  ///
  /// In en, this message translates to:
  /// **'Submit Profile'**
  String get preview_submit_btn;

  /// No description provided for @preview_title.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get preview_title;

  /// No description provided for @preview_vaping_label.
  ///
  /// In en, this message translates to:
  /// **'Vaping'**
  String get preview_vaping_label;

  /// No description provided for @preview_willing_relocate_label.
  ///
  /// In en, this message translates to:
  /// **'Willing to Relocate'**
  String get preview_willing_relocate_label;

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

  /// No description provided for @settings_brand_credit.
  ///
  /// In en, this message translates to:
  /// **'NOOR (نور) · For the sake of Allah'**
  String get settings_brand_credit;

  /// No description provided for @settings_button_deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get settings_button_deleteAccount;

  /// No description provided for @settings_guardian_mirror.
  ///
  /// In en, this message translates to:
  /// **'Mirror Messages'**
  String get settings_guardian_mirror;

  /// No description provided for @settings_guardian_mirror_sub.
  ///
  /// In en, this message translates to:
  /// **'Send copies of all messages to guardian'**
  String get settings_guardian_mirror_sub;

  /// No description provided for @settings_guardian_name_hint.
  ///
  /// In en, this message translates to:
  /// **'Guardian Name'**
  String get settings_guardian_name_hint;

  /// No description provided for @settings_guardian_phone_hint.
  ///
  /// In en, this message translates to:
  /// **'Guardian Phone'**
  String get settings_guardian_phone_hint;

  /// No description provided for @settings_guardian_relationship.
  ///
  /// In en, this message translates to:
  /// **'Relationship'**
  String get settings_guardian_relationship;

  /// No description provided for @settings_guardian_reply.
  ///
  /// In en, this message translates to:
  /// **'Allow Guardian to Reply'**
  String get settings_guardian_reply;

  /// No description provided for @settings_guardian_reply_sub.
  ///
  /// In en, this message translates to:
  /// **'Guardian may participate in conversations'**
  String get settings_guardian_reply_sub;

  /// No description provided for @settings_guardian_save.
  ///
  /// In en, this message translates to:
  /// **'Save Guardian Settings'**
  String get settings_guardian_save;

  /// No description provided for @settings_guardian_saved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get settings_guardian_saved;

  /// No description provided for @settings_guardian_sub.
  ///
  /// In en, this message translates to:
  /// **'Enable Wali oversight for messaging'**
  String get settings_guardian_sub;

  /// No description provided for @settings_guardian_title.
  ///
  /// In en, this message translates to:
  /// **'Guardian Mode'**
  String get settings_guardian_title;

  /// No description provided for @settings_label_blocked.
  ///
  /// In en, this message translates to:
  /// **'Blocked Profiles'**
  String get settings_label_blocked;

  /// No description provided for @settings_label_blocked_count.
  ///
  /// In en, this message translates to:
  /// **'{count} blocked'**
  String settings_label_blocked_count(Object count);

  /// No description provided for @settings_label_blocked_none.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get settings_label_blocked_none;

  /// No description provided for @settings_label_deleteGrace.
  ///
  /// In en, this message translates to:
  /// **'Your profile will be hidden immediately. Your data will be permanently deleted after 30 days.'**
  String get settings_label_deleteGrace;

  /// No description provided for @settings_label_editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get settings_label_editProfile;

  /// No description provided for @settings_label_language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settings_label_language;

  /// No description provided for @settings_label_phoneCannotChange.
  ///
  /// In en, this message translates to:
  /// **'Phone number cannot be changed. Contact support for help.'**
  String get settings_label_phoneCannotChange;

  /// No description provided for @settings_label_phoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get settings_label_phoneNumber;

  /// No description provided for @settings_label_photoPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Photo Privacy'**
  String get settings_label_photoPrivacy;

  /// No description provided for @settings_label_rate.
  ///
  /// In en, this message translates to:
  /// **'Rate Mithaq'**
  String get settings_label_rate;

  /// No description provided for @settings_label_rate_snackbar.
  ///
  /// In en, this message translates to:
  /// **'Rating will be available once Mithaq launches on the app store.'**
  String get settings_label_rate_snackbar;

  /// No description provided for @settings_label_reports.
  ///
  /// In en, this message translates to:
  /// **'Report History'**
  String get settings_label_reports;

  /// No description provided for @settings_label_reports_count.
  ///
  /// In en, this message translates to:
  /// **'{count} reports'**
  String settings_label_reports_count(Object count);

  /// No description provided for @settings_label_reports_none.
  ///
  /// In en, this message translates to:
  /// **'No reports submitted'**
  String get settings_label_reports_none;

  /// No description provided for @settings_label_selfieChallenge.
  ///
  /// In en, this message translates to:
  /// **'Selfie Challenge'**
  String get settings_label_selfieChallenge;

  /// No description provided for @settings_label_verifyProfile.
  ///
  /// In en, this message translates to:
  /// **'Verify Profile'**
  String get settings_label_verifyProfile;

  /// No description provided for @settings_label_version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get settings_label_version;

  /// No description provided for @settings_notify_activityNudges.
  ///
  /// In en, this message translates to:
  /// **'Activity Nudges'**
  String get settings_notify_activityNudges;

  /// No description provided for @settings_notify_activityNudgesSub.
  ///
  /// In en, this message translates to:
  /// **'Remind when inactive for 7+ days'**
  String get settings_notify_activityNudgesSub;

  /// No description provided for @settings_notify_boostReminders.
  ///
  /// In en, this message translates to:
  /// **'Boost Reminders'**
  String get settings_notify_boostReminders;

  /// No description provided for @settings_notify_boostRemindersSub.
  ///
  /// In en, this message translates to:
  /// **'Remind when your weekly boost is ready'**
  String get settings_notify_boostRemindersSub;

  /// No description provided for @settings_notify_interestAccepted.
  ///
  /// In en, this message translates to:
  /// **'Interest Accepted'**
  String get settings_notify_interestAccepted;

  /// No description provided for @settings_notify_interestExpiring.
  ///
  /// In en, this message translates to:
  /// **'Interest Expiring Soon'**
  String get settings_notify_interestExpiring;

  /// No description provided for @settings_notify_newInterest.
  ///
  /// In en, this message translates to:
  /// **'New Interests'**
  String get settings_notify_newInterest;

  /// No description provided for @settings_notify_newMessage.
  ///
  /// In en, this message translates to:
  /// **'New Messages'**
  String get settings_notify_newMessage;

  /// No description provided for @settings_notify_profileApproved.
  ///
  /// In en, this message translates to:
  /// **'Profile Approved'**
  String get settings_notify_profileApproved;

  /// No description provided for @settings_notify_quietHours.
  ///
  /// In en, this message translates to:
  /// **'Quiet Hours'**
  String get settings_notify_quietHours;

  /// No description provided for @settings_photo_privacy_accepted_interests.
  ///
  /// In en, this message translates to:
  /// **'Accepted interests only'**
  String get settings_photo_privacy_accepted_interests;

  /// No description provided for @settings_photo_privacy_after_acceptance.
  ///
  /// In en, this message translates to:
  /// **'After Acceptance'**
  String get settings_photo_privacy_after_acceptance;

  /// No description provided for @settings_photo_privacy_everyone.
  ///
  /// In en, this message translates to:
  /// **'Everyone'**
  String get settings_photo_privacy_everyone;

  /// No description provided for @settings_photo_privacy_public.
  ///
  /// In en, this message translates to:
  /// **'Public'**
  String get settings_photo_privacy_public;

  /// No description provided for @settings_photo_privacy_request_only.
  ///
  /// In en, this message translates to:
  /// **'Request Only'**
  String get settings_photo_privacy_request_only;

  /// No description provided for @settings_photo_privacy_request_to_view.
  ///
  /// In en, this message translates to:
  /// **'Request to view'**
  String get settings_photo_privacy_request_to_view;

  /// No description provided for @settings_privacy_download_body.
  ///
  /// In en, this message translates to:
  /// **'Under GDPR and other privacy regulations, you can request a complete export of your profile, matching, and activity data. The file will be prepared and sent to your registered address.'**
  String get settings_privacy_download_body;

  /// No description provided for @settings_privacy_download_btn.
  ///
  /// In en, this message translates to:
  /// **'Request Data Export'**
  String get settings_privacy_download_btn;

  /// No description provided for @settings_privacy_download_label.
  ///
  /// In en, this message translates to:
  /// **'DOWNLOAD MY DATA'**
  String get settings_privacy_download_label;

  /// No description provided for @settings_privacy_download_sub.
  ///
  /// In en, this message translates to:
  /// **'Export a copy of your personal data under GDPR'**
  String get settings_privacy_download_sub;

  /// No description provided for @settings_privacy_export_body.
  ///
  /// In en, this message translates to:
  /// **'Your request has been received! We are compiling your personal data archive.'**
  String get settings_privacy_export_body;

  /// No description provided for @settings_privacy_export_btn_close.
  ///
  /// In en, this message translates to:
  /// **'Understood'**
  String get settings_privacy_export_btn_close;

  /// No description provided for @settings_privacy_export_subbody.
  ///
  /// In en, this message translates to:
  /// **'A download link will be sent to your registered phone/email within 48 hours in compliance with GDPR guidelines.'**
  String get settings_privacy_export_subbody;

  /// No description provided for @settings_privacy_export_title.
  ///
  /// In en, this message translates to:
  /// **'Export Requested'**
  String get settings_privacy_export_title;

  /// No description provided for @settings_privacy_online_label.
  ///
  /// In en, this message translates to:
  /// **'ONLINE STATUS'**
  String get settings_privacy_online_label;

  /// No description provided for @settings_privacy_online_sub.
  ///
  /// In en, this message translates to:
  /// **'Show when you were last active'**
  String get settings_privacy_online_sub;

  /// No description provided for @settings_privacy_pause_label.
  ///
  /// In en, this message translates to:
  /// **'PROFILE PAUSE'**
  String get settings_privacy_pause_label;

  /// No description provided for @settings_privacy_pause_sub.
  ///
  /// In en, this message translates to:
  /// **'Hide your profile from search'**
  String get settings_privacy_pause_sub;

  /// No description provided for @settings_privacy_pause_warning.
  ///
  /// In en, this message translates to:
  /// **'Your profile is hidden. No one can find you.'**
  String get settings_privacy_pause_warning;

  /// No description provided for @settings_privacy_photo_label.
  ///
  /// In en, this message translates to:
  /// **'PHOTO VISIBILITY'**
  String get settings_privacy_photo_label;

  /// No description provided for @settings_privacy_photo_sub.
  ///
  /// In en, this message translates to:
  /// **'Who can see your photos'**
  String get settings_privacy_photo_sub;

  /// No description provided for @settings_privacy_visibility_all.
  ///
  /// In en, this message translates to:
  /// **'All registered users'**
  String get settings_privacy_visibility_all;

  /// No description provided for @settings_privacy_visibility_label.
  ///
  /// In en, this message translates to:
  /// **'WHO CAN SEE MY PROFILE'**
  String get settings_privacy_visibility_label;

  /// No description provided for @settings_privacy_visibility_sub.
  ///
  /// In en, this message translates to:
  /// **'Controls who can browse your profile'**
  String get settings_privacy_visibility_sub;

  /// No description provided for @settings_privacy_visibility_subscribers.
  ///
  /// In en, this message translates to:
  /// **'Subscribers only'**
  String get settings_privacy_visibility_subscribers;

  /// No description provided for @settings_relation_brother.
  ///
  /// In en, this message translates to:
  /// **'Brother'**
  String get settings_relation_brother;

  /// No description provided for @settings_relation_father.
  ///
  /// In en, this message translates to:
  /// **'Father'**
  String get settings_relation_father;

  /// No description provided for @settings_relation_mother.
  ///
  /// In en, this message translates to:
  /// **'Mother'**
  String get settings_relation_mother;

  /// No description provided for @settings_relation_other.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get settings_relation_other;

  /// No description provided for @settings_relation_uncle.
  ///
  /// In en, this message translates to:
  /// **'Uncle'**
  String get settings_relation_uncle;

  /// No description provided for @settings_section_account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settings_section_account;

  /// No description provided for @settings_section_app.
  ///
  /// In en, this message translates to:
  /// **'App'**
  String get settings_section_app;

  /// No description provided for @settings_section_dangerZone.
  ///
  /// In en, this message translates to:
  /// **'Danger Zone'**
  String get settings_section_dangerZone;

  /// No description provided for @settings_section_guardian.
  ///
  /// In en, this message translates to:
  /// **'Guardian'**
  String get settings_section_guardian;

  /// No description provided for @settings_section_legal.
  ///
  /// In en, this message translates to:
  /// **'Legal'**
  String get settings_section_legal;

  /// No description provided for @settings_section_notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settings_section_notifications;

  /// No description provided for @settings_section_privacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get settings_section_privacy;

  /// No description provided for @settings_section_safety.
  ///
  /// In en, this message translates to:
  /// **'Safety'**
  String get settings_section_safety;

  /// No description provided for @settings_support_body.
  ///
  /// In en, this message translates to:
  /// **'For any questions, concerns, or feedback:'**
  String get settings_support_body;

  /// No description provided for @settings_support_btn_close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get settings_support_btn_close;

  /// No description provided for @settings_support_contact.
  ///
  /// In en, this message translates to:
  /// **'Contact Support'**
  String get settings_support_contact;

  /// No description provided for @settings_support_note.
  ///
  /// In en, this message translates to:
  /// **'We aim to respond within 48 hours.'**
  String get settings_support_note;

  /// No description provided for @settings_title.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings_title;

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

  /// No description provided for @splash_referral_button.
  ///
  /// In en, this message translates to:
  /// **'Apply Code'**
  String get splash_referral_button;

  /// No description provided for @splash_referral_hint.
  ///
  /// In en, this message translates to:
  /// **'e.g. MITHAQXX'**
  String get splash_referral_hint;

  /// No description provided for @splash_referral_invalid.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid 6-character code.'**
  String get splash_referral_invalid;

  /// No description provided for @splash_referral_question.
  ///
  /// In en, this message translates to:
  /// **'Have a referral code?'**
  String get splash_referral_question;

  /// No description provided for @splash_referral_saved.
  ///
  /// In en, this message translates to:
  /// **'Referral code saved! It will be applied after you sign in.'**
  String get splash_referral_saved;

  /// No description provided for @splash_referral_subtitle.
  ///
  /// In en, this message translates to:
  /// **'If a friend invited you to Mithaq, enter their 6-character referral code below.'**
  String get splash_referral_subtitle;

  /// No description provided for @splash_referral_title.
  ///
  /// In en, this message translates to:
  /// **'Enter Referral Code'**
  String get splash_referral_title;

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

  /// No description provided for @subscription_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Women message free. Men subscribe to connect.'**
  String get subscription_subtitle;

  /// No description provided for @subscription_title.
  ///
  /// In en, this message translates to:
  /// **'Unlock NOOR'**
  String get subscription_title;
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
