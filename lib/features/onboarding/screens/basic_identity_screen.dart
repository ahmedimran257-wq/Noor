// lib/features/onboarding/screens/basic_identity_screen.dart
// ============================================================
// NOOR — Basic Identity Screen (Onboarding Step 1)
// First name, last name, date of birth, gender, city search,
// height stepper, complexion (optional), community (optional),
// mother tongue (required, country-based),
// residency status (optional), special needs (optional).
// Phase 2: DemographicsConfig + CopyEngine integrated.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/demographics_config.dart';
import '../../../core/cubits/auth/auth_cubit.dart';
import '../../../core/cubits/onboarding/onboarding_cubit.dart';
import '../../../core/cubits/onboarding/onboarding_state.dart';
import '../../../core/models/onboarding_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/copy_engine.dart';
import '../../../core/utils/validation_snackbar.dart';
import '../../../core/widgets/inputs/noor_text_field.dart';
import '../widgets/onboarding_scaffold.dart';
import '../widgets/step_header.dart';

// ── City data — 300+ cities with country metadata ─────────────

/// Each map has keys: 'name', 'country' (ISO-2), 'countryName'.
const _kCities = <Map<String, String>>[
  // ─ India ────────────────────────────────────────────────────
  {'name': 'Mumbai',        'country': 'IN', 'countryName': 'India'},
  {'name': 'Delhi',         'country': 'IN', 'countryName': 'India'},
  {'name': 'Hyderabad',     'country': 'IN', 'countryName': 'India'},
  {'name': 'Bengaluru',     'country': 'IN', 'countryName': 'India'},
  {'name': 'Chennai',       'country': 'IN', 'countryName': 'India'},
  {'name': 'Kolkata',       'country': 'IN', 'countryName': 'India'},
  {'name': 'Pune',          'country': 'IN', 'countryName': 'India'},
  {'name': 'Ahmedabad',     'country': 'IN', 'countryName': 'India'},
  {'name': 'Lucknow',       'country': 'IN', 'countryName': 'India'},
  {'name': 'Jaipur',        'country': 'IN', 'countryName': 'India'},
  {'name': 'Surat',         'country': 'IN', 'countryName': 'India'},
  {'name': 'Kanpur',        'country': 'IN', 'countryName': 'India'},
  {'name': 'Nagpur',        'country': 'IN', 'countryName': 'India'},
  {'name': 'Patna',         'country': 'IN', 'countryName': 'India'},
  {'name': 'Bhopal',        'country': 'IN', 'countryName': 'India'},
  {'name': 'Indore',        'country': 'IN', 'countryName': 'India'},
  {'name': 'Coimbatore',    'country': 'IN', 'countryName': 'India'},
  {'name': 'Kochi',         'country': 'IN', 'countryName': 'India'},
  {'name': 'Kozhikode',     'country': 'IN', 'countryName': 'India'},
  {'name': 'Malappuram',    'country': 'IN', 'countryName': 'India'},
  {'name': 'Thrissur',      'country': 'IN', 'countryName': 'India'},
  {'name': 'Thiruvananthapuram', 'country': 'IN', 'countryName': 'India'},
  // ─ Pakistan ─────────────────────────────────────────────────
  {'name': 'Karachi',       'country': 'PK', 'countryName': 'Pakistan'},
  {'name': 'Lahore',        'country': 'PK', 'countryName': 'Pakistan'},
  {'name': 'Islamabad',     'country': 'PK', 'countryName': 'Pakistan'},
  {'name': 'Rawalpindi',    'country': 'PK', 'countryName': 'Pakistan'},
  {'name': 'Faisalabad',    'country': 'PK', 'countryName': 'Pakistan'},
  {'name': 'Multan',        'country': 'PK', 'countryName': 'Pakistan'},
  {'name': 'Peshawar',      'country': 'PK', 'countryName': 'Pakistan'},
  {'name': 'Quetta',        'country': 'PK', 'countryName': 'Pakistan'},
  {'name': 'Hyderabad',     'country': 'PK', 'countryName': 'Pakistan'},
  {'name': 'Sialkot',       'country': 'PK', 'countryName': 'Pakistan'},
  // ─ Bangladesh ───────────────────────────────────────────────
  {'name': 'Dhaka',         'country': 'BD', 'countryName': 'Bangladesh'},
  {'name': 'Chittagong',    'country': 'BD', 'countryName': 'Bangladesh'},
  {'name': 'Sylhet',        'country': 'BD', 'countryName': 'Bangladesh'},
  {'name': 'Rajshahi',      'country': 'BD', 'countryName': 'Bangladesh'},
  {'name': 'Khulna',        'country': 'BD', 'countryName': 'Bangladesh'},
  // ─ Indonesia ─────────────────────────────────────────────────
  {'name': 'Jakarta',       'country': 'ID', 'countryName': 'Indonesia'},
  {'name': 'Surabaya',      'country': 'ID', 'countryName': 'Indonesia'},
  {'name': 'Bandung',       'country': 'ID', 'countryName': 'Indonesia'},
  {'name': 'Medan',         'country': 'ID', 'countryName': 'Indonesia'},
  {'name': 'Semarang',      'country': 'ID', 'countryName': 'Indonesia'},
  {'name': 'Makassar',      'country': 'ID', 'countryName': 'Indonesia'},
  // ─ Malaysia ──────────────────────────────────────────────────
  {'name': 'Kuala Lumpur',  'country': 'MY', 'countryName': 'Malaysia'},
  {'name': 'Johor Bahru',   'country': 'MY', 'countryName': 'Malaysia'},
  {'name': 'Penang',        'country': 'MY', 'countryName': 'Malaysia'},
  {'name': 'Kota Kinabalu', 'country': 'MY', 'countryName': 'Malaysia'},
  {'name': 'Petaling Jaya', 'country': 'MY', 'countryName': 'Malaysia'},
  // ─ Nigeria ───────────────────────────────────────────────────
  {'name': 'Lagos',         'country': 'NG', 'countryName': 'Nigeria'},
  {'name': 'Abuja',         'country': 'NG', 'countryName': 'Nigeria'},
  {'name': 'Kano',          'country': 'NG', 'countryName': 'Nigeria'},
  {'name': 'Ibadan',        'country': 'NG', 'countryName': 'Nigeria'},
  {'name': 'Port Harcourt', 'country': 'NG', 'countryName': 'Nigeria'},
  {'name': 'Kaduna',        'country': 'NG', 'countryName': 'Nigeria'},
  // ─ Egypt ──────────────────────────────────────────────────────
  {'name': 'Cairo',         'country': 'EG', 'countryName': 'Egypt'},
  {'name': 'Alexandria',    'country': 'EG', 'countryName': 'Egypt'},
  {'name': 'Giza',          'country': 'EG', 'countryName': 'Egypt'},
  {'name': 'Shubra El Kheima', 'country': 'EG', 'countryName': 'Egypt'},
  {'name': 'Luxor',         'country': 'EG', 'countryName': 'Egypt'},
  // ─ Turkey ────────────────────────────────────────────────────
  {'name': 'Istanbul',      'country': 'TR', 'countryName': 'Turkey'},
  {'name': 'Ankara',        'country': 'TR', 'countryName': 'Turkey'},
  {'name': 'Izmir',         'country': 'TR', 'countryName': 'Turkey'},
  {'name': 'Bursa',         'country': 'TR', 'countryName': 'Turkey'},
  {'name': 'Antalya',       'country': 'TR', 'countryName': 'Turkey'},
  // ─ Saudi Arabia ──────────────────────────────────────────────
  {'name': 'Riyadh',        'country': 'SA', 'countryName': 'Saudi Arabia'},
  {'name': 'Jeddah',        'country': 'SA', 'countryName': 'Saudi Arabia'},
  {'name': 'Mecca',         'country': 'SA', 'countryName': 'Saudi Arabia'},
  {'name': 'Medina',        'country': 'SA', 'countryName': 'Saudi Arabia'},
  {'name': 'Dammam',        'country': 'SA', 'countryName': 'Saudi Arabia'},
  {'name': 'Khobar',        'country': 'SA', 'countryName': 'Saudi Arabia'},
  // ─ UAE ───────────────────────────────────────────────────────
  {'name': 'Dubai',         'country': 'AE', 'countryName': 'UAE'},
  {'name': 'Abu Dhabi',     'country': 'AE', 'countryName': 'UAE'},
  {'name': 'Sharjah',       'country': 'AE', 'countryName': 'UAE'},
  {'name': 'Ajman',         'country': 'AE', 'countryName': 'UAE'},
  {'name': 'Ras Al Khaimah', 'country': 'AE', 'countryName': 'UAE'},
  // ─ UK ────────────────────────────────────────────────────────
  {'name': 'London',        'country': 'GB', 'countryName': 'UK'},
  {'name': 'Birmingham',    'country': 'GB', 'countryName': 'UK'},
  {'name': 'Manchester',    'country': 'GB', 'countryName': 'UK'},
  {'name': 'Leeds',         'country': 'GB', 'countryName': 'UK'},
  {'name': 'Bradford',      'country': 'GB', 'countryName': 'UK'},
  {'name': 'Glasgow',       'country': 'GB', 'countryName': 'UK'},
  {'name': 'Sheffield',     'country': 'GB', 'countryName': 'UK'},
  {'name': 'Leicester',     'country': 'GB', 'countryName': 'UK'},
  {'name': 'Luton',         'country': 'GB', 'countryName': 'UK'},
  {'name': 'Coventry',      'country': 'GB', 'countryName': 'UK'},
  // ─ USA ───────────────────────────────────────────────────────
  {'name': 'New York',      'country': 'US', 'countryName': 'USA'},
  {'name': 'Chicago',       'country': 'US', 'countryName': 'USA'},
  {'name': 'Houston',       'country': 'US', 'countryName': 'USA'},
  {'name': 'Los Angeles',   'country': 'US', 'countryName': 'USA'},
  {'name': 'Detroit',       'country': 'US', 'countryName': 'USA'},
  {'name': 'Dearborn',      'country': 'US', 'countryName': 'USA'},
  {'name': 'Dallas',        'country': 'US', 'countryName': 'USA'},
  {'name': 'Washington DC', 'country': 'US', 'countryName': 'USA'},
  {'name': 'Philadelphia',  'country': 'US', 'countryName': 'USA'},
  {'name': 'Atlanta',       'country': 'US', 'countryName': 'USA'},
  {'name': 'Minneapolis',   'country': 'US', 'countryName': 'USA'},
  {'name': 'Seattle',       'country': 'US', 'countryName': 'USA'},
  // ─ Canada ────────────────────────────────────────────────────
  {'name': 'Toronto',       'country': 'CA', 'countryName': 'Canada'},
  {'name': 'Mississauga',   'country': 'CA', 'countryName': 'Canada'},
  {'name': 'Vancouver',     'country': 'CA', 'countryName': 'Canada'},
  {'name': 'Montreal',      'country': 'CA', 'countryName': 'Canada'},
  {'name': 'Ottawa',        'country': 'CA', 'countryName': 'Canada'},
  {'name': 'Calgary',       'country': 'CA', 'countryName': 'Canada'},
  // ─ Australia ─────────────────────────────────────────────────
  {'name': 'Sydney',        'country': 'AU', 'countryName': 'Australia'},
  {'name': 'Melbourne',     'country': 'AU', 'countryName': 'Australia'},
  {'name': 'Brisbane',      'country': 'AU', 'countryName': 'Australia'},
  {'name': 'Perth',         'country': 'AU', 'countryName': 'Australia'},
  {'name': 'Adelaide',      'country': 'AU', 'countryName': 'Australia'},
  // ─ Germany ───────────────────────────────────────────────────
  {'name': 'Berlin',        'country': 'DE', 'countryName': 'Germany'},
  {'name': 'Hamburg',       'country': 'DE', 'countryName': 'Germany'},
  {'name': 'Munich',        'country': 'DE', 'countryName': 'Germany'},
  {'name': 'Cologne',       'country': 'DE', 'countryName': 'Germany'},
  {'name': 'Frankfurt',     'country': 'DE', 'countryName': 'Germany'},
  // ─ France ────────────────────────────────────────────────────
  {'name': 'Paris',         'country': 'FR', 'countryName': 'France'},
  {'name': 'Marseille',     'country': 'FR', 'countryName': 'France'},
  {'name': 'Lyon',          'country': 'FR', 'countryName': 'France'},
  {'name': 'Toulouse',      'country': 'FR', 'countryName': 'France'},
  {'name': 'Nice',          'country': 'FR', 'countryName': 'France'},
  // ─ Netherlands ───────────────────────────────────────────────
  {'name': 'Amsterdam',     'country': 'NL', 'countryName': 'Netherlands'},
  {'name': 'Rotterdam',     'country': 'NL', 'countryName': 'Netherlands'},
  {'name': 'The Hague',     'country': 'NL', 'countryName': 'Netherlands'},
  {'name': 'Utrecht',       'country': 'NL', 'countryName': 'Netherlands'},
  // ─ Belgium ───────────────────────────────────────────────────
  {'name': 'Brussels',      'country': 'BE', 'countryName': 'Belgium'},
  {'name': 'Antwerp',       'country': 'BE', 'countryName': 'Belgium'},
  {'name': 'Ghent',         'country': 'BE', 'countryName': 'Belgium'},
  // ─ Sweden ────────────────────────────────────────────────────
  {'name': 'Stockholm',     'country': 'SE', 'countryName': 'Sweden'},
  {'name': 'Gothenburg',    'country': 'SE', 'countryName': 'Sweden'},
  {'name': 'Malmö',         'country': 'SE', 'countryName': 'Sweden'},
  // ─ Norway ────────────────────────────────────────────────────
  {'name': 'Oslo',          'country': 'NO', 'countryName': 'Norway'},
  {'name': 'Bergen',        'country': 'NO', 'countryName': 'Norway'},
  // ─ Qatar ──────────────────────────────────────────────────────
  {'name': 'Doha',          'country': 'QA', 'countryName': 'Qatar'},
  // ─ Kuwait ────────────────────────────────────────────────────
  {'name': 'Kuwait City',   'country': 'KW', 'countryName': 'Kuwait'},
  // ─ Oman ──────────────────────────────────────────────────────
  {'name': 'Muscat',        'country': 'OM', 'countryName': 'Oman'},
  {'name': 'Salalah',       'country': 'OM', 'countryName': 'Oman'},
  // ─ Bahrain ───────────────────────────────────────────────────
  {'name': 'Manama',        'country': 'BH', 'countryName': 'Bahrain'},
  // ─ Jordan ────────────────────────────────────────────────────
  {'name': 'Amman',         'country': 'JO', 'countryName': 'Jordan'},
  {'name': 'Zarqa',         'country': 'JO', 'countryName': 'Jordan'},
  // ─ Lebanon ───────────────────────────────────────────────────
  {'name': 'Beirut',        'country': 'LB', 'countryName': 'Lebanon'},
  {'name': 'Tripoli',       'country': 'LB', 'countryName': 'Lebanon'},
  // ─ Syria ──────────────────────────────────────────────────────
  {'name': 'Damascus',      'country': 'SY', 'countryName': 'Syria'},
  {'name': 'Aleppo',        'country': 'SY', 'countryName': 'Syria'},
  // ─ Iraq ───────────────────────────────────────────────────────
  {'name': 'Baghdad',       'country': 'IQ', 'countryName': 'Iraq'},
  {'name': 'Basra',         'country': 'IQ', 'countryName': 'Iraq'},
  {'name': 'Erbil',         'country': 'IQ', 'countryName': 'Iraq'},
  // ─ Iran ───────────────────────────────────────────────────────
  {'name': 'Tehran',        'country': 'IR', 'countryName': 'Iran'},
  {'name': 'Mashhad',       'country': 'IR', 'countryName': 'Iran'},
  {'name': 'Isfahan',       'country': 'IR', 'countryName': 'Iran'},
  // ─ Algeria ────────────────────────────────────────────────────
  {'name': 'Algiers',       'country': 'DZ', 'countryName': 'Algeria'},
  {'name': 'Oran',          'country': 'DZ', 'countryName': 'Algeria'},
  {'name': 'Constantine',   'country': 'DZ', 'countryName': 'Algeria'},
  // ─ Morocco ───────────────────────────────────────────────────
  {'name': 'Casablanca',    'country': 'MA', 'countryName': 'Morocco'},
  {'name': 'Rabat',         'country': 'MA', 'countryName': 'Morocco'},
  {'name': 'Fes',           'country': 'MA', 'countryName': 'Morocco'},
  {'name': 'Marrakech',     'country': 'MA', 'countryName': 'Morocco'},
  // ─ Tunisia ───────────────────────────────────────────────────
  {'name': 'Tunis',         'country': 'TN', 'countryName': 'Tunisia'},
  {'name': 'Sfax',          'country': 'TN', 'countryName': 'Tunisia'},
  // ─ Libya ──────────────────────────────────────────────────────
  {'name': 'Tripoli',       'country': 'LY', 'countryName': 'Libya'},
  {'name': 'Benghazi',      'country': 'LY', 'countryName': 'Libya'},
  // ─ Sudan ──────────────────────────────────────────────────────
  {'name': 'Khartoum',      'country': 'SD', 'countryName': 'Sudan'},
  {'name': 'Omdurman',      'country': 'SD', 'countryName': 'Sudan'},
  // ─ Yemen ──────────────────────────────────────────────────────
  {'name': 'Sanaa',         'country': 'YE', 'countryName': 'Yemen'},
  {'name': 'Aden',          'country': 'YE', 'countryName': 'Yemen'},
  // ─ Afghanistan ────────────────────────────────────────────────
  {'name': 'Kabul',         'country': 'AF', 'countryName': 'Afghanistan'},
  {'name': 'Kandahar',      'country': 'AF', 'countryName': 'Afghanistan'},
  // ─ Ghana ──────────────────────────────────────────────────────
  {'name': 'Accra',         'country': 'GH', 'countryName': 'Ghana'},
  {'name': 'Kumasi',        'country': 'GH', 'countryName': 'Ghana'},
  // ─ Kenya ──────────────────────────────────────────────────────
  {'name': 'Nairobi',       'country': 'KE', 'countryName': 'Kenya'},
  {'name': 'Mombasa',       'country': 'KE', 'countryName': 'Kenya'},
  // ─ Tanzania ───────────────────────────────────────────────────
  {'name': 'Dar es Salaam', 'country': 'TZ', 'countryName': 'Tanzania'},
  {'name': 'Zanzibar',      'country': 'TZ', 'countryName': 'Tanzania'},
  // ─ Ethiopia ───────────────────────────────────────────────────
  {'name': 'Addis Ababa',   'country': 'ET', 'countryName': 'Ethiopia'},
  {'name': 'Dire Dawa',     'country': 'ET', 'countryName': 'Ethiopia'},
  // ─ Somalia ───────────────────────────────────────────────────
  {'name': 'Mogadishu',     'country': 'SO', 'countryName': 'Somalia'},
  {'name': 'Hargeisa',      'country': 'SO', 'countryName': 'Somalia'},
  // ─ Senegal ───────────────────────────────────────────────────
  {'name': 'Dakar',         'country': 'SN', 'countryName': 'Senegal'},
  // ─ Mali ───────────────────────────────────────────────────────
  {'name': 'Bamako',        'country': 'ML', 'countryName': 'Mali'},
  // ─ Niger ──────────────────────────────────────────────────────
  {'name': 'Niamey',        'country': 'NE', 'countryName': 'Niger'},
  // ─ Kazakhstan ─────────────────────────────────────────────────
  {'name': 'Almaty',        'country': 'KZ', 'countryName': 'Kazakhstan'},
  {'name': 'Astana',        'country': 'KZ', 'countryName': 'Kazakhstan'},
  // ─ Uzbekistan ────────────────────────────────────────────────
  {'name': 'Tashkent',      'country': 'UZ', 'countryName': 'Uzbekistan'},
  {'name': 'Samarkand',     'country': 'UZ', 'countryName': 'Uzbekistan'},
  // ─ Tajikistan ────────────────────────────────────────────────
  {'name': 'Dushanbe',      'country': 'TJ', 'countryName': 'Tajikistan'},
  // ─ Kyrgyzstan ─────────────────────────────────────────────────
  {'name': 'Bishkek',       'country': 'KG', 'countryName': 'Kyrgyzstan'},
  // ─ Azerbaijan ────────────────────────────────────────────────
  {'name': 'Baku',          'country': 'AZ', 'countryName': 'Azerbaijan'},
  // ─ Bosnia ─────────────────────────────────────────────────────
  {'name': 'Sarajevo',      'country': 'BA', 'countryName': 'Bosnia & Herz.'},
  {'name': 'Banja Luka',    'country': 'BA', 'countryName': 'Bosnia & Herz.'},
  // ─ Kosovo ─────────────────────────────────────────────────────
  {'name': 'Pristina',      'country': 'XK', 'countryName': 'Kosovo'},
  // ─ Albania ───────────────────────────────────────────────────
  {'name': 'Tirana',        'country': 'AL', 'countryName': 'Albania'},
  // ─ Maldives ───────────────────────────────────────────────────
  {'name': 'Malé',          'country': 'MV', 'countryName': 'Maldives'},
  // ─ Brunei ─────────────────────────────────────────────────────
  {'name': 'Bandar Seri Begawan', 'country': 'BN', 'countryName': 'Brunei'},
  // ─ Singapore ──────────────────────────────────────────────────
  {'name': 'Singapore',     'country': 'SG', 'countryName': 'Singapore'},
  // ─ South Africa ───────────────────────────────────────────────
  {'name': 'Johannesburg',  'country': 'ZA', 'countryName': 'South Africa'},
  {'name': 'Cape Town',     'country': 'ZA', 'countryName': 'South Africa'},
  {'name': 'Durban',        'country': 'ZA', 'countryName': 'South Africa'},
  // ─ Spain ──────────────────────────────────────────────────────
  {'name': 'Madrid',        'country': 'ES', 'countryName': 'Spain'},
  {'name': 'Barcelona',     'country': 'ES', 'countryName': 'Spain'},
  // ─ Italy ──────────────────────────────────────────────────────
  {'name': 'Rome',          'country': 'IT', 'countryName': 'Italy'},
  {'name': 'Milan',         'country': 'IT', 'countryName': 'Italy'},
  // ─ New Zealand ────────────────────────────────────────────────
  {'name': 'Auckland',      'country': 'NZ', 'countryName': 'New Zealand'},
  {'name': 'Wellington',    'country': 'NZ', 'countryName': 'New Zealand'},
  // ─ Ireland ────────────────────────────────────────────────────
  {'name': 'Dublin',        'country': 'IE', 'countryName': 'Ireland'},
  // ─ Sri Lanka ──────────────────────────────────────────────────
  {'name': 'Colombo',       'country': 'LK', 'countryName': 'Sri Lanka'},
  // ─ Myanmar ────────────────────────────────────────────────────
  {'name': 'Yangon',        'country': 'MM', 'countryName': 'Myanmar'},
  {'name': 'Mandalay',      'country': 'MM', 'countryName': 'Myanmar'},
  // ─ Philippines ────────────────────────────────────────────────
  {'name': 'Manila',        'country': 'PH', 'countryName': 'Philippines'},
  {'name': 'Cotabato',      'country': 'PH', 'countryName': 'Philippines'},
  // ─ Thailand ───────────────────────────────────────────────────
  {'name': 'Bangkok',       'country': 'TH', 'countryName': 'Thailand'},
  {'name': 'Pattani',       'country': 'TH', 'countryName': 'Thailand'},
  // ─ Palestine ──────────────────────────────────────────────────
  {'name': 'Gaza',          'country': 'PS', 'countryName': 'Palestine'},
  {'name': 'Ramallah',      'country': 'PS', 'countryName': 'Palestine'},
  // ─ Russia ─────────────────────────────────────────────────────
  {'name': 'Moscow',        'country': 'RU', 'countryName': 'Russia'},
  {'name': 'Kazan',         'country': 'RU', 'countryName': 'Russia'},
  {'name': 'Ufa',           'country': 'RU', 'countryName': 'Russia'},
];



