// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Indonesian (`id`).
class AppLocalizationsId extends AppLocalizations {
  AppLocalizationsId([String locale = 'id']) : super(locale);

  @override
  String get appName => 'NOOR';

  @override
  String get appTagline => 'Mulai dengan bismillah';

  @override
  String get common_button_next => 'Berikutnya';

  @override
  String get common_button_back => 'Kembali';

  @override
  String get common_button_skip => 'Lewati';

  @override
  String get common_button_save => 'Simpan';

  @override
  String get common_button_cancel => 'Batal';

  @override
  String get common_button_submit => 'Kirim';

  @override
  String get common_button_done => 'Selesai';

  @override
  String get common_button_retry => 'Coba Lagi';

  @override
  String get common_label_optional => 'Opsional';

  @override
  String get common_error_generic => 'Terjadi kesalahan. Silakan coba lagi.';

  @override
  String get common_error_noInternet => 'Tidak ada koneksi internet.';

  @override
  String get splash_button_createProfile => 'Buat Profil';

  @override
  String get splash_button_signIn => 'Masuk';

  @override
  String get legal_title => 'Sebelum Anda mulai';

  @override
  String get legal_checkbox_age =>
      'Saya mengonfirmasi bahwa saya berusia 18 tahun atau lebih';

  @override
  String get legal_checkbox_terms =>
      'Saya menyetujui Ketentuan Layanan dan Kebijakan Privasi';

  @override
  String get legal_button_continue => 'Lanjutkan';

  @override
  String get auth_label_phoneNumber => 'Nomor Telepon';

  @override
  String get auth_hint_phoneNumber => 'Masukkan nomor telepon Anda';

  @override
  String get auth_button_sendOtp => 'Kirim Kode Verifikasi';

  @override
  String get auth_label_enterOtp => 'Masukkan kode 6 digit yang dikirim ke';

  @override
  String get auth_button_verifyOtp => 'Verifikasi';

  @override
  String get auth_button_resendOtp => 'Kirim Ulang Kode';

  @override
  String auth_label_resendIn(int seconds) {
    return 'Kirim ulang dalam ${seconds}d';
  }

  @override
  String onboarding_label_step(int current, int total) {
    return 'Langkah $current dari $total';
  }

  @override
  String get onboarding_profileForWhom_title => 'Profil ini untuk siapa?';

  @override
  String get onboarding_profileForWhom_myself => 'Diri sendiri';

  @override
  String get onboarding_profileForWhom_myselfSub =>
      'Saya mencari pasangan hidup';

  @override
  String get onboarding_profileForWhom_guardian => 'Putra atau putri saya';

  @override
  String get onboarding_profileForWhom_guardianSub =>
      'Saya adalah orang tua atau wali';

  @override
  String get onboarding_profileForWhom_sibling => 'Saudara saya';

  @override
  String get onboarding_profileForWhom_siblingSub =>
      'Saya membantu saudara saya mencari pasangan';

  @override
  String get onboarding_profileForWhom_ward => 'Orang yang saya walikan';

  @override
  String get onboarding_profileForWhom_wardSub =>
      'Saya wali yang mengelola profil ini';

  @override
  String get onboarding_basicIdentity_title => 'Ceritakan tentang diri Anda';

  @override
  String get onboarding_label_firstName => 'Nama Depan';

  @override
  String get onboarding_label_lastName => 'Nama Belakang';

  @override
  String get onboarding_label_dateOfBirth => 'Tanggal Lahir';

  @override
  String get onboarding_label_gender => 'Jenis Kelamin';

  @override
  String get onboarding_label_male => 'Laki-laki';

  @override
  String get onboarding_label_female => 'Perempuan';

  @override
  String get onboarding_label_city => 'Kota';

  @override
  String get onboarding_hint_searchCity => 'Cari kota Anda…';

  @override
  String get onboarding_error_under18 =>
      'NOOR untuk mereka yang berusia 18 tahun ke atas.';

  @override
  String get onboarding_islamicIdentity_title => 'Identitas Islam Anda';

  @override
  String get onboarding_label_sect => 'Mazhab';

  @override
  String get onboarding_label_sunni => 'Sunni';

  @override
  String get onboarding_label_shia => 'Syiah';

  @override
  String get onboarding_label_preferNotToSay => 'Tidak ingin menjawab';

  @override
  String get onboarding_label_deenLevel => 'Tingkat Keagamaan';

  @override
  String get onboarding_label_practicing => 'Taat';

  @override
  String get onboarding_tooltip_practicing =>
      'Menjalankan lima rukun, shalat teratur, gaya hidup halal';

  @override
  String get onboarding_label_moderate => 'Moderat';

  @override
  String get onboarding_tooltip_moderate =>
      'Menghargai prinsip Islam, shalat teratur tapi tidak selalu';

