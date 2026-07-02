// lib/core/data/country_communities_data.dart
// ============================================================
// MITHAQ — Muslim Communities by Country
//
// Covers all 198 supported countries through curated, regional, or
// country-specific options. Supabase can later supply editorial updates.
//
// Data principle:
//   • Biradari/caste communities for South Asia (user expectation)
//   • Ethnic/tribal communities for MENA and Africa
//   • Diaspora community blends for Western countries
//   • "Prefer not to say" + "Other" always at end
//   • No offensive or derogatory community labels
// ============================================================

import 'country_data.dart';

class CountryCommunityData {
  CountryCommunityData._();

  /// Synchronous: Tier 1 (curated) → Tier 2 (regional) → country-specific.
  static List<String> forCountry(String rawIso2) {
    final iso2 = rawIso2.toUpperCase();

    // Tier 1: curated list
    if (_data.containsKey(iso2)) return _data[iso2]!;

    // Tier 2: regional cluster
    for (final entry in _regionalClusters.entries) {
      if (entry.value.contains(iso2)) return entry.key;
    }

    return _countrySpecificFallback(iso2);
  }

  /// Async-compatible form used by callers that previously awaited enrichment.
  static Future<List<String>> forCountryAsync(String rawIso2) async {
    final iso2 = rawIso2.toUpperCase();
    if (_data.containsKey(iso2)) return _data[iso2]!;
    for (final entry in _regionalClusters.entries) {
      if (entry.value.contains(iso2)) return entry.key;
    }

    return _countrySpecificFallback(iso2);
  }

  static List<String> _countrySpecificFallback(String iso2) {
    final countryName = kAllCountries
        .where((country) => country.iso2 == iso2)
        .map((country) => country.name)
        .firstOrNull;
    final label = countryName == null
        ? 'Local Muslim community'
        : '$countryName Muslim community';
    return [label, 'Convert / Revert', 'Other', 'Prefer not to say'];
  }