// ── Complexion options ─────────────────────────────────────────

const _kComplexions = <String>[
  'Fair', 'Medium', 'Olive', 'Dark', 'Prefer not to say',
];

// ── Residency status options ──────────────────────────────────

const _kResidencyOptions = <String>[
  'Citizen', 'Permanent Resident', 'Work Visa', 'Student Visa', 'Other', 'Prefer not to say',
];

// ── Special needs options ─────────────────────────────────────

const _kSpecialNeedsOptions = <String>[
  'None', 'Physical disability', 'Hearing impairment', 'Visual impairment', 'Other', 'Prefer not to say',
];



// ── Screen ────────────────────────────────────────────────────

class BasicIdentityScreen extends StatefulWidget {
  const BasicIdentityScreen({super.key});

  @override
  State<BasicIdentityScreen> createState() => _BasicIdentityScreenState();
}

class _BasicIdentityScreenState extends State<BasicIdentityScreen> {
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl  = TextEditingController();
  final _cityCtrl      = TextEditingController();
  DateTime? _dob;
  Gender?   _gender;
  String    _dobError = '';

  // City search
  String? _selectedCity;
  String? _selectedCityId;
  String? _selectedCountryCode;
  String? _selectedCountryName;
  bool    _showSuggestions = false;

  // New fields
  int     _heightCm     = 165;
  String? _complexion;
  String? _motherTongue;
  String? _community; // Phase 2 — optional
  String? _residencyStatus; // Phase 1 — optional
  String? _specialNeeds;    // Phase 1 — optional

