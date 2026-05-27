// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appName => 'NOOR';

  @override
  String get appTagline => 'Beginne mit Bismillah';

  @override
  String get common_button_next => 'Weiter';

  @override
  String get common_button_back => 'Zurück';

  @override
  String get common_button_skip => 'Überspringen';

  @override
  String get common_button_save => 'Speichern';

  @override
  String get common_button_cancel => 'Abbrechen';

  @override
  String get common_button_submit => 'Absenden';

  @override
  String get common_button_done => 'Fertig';

  @override
  String get common_button_retry => 'Erneut versuchen';

  @override
  String get common_label_optional => 'Optional';

  @override
  String get common_error_generic =>
      'Etwas ist schiefgelaufen. Bitte versuche es erneut.';

  @override
  String get common_error_noInternet => 'Keine Internetverbindung.';

  @override
  String get splash_button_createProfile => 'Profil erstellen';

  @override
  String get splash_button_signIn => 'Anmelden';

  @override
  String get legal_title => 'Bevor du beginnst';

  @override
  String get legal_checkbox_age =>
      'Ich bestätige, dass ich 18 Jahre oder älter bin';

  @override
  String get legal_checkbox_terms =>
      'Ich stimme den Nutzungsbedingungen und der Datenschutzerklärung zu';

  @override
  String get legal_button_continue => 'Weiter';

  @override
  String get auth_label_phoneNumber => 'Telefonnummer';

  @override
  String get auth_hint_phoneNumber => 'Gib deine Telefonnummer ein';

  @override
  String get auth_button_sendOtp => 'Bestätigungscode senden';

  @override
  String get auth_label_enterOtp =>
      'Gib den 6-stelligen Code ein, der gesendet wurde an';

  @override
  String get auth_button_verifyOtp => 'Bestätigen';

  @override
  String get auth_button_resendOtp => 'Code erneut senden';

  @override
  String auth_label_resendIn(int seconds) {
    return 'Erneut senden in ${seconds}s';
  }

  @override
  String onboarding_label_step(int current, int total) {
    return 'Schritt $current von $total';
  }

  @override
  String get onboarding_profileForWhom_title => 'Für wen ist dieses Profil?';

  @override
  String get onboarding_profileForWhom_myself => 'Für mich selbst';

  @override
  String get onboarding_profileForWhom_myselfSub =>
      'Ich suche einen Ehepartner';

  @override
  String get onboarding_profileForWhom_guardian =>
      'Mein Sohn oder meine Tochter';

  @override
  String get onboarding_profileForWhom_guardianSub =>
      'Ich bin Elternteil oder Vormund';

  @override
  String get onboarding_profileForWhom_sibling =>
      'Mein Bruder oder meine Schwester';

  @override
  String get onboarding_profileForWhom_siblingSub =>
      'Ich helfe meinem Geschwister einen Partner zu finden';

  @override
  String get onboarding_profileForWhom_ward => 'Mein Schützling';

  @override
  String get onboarding_profileForWhom_wardSub =>
      'Ich bin Vormund und verwalte dieses Profil';

  @override
  String get onboarding_basicIdentity_title => 'Erzähle uns von dir';

  @override
  String get onboarding_label_firstName => 'Vorname';

  @override
  String get onboarding_label_lastName => 'Nachname';

  @override
  String get onboarding_label_dateOfBirth => 'Geburtsdatum';

  @override
  String get onboarding_label_gender => 'Geschlecht';

  @override
  String get onboarding_label_male => 'Männlich';

  @override
  String get onboarding_label_female => 'Weiblich';

  @override
  String get onboarding_label_city => 'Stadt';

  @override
  String get onboarding_hint_searchCity => 'Suche deine Stadt…';

  @override
  String get onboarding_error_under18 => 'NOOR ist für Personen ab 18 Jahren.';

  @override
  String get onboarding_islamicIdentity_title => 'Deine islamische Identität';

  @override
  String get onboarding_label_sect => 'Glaubensrichtung';

  @override
  String get onboarding_label_sunni => 'Sunni';

  @override
  String get onboarding_label_shia => 'Schia';

  @override
  String get onboarding_label_preferNotToSay => 'Möchte ich nicht sagen';

  @override
  String get onboarding_label_deenLevel => 'Religiositätsstufe';

  @override
  String get onboarding_label_practicing => 'Praktizierend';

  @override
  String get onboarding_tooltip_practicing =>
      'Befolgt alle fünf Säulen, betet regelmäßig, halal Lebensstil';

  @override
  String get onboarding_label_moderate => 'Moderat';

  @override
  String get onboarding_tooltip_moderate =>
      'Schätzt islamische Prinzipien, betet regelmäßig aber nicht immer';

  @override
  String get onboarding_label_cultural => 'Kultureller Muslim';

  @override
  String get onboarding_tooltip_cultural =>
      'Identifiziert sich als Muslim, feiert Anlässe, betet möglicherweise nicht regelmäßig';

  @override
  String get onboarding_label_praysFiveDaily => 'Ich bete fünfmal täglich';

  @override
  String get onboarding_label_community => 'Deine Gemeinschaft / Biradari';

  @override
  String get onboarding_label_community_parent =>
      'Ihre Gemeinschaft / Biradari';

  @override
  String get onboarding_label_motherTongue => 'Muttersprache';

  @override
  String get onboarding_label_diet => 'Ernährung';

  @override
  String get onboarding_diet_zabihaStrict => 'Streng Zabiha';

  @override
  String get onboarding_diet_halalOnly => 'Nur Halal';

  @override
  String get onboarding_diet_eatsAnything => 'Isst alles Halale';

  @override
  String get onboarding_diet_vegetarian => 'Vegetarisch';

  @override
  String get onboarding_diet_vegan => 'Vegan';

  @override
  String get onboarding_label_smoking => 'Rauchen';

  @override
  String get onboarding_label_vaping => 'E-Zigaretten';

  @override
  String get onboarding_label_hookah => 'Shisha';

  @override
  String get onboarding_habit_never => 'Nie';

  @override
  String get onboarding_habit_occasionally => 'Gelegentlich';

  @override
  String get onboarding_habit_frequently => 'Häufig';

  @override
  String get onboarding_habit_preferNotToSay => 'Möchte ich nicht sagen';

  @override
  String get onboarding_label_livingExpectation =>
      'Wohnerwartungen nach der Ehe';

  @override
  String get onboarding_living_withInlaws => 'Bei der Familie';

  @override
  String get onboarding_living_withInlawsSub =>
      'Ich erwarte bei der Familie meines Partners zu leben.';

  @override
  String get onboarding_living_separate => 'Eigene Wohnung';

  @override
  String get onboarding_living_separateSub =>
      'Ich bevorzuge eine eigene unabhängige Wohnung.';

  @override
  String get onboarding_living_openToDiscussion => 'Offen für Diskussion';

  @override
  String get onboarding_living_openToDiscussionSub =>
      'Ich bin flexibel und bereit zu besprechen was für beide passt.';

  @override
  String get onboarding_label_preferredLiving => 'Bevorzugte Wohnvereinbarung';

  @override
  String get onboarding_preferredLiving_noPreference => 'Keine Präferenz';

  @override
  String get copy_prayer_self => 'Betest du fünfmal täglich?';

  @override
  String get copy_prayer_parent => 'Betet dein Kind fünfmal täglich?';

  @override
  String get copy_prayer_sibling => 'Betet dein Geschwister fünfmal täglich?';

  @override
  String get copy_hijab_self => 'Trägst du Hijab?';

  @override
  String get copy_hijab_parent => 'Trägt deine Tochter Hijab?';

  @override
  String get copy_hijab_sibling => 'Trägt deine Schwester Hijab?';

  @override
  String get copy_beard_self => 'Trägst du einen Bart?';

  @override
  String get copy_beard_parent => 'Trägt dein Sohn einen Bart?';

  @override
  String get copy_beard_sibling => 'Trägt dein Bruder einen Bart?';

  @override
  String get onboarding_background_title => 'Bildung und Karriere';

  @override
  String get onboarding_label_educationLevel => 'Bildungsniveau';

  @override
  String get onboarding_label_profession => 'Beruf';

  @override
  String get onboarding_hint_profession => 'z.B. Ingenieur, Lehrer, Arzt';

  @override
  String get onboarding_about_title => 'Über dich';

  @override
  String get onboarding_hint_bio =>
      'Beschreibe dich mit Ehrlichkeit und Würde.';

  @override
  String onboarding_label_bioCount(int count) {
    return '$count/300';
  }

  @override
  String get onboarding_error_bioContactInfo =>
      'Bitte entferne Kontaktinformationen aus deiner Bio.';

  @override
  String get onboarding_photo_title => 'Füge deine Fotos hinzu';

  @override
  String get onboarding_photo_subtitle =>
      'Mindestens ein Foto ist erforderlich. Dein Hauptfoto muss dein Gesicht deutlich zeigen.';

  @override
  String get onboarding_photo_verifySelfie => 'Verifizierungs-Selfie';

  @override
  String get onboarding_photo_verifySelfieHint =>
      'Mache ein Live-Foto zur Identitätsbestätigung';

  @override
  String get onboarding_error_noFace =>
      'Bitte verwende ein Foto auf dem dein Gesicht deutlich sichtbar ist.';

  @override
  String get onboarding_error_multipleFaces =>
      'Gruppenfotos können nicht dein Hauptfoto sein.';

  @override
  String get discovery_header_title => 'NOOR';

  @override
  String discovery_label_profilesRemaining(int count) {
    return '$count Profile heute verbleibend';
  }

  @override
  String get discovery_button_sendInterest => 'Interesse senden';

  @override
  String get discovery_label_interestSent => 'Interesse gesendet ✓';

  @override
  String get discovery_label_outsidePrefs =>
      'Jemand mit dem du dich verbinden könntest';

  @override
  String get ceremony_text_blessing => 'Möge Allah dies mit Gutem segnen';

  @override
  String get chat_placeholder_typeMessage => 'Nachricht schreiben…';

  @override
  String chat_label_probation(int hours) {
    return 'Nachrichten werden in $hours Stunden freigeschaltet.';
  }

  @override
  String get chat_label_subscribeToMessage =>
      'Abonniere um Nachrichten freizuschalten. Frauen senden auf NOOR immer kostenlos.';

  @override
  String get chat_opener_1 =>
      'Assalamu Alaikum! Ich habe dein Profil gesehen und war aufrichtig beeindruckt. Darf ich mich vorstellen?';

  @override
  String get chat_opener_2 =>
      'Bismillah. Dein Profil hat meine Aufmerksamkeit erregt. Ich würde gerne mehr über dich erfahren.';

  @override
  String get chat_opener_3 =>
      'Assalamu Alaikum. Ich glaube wir teilen ähnliche Werte. Wärst du offen dafür einander kennenzulernen?';

  @override
  String get chat_endMatch_title => 'Dieses Match beenden';

  @override
  String get chat_endMatch_subtitle =>
      'Wähle eine respektvolle Nachricht um dieses Gespräch zu beenden.';

  @override
  String get chat_endMatch_button => 'Senden und Match beenden';

  @override
  String get chat_matchClosed_banner =>
      'Dieses Match wurde respektvoll beendet.';

  @override
  String get chat_closure_1 =>
      'Assalamu Alaikum. Nach reiflicher Überlegung denke ich dass wir nicht zueinander passen. Ich wünsche dir aufrichtig alles Gute. JazakAllah khair.';

  @override
  String get chat_closure_2 =>
      'Assalamu Alaikum. Ich wollte ehrlich und respektvoll zu dir sein. Ich denke nicht dass wir zusammenpassen aber ich bete dass Allah dir bessere Türen öffnet.';

  @override
  String get chat_closure_3 =>
      'Assalamu Alaikum. Nach aufrichtiger Überlegung denke ich dass wir nicht kompatibel sind. JazakAllah khair für deine Zeit.';

  @override
  String get chat_closure_4 =>
      'Assalamu Alaikum. Ich habe über unsere Gespräche nachgedacht und denke es ist am besten dieses Match zu beenden. Ich habe nur Respekt für dich.';

  @override
  String get chat_closure_5 =>
      'Assalamu Alaikum. Ich wollte transparent mit dir sein anstatt zu verschwinden. Ich schätze deine Zeit aufrichtig. Möge Allah dich segnen.';

  @override
  String get filter_label_motherTongue => 'Muttersprache';

  @override
  String get filter_label_community => 'Gemeinschaft / Biradari';

  @override
  String get filter_label_livingExpectation => 'Wohnen nach der Ehe';

  @override
  String get subscription_title => 'NOOR freischalten';

  @override
  String get subscription_subtitle =>
      'Frauen senden kostenlos. Männer abonnieren für Kontakt.';

  @override
  String subscription_button_monthly(String price) {
    return 'Abonnieren — $price/Monat';
  }

  @override
  String get subscription_label_bestValue => 'Bestes Angebot';

  @override
  String profile_label_completeness(int percent) {
    return 'Profil zu $percent% vollständig';
  }

  @override
  String get profile_nudge_completeness =>
      'Profile mit 80%+ Vollständigkeit erhalten 3× mehr Interessen.';

  @override
  String get interests_tab_received => 'Empfangen';

  @override
  String get interests_tab_sent => 'Gesendet';

  @override
  String get interests_button_accept => 'Annehmen';

  @override
  String get interests_button_decline => 'Ablehnen';

  @override
  String get settings_title => 'Einstellungen';

  @override
  String get settings_section_account => 'Konto';

  @override
  String get settings_section_safety => 'Sicherheit';

  @override
  String get settings_section_app => 'App';

  @override
  String get settings_section_legal => 'Rechtliches';

  @override
  String get settings_section_dangerZone => 'Gefahrenzone';

  @override
  String get settings_button_deleteAccount => 'Konto löschen';

  @override
  String get settings_label_deleteGrace =>
      'Dein Profil wird sofort ausgeblendet. Deine Daten werden nach 30 Tagen endgültig gelöscht.';

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
