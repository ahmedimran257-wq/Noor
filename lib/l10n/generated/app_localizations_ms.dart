// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Malay (`ms`).
class AppLocalizationsMs extends AppLocalizations {
  AppLocalizationsMs([String locale = 'ms']) : super(locale);

  @override
  String get appName => 'NOOR';

  @override
  String get appTagline => 'Mulakan dengan bismillah';

  @override
  String get common_button_next => 'Seterusnya';

  @override
  String get common_button_back => 'Kembali';

  @override
  String get common_button_skip => 'Langkau';

  @override
  String get common_button_save => 'Simpan';

  @override
  String get common_button_cancel => 'Batal';

  @override
  String get common_button_submit => 'Hantar';

  @override
  String get common_button_done => 'Selesai';

  @override
  String get common_button_retry => 'Cuba Lagi';

  @override
  String get common_label_optional => 'Pilihan';

  @override
  String get common_error_generic => 'Sesuatu telah berlaku. Sila cuba lagi.';

  @override
  String get common_error_noInternet => 'Tiada sambungan internet.';

  @override
  String get splash_button_createProfile => 'Cipta Profil';

  @override
  String get splash_button_signIn => 'Log Masuk';

  @override
  String get legal_title => 'Sebelum anda mula';

  @override
  String get legal_checkbox_age =>
      'Saya mengesahkan bahawa saya berumur 18 tahun atau lebih';

  @override
  String get legal_checkbox_terms =>
      'Saya bersetuju dengan Syarat Perkhidmatan dan Dasar Privasi';

  @override
  String get legal_button_continue => 'Teruskan';

  @override
  String get auth_label_phoneNumber => 'Nombor Telefon';

  @override
  String get auth_hint_phoneNumber => 'Masukkan nombor telefon anda';

  @override
  String get auth_button_sendOtp => 'Hantar Kod Pengesahan';

  @override
  String get auth_label_enterOtp => 'Masukkan kod 6 digit yang dihantar ke';

  @override
  String get auth_button_verifyOtp => 'Sahkan';

  @override
  String get auth_button_resendOtp => 'Hantar Semula Kod';

  @override
  String auth_label_resendIn(int seconds) {
    return 'Hantar semula dalam ${seconds}s';
  }

  @override
  String onboarding_label_step(int current, int total) {
    return 'Langkah $current daripada $total';
  }

  @override
  String get onboarding_profileForWhom_title => 'Profil ini untuk siapa?';

  @override
  String get onboarding_profileForWhom_myself => 'Diri sendiri';

  @override
  String get onboarding_profileForWhom_myselfSub =>
      'Saya mencari pasangan hidup';

  @override
  String get onboarding_profileForWhom_guardian =>
      'Anak lelaki atau perempuan saya';

  @override
  String get onboarding_profileForWhom_guardianSub =>
      'Saya adalah ibu bapa atau penjaga';

  @override
  String get onboarding_profileForWhom_sibling => 'Adik-beradik saya';

  @override
  String get onboarding_profileForWhom_siblingSub =>
      'Saya membantu adik-beradik mencari pasangan';

  @override
  String get onboarding_profileForWhom_ward => 'Orang yang saya jagakan';

  @override
  String get onboarding_profileForWhom_wardSub =>
      'Saya penjaga yang menguruskan profil ini';

  @override
  String get onboarding_basicIdentity_title => 'Ceritakan tentang diri anda';

  @override
  String get onboarding_label_firstName => 'Nama Pertama';

  @override
  String get onboarding_label_lastName => 'Nama Keluarga';

  @override
  String get onboarding_label_dateOfBirth => 'Tarikh Lahir';

  @override
  String get onboarding_label_gender => 'Jantina';

  @override
  String get onboarding_label_male => 'Lelaki';

  @override
  String get onboarding_label_female => 'Perempuan';

  @override
  String get onboarding_label_city => 'Bandar';

  @override
  String get onboarding_hint_searchCity => 'Cari bandar anda…';

  @override
  String get onboarding_error_under18 =>
      'NOOR untuk mereka yang berumur 18 tahun ke atas.';

  @override
  String get onboarding_islamicIdentity_title => 'Identiti Islam anda';

  @override
  String get onboarding_label_sect => 'Mazhab';

  @override
  String get onboarding_label_sunni => 'Sunni';

  @override
  String get onboarding_label_shia => 'Syiah';

  @override
  String get onboarding_label_preferNotToSay => 'Tidak mahu menjawab';

  @override
  String get onboarding_label_deenLevel => 'Tahap Keagamaan';

  @override
  String get onboarding_label_practicing => 'Mengamalkan';

  @override
  String get onboarding_tooltip_practicing =>
      'Menjalankan lima rukun, solat tetap, gaya hidup halal';

  @override
  String get onboarding_label_moderate => 'Sederhana';

  @override
  String get onboarding_tooltip_moderate =>
      'Menghargai prinsip Islam, solat tetap tetapi tidak selalu';