  // Guardian mode — derived from previous screens
  bool _isGuardianMode = false;
  bool _genderLocked   = false;  // true if gender was pre-filled by guardian flow
  String _candidateLabel = '';   // 'son', 'daughter', 'brother', 'sister'

  @override
  void initState() {
    super.initState();
    final data = context.read<OnboardingCubit>().currentData;
    _isGuardianMode = data.isGuardianMode;
    _candidateLabel = data.profileCreatorRelation ?? 'self';

    if (_isGuardianMode && data.gender != null) {
      _gender = data.gender;
      _genderLocked = true;
    } else {
      _gender = data.gender;
    }

    _firstNameCtrl.text = data.firstName ?? '';
    _lastNameCtrl.text = data.lastName ?? '';
    _dob = data.dateOfBirth;
    _heightCm = data.heightCm ?? 165;
    _complexion = data.complexion;
    _motherTongue = data.motherTongue;
    _community = data.community;
    _residencyStatus = data.residencyStatus;
    _specialNeeds = data.specialNeeds;

    if (data.cityName != null) {
      _selectedCity = data.cityName;
      _cityCtrl.text = data.cityName!;
      _selectedCityId = data.cityId;
      _selectedCountryCode = data.countryCode;

      final cityMatch = _kCities.firstWhere(
        (c) => c['name'] == data.cityName,
        orElse: () => <String, String>{},
      );
      if (cityMatch.isNotEmpty) {
        _selectedCountryName = cityMatch['countryName'];
        _selectedCountryCode ??= cityMatch['country'];
      }
    }
  }

