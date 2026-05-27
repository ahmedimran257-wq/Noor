// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appName => 'NOOR';

  @override
  String get appTagline => 'Commencez par bismillah';

  @override
  String get common_button_next => 'Suivant';

  @override
  String get common_button_back => 'Retour';

  @override
  String get common_button_skip => 'Passer';

  @override
  String get common_button_save => 'Enregistrer';

  @override
  String get common_button_cancel => 'Annuler';

  @override
  String get common_button_submit => 'Soumettre';

  @override
  String get common_button_done => 'Terminé';

  @override
  String get common_button_retry => 'Réessayer';

  @override
  String get common_label_optional => 'Facultatif';

  @override
  String get common_error_generic =>
      'Une erreur est survenue. Veuillez réessayer.';

  @override
  String get common_error_noInternet =>
      'Pas de connexion Internet. Veuillez vérifier votre connexion.';

  @override
  String get splash_button_createProfile => 'Créer un profil';

  @override
  String get splash_button_signIn => 'Se connecter';

  @override
  String get legal_title => 'Avant de commencer';

  @override
  String get legal_checkbox_age => 'Je confirme avoir 18 ans ou plus';

  @override
  String get legal_checkbox_terms =>
      'J\'accepte les Conditions d\'utilisation et la Politique de confidentialité';

  @override
  String get legal_button_continue => 'Continuer';

  @override
  String get auth_label_phoneNumber => 'Numéro de téléphone';

  @override
  String get auth_hint_phoneNumber => 'Entrez votre numéro de téléphone';

  @override
  String get auth_button_sendOtp => 'Envoyer le code de vérification';

  @override
  String get auth_label_enterOtp => 'Entrez le code à 6 chiffres envoyé à';

  @override
  String get auth_button_verifyOtp => 'Vérifier';

  @override
  String get auth_button_resendOtp => 'Renvoyer le code';

  @override
  String auth_label_resendIn(int seconds) {
    return 'Renvoyer dans ${seconds}s';
  }

  @override
  String onboarding_label_step(int current, int total) {
    return 'Étape $current sur $total';
  }

  @override
  String get onboarding_profileForWhom_title => 'Pour qui est ce profil ?';

  @override
  String get onboarding_profileForWhom_myself => 'Moi-même';

  @override
  String get onboarding_profileForWhom_myselfSub =>
      'Je cherche un(e) époux(se)';

  @override
  String get onboarding_profileForWhom_guardian => 'Mon fils ou ma fille';

  @override
  String get onboarding_profileForWhom_guardianSub =>
      'Je suis un parent ou tuteur';

  @override
  String get onboarding_profileForWhom_sibling => 'Mon frère ou ma sœur';

  @override
  String get onboarding_profileForWhom_siblingSub =>
      'J\'aide mon frère/sœur à trouver un(e) partenaire';

  @override
  String get onboarding_profileForWhom_ward => 'Mon pupille';

  @override
  String get onboarding_profileForWhom_wardSub =>
      'Je suis un tuteur gérant ce profil';

  @override
  String get onboarding_basicIdentity_title => 'Parlez-nous de vous';

  @override
  String get onboarding_label_firstName => 'Prénom';

  @override
  String get onboarding_label_lastName => 'Nom de famille';

  @override
  String get onboarding_label_dateOfBirth => 'Date de naissance';

  @override
  String get onboarding_label_gender => 'Genre';

  @override
  String get onboarding_label_male => 'Homme';

  @override
  String get onboarding_label_female => 'Femme';

  @override
  String get onboarding_label_city => 'Ville';

  @override
  String get onboarding_hint_searchCity => 'Recherchez votre ville…';

  @override
  String get onboarding_error_under18 =>
      'NOOR est réservé aux personnes de 18 ans et plus. Cette exigence protège notre communauté.';

  @override
  String get onboarding_islamicIdentity_title => 'Votre identité islamique';

  @override
  String get onboarding_label_sect => 'Courant';

  @override
  String get onboarding_label_sunni => 'Sunnite';

  @override
  String get onboarding_label_shia => 'Chiite';

  @override
  String get onboarding_label_preferNotToSay => 'Préfère ne pas dire';

  @override
  String get onboarding_label_deenLevel => 'Niveau de piété';

  @override
  String get onboarding_label_practicing => 'Pratiquant';

  @override
  String get onboarding_tooltip_practicing =>
      'Suit les cinq piliers, prie régulièrement, mode de vie halal';

  @override
  String get onboarding_label_moderate => 'Modéré';

  @override
  String get onboarding_tooltip_moderate =>
      'Valorise les principes islamiques, prie régulièrement mais pas toujours';

  @override
  String get onboarding_label_cultural => 'Musulman culturel';

  @override
  String get onboarding_tooltip_cultural =>
      'S\'identifie comme musulman, célèbre les occasions, ne prie pas forcément régulièrement';

  @override
  String get onboarding_label_praysFiveDaily => 'Je prie cinq fois par jour';

  @override
  String get onboarding_label_community => 'Votre communauté / biradari';

  @override
  String get onboarding_label_community_parent => 'Leur communauté / biradari';

  @override
  String get onboarding_label_motherTongue => 'Langue maternelle';

  @override
  String get onboarding_label_diet => 'Régime alimentaire';

  @override
  String get onboarding_diet_zabihaStrict => 'Zabiha strict';

  @override
  String get onboarding_diet_halalOnly => 'Halal uniquement';

  @override
  String get onboarding_diet_eatsAnything => 'Mange tout ce qui est halal';

  @override
  String get onboarding_diet_vegetarian => 'Végétarien';

  @override
  String get onboarding_diet_vegan => 'Végétalien';

  @override
  String get onboarding_label_smoking => 'Tabac';

  @override
  String get onboarding_label_vaping => 'Cigarette électronique';

  @override
  String get onboarding_label_hookah => 'Chicha';

  @override
  String get onboarding_habit_never => 'Jamais';

  @override
  String get onboarding_habit_occasionally => 'Occasionnellement';

  @override
  String get onboarding_habit_frequently => 'Fréquemment';

  @override
  String get onboarding_habit_preferNotToSay => 'Préfère ne pas dire';

  @override
  String get onboarding_label_livingExpectation =>
      'Attentes de logement après le mariage';

  @override
  String get onboarding_living_withInlaws => 'Avec la belle-famille';

  @override
  String get onboarding_living_withInlawsSub =>
      'Je m\'attends à vivre avec la famille de mon conjoint ou la mienne.';

  @override
  String get onboarding_living_separate => 'Logement séparé';

  @override
  String get onboarding_living_separateSub =>
      'Je préfère avoir notre propre logement indépendant.';

  @override
  String get onboarding_living_openToDiscussion => 'Ouvert à la discussion';

  @override
  String get onboarding_living_openToDiscussionSub =>
      'Je suis flexible et ouvert à discuter de ce qui convient à tous les deux.';

  @override
  String get onboarding_label_preferredLiving =>
      'Préférence d\'arrangement de vie';

  @override
  String get onboarding_preferredLiving_noPreference => 'Aucune préférence';

  @override
  String get copy_prayer_self => 'Priez-vous cinq fois par jour ?';

  @override
  String get copy_prayer_parent =>
      'Votre enfant prie-t-il cinq fois par jour ?';

  @override
  String get copy_prayer_sibling =>
      'Votre frère/sœur prie-t-il cinq fois par jour ?';

  @override
  String get copy_hijab_self => 'Portez-vous le hijab ?';

  @override
  String get copy_hijab_parent => 'Votre fille porte-t-elle le hijab ?';

  @override
  String get copy_hijab_sibling => 'Votre sœur porte-t-elle le hijab ?';

  @override
  String get copy_beard_self => 'Portez-vous la barbe ?';

  @override
  String get copy_beard_parent => 'Votre fils porte-t-il la barbe ?';

  @override
  String get copy_beard_sibling => 'Votre frère porte-t-il la barbe ?';

  @override
  String get onboarding_background_title => 'Études et carrière';

  @override
  String get onboarding_label_educationLevel => 'Niveau d\'études';

  @override
  String get onboarding_label_profession => 'Profession';

  @override
  String get onboarding_hint_profession => 'ex. Ingénieur, Enseignant, Médecin';

  @override
  String get onboarding_about_title => 'À propos de vous';

  @override
  String get onboarding_hint_bio => 'Décrivez-vous avec honnêteté et dignité.';

  @override
  String onboarding_label_bioCount(int count) {
    return '$count/300';
  }

  @override
  String get onboarding_error_bioContactInfo =>
      'Veuillez supprimer les informations de contact de votre bio. Les coordonnées externes ne sont pas autorisées pour votre sécurité.';

  @override
  String get onboarding_photo_title => 'Ajoutez vos photos';

  @override
  String get onboarding_photo_subtitle =>
      'Au moins une photo est requise. Votre photo principale doit montrer clairement votre visage.';

  @override
  String get onboarding_photo_verifySelfie => 'Selfie de vérification';

  @override
  String get onboarding_photo_verifySelfieHint =>
      'Prenez une photo en direct pour vérifier votre identité';

  @override
  String get onboarding_error_noFace =>
      'Veuillez utiliser une photo où votre visage est clairement visible.';

  @override
  String get onboarding_error_multipleFaces =>
      'Les photos de groupe ne peuvent pas être votre photo principale.';

  @override
  String get discovery_header_title => 'NOOR';

  @override
  String discovery_label_profilesRemaining(int count) {
    return '$count profils restants aujourd\'hui';
  }

  @override
  String get discovery_button_sendInterest => 'Envoyer un intérêt';

  @override
  String get discovery_label_interestSent => 'Intérêt envoyé ✓';

  @override
  String get discovery_label_outsidePrefs =>
      'Quelqu\'un avec qui vous pourriez tisser un lien';

  @override
  String get ceremony_text_blessing => 'Qu\'Allah bénisse cela de bonté';

  @override
  String get chat_placeholder_typeMessage => 'Écrire un message…';

  @override
  String chat_label_probation(int hours) {
    return 'La messagerie se déverrouille dans $hours heures. Vous pouvez envoyer des intérêts maintenant.';
  }

  @override
  String get chat_label_subscribeToMessage =>
      'Abonnez-vous pour déverrouiller la messagerie. Les femmes envoient toujours des messages gratuitement sur NOOR.';

  @override
  String get chat_opener_1 =>
      'Assalamu Alaikum ! J\'ai vu votre profil et j\'ai été sincèrement impressionné(e). Puis-je me présenter ?';

  @override
  String get chat_opener_2 =>
      'Bismillah. Votre profil a attiré mon attention. J\'aimerais en savoir plus sur vous.';

  @override
  String get chat_opener_3 =>
      'Assalamu Alaikum. Je crois que nous partageons des valeurs similaires. Seriez-vous ouvert(e) à faire connaissance ?';

  @override
  String get chat_endMatch_title => 'Mettre fin à ce match';

  @override
  String get chat_endMatch_subtitle =>
      'Choisissez un message respectueux pour clore cette conversation. L\'autre personne sera notifiée.';

  @override
  String get chat_endMatch_button => 'Envoyer et clore le match';

  @override
  String get chat_matchClosed_banner => 'Ce match a été respectueusement clos.';

  @override
  String get chat_closure_1 =>
      'Assalamu Alaikum. Après mûre réflexion, je pense que nous ne sommes pas faits l\'un pour l\'autre. Je vous souhaite sincèrement le meilleur et prie Allah de vous bénir d\'un(e) merveilleux(se) partenaire. JazakAllah khair.';

  @override
  String get chat_closure_2 =>
      'Assalamu Alaikum. Je voulais être honnête et respectueux(se) avec vous. Je ne pense pas que nous soyons compatibles, mais je prie qu\'Allah vous ouvre de meilleures portes. Avec mes meilleurs vœux.';

  @override
  String get chat_closure_3 =>
      'Assalamu Alaikum. Après une réflexion sincère, je pense que nous ne sommes pas compatibles. J\'espère que vous trouverez la bonne personne pour vous. JazakAllah khair pour votre temps.';

  @override
  String get chat_closure_4 =>
      'Assalamu Alaikum. J\'ai réfléchi à nos conversations et je pense qu\'il est préférable de clore ce match. Je n\'ai que du respect pour vous et je fais des duas pour qu\'Allah vous bénisse du meilleur.';

  @override
  String get chat_closure_5 =>
      'Assalamu Alaikum. Je voulais être transparent(e) avec vous plutôt que de disparaître. Je ne vois pas cela progresser davantage, mais j\'apprécie sincèrement votre temps et vous souhaite tout le bonheur. Qu\'Allah vous bénisse.';

  @override
  String get filter_label_motherTongue => 'Langue maternelle';

  @override
  String get filter_label_community => 'Communauté / Biradari';

  @override
  String get filter_label_livingExpectation => 'Logement après mariage';

  @override
  String get subscription_title => 'Débloquez NOOR';

  @override
  String get subscription_subtitle =>
      'Les femmes envoient des messages gratuitement. Les hommes s\'abonnent pour se connecter.';

  @override
  String subscription_button_monthly(String price) {
    return 'S\'abonner — $price/mois';
  }

  @override
  String get subscription_label_bestValue => 'Meilleure offre';

  @override
  String profile_label_completeness(int percent) {
    return 'Profil complété à $percent%';
  }

  @override
  String get profile_nudge_completeness =>
      'Les profils complétés à 80%+ reçoivent 3× plus d\'intérêts.';

  @override
  String get interests_tab_received => 'Reçus';

  @override
  String get interests_tab_sent => 'Envoyés';

  @override
  String get interests_button_accept => 'Accepter';

  @override
  String get interests_button_decline => 'Refuser';

  @override
  String get settings_title => 'Paramètres';

  @override
  String get settings_section_account => 'Compte';

  @override
  String get settings_section_safety => 'Sécurité';

  @override
  String get settings_section_app => 'Application';

  @override
  String get settings_section_legal => 'Mentions légales';

  @override
  String get settings_section_dangerZone => 'Zone de danger';

  @override
  String get settings_button_deleteAccount => 'Supprimer le compte';

  @override
  String get settings_label_deleteGrace =>
      'Votre profil sera masqué immédiatement. Vos données seront définitivement supprimées après 30 jours.';

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