  @override
  String get onboarding_label_cultural => 'Muslim Kultural';

  @override
  String get onboarding_tooltip_cultural =>
      'Mengidentifikasi diri sebagai Muslim, merayakan hari besar, mungkin tidak shalat teratur';

  @override
  String get onboarding_label_praysFiveDaily =>
      'Saya shalat lima waktu setiap hari';

  @override
  String get onboarding_label_community => 'Komunitas / biradari Anda';

  @override
  String get onboarding_label_community_parent => 'Komunitas / biradari mereka';

  @override
  String get onboarding_label_motherTongue => 'Bahasa ibu';

  @override
  String get onboarding_label_diet => 'Diet';

  @override
  String get onboarding_diet_zabihaStrict => 'Zabiha ketat';

  @override
  String get onboarding_diet_halalOnly => 'Halal saja';

  @override
  String get onboarding_diet_eatsAnything => 'Makan apa saja yang halal';

  @override
  String get onboarding_diet_vegetarian => 'Vegetarian';

  @override
  String get onboarding_diet_vegan => 'Vegan';

  @override
  String get onboarding_label_smoking => 'Merokok';

  @override
  String get onboarding_label_vaping => 'Vaping / Rokok elektrik';

  @override
  String get onboarding_label_hookah => 'Hookah / Shisha';

  @override
  String get onboarding_habit_never => 'Tidak pernah';

  @override
  String get onboarding_habit_occasionally => 'Kadang-kadang';

  @override
  String get onboarding_habit_frequently => 'Sering';

  @override
  String get onboarding_habit_preferNotToSay => 'Tidak ingin menjawab';

  @override
  String get onboarding_label_livingExpectation =>
      'Ekspektasi tempat tinggal setelah menikah';

  @override
  String get onboarding_living_withInlaws => 'Bersama Mertua';

  @override
  String get onboarding_living_withInlawsSub =>
      'Saya berharap tinggal bersama keluarga pasangan atau keluarga sendiri.';

  @override
  String get onboarding_living_separate => 'Rumah Terpisah';

  @override
  String get onboarding_living_separateSub =>
      'Saya lebih suka memiliki rumah sendiri yang mandiri.';

  @override
  String get onboarding_living_openToDiscussion => 'Terbuka untuk Diskusi';

  @override
  String get onboarding_living_openToDiscussionSub =>
      'Saya fleksibel dan senang mendiskusikan apa yang cocok untuk kami berdua.';

  @override
  String get onboarding_label_preferredLiving =>
      'Preferensi pengaturan tempat tinggal';

  @override
  String get onboarding_preferredLiving_noPreference => 'Tidak Ada Preferensi';

  @override
  String get copy_prayer_self => 'Apakah Anda shalat lima waktu setiap hari?';

  @override
  String get copy_prayer_parent =>
      'Apakah anak Anda shalat lima waktu setiap hari?';

  @override
  String get copy_prayer_sibling =>
      'Apakah saudara Anda shalat lima waktu setiap hari?';

  @override
  String get copy_hijab_self => 'Apakah Anda memakai hijab?';

  @override
  String get copy_hijab_parent => 'Apakah putri Anda memakai hijab?';

  @override
  String get copy_hijab_sibling => 'Apakah saudari Anda memakai hijab?';

  @override
  String get copy_beard_self => 'Apakah Anda berjenggot?';

  @override
  String get copy_beard_parent => 'Apakah putra Anda berjenggot?';

  @override
  String get copy_beard_sibling => 'Apakah saudara laki-laki Anda berjenggot?';

  @override
  String get onboarding_background_title => 'Pendidikan & Karir';

  @override
  String get onboarding_label_educationLevel => 'Tingkat Pendidikan';

  @override
  String get onboarding_label_profession => 'Profesi';

  @override
  String get onboarding_hint_profession => 'mis. Insinyur, Guru, Dokter';

  @override
  String get onboarding_about_title => 'Tentang diri Anda';

  @override
  String get onboarding_hint_bio =>
      'Jelaskan diri Anda dengan jujur dan bermartabat.';

  @override
  String onboarding_label_bioCount(int count) {
    return '$count/300';
  }

  @override
  String get onboarding_error_bioContactInfo =>
      'Harap hapus informasi kontak dari bio Anda.';

  @override
  String get onboarding_photo_title => 'Tambahkan foto Anda';

  @override
  String get onboarding_photo_subtitle =>
      'Minimal satu foto diperlukan. Foto utama harus menunjukkan wajah Anda dengan jelas.';

  @override
  String get onboarding_photo_verifySelfie => 'Selfie Verifikasi';

  @override
  String get onboarding_photo_verifySelfieHint =>
      'Ambil foto langsung untuk memverifikasi identitas Anda';

  @override
  String get onboarding_error_noFace =>
      'Silakan gunakan foto di mana wajah Anda terlihat jelas.';