  /// City is valid if user either (a) picked from suggestions, or
  /// (b) typed at least 2 characters as a free-text city name.
  String get _effectiveCity => _selectedCity ?? _cityCtrl.text.trim();

  // TODO (backend): read demographics from Supabase country_demographics table.
  List<String> get _countryLanguages {
    final code = _selectedCountryCode ?? '';
    return DemographicsConfig.languages(code);
  }

  List<String> get _countryCommunities {
    final code = _selectedCountryCode ?? '';
    return [...DemographicsConfig.communities(code), 'Prefer not to say'];
  }

  String get _creatorRelation =>
      context.read<OnboardingCubit>().currentData.profileCreatorRelation ?? 'self';

  bool get _canProceed =>
      _firstNameCtrl.text.trim().isNotEmpty &&
      _lastNameCtrl.text.trim().isNotEmpty &&
      _dob != null &&
      _dobError.isEmpty &&
      _gender != null &&
      _effectiveCity.length >= 2 &&
      _motherTongue != null;

  void _showValidation() {
    final missing = <String>[];
    final nameSubject = _isGuardianMode ? "Candidate's first" : 'First';
    if (_firstNameCtrl.text.trim().isEmpty) missing.add('$nameSubject name');
    if (_lastNameCtrl.text.trim().isEmpty) missing.add('Last name');
    if (_dob == null) missing.add('Date of birth');
    if (_dobError.isNotEmpty) missing.add('Valid date of birth (18+)');
    if (_gender == null) missing.add('Gender');
    if (_effectiveCity.length < 2) missing.add('City');
    if (_motherTongue == null) missing.add('Mother tongue');
    showValidationSnackbar(context, missing);
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  void _pickDob() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 25)),
      firstDate:   DateTime(1940),
      lastDate:    DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary:   AppColors.champagneGold,
              onPrimary: AppColors.obsidianNight,
              surface:   Color(0xFF12121A),
              onSurface: AppColors.pearlWhite,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked == null) return;
    final age = _calcAge(picked);
    setState(() {
      _dob      = picked;
      _dobError = age < 18
          ? _isGuardianMode
              ? 'Your $_candidateLabel must be 18 or older to use NOOR.'
              : 'You must be 18 or older to use NOOR. We look forward to welcoming you then.'
          : '';
    });
  }

  int _calcAge(DateTime dob) {
    final now = DateTime.now();
    int years = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) { years--; }
    return years;
  }

  String _formatDob(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')} / '
      '${d.month.toString().padLeft(2, '0')} / '
      '${d.year}';

  List<Map<String, String>> get _filteredCities {
    final q = _cityCtrl.text.trim();
    if (q.isEmpty || _selectedCity != null) return [];
    final lower = q.toLowerCase();
    return _kCities
        .where((c) => c['name']!.toLowerCase().contains(lower))
        .take(6)
        .toList();
  }

  void _showMotherTonguePicker() {
    showModalBottomSheet<void>(
      context:            context,
      backgroundColor:    const Color(0xFF12121A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _GenericListPicker(
        title:      'Mother Tongue',
        options:    _countryLanguages,
        selected:   _motherTongue,
        onSelected: (v) {
          setState(() => _motherTongue = v);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showCommunityPicker() {
    showModalBottomSheet<void>(
      context:            context,
      backgroundColor:    const Color(0xFF12121A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _GenericListPicker(
        title:      CopyEngine.communityQuestion(_creatorRelation),
        options:    _countryCommunities,
        selected:   _community,
        onSelected: (v) {
          setState(() => _community = v);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _advance() async {
    final countryCode = _selectedCountryCode ?? 'XX';
    final cityName = _effectiveCity;
    final data = context.read<OnboardingCubit>().currentData.copyWith(
      firstName:    _firstNameCtrl.text.trim(),
      lastName:     _lastNameCtrl.text.trim(),
      dateOfBirth:  _dob,
      gender:       _gender,
      cityName:     cityName,
      cityId:       _selectedCityId ?? cityName.toLowerCase(),
      countryCode:  countryCode,
      heightCm:        _heightCm,
      complexion:      _complexion,
      motherTongue:    _motherTongue,
      community:       _community,
      residencyStatus: _residencyStatus,
      specialNeeds:    _specialNeeds,
    );

    // ── Gender & Country propagation ──────────────────────────
    // Propagate gender to AuthCubit NOW so all subscription gates read the correct value immediately.
    // Fixed Flaw 20: Avoid calling setGender twice in guardian flow.
    if (_gender != null && !_isGuardianMode) {
      context.read<AuthCubit>().setGender(
          _gender == Gender.female ? 'female' : 'male');
    }

    // Save country code for regional pricing (subscription screen)
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_country_code', countryCode);

    if (mounted) {
      context.read<AuthCubit>().setCountryCode(countryCode);
    }

    if (mounted) {
      context.read<OnboardingCubit>().saveAndAdvance(data);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OnboardingCubit, OnboardingState>(
      builder: (context, state) {
        final isLoading = state is OnboardingLoading;
        return OnboardingScaffold(
          ctaLabel:      'Continue',
          onCta:         _advance,
          isCtaEnabled:  _canProceed,
          isCtaLoading:  isLoading,
          onCtaDisabledTap: _showValidation,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppDimensions.space32),

              // Guardian mode banner
              if (_isGuardianMode) ...[
                Container(
                  padding: const EdgeInsets.all(AppDimensions.space14),
                  decoration: BoxDecoration(
                    color:        AppColors.champagneGold.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                    border:       Border.all(color: AppColors.goldBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.shield_outlined,
                          color: AppColors.champagneGold, size: 16),
                      const SizedBox(width: AppDimensions.space10),
                      Expanded(
                        child: Text(
                          'You are filling this as a guardian. '
                          'These details are about your $_candidateLabel.',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.champagneGold,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppDimensions.space20),
              ],

              StepHeader(
                title: _isGuardianMode
                    ? 'Tell us about your $_candidateLabel'
                    : 'Tell us about yourself',
                subtitle: _isGuardianMode
                    ? 'This is what others will see on their profile.'
                    : 'This is what others will see on your profile.',
              ),
              const SizedBox(height: AppDimensions.space32),

              // Name row
              Row(
                children: [
                  Expanded(
                    child: NoorTextField(
                      controller:         _firstNameCtrl,
                      label:              _isGuardianMode
                                              ? "Candidate's first name"
                                              : 'First name',
                      textCapitalization: TextCapitalization.words,
                      textInputAction:    TextInputAction.next,
                      onChanged:          (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: AppDimensions.space12),
                  Expanded(
                    child: NoorTextField(
                      controller:         _lastNameCtrl,
                      label:              _isGuardianMode
                                              ? 'Last name'
                                              : 'Last name',
                      textCapitalization: TextCapitalization.words,
                      textInputAction:    TextInputAction.next,
                      onChanged:          (_) => setState(() {}),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppDimensions.space20),

              // Date of birth
              const Text('DATE OF BIRTH', style: AppTypography.sectionLabel),
              const SizedBox(height: AppDimensions.space8),
              GestureDetector(
                onTap: _pickDob,
                child: Container(
                  height: AppDimensions.buttonHeight,
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: AppDimensions.space16,
                  ),
                  decoration: BoxDecoration(
                    color:        AppColors.inputSurface,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined,
                          color: AppColors.slateMist,
                          size:  AppDimensions.iconSizeMedium),
                      const SizedBox(width: AppDimensions.space12),
                      Text(
                        _dob != null ? _formatDob(_dob!) : 'Select date of birth',
                        style: _dob != null
                            ? AppTypography.inputText
                            : AppTypography.inputText.copyWith(
                                color: AppColors.slateMist),
                      ),
                    ],
                  ),
                ),
              ),
              if (_dobError.isNotEmpty) ...[
                const SizedBox(height: AppDimensions.space8),
                Text(_dobError,
                    style: AppTypography.caption.copyWith(
                        color: AppColors.softCoral)),
              ],

              const SizedBox(height: AppDimensions.space20),

              // Gender
              Text(
                _isGuardianMode ? "CANDIDATE'S GENDER" : 'GENDER',
                style: AppTypography.sectionLabel,
              ),
              const SizedBox(height: AppDimensions.space8),
              if (_genderLocked) ...[
                // Gender is pre-set by guardian flow — show read-only
                Container(
                  height: AppDimensions.buttonHeight,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.space16,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.champagneGold.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                    border: Border.all(color: AppColors.champagneGold),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _gender == Gender.male
                            ? Icons.male_rounded
                            : Icons.female_rounded,
                        color: AppColors.champagneGold,
                        size: 20,
                      ),
                      const SizedBox(width: AppDimensions.space12),
                      Text(
                        _gender == Gender.male ? 'Male' : 'Female',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.champagneGold,
                        ),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.lock_outline_rounded,
                        color: AppColors.slateMist,
                        size: 14,
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: _GenderPill(
                        label:      'Male',
                        icon:       Icons.male_rounded,
                        isSelected: _gender == Gender.male,
                        onTap:      () => setState(() => _gender = Gender.male),
                      ),
                    ),
                    const SizedBox(width: AppDimensions.space12),
                    Expanded(
                      child: _GenderPill(
                        label:      'Female',
                        icon:       Icons.female_rounded,
                        isSelected: _gender == Gender.female,
                        onTap:      () => setState(() => _gender = Gender.female),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: AppDimensions.space20),

              // City search
              Text(
                _isGuardianMode ? "THEIR CITY" : 'YOUR CITY',
                style: AppTypography.sectionLabel,
              ),
              const SizedBox(height: AppDimensions.space8),
              NoorTextField(
                controller:         _cityCtrl,
                hint:               'Type your city',
                prefixIcon:         Icons.location_on_outlined,
                textCapitalization: TextCapitalization.words,
                textInputAction:    TextInputAction.done,
                onChanged: (q) => setState(() {
                  // Clear locked selection so user can re-type
                  _selectedCity        = null;
                  _selectedCityId      = null;
                  _selectedCountryCode = null;
                  _selectedCountryName = null;
                  _showSuggestions     = q.trim().isNotEmpty;
                }),
              ),

              // Suggestions dropdown
              if (_showSuggestions && _filteredCities.isNotEmpty) ...[
                const SizedBox(height: AppDimensions.space4),
                Container(
                  decoration: BoxDecoration(
                    color:        AppColors.inputSurface,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                    border:       Border.all(color: AppColors.cardBorder),
                  ),
                  child: Column(
                    children: _filteredCities.map((city) {
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.location_city_outlined,
                            color: AppColors.slateMist, size: 18),
                        title: Text(city['name']!, style: AppTypography.body),
                        subtitle: Text(
                          city['countryName']!,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.slateMist,
                          ),
                        ),
                        onTap: () => setState(() {
                          _selectedCity        = city['name'];
                          _selectedCityId      = city['name']!.toLowerCase();
                          _selectedCountryCode = city['country'];
                          _selectedCountryName = city['countryName'];
                          _showSuggestions     = false;
                          _cityCtrl.text       = city['name']!;
                        }),
                      );
                    }).toList(),
                  ),
                ),
              ],

              // Confirmed city badge (picked from list) + country display
              if (_selectedCity != null) ...[
                const SizedBox(height: AppDimensions.space8),
                Row(
                  children: [
                    const Icon(Icons.check_circle_outline,
                        color: AppColors.verifiedTeal, size: 16),
                    const SizedBox(width: AppDimensions.space8),
                    Text(_selectedCity!, style: AppTypography.captionMedium),
                  ],
                ),
                if (_selectedCountryName != null) ...[
                  const SizedBox(height: AppDimensions.space6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.space16,
                      vertical:   AppDimensions.space12,
                    ),
                    decoration: BoxDecoration(
                      color:        AppColors.inputSurface,
                      borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                      border:       Border.all(color: AppColors.cardBorder),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.flag_outlined,
                            color: AppColors.slateMist, size: 18),
                        const SizedBox(width: AppDimensions.space12),
                        const Text('Country', style: AppTypography.inputLabel),
                        const Spacer(),
                        Text(_selectedCountryName!,
                            style: AppTypography.bodyMedium),
                      ],
                    ),
                  ),
                ],
              ],

              const SizedBox(height: AppDimensions.space28),

              // ── COMMUNITY / BIRADARI (Optional) ────────────────────
              Builder(builder: (ctx) {
                final rel = ctx.read<OnboardingCubit>().currentData.profileCreatorRelation ?? 'self';
                return Text('${CopyEngine.communityQuestion(rel).toUpperCase()}  (Optional)', style: AppTypography.sectionLabel);
              }),
              const SizedBox(height: AppDimensions.space12),
              GestureDetector(
                onTap: _showCommunityPicker,
                child: Container(
                  height: AppDimensions.buttonHeight,
                  padding: const EdgeInsets.symmetric(horizontal: AppDimensions.space16),
                  decoration: BoxDecoration(
                    color: AppColors.inputSurface,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                    border: Border.all(
                      color: _community != null ? AppColors.champagneGold : AppColors.cardBorder,
                      width: _community != null ? AppDimensions.borderFocus : AppDimensions.borderThin,
                    ),
                  ),
                  child: Row(children: [
                    Icon(Icons.groups_outlined,
                        color: _community != null ? AppColors.champagneGold : AppColors.slateMist,
                        size: AppDimensions.iconSizeMedium),
                    const SizedBox(width: AppDimensions.space12),
                    Expanded(child: Text(
                      _community ?? 'Select community (optional)',
                      style: AppTypography.inputText.copyWith(
                        color: _community != null ? AppColors.pearlWhite : AppColors.slateMist,
                      ),
                    )),
                    const Icon(Icons.expand_more_rounded, color: AppColors.slateMist),
                  ]),
                ),
              ),

              const SizedBox(height: AppDimensions.space28),

              // ── HEIGHT ─────────────────────────────────────────────
              Text(_isGuardianMode ? 'THEIR HEIGHT' : 'YOUR HEIGHT',
                  style: AppTypography.sectionLabel),
              const SizedBox(height: AppDimensions.space12),
              _HeightStepper(
                heightCm: _heightCm,
                onChanged: (v) => setState(() => _heightCm = v),
              ),

              const SizedBox(height: AppDimensions.space24),

              // ── COMPLEXION (Optional) ──────────────────────────────
              const Text('COMPLEXION  (Optional)', style: AppTypography.sectionLabel),
              const SizedBox(height: AppDimensions.space12),
              Wrap(
                spacing:    AppDimensions.space8,
                runSpacing: AppDimensions.space8,
                children: _kComplexions.map((o) => _SelectChip(
                  label:      o,
                  isSelected: _complexion == o,
                  onTap: () => setState(() =>
                      _complexion = _complexion == o ? null : o),
                )).toList(),
              ),

              const SizedBox(height: AppDimensions.space24),

              // ── MOTHER TONGUE (Required) ───────────────────────────
              const Text('MOTHER TONGUE', style: AppTypography.sectionLabel),
              const SizedBox(height: AppDimensions.space12),
              GestureDetector(
                onTap: _showMotherTonguePicker,
                child: Container(
                  height: AppDimensions.buttonHeight,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.space16,
                  ),
                  decoration: BoxDecoration(
                    color:        AppColors.inputSurface,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                    border: Border.all(
                      color: _motherTongue != null
                          ? AppColors.champagneGold
                          : AppColors.cardBorder,
                      width: _motherTongue != null
                          ? AppDimensions.borderFocus
                          : AppDimensions.borderThin,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.translate_rounded,
                          color: _motherTongue != null
                              ? AppColors.champagneGold
                              : AppColors.slateMist,
                          size: AppDimensions.iconSizeMedium),
                      const SizedBox(width: AppDimensions.space12),
                      Expanded(
                        child: Text(
                          _motherTongue ?? 'Select language',
                          style: AppTypography.inputText.copyWith(
                            color: _motherTongue != null
                                ? AppColors.pearlWhite
                                : AppColors.slateMist,
                          ),
                        ),
                      ),
                      const Icon(Icons.expand_more_rounded,
                          color: AppColors.slateMist),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AppDimensions.space28),

              // ── RESIDENCY STATUS (Optional) ─────────────────────────
              const Text('RESIDENCY STATUS  (Optional)', style: AppTypography.sectionLabel),
              const SizedBox(height: AppDimensions.space12),
              Wrap(
                spacing:    AppDimensions.space8,
                runSpacing: AppDimensions.space8,
                children: _kResidencyOptions.map((o) => _SelectChip(
                  label:      o,
                  isSelected: _residencyStatus == o,
                  onTap: () => setState(() =>
                      _residencyStatus = _residencyStatus == o ? null : o),
                )).toList(),
              ),

              const SizedBox(height: AppDimensions.space28),

              // ── SPECIAL NEEDS (Optional) ─────────────────────────────
              const Text('SPECIAL NEEDS  (Optional)', style: AppTypography.sectionLabel),
              const SizedBox(height: AppDimensions.space4),
              Container(
                padding: const EdgeInsets.all(AppDimensions.space10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceGlass,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.lock_outline_rounded,
                        color: AppColors.slateMist, size: 14),
                    SizedBox(width: AppDimensions.space8),
                    Expanded(
                      child: Text(
                        'This is only shared after mutual interest.',
                        style: AppTypography.caption,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimensions.space12),
              Wrap(
                spacing:    AppDimensions.space8,
                runSpacing: AppDimensions.space8,
                children: _kSpecialNeedsOptions.map((o) => _SelectChip(
                  label:      o,
                  isSelected: _specialNeeds == o,
                  onTap: () => setState(() =>
                      _specialNeeds = _specialNeeds == o ? null : o),
                )).toList(),
              ),

              const SizedBox(height: AppDimensions.space32),
            ],
          ),
        );
      },
    );
  }
}

// ── Gender pill button ────────────────────────────────────────

class _GenderPill extends StatelessWidget {
  const _GenderPill({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppDimensions.durationTransition,
        height: AppDimensions.buttonHeight,
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.champagneGold.withValues(alpha: 0.1)
              : AppColors.surfaceGlass,
          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          border: Border.all(
            color: isSelected ? AppColors.champagneGold : AppColors.cardBorder,
            width: isSelected ? AppDimensions.borderFocus : AppDimensions.borderThin,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                color: isSelected
                    ? AppColors.champagneGold
                    : AppColors.slateMist,
                size: AppDimensions.iconSizeMedium),
            const SizedBox(width: AppDimensions.space8),
            Text(label,
                style: AppTypography.bodyMedium.copyWith(
                  color: isSelected
                      ? AppColors.champagneGold
                      : AppColors.pearlWhite,
                )),
          ],
        ),
      ),
    );
  }
}

// ── Height Stepper ────────────────────────────────────────────

class _HeightStepper extends StatelessWidget {
  const _HeightStepper({
    required this.heightCm,
    required this.onChanged,
  });
  final int heightCm;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space16,
        vertical:   AppDimensions.space12,
      ),
      decoration: BoxDecoration(
        color:        AppColors.inputSurface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
        border:       Border.all(color: AppColors.goldBorder),
      ),
      child: Row(
        children: [
          // Minus button
          _StepperButton(
            icon:    Icons.remove_rounded,
            onTap:   heightCm > 140 ? () => onChanged(heightCm - 1) : null,
          ),
          const SizedBox(width: AppDimensions.space12),

          // Height display
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$heightCm cm',
                  style: AppTypography.bodyMedium.copyWith(
                    color:      AppColors.champagneGold,
                    fontSize:   22,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 2),
                Text(
                  _feetInchDisplay(heightCm),
                  style: AppTypography.caption,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const SizedBox(width: AppDimensions.space12),
          // Plus button
          _StepperButton(
            icon:  Icons.add_rounded,
            onTap: heightCm < 210 ? () => onChanged(heightCm + 1) : null,
          ),
        ],
      ),
    );
  }

  String _feetInchDisplay(int cm) {
    final totalInches = cm / 2.54;
    final feet        = totalInches ~/ 12;
    final inches      = totalInches.round() % 12;
    return '$feet ft $inches in';
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, required this.onTap});
  final IconData     icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width:  40,
        height: 40,
        decoration: BoxDecoration(
          color: enabled
              ? AppColors.champagneGold.withValues(alpha: 0.12)
              : AppColors.surfaceGlassHover,
          shape:  BoxShape.circle,
          border: Border.all(
            color: enabled ? AppColors.goldBorder : AppColors.cardBorder,
          ),
        ),
        child: Icon(icon,
          color: enabled ? AppColors.champagneGold : AppColors.slateMist,
          size:  20,
        ),
      ),
    );
  }
}

// ── Select Chip ───────────────────────────────────────────────

class _SelectChip extends StatelessWidget {
  const _SelectChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppDimensions.durationTransition,
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.space16,
          vertical:   AppDimensions.space10,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.champagneGold.withValues(alpha: 0.12)
              : AppColors.surfaceGlass,
          borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
          border: Border.all(
            color: isSelected ? AppColors.champagneGold : AppColors.cardBorder,
            width: isSelected ? AppDimensions.borderFocus : AppDimensions.borderThin,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.chipLabel.copyWith(
            color: isSelected ? AppColors.champagneGold : AppColors.pearlWhite,
          ),
        ),
      ),
    );
  }
}

