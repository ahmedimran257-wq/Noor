// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get appName => 'NOOR';

  @override
  String get appTagline => 'Bismillah ile başla';

  @override
  String get common_button_next => 'İleri';

  @override
  String get common_button_back => 'Geri';

  @override
  String get common_button_skip => 'Atla';

  @override
  String get common_button_save => 'Kaydet';

  @override
  String get common_button_cancel => 'İptal';

  @override
  String get common_button_submit => 'Gönder';

  @override
  String get common_button_done => 'Tamam';

  @override
  String get common_button_retry => 'Tekrar Dene';

  @override
  String get common_label_optional => 'İsteğe bağlı';

  @override
  String get common_error_generic => 'Bir hata oluştu. Lütfen tekrar deneyin.';

  @override
  String get common_error_noInternet => 'İnternet bağlantısı yok.';

  @override
  String get splash_button_createProfile => 'Profil Oluştur';

  @override
  String get splash_button_signIn => 'Giriş Yap';

  @override
  String get legal_title => 'Başlamadan önce';

  @override
  String get legal_checkbox_age =>
      '18 yaşında veya üzerinde olduğumu onaylıyorum';

  @override
  String get legal_checkbox_terms =>
      'Kullanım Koşullarını ve Gizlilik Politikasını kabul ediyorum';

  @override
  String get legal_button_continue => 'Devam Et';

  @override
  String get auth_label_phoneNumber => 'Telefon Numarası';

  @override
  String get auth_hint_phoneNumber => 'Telefon numaranızı girin';

  @override
  String get auth_button_sendOtp => 'Doğrulama Kodu Gönder';

  @override
  String get auth_label_enterOtp => 'Gönderilen 6 haneli kodu girin';

  @override
  String get auth_button_verifyOtp => 'Doğrula';

  @override
  String get auth_button_resendOtp => 'Kodu Tekrar Gönder';

  @override
  String auth_label_resendIn(int seconds) {
    return '${seconds}s içinde tekrar gönder';
  }

  @override
  String onboarding_label_step(int current, int total) {
    return 'Adım $current / $total';
  }

  @override
  String get onboarding_profileForWhom_title => 'Bu profil kimin için?';

  @override
  String get onboarding_profileForWhom_myself => 'Kendim için';

  @override
  String get onboarding_profileForWhom_myselfSub => 'Eş arıyorum';

  @override
  String get onboarding_profileForWhom_guardian => 'Oğlum veya kızım için';

  @override
  String get onboarding_profileForWhom_guardianSub => 'Ebeveyn veya veliyim';

  @override
  String get onboarding_profileForWhom_sibling => 'Kardeşim için';

  @override
  String get onboarding_profileForWhom_siblingSub =>
      'Kardeşimin eş bulmasına yardım ediyorum';

  @override
  String get onboarding_profileForWhom_ward => 'Vesayetimdeki kişi için';

  @override
  String get onboarding_profileForWhom_wardSub => 'Bu profili yöneten veliyim';

  @override
  String get onboarding_basicIdentity_title => 'Bize kendinizden bahsedin';

  @override
  String get onboarding_label_firstName => 'Ad';

  @override
  String get onboarding_label_lastName => 'Soyad';

  @override
  String get onboarding_label_dateOfBirth => 'Doğum Tarihi';

  @override
  String get onboarding_label_gender => 'Cinsiyet';

  @override
  String get onboarding_label_male => 'Erkek';

  @override
  String get onboarding_label_female => 'Kadın';

  @override
  String get onboarding_label_city => 'Şehir';

  @override
  String get onboarding_hint_searchCity => 'Şehrinizi arayın…';

  @override
  String get onboarding_error_under18 => 'NOOR 18 yaş ve üstü içindir.';

  @override
  String get onboarding_islamicIdentity_title => 'İslami kimliğiniz';

  @override
  String get onboarding_label_sect => 'Mezhep';

  @override
  String get onboarding_label_sunni => 'Sünni';

  @override
  String get onboarding_label_shia => 'Şii';

  @override
  String get onboarding_label_preferNotToSay => 'Söylemeyi tercih etmiyorum';

  @override
  String get onboarding_label_deenLevel => 'Dindarlık Seviyesi';

  @override
  String get onboarding_label_practicing => 'Uygulayan';

  @override
  String get onboarding_tooltip_practicing =>
      'Beş şartı yerine getirir, düzenli namaz kılar, helal yaşam tarzı';

  @override
  String get onboarding_label_moderate => 'Ilımlı';

  @override
  String get onboarding_tooltip_moderate =>
      'İslami ilkelere değer verir, düzenli ama her zaman değil namaz kılar';

  @override
  String get onboarding_label_cultural => 'Kültürel Müslüman';

  @override
  String get onboarding_tooltip_cultural =>
      'Müslüman olarak tanımlar, özel günleri kutlar, düzenli namaz kılmayabilir';

  @override
  String get onboarding_label_praysFiveDaily =>
      'Günde beş vakit namaz kılıyorum';

  @override
  String get onboarding_label_community => 'Topluluk / Biradari';

  @override
  String get onboarding_label_community_parent =>
      'Onların topluluğu / Biradari';

  @override
  String get onboarding_label_motherTongue => 'Ana dil';

  @override
  String get onboarding_label_diet => 'Beslenme';

  @override
  String get onboarding_diet_zabihaStrict => 'Sıkı Zebiha';

  @override
  String get onboarding_diet_halalOnly => 'Sadece Helal';

  @override
  String get onboarding_diet_eatsAnything => 'Helal olan her şeyi yer';

  @override
  String get onboarding_diet_vegetarian => 'Vejetaryen';

  @override
  String get onboarding_diet_vegan => 'Vegan';

  @override
  String get onboarding_label_smoking => 'Sigara';

  @override
  String get onboarding_label_vaping => 'Elektronik Sigara';

  @override
  String get onboarding_label_hookah => 'Nargile';

  @override
  String get onboarding_habit_never => 'Asla';

  @override
  String get onboarding_habit_occasionally => 'Ara sıra';

  @override
  String get onboarding_habit_frequently => 'Sık sık';

  @override
  String get onboarding_habit_preferNotToSay => 'Söylemeyi tercih etmiyorum';

  @override
  String get onboarding_label_livingExpectation =>
      'Evlilik sonrası yaşam beklentileri';

  @override
  String get onboarding_living_withInlaws => 'Aile ile birlikte';

  @override
  String get onboarding_living_withInlawsSub =>
      'Eşimin ailesinin veya kendi ailemin yanında yaşamayı bekliyorum.';

  @override
  String get onboarding_living_separate => 'Ayrı Ev';

  @override
  String get onboarding_living_separateSub =>
      'Kendi bağımsız evimizin olmasını tercih ediyorum.';

  @override
  String get onboarding_living_openToDiscussion => 'Tartışmaya Açık';

  @override
  String get onboarding_living_openToDiscussionSub =>
      'Esneyim ve her ikimize uygun olanı tartışmaya hazırım.';

  @override
  String get onboarding_label_preferredLiving => 'Tercih edilen yaşam düzeni';

  @override
  String get onboarding_preferredLiving_noPreference => 'Tercih Yok';

  @override
  String get copy_prayer_self => 'Günde beş vakit namaz kılıyor musunuz?';

  @override
  String get copy_prayer_parent =>
      'Çocuğunuz günde beş vakit namaz kılıyor mu?';

  @override
  String get copy_prayer_sibling =>
      'Kardeşiniz günde beş vakit namaz kılıyor mu?';

  @override
  String get copy_hijab_self => 'Başörtüsü takıyor musunuz?';

  @override
  String get copy_hijab_parent => 'Kızınız başörtüsü takıyor mu?';

  @override
  String get copy_hijab_sibling => 'Kız kardeşiniz başörtüsü takıyor mu?';

  @override
  String get copy_beard_self => 'Sakal bırakıyor musunuz?';

  @override
  String get copy_beard_parent => 'Oğlunuz sakal bırakıyor mu?';

  @override
  String get copy_beard_sibling => 'Erkek kardeşiniz sakal bırakıyor mu?';

  @override
  String get onboarding_background_title => 'Eğitim ve Kariyer';

  @override
  String get onboarding_label_educationLevel => 'Eğitim Seviyesi';

  @override
  String get onboarding_label_profession => 'Meslek';

  @override
  String get onboarding_hint_profession => 'ör. Mühendis, Öğretmen, Doktor';

  @override
  String get onboarding_about_title => 'Hakkınızda';

  @override
  String get onboarding_hint_bio =>
      'Kendinizi dürüstlük ve saygınlıkla tanımlayın.';

  @override
  String onboarding_label_bioCount(int count) {
    return '$count/300';
  }

  @override
  String get onboarding_error_bioContactInfo =>
      'Lütfen biyografinizden iletişim bilgilerini kaldırın.';

  @override
  String get onboarding_photo_title => 'Fotoğraflarınızı ekleyin';

  @override
  String get onboarding_photo_subtitle =>
      'En az bir fotoğraf gereklidir. Ana fotoğrafınız yüzünüzü açıkça göstermelidir.';

  @override
  String get onboarding_photo_verifySelfie => 'Doğrulama Selfie\'si';

  @override
  String get onboarding_photo_verifySelfieHint =>
      'Kimliğinizi doğrulamak için canlı bir fotoğraf çekin';

  @override
  String get onboarding_error_noFace =>
      'Lütfen yüzünüzün açıkça görüldüğü bir fotoğraf kullanın.';

  @override
  String get onboarding_error_multipleFaces =>
      'Grup fotoğrafları ana fotoğrafınız olamaz.';

  @override
  String get discovery_header_title => 'NOOR';

  @override
  String discovery_label_profilesRemaining(int count) {
    return 'Bugün $count profil kaldı';
  }

  @override
  String get discovery_button_sendInterest => 'İlgi Gönder';

  @override
  String get discovery_label_interestSent => 'İlgi Gönderildi ✓';

  @override
  String get discovery_label_outsidePrefs => 'Bağlantı kurabileceğiniz biri';

  @override
  String get ceremony_text_blessing => 'Allah bunu hayırla bereketlendirsin';

  @override
  String get chat_placeholder_typeMessage => 'Bir mesaj yazın…';

  @override
  String chat_label_probation(int hours) {
    return 'Mesajlaşma $hours saat içinde açılır.';
  }

  @override
  String get chat_label_subscribeToMessage =>
      'Mesajlaşmayı açmak için abone olun. Kadınlar NOOR\'da her zaman ücretsiz mesaj gönderir.';

  @override
  String get chat_opener_1 =>
      'Selamün Aleyküm! Profilinizi gördüm ve gerçekten etkilendim. Kendimi tanıtabilir miyim?';

  @override
  String get chat_opener_2 =>
      'Bismillah. Profiliniz dikkatimi çekti. Sizin hakkınızda daha fazla bilgi edinmek isterim.';

  @override
  String get chat_opener_3 =>
      'Selamün Aleyküm. Benzer değerleri paylaştığımıza inanıyorum. Tanışmaya açık mısınız?';

  @override
  String get chat_endMatch_title => 'Bu eşleşmeyi sonlandır';

  @override
  String get chat_endMatch_subtitle =>
      'Bu sohbeti kapatmak için saygılı bir mesaj seçin.';

  @override
  String get chat_endMatch_button => 'Gönder ve Eşleşmeyi Sonlandır';

  @override
  String get chat_matchClosed_banner => 'Bu eşleşme saygıyla kapatıldı.';

  @override
  String get chat_closure_1 =>
      'Selamün Aleyküm. Düşündükten sonra bunun doğru eşleşme olmadığını hissediyorum. Size en iyisini diliyorum. JazakAllah khair.';

  @override
  String get chat_closure_2 =>
      'Selamün Aleyküm. Size karşı dürüst ve saygılı olmak istedim. Uygun olmadığımızı düşünüyorum ama Allah\'tan size daha iyi kapılar açmasını diliyorum.';

  @override
  String get chat_closure_3 =>
      'Selamün Aleyküm. Samimi bir düşünceden sonra uyumlu olmadığımızı hissediyorum. Vaktiniz için JazakAllah khair.';

  @override
  String get chat_closure_4 =>
      'Selamün Aleyküm. Sohbetlerimiz üzerinde düşündüm ve bu eşleşmeyi kapatmanın en iyisi olduğunu düşünüyorum. Size büyük saygı duyuyorum.';

  @override
  String get chat_closure_5 =>
      'Selamün Aleyküm. Kaybolmaktansa sizinle şeffaf olmak istedim. Vaktinizi gerçekten takdir ediyorum. Allah sizi bereketlendirsin.';

  @override
  String get filter_label_motherTongue => 'Ana Dil';

  @override
  String get filter_label_community => 'Topluluk / Biradari';

  @override
  String get filter_label_livingExpectation => 'Evlilik Sonrası Yaşam';

  @override
  String get subscription_title => 'NOOR\'u Açın';

  @override
  String get subscription_subtitle =>
      'Kadınlar ücretsiz mesaj gönderir. Erkekler bağlantı için abone olur.';

  @override
  String subscription_button_monthly(String price) {
    return 'Abone Ol — $price/ay';
  }

  @override
  String get subscription_label_bestValue => 'En İyi Fırsat';

  @override
  String profile_label_completeness(int percent) {
    return 'Profil %$percent tamamlandı';
  }

  @override
  String get profile_nudge_completeness =>
      '%80+ tamamlanan profiller 3 kat daha fazla ilgi alır.';

  @override
  String get interests_tab_received => 'Alınan';

  @override
  String get interests_tab_sent => 'Gönderilen';

  @override
  String get interests_button_accept => 'Kabul Et';

  @override
  String get interests_button_decline => 'Reddet';

  @override
  String get settings_title => 'Ayarlar';

  @override
  String get settings_section_account => 'Hesap';

  @override
  String get settings_section_safety => 'Güvenlik';

  @override
  String get settings_section_app => 'Uygulama';

  @override
  String get settings_section_legal => 'Yasal';

  @override
  String get settings_section_dangerZone => 'Tehlikeli Bölge';

  @override
  String get settings_button_deleteAccount => 'Hesabı Sil';

  @override
  String get settings_label_deleteGrace =>
      'Profiliniz hemen gizlenecektir. Verileriniz 30 gün sonra kalıcı olarak silinecektir.';

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