  @override
  String get onboarding_label_cultural => 'Muslim Budaya';

  @override
  String get onboarding_tooltip_cultural =>
      'Mengenal pasti sebagai Muslim, meraikan perayaan, mungkin tidak solat tetap';

  @override
  String get onboarding_label_praysFiveDaily =>
      'Saya solat lima waktu setiap hari';

  @override
  String get onboarding_label_community => 'Komuniti / biradari anda';

  @override
  String get onboarding_label_community_parent => 'Komuniti / biradari mereka';

  @override
  String get onboarding_label_motherTongue => 'Bahasa ibunda';

  @override
  String get onboarding_label_diet => 'Diet';

  @override
  String get onboarding_diet_zabihaStrict => 'Zabiha ketat';

  @override
  String get onboarding_diet_halalOnly => 'Halal sahaja';

  @override
  String get onboarding_diet_eatsAnything => 'Makan apa sahaja yang halal';

  @override
  String get onboarding_diet_vegetarian => 'Vegetarian';

  @override
  String get onboarding_diet_vegan => 'Vegan';

  @override
  String get onboarding_label_smoking => 'Merokok';

  @override
  String get onboarding_label_vaping => 'Vaping / Rokok elektronik';

  @override
  String get onboarding_label_hookah => 'Hookah / Shisha';

  @override
  String get onboarding_habit_never => 'Tidak pernah';

  @override
  String get onboarding_habit_occasionally => 'Kadang-kadang';

  @override
  String get onboarding_habit_frequently => 'Kerap';

  @override
  String get onboarding_habit_preferNotToSay => 'Tidak mahu menjawab';

  @override
  String get onboarding_label_livingExpectation =>
      'Jangkaan tempat tinggal selepas berkahwin';

  @override
  String get onboarding_living_withInlaws => 'Bersama Mertua';

  @override
  String get onboarding_living_withInlawsSub =>
      'Saya menjangkakan tinggal bersama keluarga pasangan atau keluarga sendiri.';

  @override
  String get onboarding_living_separate => 'Rumah Berasingan';

  @override
  String get onboarding_living_separateSub =>
      'Saya lebih suka mempunyai rumah sendiri yang bebas.';

  @override
  String get onboarding_living_openToDiscussion => 'Terbuka untuk Perbincangan';

  @override
  String get onboarding_living_openToDiscussionSub =>
      'Saya fleksibel dan gembira berbincang apa yang sesuai untuk kedua-dua pihak.';

  @override
  String get onboarding_label_preferredLiving =>
      'Keutamaan pengaturan tempat tinggal';

  @override
  String get onboarding_preferredLiving_noPreference => 'Tiada Keutamaan';

  @override
  String get copy_prayer_self => 'Adakah anda solat lima waktu setiap hari?';

  @override
  String get copy_prayer_parent =>
      'Adakah anak anda solat lima waktu setiap hari?';

  @override
  String get copy_prayer_sibling =>
      'Adakah adik-beradik anda solat lima waktu setiap hari?';

  @override
  String get copy_hijab_self => 'Adakah anda memakai hijab?';

  @override
  String get copy_hijab_parent => 'Adakah anak perempuan anda memakai hijab?';

  @override
  String get copy_hijab_sibling => 'Adakah adik perempuan anda memakai hijab?';

  @override
  String get copy_beard_self => 'Adakah anda berjanggut?';

  @override
  String get copy_beard_parent => 'Adakah anak lelaki anda berjanggut?';

  @override
  String get copy_beard_sibling => 'Adakah adik lelaki anda berjanggut?';

  @override
  String get onboarding_background_title => 'Pendidikan & Kerjaya';

  @override
  String get onboarding_label_educationLevel => 'Tahap Pendidikan';

  @override
  String get onboarding_label_profession => 'Profesion';

  @override
  String get onboarding_hint_profession => 'cth. Jurutera, Guru, Doktor';

  @override
  String get onboarding_about_title => 'Tentang diri anda';

  @override
  String get onboarding_hint_bio =>
      'Terangkan diri anda dengan jujur dan bermartabat.';

  @override
  String onboarding_label_bioCount(int count) {
    return '$count/300';
  }

  @override
  String get onboarding_error_bioContactInfo =>
      'Sila buang maklumat hubungan daripada bio anda.';

  @override
  String get onboarding_photo_title => 'Tambah foto anda';

  @override
  String get onboarding_photo_subtitle =>
      'Sekurang-kurangnya satu foto diperlukan. Foto utama anda mesti menunjukkan wajah anda dengan jelas.';

  @override
  String get onboarding_photo_verifySelfie => 'Selfie Pengesahan';

  @override
  String get onboarding_photo_verifySelfieHint =>
      'Ambil foto langsung untuk mengesahkan identiti anda';

  @override
  String get onboarding_error_noFace =>
      'Sila gunakan foto di mana wajah anda kelihatan jelas.';