  @override
  String get onboarding_error_multipleFaces =>
      'Foto grup tidak bisa menjadi foto utama Anda.';

  @override
  String get discovery_header_title => 'NOOR';

  @override
  String discovery_label_profilesRemaining(int count) {
    return '$count profil tersisa hari ini';
  }

  @override
  String get discovery_button_sendInterest => 'Kirim Ketertarikan';

  @override
  String get discovery_label_interestSent => 'Ketertarikan Terkirim ✓';

  @override
  String get discovery_label_outsidePrefs =>
      'Seseorang yang mungkin cocok dengan Anda';

  @override
  String get ceremony_text_blessing =>
      'Semoga Allah memberkahi ini dengan kebaikan';

  @override
  String get chat_placeholder_typeMessage => 'Ketik pesan…';

  @override
  String chat_label_probation(int hours) {
    return 'Pesan akan terbuka dalam $hours jam.';
  }

  @override
  String get chat_label_subscribeToMessage =>
      'Berlangganan untuk membuka pesan. Wanita selalu mengirim pesan gratis di NOOR.';

  @override
  String get chat_opener_1 =>
      'Assalamu Alaikum! Saya melihat profil Anda dan terkesan. Bolehkah saya memperkenalkan diri?';

  @override
  String get chat_opener_2 =>
      'Bismillah. Profil Anda menarik perhatian saya. Saya ingin tahu lebih banyak tentang Anda.';

  @override
  String get chat_opener_3 =>
      'Assalamu Alaikum. Saya yakin kita memiliki nilai yang sama. Apakah Anda terbuka untuk saling mengenal?';

  @override
  String get chat_endMatch_title => 'Akhiri kecocokan ini';

  @override
  String get chat_endMatch_subtitle =>
      'Pilih pesan yang sopan untuk menutup percakapan ini.';

  @override
  String get chat_endMatch_button => 'Kirim & Akhiri Kecocokan';

  @override
  String get chat_matchClosed_banner =>
      'Kecocokan ini telah ditutup dengan hormat.';

  @override
  String get chat_closure_1 =>
      'Assalamu Alaikum. Setelah berpikir matang, saya merasa ini bukan kecocokan yang tepat. Saya mendoakan yang terbaik untuk Anda. JazakAllah khair.';

  @override
  String get chat_closure_2 =>
      'Assalamu Alaikum. Saya ingin jujur dan hormat kepada Anda. Saya rasa kita tidak cocok tapi saya berdoa Allah membuka pintu yang lebih baik untuk Anda.';

  @override
  String get chat_closure_3 =>
      'Assalamu Alaikum. Setelah pertimbangan yang tulus, saya merasa kita tidak cocok. JazakAllah khair atas waktu Anda.';

  @override
  String get chat_closure_4 =>
      'Assalamu Alaikum. Saya telah merenung dan merasa lebih baik menutup kecocokan ini. Saya sangat menghormati Anda.';

  @override
  String get chat_closure_5 =>
      'Assalamu Alaikum. Saya ingin transparan daripada menghilang. Saya menghargai waktu Anda. Semoga Allah memberkahi Anda.';

  @override
  String get filter_label_motherTongue => 'Bahasa Ibu';

  @override
  String get filter_label_community => 'Komunitas / Biradari';

  @override
  String get filter_label_livingExpectation => 'Tempat Tinggal Setelah Menikah';

  @override
  String get subscription_title => 'Buka NOOR';

  @override
  String get subscription_subtitle =>
      'Wanita mengirim pesan gratis. Pria berlangganan untuk terhubung.';

  @override
  String subscription_button_monthly(String price) {
    return 'Berlangganan — $price/bulan';
  }

  @override
  String get subscription_label_bestValue => 'Penawaran Terbaik';

  @override
  String profile_label_completeness(int percent) {
    return 'Profil $percent% lengkap';
  }

  @override
  String get profile_nudge_completeness =>
      'Profil dengan 80%+ kelengkapan menerima 3× lebih banyak ketertarikan.';

  @override
  String get interests_tab_received => 'Diterima';

  @override
  String get interests_tab_sent => 'Terkirim';

  @override
  String get interests_button_accept => 'Terima';

  @override
  String get interests_button_decline => 'Tolak';

  @override
  String get settings_title => 'Pengaturan';

  @override
  String get settings_section_account => 'Akun';

  @override
  String get settings_section_safety => 'Keamanan';

  @override
  String get settings_section_app => 'Aplikasi';

  @override
  String get settings_section_legal => 'Hukum';

  @override
  String get settings_section_dangerZone => 'Zona Bahaya';

  @override
  String get settings_button_deleteAccount => 'Hapus Akun';

  @override
  String get settings_label_deleteGrace =>
      'Profil Anda akan segera disembunyikan. Data Anda akan dihapus secara permanen setelah 30 hari.';
}
