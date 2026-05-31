// lib/core/data/country_communities_data.dart
// ============================================================
// NOOR — Muslim Communities by Country
//
// Covers 85 countries. Designed to be replaced by a Supabase
// query (SELECT communities FROM country_config WHERE iso2 = ?)
// when backend is wired — no other code changes needed.
//
// Data principle:
//   • Biradari/caste communities for South Asia (user expectation)
//   • Ethnic/tribal communities for MENA and Africa
//   • Diaspora community blends for Western countries
//   • "Prefer not to say" + "Other" always at end
//   • No offensive or derogatory community labels
//
// FUTURE: Move to Supabase table `country_config.communities` (jsonb)
// and replace forCountry() with a Supabase .select() call.
// ============================================================

class CountryCommunityData {
  CountryCommunityData._();

  static const _default = [
    'Arab', 'South Asian', 'African', 'Malay', 'Turkish',
    'Persian', 'Other', 'Prefer not to say',
  ];

  static List<String> forCountry(String rawIso2) {
    final iso2 = rawIso2.toUpperCase();
    return _data[iso2] ?? _default;
  }

  // ── Community map ─────────────────────────────────────────
  static const Map<String, List<String>> _data = {

    // ═══════════════ SOUTH ASIA ══════════════════════════════

    'IN': [
      // North Indian / UP / Bihar
      'Syed', 'Sheikh', 'Qureshi', 'Ansari', 'Khan',
      'Pathan / Pashto', 'Mughal', 'Mirza', 'Siddiqui', 'Alvi',
      // Rajput & related
      'Rajput', 'Taga', 'Tyagi',
      // Occupational & trade
      'Julaaha (Ansari)', 'Kasai / Qassab', 'Darzi', 'Nai / Hajjam',
      'Dhobi / Hawari', 'Lohar / Saifi', 'Teli', 'Fakir',
      // West India
      'Memon', 'Bohra (Dawoodi)', 'Bohra (Sulaimani)',
      'Khoja (Ismaili)', 'Khoja (Ithna Ashari)',
      'Kutchi Memon', 'Kathiawadi Memon',
      // South India
      'Mappila / Moplah', 'Labbai', 'Rowther', 'Marakkayar',
      'Lebbai', 'Deccan Muslim',
      // East India
      'Bengali Muslim', 'Bihari Muslim',
      // Dehlavi / Delhi ashraf
      'Dehlavi', 'Farooqi', 'Hashmi', 'Naqvi', 'Rizvi', 'Zaidi',
      // Scholarly / Sufi lineage
      'Nomani', 'Thanvi', 'Chishti',
      // Other
      'Kashmiri Muslim', 'Sindhi Muslim', 'Other', 'Prefer not to say',
    ],

    'PK': [
      // Ashraf / status
      'Syed', 'Qureshi', 'Sheikh', 'Siddiqui', 'Alvi', 'Hashmi',
      'Naqvi', 'Rizvi', 'Farooqi',
      // Pathan / Pashtun
      'Pathan / Pashto', 'Yousafzai', 'Afridi', 'Shinwari', 'Mohmand',
      // Punjabi
      'Awan', 'Chaudhry / Chaudhary', 'Rajput',
      'Arain', 'Gujjar', 'Jat', 'Butt', 'Virk',
      'Dogar', 'Langah', 'Wattoo', 'Tiwana',
      // Sindhi
      'Soomro', 'Bhutto', 'Talpur', 'Chandio', 'Memon (Sindhi)',
      'Khoja (Karachi)',
      // Baloch / Brahui
      'Baloch', 'Marri', 'Bugti', 'Mengal', 'Brahui', 'Rind',
      // Kashmiri
      'Kashmiri',
      // Hazara
      'Hazara',
      // Mohajir
      'Mohajir / Urdu-speaking',
      // Other
      'Gilgiti', 'Chitrali', 'Other', 'Prefer not to say',
    ],

    'BD': [
      'Syed', 'Sheikh', 'Chowdhury', 'Bhuiyan', 'Khan',
      'Talukdar', 'Molla', 'Bepari', 'Hawladar',
      'Sarkar', 'Mandal', 'Majumdar', 'Biswas',
      'Akon', 'Fakir', 'Dhali',
      'Sylheti', 'Chittagonian', 'Bihari Muslim',
      'Rohingya', 'Chakma Muslim',
      'Other', 'Prefer not to say',
    ],

    'LK': [
      'Sri Lankan Moor', 'Malay Muslim', 'Memon (Sri Lanka)',
      'Tamil Muslim', 'Other', 'Prefer not to say',
    ],

    'MV': [
      'Maldivian', 'Other', 'Prefer not to say',
    ],

    'AF': [
      'Pashtun / Pathan', 'Tajik', 'Hazara', 'Uzbek',
      'Aimak', 'Turkmen', 'Baloch', 'Pashayi',
      'Nuristani', 'Gujjar', 'Arab', 'Brahui',
      'Other', 'Prefer not to say',
    ],

    // ═══════════════ MENA ════════════════════════════════════

    'SA': [
      'Hejazi Arab', 'Najdi Arab', 'Gulf Arab',
      'Asiri', 'Tihamawi', 'Sharawi',
      'Yemeni (resident)', 'Egyptian (resident)',
      'South Asian (resident)',
      'Other', 'Prefer not to say',
    ],

    'AE': [
      'Emirati', 'Abu Dhabi', 'Dubai', 'Sharjah', 'Ajman',
      'Ras Al Khaimah', 'Fujairah',
      'Balochi (UAE resident)', 'Arab expatriate',
      'South Asian expatriate', 'Egyptian expatriate',
      'Other', 'Prefer not to say',
    ],

    'QA': [
      'Qatari', 'Gulf Arab', 'Arab expatriate',
      'South Asian expatriate', 'Egyptian expatriate',
      'Other', 'Prefer not to say',
    ],

    'KW': [
      'Kuwaiti', 'Bidoon', 'Gulf Arab',
      'Arab expatriate', 'South Asian expatriate',
      'Other', 'Prefer not to say',
    ],

    'OM': [
      'Omani Arab', 'Balochi', 'Zanzibari Omani',
      'South Asian (resident)', 'Other', 'Prefer not to say',
    ],

    'BH': [
      'Bahraini Sunni', 'Bahraini Shia (Baharna)',
      'Ajam (Persian-origin)', 'Arab expatriate',
      'South Asian expatriate', 'Other', 'Prefer not to say',
    ],

    'YE': [
      'Zaydi (Houthi region)', 'Shafi\'i Yemeni',
      'Hadhrami', 'Akhdam', 'South Arabian',
      'Other', 'Prefer not to say',
    ],

    'IQ': [
      'Arab Sunni', 'Arab Shia', 'Kurdish Sunni',
      'Turkmen Sunni', 'Turkmen Shia',
      'Shabak', 'Yezidi (minority)', 'Mandaean',
      'Other', 'Prefer not to say',
    ],

    'SY': [
      'Syrian Arab', 'Kurdish', 'Alawite',
      'Druze', 'Circassian', 'Turkmen',
      'Assyrian', 'Other', 'Prefer not to say',
    ],

    'JO': [
      'East Jordanian', 'Palestinian Jordanian',
      'Circassian', 'Chechen', 'Iraqi (resident)',
      'Syrian (resident)', 'Other', 'Prefer not to say',
    ],

    'LB': [
      'Lebanese Sunni', 'Lebanese Shia (Amal/Hezbollah region)',
      'Lebanese Druze', 'Palestinian (camp resident)',
      'Alawite', 'Maronite background',
      'Other', 'Prefer not to say',
    ],

    'PS': [
      'Palestinian Arab', 'Bedouin', 'Other', 'Prefer not to say',
    ],

    'EG': [
      'Egyptian Arab', 'Saidi (Upper Egypt)',
      'Alexandrian', 'Nubian', 'Sinai Bedouin',
      'Bedouin (Matruh)', 'Coptic background',
      'Other', 'Prefer not to say',
    ],

    'LY': [
      'Libyan Arab', 'Berber (Amazigh)', 'Tuareg',
      'Tebu', 'Other', 'Prefer not to say',
    ],

    'TN': [
      'Tunisian Arab', 'Berber (Amazigh)', 'Andalusian descent',
      'Jewish-Muslim convert background',
      'Other', 'Prefer not to say',
    ],

    'DZ': [
      'Algerian Arab', 'Kabyle (Berber)', 'Chaoui (Berber)',
      'Tuareg', 'Mozabite', 'Shawi',
      'Other', 'Prefer not to say',
    ],

    'MA': [
      'Moroccan Arab', 'Amazigh (Berber)', 'Riffian',
      'Soussi', 'Saharan / Sahrawi',
      'Andalusian descent', 'Gnawa',
      'Other', 'Prefer not to say',
    ],

    'MR': [
      'Bidan (White Moor)', 'Haratin (Black Moor)',
      'Pulaar / Fula', 'Soninke', 'Wolof',
      'Other', 'Prefer not to say',
    ],

    'IR': [
      'Persian', 'Azeri', 'Kurdish', 'Lor',
      'Balochi', 'Turkmen', 'Arab (Ahvazi)',
      'Gilaki', 'Mazandarani', 'Talysh',
      'Other', 'Prefer not to say',
    ],

    // ═══════════════ CENTRAL / INNER ASIA ════════════════════

    'TR': [
      'Turkish', 'Kurdish', 'Alevi Kurdish', 'Laz',
      'Circassian', 'Georgian', 'Pomak',
      'Azerbaijani', 'Roma', 'Other', 'Prefer not to say',
    ],

    'KZ': [
      'Kazakh', 'Russian (Muslim background)',
      'Uzbek', 'Uyghur', 'Kyrgyz',
      'Other', 'Prefer not to say',
    ],

    'UZ': [
      'Uzbek', 'Tajik', 'Karakalpak',
      'Kazakh', 'Russian background',
      'Other', 'Prefer not to say',
    ],

    'TJ': [
      'Tajik', 'Uzbek', 'Pamiri',
      'Yagnabi', 'Other', 'Prefer not to say',
    ],

    'KG': [
      'Kyrgyz', 'Uzbek', 'Dungan (Hui)',
      'Russian background', 'Other', 'Prefer not to say',
    ],

    'TM': [
      'Turkmen', 'Uzbek', 'Kazakh',
      'Other', 'Prefer not to say',
    ],

    'AZ': [
      'Azerbaijani', 'Lezgin', 'Talysh',
      'Avar', 'Tsakhur', 'Other', 'Prefer not to say',
    ],

    // ═══════════════ SOUTHEAST ASIA ══════════════════════════

    'ID': [
      'Javanese', 'Sundanese', 'Malay (Sumatera)',
      'Madurese', 'Minangkabau', 'Bugis',
      'Makassarese', 'Banjar', 'Acehnese',
      'Betawi', 'Batak (Muslim)', 'Sasak',
      'Gorontalo', 'Bima', 'Other', 'Prefer not to say',
    ],

    'MY': [
      'Malay', 'Javanese (Malaysian)',
      'Banjar', 'Bugis (Malaysian)',
      'Bajau', 'Champa Malay',
      'Indian Muslim (Mamak)', 'Arab Malaysian',
      'Other', 'Prefer not to say',
    ],

    'SG': [
      'Malay Singaporean', 'Javanese Singaporean',
      'Boyanese', 'Arab Singaporean',
      'Indian Muslim (Singaporean)',
      'Other', 'Prefer not to say',
    ],

    'PH': [
      'Maranao', 'Maguindanao', 'Tausug',
      'Sama-Bajau', 'Yakan', 'Kalibugan',
      'Other', 'Prefer not to say',
    ],

    'TH': [
      'Malay Muslim (Patani)', 'Thai Muslim',
      'Cham Muslim', 'Chinese Muslim (Haw)',
      'Other', 'Prefer not to say',
    ],

    'MM': [
      'Rohingya', 'Bamar Muslim', 'Indian Muslim (Burmese)',
      'Kaman', 'Chinese Muslim (Panthay)',
      'Other', 'Prefer not to say',
    ],

    // ═══════════════ SUB-SAHARAN AFRICA ══════════════════════

    'NG': [
      'Hausa', 'Fulani / Fula', 'Kanuri',
      'Yoruba Muslim', 'Nupe', 'Tiv Muslim',
      'Igbo Muslim', 'Ebira', 'Gbagyi',
      'Other', 'Prefer not to say',
    ],

    'ET': [
      'Oromo Muslim', 'Somali Ethiopian',
      'Afar', 'Harari', 'Argobba',
      'Other', 'Prefer not to say',
    ],

    'SO': [
      'Somali (Hawiye)', 'Somali (Darod)',
      'Somali (Dir)', 'Somali (Rahanweyn)',
      'Somali (Issaq)',
      'Other', 'Prefer not to say',
    ],

    'SD': [
      'Sudanese Arab', 'Nubian',
      'Fur', 'Zaghawa', 'Masalit',
      'Beja', 'Nuba Muslim', 'Dinka Muslim',
      'Other', 'Prefer not to say',
    ],

    'ML': [
      'Mandé (Bambara Muslim)', 'Fulani (Peul)',
      'Tuareg', 'Songhai', 'Dogon Muslim',
      'Bobo Muslim', 'Other', 'Prefer not to say',
    ],

    'SN': [
      'Wolof', 'Fula / Fulbe', 'Serer Muslim',
      'Mandinka', 'Jola Muslim', 'Soninke',
      'Lebou', 'Other', 'Prefer not to say',
    ],

    'GH': [
      'Akan Muslim', 'Dagomba', 'Mamprusi',
      'Gonja', 'Hausa (Ghana)', 'Wangara',
      'Other', 'Prefer not to say',
    ],

    'CI': [
      'Dioula', 'Malinké', 'Senoufo Muslim',
      'Fulani (Côte d\'Ivoire)', 'Other', 'Prefer not to say',
    ],

    'TZ': [
      'Shirazi (Zanzibar)', 'Yao', 'Sukuma Muslim',
      'Zaramo', 'Arab Tanzanian',
      'Comorian', 'Indian Muslim (Tanzanian)',
      'Other', 'Prefer not to say',
    ],

    'KE': [
      'Somali Kenyan', 'Swahili', 'Oromo Kenyan',
      'Arab Kenyan', 'Indian Muslim (Kenyan)',
      'Bajuni', 'Other', 'Prefer not to say',
    ],

    'MZ': [
      'Makhuwa Muslim', 'Yao', 'Comorian (Mozambique)',
      'Other', 'Prefer not to say',
    ],

    'CM': [
      'Fulbe (Fula)', 'Arab Choa', 'Kanuri',
      'Kotoko', 'Other', 'Prefer not to say',
    ],

    // ═══════════════ WESTERN EUROPE ══════════════════════════

    'GB': [
      // South Asian diaspora (largest Muslim group in UK)
      'Pakistani British', 'Bangladeshi British',
      'Indian Muslim British', 'Sri Lankan Muslim British',
      // Arab diaspora
      'Arab British', 'Somali British', 'Yemeni British',
      'Libyan British', 'Algerian British', 'Moroccan British',
      'Egyptian British', 'Iraqi British', 'Syrian British',
      // Turkish / Kurdish
      'Turkish British', 'Kurdish British',
      // West African
      'Nigerian British', 'Ghanaian British',
      // Converts
      'British Convert',
      'Other', 'Prefer not to say',
    ],

    'FR': [
      'Algerian French', 'Moroccan French', 'Tunisian French',
      'Turkish French', 'West African French',
      'Senegalese French', 'Malian French',
      'French Convert',
      'Other', 'Prefer not to say',
    ],

    'DE': [
      'Turkish German', 'Kurdish German',
      'Arab German', 'Afghan German',
      'Bosnian German', 'Pakistani German',
      'Iranian German', 'German Convert',
      'Other', 'Prefer not to say',
    ],

    'NL': [
      'Turkish Dutch', 'Moroccan Dutch',
      'Surinamese Muslim Dutch', 'Somali Dutch',
      'Dutch Convert',
      'Other', 'Prefer not to say',
    ],

    'BE': [
      'Moroccan Belgian', 'Turkish Belgian',
      'Algerian Belgian', 'Belgian Convert',
      'Other', 'Prefer not to say',
    ],

    'SE': [
      'Somali Swedish', 'Iraqi Swedish', 'Bosnian Swedish',
      'Turkish Swedish', 'Iranian Swedish',
      'Afghan Swedish', 'Syrian Swedish',
      'Swedish Convert',
      'Other', 'Prefer not to say',
    ],

    'NO': [
      'Pakistani Norwegian', 'Somali Norwegian',
      'Iraqi Norwegian', 'Moroccan Norwegian',
      'Norwegian Convert',
      'Other', 'Prefer not to say',
    ],

    'IT': [
      'Moroccan Italian', 'Tunisian Italian',
      'Albanian Italian', 'Bangladeshi Italian',
      'Senegalese Italian', 'Egyptian Italian',
      'Italian Convert',
      'Other', 'Prefer not to say',
    ],

    'ES': [
      'Moroccan Spanish', 'Algerian Spanish',
      'Senegalese Spanish', 'Spanish Convert',
      'Other', 'Prefer not to say',
    ],

    // ═══════════════ NORTH AMERICA ═══════════════════════════

    'US': [
      // South Asian
      'Pakistani American', 'Indian Muslim American',
      'Bangladeshi American', 'Afghan American',
      // Arab
      'Arab American', 'Palestinian American',
      'Egyptian American', 'Yemeni American',
      'Lebanese American', 'Syrian American',
      'Iraqi American', 'Jordanian American',
      // African
      'Somali American', 'Nigerian American',
      'Ethiopian American',
      // African American
      'African American Muslim (NOI background)',
      'African American Muslim (Sunni)',
      // Southeast Asian
      'Indonesian American', 'Malaysian American',
      // Iranian
      'Iranian American',
      // Converts
      'American Convert',
      'Other', 'Prefer not to say',
    ],

    'CA': [
      'Pakistani Canadian', 'Arab Canadian',
      'Somali Canadian', 'Iranian Canadian',
      'Afghan Canadian', 'Indian Muslim Canadian',
      'Bangladeshi Canadian', 'Egyptian Canadian',
      'Canadian Convert',
      'Other', 'Prefer not to say',
    ],

    // ═══════════════ OCEANIA ═════════════════════════════════

    'AU': [
      'Lebanese Australian', 'Pakistani Australian',
      'Turkish Australian', 'Indonesian Australian',
      'Bangladeshi Australian', 'Bosnian Australian',
      'Somali Australian', 'Afghan Australian',
      'Egyptian Australian', 'Indian Muslim Australian',
      'Australian Convert',
      'Other', 'Prefer not to say',
    ],

    'NZ': [
      'Somali New Zealander', 'Fijian Muslim',
      'Indian Muslim New Zealander', 'Arab New Zealander',
      'New Zealand Convert',
      'Other', 'Prefer not to say',
    ],

    // ═══════════════ BALKANS / EASTERN EUROPE ════════════════

    'BA': [
      'Bosniak', 'Bosanski', 'Other', 'Prefer not to say',
    ],

    'AL': [
      'Albanian Muslim', 'Bektashi',
      'Other', 'Prefer not to say',
    ],

    'XK': [
      'Kosovar Albanian', 'Kosovar Bosniak',
      'Kosovar Roma Muslim', 'Other', 'Prefer not to say',
    ],

    'MK': [
      'Macedonian Albanian', 'Macedonian Turk',
      'Macedonian Roma Muslim', 'Other', 'Prefer not to say',
    ],

    'ME': [
      'Bosniak Montenegrin', 'Albanian Montenegrin',
      'Other', 'Prefer not to say',
    ],

    // ═══════════════ OTHER ════════════════════════════════════

    'RU': [
      'Tatar', 'Bashkir', 'Chechen', 'Ingush',
      'Avar', 'Dargin', 'Kumyk', 'Lezgin',
      'Kabardian', 'Karachay', 'Nogai',
      'Azerbaijani (Russian)', 'Other', 'Prefer not to say',
    ],

    'CN': [
      'Hui', 'Uyghur', 'Kazakh (Chinese)', 'Kyrgyz (Chinese)',
      'Tajik (Chinese)', 'Uzbek (Chinese)', 'Dongxiang',
      'Salar', 'Bao\'an', 'Tatar (Chinese)',
      'Other', 'Prefer not to say',
    ],
  };
}