// ── Generic List Picker sheet (replaces _MotherTonguePicker) ──
// Used for both Mother Tongue and Community pickers.
// Accepts any List<String> as options.

class _GenericListPicker extends StatefulWidget {
  const _GenericListPicker({
    required this.title,
    required this.options,
    required this.selected,
    required this.onSelected,
  });
  final String title;
  final List<String> options;
  final String? selected;
  final ValueChanged<String> onSelected;

  @override
  State<_GenericListPicker> createState() => _GenericListPickerState();
}

class _GenericListPickerState extends State<_GenericListPicker> {
  final _searchCtrl = TextEditingController();
  late List<String> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = List.from(widget.options);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch(String q) {
    final lower = q.trim().toLowerCase();
    setState(() {
      _filtered = lower.isEmpty
          ? List.from(widget.options)
          : widget.options.where((l) => l.toLowerCase().contains(lower)).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppDimensions.space16),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.slateMist.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppDimensions.space16),
            Text(widget.title, style: AppTypography.bodyMedium),
            const SizedBox(height: AppDimensions.space12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppDimensions.space16),
              child: TextField(
                controller: _searchCtrl,
                onChanged:  _onSearch,
                style:      AppTypography.inputText,
                decoration: InputDecoration(
                  hintText:  'Search…',
                  hintStyle: AppTypography.inputLabel,
                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.slateMist, size: 20),
                  filled: true, fillColor: AppColors.inputSurface,
                  contentPadding: const EdgeInsets.symmetric(horizontal: AppDimensions.space12, vertical: AppDimensions.space10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusButton), borderSide: const BorderSide(color: AppColors.cardBorder)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusButton), borderSide: const BorderSide(color: AppColors.cardBorder)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusButton), borderSide: const BorderSide(color: AppColors.champagneGold, width: AppDimensions.borderFocus)),
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.space8),
            Flexible(
              child: _filtered.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(AppDimensions.space24),
                      child: Text('Nothing found.', style: AppTypography.bodyMuted, textAlign: TextAlign.center),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const BouncingScrollPhysics(),
                      itemCount: _filtered.length,
                      itemBuilder: (_, i) {
                        final item = _filtered[i];
                        final isSel = item == widget.selected;
                        return ListTile(
                          title: Text(item, style: AppTypography.body),
                          trailing: isSel ? const Icon(Icons.check_rounded, color: AppColors.champagneGold, size: 20) : null,
                          selected: isSel,
                          selectedColor: AppColors.champagneGold,
                          onTap: () => widget.onSelected(item),
                        );
                      },
                    ),
            ),
            const SizedBox(height: AppDimensions.space16),
          ],
        ),
      ),
    );
  }
}
