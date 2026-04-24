// lib/features/onboarding/screens/basic_identity_screen.dart
// ============================================================
// NOOR — Basic Identity Screen (Onboarding Step 1)
// First name, last name, date of birth, gender, city search.
// City list: 300+ cities with country auto-fill.
// Under-18 DOB is blocked with a kind message.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/cubits/onboarding/onboarding_cubit.dart';
import '../../../core/cubits/onboarding/onboarding_state.dart';
import '../../../core/cubits/auth/auth_cubit.dart';
import '../../../core/models/onboarding_data.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
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

  /// City is valid if user either (a) picked from suggestions, or
  /// (b) typed at least 2 characters as a free-text city name.
  String get _effectiveCity => _selectedCity ?? _cityCtrl.text.trim();

  bool get _canProceed =>
      _firstNameCtrl.text.trim().isNotEmpty &&
      _lastNameCtrl.text.trim().isNotEmpty &&
      _dob != null &&
      _dobError.isEmpty &&
      _gender != null &&
      _effectiveCity.length >= 2;

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
            colorScheme: ColorScheme.dark(
              primary:   AppColors.champagneGold,
              onPrimary: AppColors.obsidianNight,
              surface:   const Color(0xFF12121A),
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
          ? 'You must be 18 or older to use NOOR. We look forward to welcoming you then.'
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

  void _advance() {
    final cityName = _effectiveCity;
    final data = context.read<OnboardingCubit>().currentData.copyWith(
      firstName:   _firstNameCtrl.text.trim(),
      lastName:    _lastNameCtrl.text.trim(),
      dateOfBirth: _dob,
      gender:      _gender,
      cityName:    cityName,
      cityId:      _selectedCityId ?? cityName.toLowerCase(),
      countryCode: _selectedCountryCode ?? 'XX',
    );

    // ── Gender propagation ────────────────────────────────────
    // Blueprint: "Women always message/interest free."
    // Propagate gender to AuthCubit NOW so all subscription gates,
    // daily-limit banners, and boost sections read the correct value
    // immediately — including when a guardian creates a female profile.
    if (_gender != null) {
      context.read<AuthCubit>().setGender(
          _gender == Gender.female ? 'female' : 'male');
    }

    context.read<OnboardingCubit>().saveAndAdvance(data);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OnboardingCubit, OnboardingState>(
      builder: (context, state) {
        final isLoading = state is OnboardingLoading;
        return OnboardingScaffold(
          step:          1,
          ctaLabel:      'Continue',
          onCta:         _advance,
          isCtaEnabled:  _canProceed,
          isCtaLoading:  isLoading,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppDimensions.space32),
              const StepHeader(
                title:    'Tell us about yourself',
                subtitle: 'This is what others will see on your profile.',
              ),
              const SizedBox(height: AppDimensions.space32),

              // Name row
              Row(
                children: [
                  Expanded(
                    child: NoorTextField(
                      controller:         _firstNameCtrl,
                      label:              'First name',
                      textCapitalization: TextCapitalization.words,
                      textInputAction:    TextInputAction.next,
                      onChanged:          (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: AppDimensions.space12),
                  Expanded(
                    child: NoorTextField(
                      controller:         _lastNameCtrl,
                      label:              'Last name',
                      textCapitalization: TextCapitalization.words,
                      textInputAction:    TextInputAction.next,
                      onChanged:          (_) => setState(() {}),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppDimensions.space20),

              // Date of birth
              Text('DATE OF BIRTH', style: AppTypography.sectionLabel),
              const SizedBox(height: AppDimensions.space8),
              GestureDetector(
                onTap: _pickDob,
                child: Container(
                  height: AppDimensions.buttonHeight,
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: AppDimensions.space16,
                  ),
                  decoration: BoxDecoration(
                    color:        AppColors.surfaceGlass,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today_outlined,
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
              Text('GENDER', style: AppTypography.sectionLabel),
              const SizedBox(height: AppDimensions.space8),
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

              const SizedBox(height: AppDimensions.space20),

              // City search
              Text('YOUR CITY', style: AppTypography.sectionLabel),
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
                    color:        AppColors.surfaceGlass,
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
                      color:        AppColors.surfaceGlass,
                      borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                      border:       Border.all(color: AppColors.cardBorder),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.flag_outlined,
                            color: AppColors.slateMist, size: 18),
                        const SizedBox(width: AppDimensions.space12),
                        Text('Country', style: AppTypography.inputLabel),
                        const Spacer(),
                        Text(_selectedCountryName!,
                            style: AppTypography.bodyMedium),
                      ],
                    ),
                  ),
                ],
              ],

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