  @override
  String get onboarding_error_multipleFaces =>
      'Foto kumpulan tidak boleh menjadi foto utama anda.';

  @override
  String get discovery_header_title => 'NOOR';

  @override
  String discovery_label_profilesRemaining(int count) {
    return '$count profil tinggal hari ini';
  }

  @override
  String get discovery_button_sendInterest => 'Hantar Minat';

  @override
  String get discovery_label_interestSent => 'Minat Dihantar ✓';

  @override
  String get discovery_label_outsidePrefs =>
      'Seseorang yang mungkin sesuai dengan anda';

  @override
  String get ceremony_text_blessing =>
      'Semoga Allah memberkati ini dengan kebaikan';

  @override
  String get chat_placeholder_typeMessage => 'Taip mesej…';

  @override
  String chat_label_probation(int hours) {
    return 'Mesej akan dibuka dalam $hours jam.';
  }

  @override
  String get chat_label_subscribeToMessage =>
      'Langgan untuk membuka mesej. Wanita sentiasa menghantar mesej percuma di NOOR.';

  @override
  String get chat_opener_1 =>
      'Assalamu Alaikum! Saya melihat profil anda dan terkesan. Bolehkah saya memperkenalkan diri?';

  @override
  String get chat_opener_2 =>
      'Bismillah. Profil anda menarik perhatian saya. Saya ingin mengenali anda lebih lanjut.';

  @override
  String get chat_opener_3 =>
      'Assalamu Alaikum. Saya percaya kita berkongsi nilai yang sama. Adakah anda terbuka untuk berkenalan?';

  @override
  String get chat_endMatch_title => 'Tamatkan padanan ini';

  @override
  String get chat_endMatch_subtitle =>
      'Pilih mesej yang sopan untuk menutup perbualan ini.';

  @override
  String get chat_endMatch_button => 'Hantar & Tamatkan Padanan';

  @override
  String get chat_matchClosed_banner =>
      'Padanan ini telah ditamatkan dengan hormat.';

  @override
  String get chat_closure_1 =>
      'Assalamu Alaikum. Selepas berfikir dengan teliti, saya rasa ini bukan padanan yang tepat. Saya mendoakan yang terbaik untuk anda. JazakAllah khair.';

  @override
  String get chat_closure_2 =>
      'Assalamu Alaikum. Saya ingin jujur dan hormat kepada anda. Saya rasa kita tidak sesuai tetapi saya berdoa Allah membuka pintu yang lebih baik untuk anda.';

  @override
  String get chat_closure_3 =>
      'Assalamu Alaikum. Selepas pertimbangan yang ikhlas, saya rasa kita tidak serasi. JazakAllah khair atas masa anda.';

  @override
  String get chat_closure_4 =>
      'Assalamu Alaikum. Saya telah merenungkan perbualan kita dan rasa lebih baik menutup padanan ini. Saya sangat menghormati anda.';

  @override
  String get chat_closure_5 =>
      'Assalamu Alaikum. Saya ingin telus daripada hilang begitu sahaja. Saya menghargai masa anda. Semoga Allah memberkati anda.';

  @override
  String get filter_label_motherTongue => 'Bahasa Ibunda';

  @override
  String get filter_label_community => 'Komuniti / Biradari';

  @override
  String get filter_label_livingExpectation =>
      'Tempat Tinggal Selepas Berkahwin';

  @override
  String get subscription_title => 'Buka NOOR';

  @override
  String get subscription_subtitle =>
      'Wanita menghantar mesej percuma. Lelaki melanggan untuk berhubung.';

  @override
  String subscription_button_monthly(String price) {
    return 'Langgan — $price/bulan';
  }

  @override
  String get subscription_label_bestValue => 'Tawaran Terbaik';

  @override
  String profile_label_completeness(int percent) {
    return 'Profil $percent% lengkap';
  }

  @override
  String get profile_nudge_completeness =>
      'Profil dengan 80%+ kelengkapan menerima 3× lebih banyak minat.';

  @override
  String get interests_tab_received => 'Diterima';

  @override
  String get interests_tab_sent => 'Dihantar';

  @override
  String get interests_button_accept => 'Terima';

  @override
  String get interests_button_decline => 'Tolak';

  @override
  String get settings_title => 'Tetapan';

  @override
  String get settings_section_account => 'Akaun';

  @override
  String get settings_section_safety => 'Keselamatan';

  @override
  String get settings_section_app => 'Aplikasi';

  @override
  String get settings_section_legal => 'Undang-undang';

  @override
  String get settings_section_dangerZone => 'Zon Bahaya';

  @override
  String get settings_button_deleteAccount => 'Padam Akaun';

  @override
  String get settings_label_deleteGrace =>
      'Profil anda akan disembunyikan dengan serta-merta. Data anda akan dipadam secara kekal selepas 30 hari.';

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