  // ── Tier 2: Regional clusters for uncurated countries ─────
  static const _regionalClusters = <List<String>, List<String>>{
    // Pacific Islands
    [
      'Pacific Islander Muslim',
      'Fijian Muslim',
      'Convert / Revert',
      'Other',
      'Prefer not to say'
    ]: [
      'PG',
      'SB',
      'VU',
      'NC',
      'PF',
      'WS',
      'TO',
      'KI',
      'TV',
      'NR',
      'PW',
      'FM',
      'MH'
    ],

    // Central America / Caribbean
    [
      'Convert / Revert Muslim',
      'Caribbean Muslim',
      'Arab diaspora',
      'South Asian diaspora',
      'Other',
      'Prefer not to say'
    ]: [
      'CR',
      'PA',
      'NI',
      'HN',
      'GT',
      'SV',
      'BZ',
      'JM',
      'BB',
      'BS',
      'DM',
      'GD',
      'LC',
      'VC',
      'AG',
      'KN',
      'CU',
      'DO',
      'HT'
    ],

    // South America
    [
      'Lebanese diaspora',
      'Syrian diaspora',
      'Palestinian diaspora',
      'South Asian diaspora',
      'Convert / Revert',
      'Other',
      'Prefer not to say'
    ]: ['BR', 'AR', 'CL', 'CO', 'VE', 'EC', 'PY', 'UY', 'BO', 'PE'],

    // Sub-Saharan Africa (uncurated)
    [
      'West African Muslim',
      'East African Muslim',
      'Central African Muslim',
      'Sahel Muslim',
      'Other',
      'Prefer not to say'
    ]: [
      'LR',
      'SL',
      'GW',
      'CV',
      'AO',
      'NA',
      'LS',
      'SZ',
      'RW',
      'BI',
      'CG',
      'CD',
      'CF'
    ],

    // East Asia (small Muslim communities)
    [
      'Chinese Muslim diaspora (Hui)',
      'Uyghur diaspora',
      'Convert / Revert',
      'South Asian diaspora',
      'Other',
      'Prefer not to say'
    ]: ['KP', 'LA'],
  };

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
      'Syed',
      'Sheikh',
      'Chowdhury',
      'Bhuiyan',
      'Khan',
      'Talukdar',
      'Molla',
      'Bepari',
      'Hawladar',
      'Sarkar',
      'Mandal',
      'Majumdar',
      'Biswas',
      'Akon',
      'Fakir',
      'Dhali',
      'Sylheti',
      'Chittagonian',
      'Bihari Muslim',
      'Rohingya',
      'Chakma Muslim',
      'Other',
      'Prefer not to say',
    ],

    'LK': [
      'Sri Lankan Moor',
      'Malay Muslim',
      'Memon (Sri Lanka)',
      'Tamil Muslim',
      'Other',
      'Prefer not to say',
    ],

    'MV': [
      'Maldivian',
      'Other',
      'Prefer not to say',
    ],

    'AF': [
      'Pashtun / Pathan',
      'Tajik',
      'Hazara',
      'Uzbek',
      'Aimak',
      'Turkmen',
      'Baloch',
      'Pashayi',
      'Nuristani',
      'Gujjar',
      'Arab',
      'Brahui',
      'Other',
      'Prefer not to say',
    ],

    // ═══════════════ MENA ════════════════════════════════════

    'SA': [
      'Hejazi Arab',
      'Najdi Arab',
      'Gulf Arab',
      'Asiri',
      'Tihamawi',
      'Sharawi',
      'Yemeni (resident)',
      'Egyptian (resident)',
      'South Asian (resident)',
      'Other',
      'Prefer not to say',
    ],

    'AE': [
      'Emirati',
      'Abu Dhabi',
      'Dubai',
      'Sharjah',
      'Ajman',
      'Ras Al Khaimah',
      'Fujairah',
      'Balochi (UAE resident)',
      'Arab expatriate',
      'South Asian expatriate',
      'Egyptian expatriate',
      'Other',
      'Prefer not to say',
    ],

    'QA': [
      'Qatari',
      'Gulf Arab',
      'Arab expatriate',
      'South Asian expatriate',
      'Egyptian expatriate',
      'Other',
      'Prefer not to say',
    ],

    'KW': [
      'Kuwaiti',
      'Bidoon',
      'Gulf Arab',
      'Arab expatriate',
      'South Asian expatriate',
      'Other',
      'Prefer not to say',
    ],

    'OM': [
      'Omani Arab',
      'Balochi',
      'Zanzibari Omani',
      'South Asian (resident)',
      'Other',
      'Prefer not to say',
    ],

    'BH': [
      'Bahraini Sunni',
      'Bahraini Shia (Baharna)',
      'Ajam (Persian-origin)',
      'Arab expatriate',
      'South Asian expatriate',
      'Other',
      'Prefer not to say',
    ],

    'YE': [
      'Zaydi (Houthi region)',
      'Shafi\'i Yemeni',
      'Hadhrami',
      'Akhdam',
      'South Arabian',
      'Other',
      'Prefer not to say',
    ],

    'IQ': [
      'Arab Sunni',
      'Arab Shia',
      'Kurdish Sunni',
      'Turkmen Sunni',
      'Turkmen Shia',
      'Shabak',
      'Yezidi (minority)',
      'Mandaean',
      'Other',
      'Prefer not to say',
    ],

    'SY': [
      'Syrian Arab',
      'Kurdish',
      'Alawite',
      'Druze',
      'Circassian',
      'Turkmen',
      'Assyrian',
      'Other',
      'Prefer not to say',
    ],

    'JO': [
      'East Jordanian',
      'Palestinian Jordanian',
      'Circassian',
      'Chechen',
      'Iraqi (resident)',
      'Syrian (resident)',
      'Other',
      'Prefer not to say',
    ],

    'LB': [
      'Lebanese Sunni',
      'Lebanese Shia (Amal/Hezbollah region)',
      'Lebanese Druze',
      'Palestinian (camp resident)',
      'Alawite',
      'Maronite background',
      'Other',
      'Prefer not to say',
    ],

    'PS': [
      'Palestinian Arab',
      'Bedouin',
      'Other',
      'Prefer not to say',
    ],

    'EG': [
      'Egyptian Arab',
      'Saidi (Upper Egypt)',
      'Alexandrian',
      'Nubian',
      'Sinai Bedouin',
      'Bedouin (Matruh)',
      'Coptic background',
      'Other',
      'Prefer not to say',
    ],

    'LY': [
      'Libyan Arab',
      'Berber (Amazigh)',
      'Tuareg',
      'Tebu',
      'Other',
      'Prefer not to say',
    ],

    'TN': [
      'Tunisian Arab',
      'Berber (Amazigh)',
      'Andalusian descent',
      'Jewish-Muslim convert background',
      'Other',
      'Prefer not to say',
    ],

    'DZ': [
      'Algerian Arab',
      'Kabyle (Berber)',
      'Chaoui (Berber)',
      'Tuareg',
      'Mozabite',
      'Shawi',
      'Other',
      'Prefer not to say',
    ],

    'MA': [
      'Moroccan Arab',
      'Amazigh (Berber)',
      'Riffian',
      'Soussi',
      'Saharan / Sahrawi',
      'Andalusian descent',
      'Gnawa',
      'Other',
      'Prefer not to say',
    ],

    'MR': [
      'Bidan (White Moor)',
      'Haratin (Black Moor)',
      'Pulaar / Fula',
      'Soninke',
      'Wolof',
      'Other',
      'Prefer not to say',
    ],

    'IR': [
      'Persian',
      'Azeri',
      'Kurdish',
      'Lor',
      'Balochi',
      'Turkmen',
      'Arab (Ahvazi)',
      'Gilaki',
      'Mazandarani',
      'Talysh',
      'Other',
      'Prefer not to say',
    ],

    // ═══════════════ CENTRAL / INNER ASIA ════════════════════

    'TR': [
      'Turkish',
      'Kurdish',
      'Alevi Kurdish',
      'Laz',
      'Circassian',
      'Georgian',
      'Pomak',
      'Azerbaijani',
      'Roma',
      'Other',
      'Prefer not to say',
    ],

    'KZ': [
      'Kazakh',
      'Russian (Muslim background)',
      'Uzbek',
      'Uyghur',
      'Kyrgyz',
      'Other',
      'Prefer not to say',
    ],

    'UZ': [
      'Uzbek',
      'Tajik',
      'Karakalpak',
      'Kazakh',
      'Russian background',
      'Other',
      'Prefer not to say',
    ],

    'TJ': [
      'Tajik',
      'Uzbek',
      'Pamiri',
      'Yagnabi',
      'Other',
      'Prefer not to say',
    ],

    'KG': [
      'Kyrgyz',
      'Uzbek',
      'Dungan (Hui)',
      'Russian background',
      'Other',
      'Prefer not to say',
    ],

    'TM': [
      'Turkmen',
      'Uzbek',
      'Kazakh',
      'Other',
      'Prefer not to say',
    ],

    'AZ': [
      'Azerbaijani',
      'Lezgin',
      'Talysh',
      'Avar',
      'Tsakhur',
      'Other',
      'Prefer not to say',
    ],

    // ═══════════════ SOUTHEAST ASIA ══════════════════════════

    'ID': [
      'Javanese',
      'Sundanese',
      'Malay (Sumatera)',
      'Madurese',
      'Minangkabau',
      'Bugis',
      'Makassarese',
      'Banjar',
      'Acehnese',
      'Betawi',
      'Batak (Muslim)',
      'Sasak',
      'Gorontalo',
      'Bima',
      'Other',
      'Prefer not to say',
    ],

    'MY': [
      'Malay',
      'Javanese (Malaysian)',
      'Banjar',
      'Bugis (Malaysian)',
      'Bajau',
      'Champa Malay',
      'Indian Muslim (Mamak)',
      'Arab Malaysian',
      'Other',
      'Prefer not to say',
    ],

    'SG': [
      'Malay Singaporean',
      'Javanese Singaporean',
      'Boyanese',
      'Arab Singaporean',
      'Indian Muslim (Singaporean)',
      'Other',
      'Prefer not to say',
    ],

    'PH': [
      'Maranao',
      'Maguindanao',
      'Tausug',
      'Sama-Bajau',
      'Yakan',
      'Kalibugan',
      'Other',
      'Prefer not to say',
    ],

    'TH': [
      'Malay Muslim (Patani)',
      'Thai Muslim',
      'Cham Muslim',
      'Chinese Muslim (Haw)',
      'Other',
      'Prefer not to say',
    ],

    'MM': [
      'Rohingya',
      'Bamar Muslim',
      'Indian Muslim (Burmese)',
      'Kaman',
      'Chinese Muslim (Panthay)',
      'Other',
      'Prefer not to say',
    ],

    // ═══════════════ SUB-SAHARAN AFRICA ══════════════════════

    'NG': [
      'Hausa',
      'Fulani / Fula',
      'Kanuri',
      'Yoruba Muslim',
      'Nupe',
      'Tiv Muslim',
      'Igbo Muslim',
      'Ebira',
      'Gbagyi',
      'Other',
      'Prefer not to say',
    ],

    'ET': [
      'Oromo Muslim',
      'Somali Ethiopian',
      'Afar',
      'Harari',
      'Argobba',
      'Other',
      'Prefer not to say',
    ],

    'SO': [
      'Somali (Hawiye)',
      'Somali (Darod)',
      'Somali (Dir)',
      'Somali (Rahanweyn)',
      'Somali (Issaq)',
      'Other',
      'Prefer not to say',
    ],

    'SD': [
      'Sudanese Arab',
      'Nubian',
      'Fur',
      'Zaghawa',
      'Masalit',
      'Beja',
      'Nuba Muslim',
      'Dinka Muslim',
      'Other',
      'Prefer not to say',
    ],

    'ML': [
      'Mandé (Bambara Muslim)',
      'Fulani (Peul)',
      'Tuareg',
      'Songhai',
      'Dogon Muslim',
      'Bobo Muslim',
      'Other',
      'Prefer not to say',
    ],

    'SN': [
      'Wolof',
      'Fula / Fulbe',
      'Serer Muslim',
      'Mandinka',
      'Jola Muslim',
      'Soninke',
      'Lebou',
      'Other',
      'Prefer not to say',
    ],

    'GH': [
      'Akan Muslim',
      'Dagomba',
      'Mamprusi',
      'Gonja',
      'Hausa (Ghana)',
      'Wangara',
      'Other',
      'Prefer not to say',
    ],

    'CI': [
      'Dioula',
      'Malinké',
      'Senoufo Muslim',
      'Fulani (Côte d\'Ivoire)',
      'Other',
      'Prefer not to say',
    ],

    'TZ': [
      'Shirazi (Zanzibar)',
      'Yao',
      'Sukuma Muslim',
      'Zaramo',
      'Arab Tanzanian',
      'Comorian',
      'Indian Muslim (Tanzanian)',
      'Other',
      'Prefer not to say',
    ],

    'KE': [
      'Somali Kenyan',
      'Swahili',
      'Oromo Kenyan',
      'Arab Kenyan',
      'Indian Muslim (Kenyan)',
      'Bajuni',
      'Other',
      'Prefer not to say',
    ],

    'MZ': [
      'Makhuwa Muslim',
      'Yao',
      'Comorian (Mozambique)',
      'Other',
      'Prefer not to say',
    ],

    'CM': [
      'Fulbe (Fula)',
      'Arab Choa',
      'Kanuri',
      'Kotoko',
      'Other',
      'Prefer not to say',
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
      'Algerian French',
      'Moroccan French',
      'Tunisian French',
      'Turkish French',
      'West African French',
      'Senegalese French',
      'Malian French',
      'French Convert',
      'Other',
      'Prefer not to say',
    ],

    'DE': [
      'Turkish German',
      'Kurdish German',
      'Arab German',
      'Afghan German',
      'Bosnian German',
      'Pakistani German',
      'Iranian German',
      'German Convert',
      'Other',
      'Prefer not to say',
    ],

    'NL': [
      'Turkish Dutch',
      'Moroccan Dutch',
      'Surinamese Muslim Dutch',
      'Somali Dutch',
      'Dutch Convert',
      'Other',
      'Prefer not to say',
    ],

    'BE': [
      'Moroccan Belgian',
      'Turkish Belgian',
      'Algerian Belgian',
      'Belgian Convert',
      'Other',
      'Prefer not to say',
    ],

    'SE': [
      'Somali Swedish',
      'Iraqi Swedish',
      'Bosnian Swedish',
      'Turkish Swedish',
      'Iranian Swedish',
      'Afghan Swedish',
      'Syrian Swedish',
      'Swedish Convert',
      'Other',
      'Prefer not to say',
    ],

    'NO': [
      'Pakistani Norwegian',
      'Somali Norwegian',
      'Iraqi Norwegian',
      'Moroccan Norwegian',
      'Norwegian Convert',
      'Other',
      'Prefer not to say',
    ],

    'IT': [
      'Moroccan Italian',
      'Tunisian Italian',
      'Albanian Italian',
      'Bangladeshi Italian',
      'Senegalese Italian',
      'Egyptian Italian',
      'Italian Convert',
      'Other',
      'Prefer not to say',
    ],

    'ES': [
      'Moroccan Spanish',
      'Algerian Spanish',
      'Senegalese Spanish',
      'Spanish Convert',
      'Other',
      'Prefer not to say',
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
      'Pakistani Canadian',
      'Arab Canadian',
      'Somali Canadian',
      'Iranian Canadian',
      'Afghan Canadian',
      'Indian Muslim Canadian',
      'Bangladeshi Canadian',
      'Egyptian Canadian',
      'Canadian Convert',
      'Other',
      'Prefer not to say',
    ],

    // ═══════════════ OCEANIA ═════════════════════════════════

    'AU': [
      'Lebanese Australian',
      'Pakistani Australian',
      'Turkish Australian',
      'Indonesian Australian',
      'Bangladeshi Australian',
      'Bosnian Australian',
      'Somali Australian',
      'Afghan Australian',
      'Egyptian Australian',
      'Indian Muslim Australian',
      'Australian Convert',
      'Other',
      'Prefer not to say',
    ],

    'NZ': [
      'Somali New Zealander',
      'Fijian Muslim',
      'Indian Muslim New Zealander',
      'Arab New Zealander',
      'New Zealand Convert',
      'Other',
      'Prefer not to say',
    ],

    // ═══════════════ BALKANS / EASTERN EUROPE ════════════════

    'BA': [
      'Bosniak',
      'Bosanski',
      'Other',
      'Prefer not to say',
    ],

    'AL': [
      'Albanian Muslim',
      'Bektashi',
      'Other',
      'Prefer not to say',
    ],

    'XK': [
      'Kosovar Albanian',
      'Kosovar Bosniak',
      'Kosovar Roma Muslim',
      'Other',
      'Prefer not to say',
    ],

    'MK': [
      'Macedonian Albanian',
      'Macedonian Turk',
      'Macedonian Roma Muslim',
      'Other',
      'Prefer not to say',
    ],

    'ME': [
      'Bosniak Montenegrin',
      'Albanian Montenegrin',
      'Other',
      'Prefer not to say',
    ],

    // ═══════════════ OTHER ════════════════════════════════════

    'RU': [
      'Tatar',
      'Bashkir',
      'Chechen',
      'Ingush',
      'Avar',
      'Dargin',
      'Kumyk',
      'Lezgin',
      'Kabardian',
      'Karachay',
      'Nogai',
      'Azerbaijani (Russian)',
      'Other',
      'Prefer not to say',
    ],

    'CN': [
      'Hui',
      'Uyghur',
      'Kazakh (Chinese)',
      'Kyrgyz (Chinese)',
      'Tajik (Chinese)',
      'Uzbek (Chinese)',
      'Dongxiang',
      'Salar',
      'Bao\'an',
      'Tatar (Chinese)',
      'Other',
      'Prefer not to say',
    ],

    // ═══════════════ PHASE 2.5 — NEW CURATED ENTRIES ══════════

    // Suriname — large Javanese/Indian Muslim population
    'SR': [
      'Javanese Surinamese',
      'Hindustani Surinamese Muslim',
      'Creole Muslim',
      'Other',
      'Prefer not to say'
    ],

    // Guyana
    'GY': [
      'Indo-Guyanese Muslim',
      'Afro-Guyanese Muslim',
      'Other',
      'Prefer not to say'
    ],

    // Trinidad & Tobago
    'TT': [
      'Indo-Trinidadian Muslim',
      'Afro-Trinidadian Muslim',
      'Syrian/Lebanese Trinidadian',
      'Other',
      'Prefer not to say'
    ],

    // Mauritius
    'MU': [
      'Indo-Mauritian Muslim',
      'Creole Muslim',
      'Other',
      'Prefer not to say'
    ],

    // Reunion / Mayotte
    'RE': [
      'Comorian',
      'Malagasy Muslim',
      'Indo-Reunionese Muslim',
      'Other',
      'Prefer not to say'
    ],
    'YT': ['Mahorais', 'Comorian', 'Other', 'Prefer not to say'],

    // Djibouti
    'DJ': [
      'Somali Djiboutian',
      'Afar',
      'Arab Djiboutian',
      'Other',
      'Prefer not to say'
    ],

    // Eritrea
    'ER': [
      'Tigrinya Muslim',
      'Afar',
      'Beja',
      'Saho',
      'Other',
      'Prefer not to say'
    ],

    // Western Sahara
    'EH': ['Sahrawi', 'Moroccan', 'Other', 'Prefer not to say'],

    // Gabon
    'GA': [
      'Fang Muslim',
      'West African diaspora (Senegalese/Malian)',
      'Other',
      'Prefer not to say'
    ],

    // Equatorial Guinea
    'GQ': [
      'Fang Muslim',
      'West African diaspora',
      'Other',
      'Prefer not to say'
    ],

    // Zambia, Malawi, Zimbabwe
    'ZM': [
      'Indian Zambian Muslim',
      'Yao Muslim',
      'Bemba Muslim',
      'Other',
      'Prefer not to say'
    ],
    'MW': [
      'Yao Muslim',
      'Indian Malawian Muslim',
      'Other',
      'Prefer not to say'
    ],
    'ZW': [
      'Indian Zimbabwean Muslim',
      'Shona Muslim',
      'Other',
      'Prefer not to say'
    ],

    // Madagascar
    'MG': [
      'Antalaotra (coastal Malagasy Muslim)',
      'Comorian Malagasy',
      'Indo-Malagasy Muslim',
      'Other',
      'Prefer not to say'
    ],

    // Vietnam, Cambodia — Cham Muslim minority
    'VN': ['Cham Muslim', 'Other', 'Prefer not to say'],
    'KH': ['Cham Muslim', 'Other', 'Prefer not to say'],

    // Nepal
    'NP': ['Madhesi Muslim', 'Newar Muslim', 'Other', 'Prefer not to say'],

    // Bhutan
    'BT': ['Nepali-origin Muslim', 'Other', 'Prefer not to say'],

    // Mongolia
    'MN': ['Kazakh Mongolian Muslim', 'Other', 'Prefer not to say'],

    // Hong Kong, Taiwan, South Korea, Japan
    'HK': [
      'South Asian Hong Konger',
      'Indonesian Hong Konger',
      'Chinese Muslim (Hui)',
      'Convert / Revert',
      'Other',
      'Prefer not to say'
    ],
    'TW': [
      'Hui Taiwanese',
      'Indonesian Taiwanese Muslim',
      'Convert / Revert',
      'Other',
      'Prefer not to say'
    ],
    'KR': [
      'Korean Muslim convert',
      'Pakistani Korean',
      'Indonesian Korean',
      'Other',
      'Prefer not to say'
    ],
    'JP': [
      'Japanese Muslim convert',
      'Pakistani Japanese',
      'Indonesian Japanese',
      'Bangladeshi Japanese',
      'Other',
      'Prefer not to say'
    ],

    // Brunei
    'BN': [
      'Brunei Malay',
      'Kedayan',
      'Dusun Muslim',
      'Other',
      'Prefer not to say'
    ],

    // Fiji
    'FJ': ['Indo-Fijian Muslim', 'Fijian Muslim', 'Other', 'Prefer not to say'],

    // Israel
    'IL': [
      'Palestinian Israeli',
      'Bedouin Israeli',
      'Circassian Israeli',
      'Other',
      'Prefer not to say'
    ],

    // Cyprus
    'CY': ['Turkish Cypriot', 'Other', 'Prefer not to say'],

    // Greece
    'GR': [
      'Western Thrace Turkish',
      'Albanian Greek Muslim',
      'Roma Muslim',
      'Other',
      'Prefer not to say'
    ],

    // Romania, Bulgaria
    'RO': ['Romanian Turkish', 'Tatar Romanian', 'Other', 'Prefer not to say'],
    'BG': [
      'Bulgarian Turkish',
      'Pomak',
      'Roma Muslim',
      'Other',
      'Prefer not to say'
    ],

    // Poland, Lithuania — Lipka Tatars
    'PL': [
      'Lipka Tatar',
      'Chechen refugee community',
      'Arab diaspora',
      'Other',
      'Prefer not to say'
    ],
    'LT': ['Lipka Tatar', 'Other', 'Prefer not to say'],

    // Portugal
    'PT': [
      'Guinean Portuguese Muslim',
      'Mozambican Portuguese Muslim',
      'Moroccan Portuguese',
      'Other',
      'Prefer not to say'
    ],

    // Ireland
    'IE': [
      'Pakistani Irish',
      'Nigerian Irish Muslim',
      'Convert / Revert',
      'Other',
      'Prefer not to say'
    ],

    // Iceland
    'IS': [
      'Convert / Revert Muslim',
      'Bosnian Icelandic',
      'Other',
      'Prefer not to say'
    ],

    // Finland
    'FI': [
      'Somali Finnish',
      'Tatar Finnish (historic)',
      'Iraqi Finnish',
      'Other',
      'Prefer not to say'
    ],

    // Switzerland, Austria
    'CH': [
      'Kosovar Swiss',
      'Turkish Swiss',
      'Bosnian Swiss',
      'Other',
      'Prefer not to say'
    ],
    'AT': [
      'Turkish Austrian',
      'Bosnian Austrian',
      'Chechen Austrian',
      'Other',
      'Prefer not to say'
    ],

    // Denmark
    'DK': [
      'Turkish Danish',
      'Palestinian Danish',
      'Somali Danish',
      'Pakistani Danish',
      'Other',
      'Prefer not to say'
    ],

    // Countries previously covered only by generated fallback labels.
    'AD': [
      'Moroccan Andorran',
      'Algerian Andorran',
      'Pakistani Andorran',
      'Convert / Revert',
      'Other',
      'Prefer not to say'
    ],
    'AM': [
      'Azeri Muslim',
      'Iranian Muslim',
      'Kurdish Muslim',
      'Levantine Arab',
      'Convert / Revert',
      'Other',
      'Prefer not to say'
    ],
    'BF': [
      'Mossi Muslim',
      'Fulani / Peul',
      'Dioula / Jula',
      'Bissa Muslim',
      'Gourmantche Muslim',
      'Other',
      'Prefer not to say'
    ],
    'BJ': [
      'Yoruba Muslim',
      'Bariba / Baatonum',
      'Dendi',
      'Fulani / Peul',
      'Hausa',
      'Fon Muslim',
      'Other',
      'Prefer not to say'
    ],
    'BW': [
      'Indian Botswana Muslim',
      'Pakistani Botswana Muslim',
      'Somali Botswana Muslim',
      'Arab diaspora',
      'Convert / Revert',
      'Other',
      'Prefer not to say'
    ],
    'BY': [
      'Belarusian Tatar',
      'Azeri Belarusian',
      'Chechen Belarusian',
      'Central Asian Muslim',
      'Convert / Revert',
      'Other',
      'Prefer not to say'
    ],
    'CZ': [
      'Bosnian Czech',
      'Turkish Czech',
      'Arab diaspora',
      'Chechen Czech',
      'Convert / Revert',
      'Other',
      'Prefer not to say'
    ],
    'EE': [
      'Estonian Tatar',
      'Azeri Estonian',
      'Chechen Estonian',
      'Central Asian Muslim',
      'Convert / Revert',
      'Other',
      'Prefer not to say'
    ],
    'GE': [
      'Ajarian Muslim',
      'Azerbaijani Georgian',
      'Kist / Chechen',
      'Meskhetian Turk',
      'Laz Muslim',
      'Other',
      'Prefer not to say'
    ],
    'GM': [
      'Mandinka',
      'Wolof',
      'Fula / Fulani',
      'Jola',
      'Sarahule / Soninke',
      'Serer Muslim',
      'Other',
      'Prefer not to say'
    ],
    'GN': [
      'Fula / Peul',
      'Malinke / Mandinka',
      'Susu',
      'Kissi Muslim',
      'Toma Muslim',
      'Other',
      'Prefer not to say'
    ],
    'HR': [
      'Bosniak Croatian',
      'Albanian Croatian',
      'Roma Muslim',
      'Turkish diaspora',
      'Convert / Revert',
      'Other',
      'Prefer not to say'
    ],
    'HU': [
      'Bosnian Hungarian',
      'Turkish Hungarian',
      'Arab diaspora',
      'Roma Muslim',
      'Convert / Revert',
      'Other',
      'Prefer not to say'
    ],
    'KM': [
      'Ngazidja / Grande Comore',
      'Ndzuwani / Anjouan',
      'Mwali / Moheli',
      'Mahorais / Comorian diaspora',
      'Other',
      'Prefer not to say'
    ],
    'LI': [
      'Turkish Liechtenstein',
      'Bosnian Liechtenstein',
      'Albanian / Kosovar',
      'Arab diaspora',
      'Convert / Revert',
      'Other',
      'Prefer not to say'
    ],
    'LU': [
      'Bosnian Luxembourgish',
      'Turkish Luxembourgish',
      'Moroccan Luxembourgish',
      'Albanian / Kosovar',
      'Convert / Revert',
      'Other',
      'Prefer not to say'
    ],
    'LV': [
      'Latvian Tatar',
      'Azeri Latvian',
      'Chechen Latvian',
      'Central Asian Muslim',
      'Convert / Revert',
      'Other',
      'Prefer not to say'
    ],
    'MC': [
      'Moroccan Monegasque',
      'French Maghrebi Muslim',
      'Turkish Monegasque',
      'Arab diaspora',
      'Convert / Revert',
      'Other',
      'Prefer not to say'
    ],
    'MD': [
      'Moldovan Tatar',
      'Azeri Moldovan',
      'Turkish Moldovan',
      'Roma Muslim',
      'Convert / Revert',
      'Other',
      'Prefer not to say'
    ],
    'MO': [
      'Indonesian Macau Muslim',
      'Filipino Muslim',
      'South Asian Muslim',
      'Chinese / Hui Muslim',
      'Convert / Revert',
      'Other',
      'Prefer not to say'
    ],
    'MT': [
      'Libyan Maltese Muslim',
      'Somali Maltese Muslim',
      'Pakistani Maltese Muslim',
      'Arab diaspora',
      'Convert / Revert',
      'Other',
      'Prefer not to say'
    ],
    'MX': [
      'Mexican Convert / Revert',
      'Lebanese Mexican Muslim',
      'Palestinian Mexican Muslim',
      'Pakistani Mexican Muslim',
      'North African diaspora',
      'Other',
      'Prefer not to say'
    ],
    'NE': [
      'Hausa',
      'Zarma / Songhai',
      'Fulani / Peul',
      'Tuareg',
      'Kanuri',
      'Arab',
      'Other',
      'Prefer not to say'
    ],
    'RS': [
      'Bosniak / Sandzak',
      'Albanian Muslim',
      'Roma Muslim',
      'Gorani',
      'Turkish diaspora',
      'Other',
      'Prefer not to say'
    ],
    'SC': [
      'Seychellois Muslim',
      'South Asian Seychellois',
      'Comorian Seychellois',
      'Arab diaspora',
      'Convert / Revert',
      'Other',
      'Prefer not to say'
    ],
    'SI': [
      'Bosniak Slovenian',
      'Albanian Slovenian',
      'Turkish Slovenian',
      'Roma Muslim',
      'Convert / Revert',
      'Other',
      'Prefer not to say'
    ],
    'SK': [
      'Bosnian Slovak',
      'Turkish Slovak',
      'Arab diaspora',
      'Chechen Slovak',
      'Convert / Revert',
      'Other',
      'Prefer not to say'
    ],
    'SM': [
      'Italian Muslim',
      'North African Muslim',
      'Albanian / Balkan Muslim',
      'Convert / Revert',
      'Other',
      'Prefer not to say'
    ],
    'SS': [
      'South Sudanese Muslim',
      'Sudanese Arab',
      'Dinka Muslim',
      'Nuer Muslim',
      'Bari Muslim',
      'Darfuri diaspora',
      'Other',
      'Prefer not to say'
    ],
    'ST': [
      'Sao Tomean Muslim',
      'Nigerian Muslim',
      'Senegalese Muslim',
      'Guinean Muslim',
      'Convert / Revert',
      'Other',
      'Prefer not to say'
    ],
    'TD': [
      'Chadian Arab',
      'Kanembu / Kanuri',
      'Zaghawa',
      'Maba',
      'Fulani / Peul',
      'Hausa',
      'Sara Muslim',
      'Other',
      'Prefer not to say'
    ],
    'TG': [
      'Kotokoli / Tem',
      'Hausa Togolese',
      'Fulani / Peul',
      'Yoruba Muslim',
      'Dendi',
      'Moba Muslim',
      'Other',
      'Prefer not to say'
    ],
    'TL': [
      'Timorese Muslim',
      'Indonesian Muslim',
      'Arab / Hadhrami diaspora',
      'Convert / Revert',
      'Other',
      'Prefer not to say'
    ],
    'UA': [
      'Crimean Tatar',
      'Volga Tatar',
      'Azerbaijani Ukrainian',
      'Turkish Ukrainian',
      'Chechen Ukrainian',
      'Central Asian Muslim',
      'Ukrainian Convert / Revert',
      'Other',
      'Prefer not to say'
    ],
    'UG': [
      'Baganda Muslim',
      'Nubian Ugandan',
      'Basoga Muslim',
      'Banyankole Muslim',
      'Somali Ugandan',
      'Indian Ugandan Muslim',
      'Other',
      'Prefer not to say'
    ],
    'ZA': [
      'Cape Malay',
      'Indian South African Muslim',
      'Somali South African',
      'Pakistani South African',
      'African Convert / Revert',
      'Malawian / Zimbabwean Muslim',
      'Other',
      'Prefer not to say'
    ],
  };
}
