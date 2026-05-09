// lib/core/config/pricing_config.dart
// ============================================================
// NOOR — Regional Pricing Configuration
//
// Country code is stored in SharedPreferences under key:
//   'user_country_code'  (set during onboarding city selection)
//
// Pricing tiers with localized currencies:
//   Tier 3 Ultra-Low: South/South-East Asia + Africa
//   Tier 2 Low:       Turkey, Malaysia, MENA ex-Gulf
//   Gulf Premium:     AE, SA, QA, KW, OM, BH
//   Tier 1 Standard:  Western markets
//   Default:          $4.99 / $44.99
// ============================================================

class PricingTier {
  const PricingTier({
    required this.monthlyPrice,
    required this.annualPrice,
    required this.monthlyCta,
    required this.annualCta,
    required this.savingsPercent,
    required this.billingNote,
  });

  final String monthlyPrice;
  final String annualPrice;
  final String monthlyCta;
  final String annualCta;
  final int    savingsPercent;
  final String billingNote;
}

/// Per-country localized pricing with native currency.
class CountryPricing {
  const CountryPricing({
    required this.countryCode,
    required this.currencyCode,
    required this.currencySymbol,
    required this.monthlyPrice,
    required this.annualPrice,
    required this.savingsPercent,
  });

  final String countryCode;
  final String currencyCode;
  final String currencySymbol;
  final String monthlyPrice;
  final String annualPrice;
  final int    savingsPercent;

  /// Creates a [PricingTier] from this localized pricing.
  PricingTier toPricingTier() => PricingTier(
    monthlyPrice:   '$currencySymbol$monthlyPrice',
    annualPrice:    '$currencySymbol$annualPrice',
    monthlyCta:     'Subscribe — $currencySymbol$monthlyPrice / month',
    annualCta:      'Subscribe — $currencySymbol$annualPrice / year',
    savingsPercent: savingsPercent,
    billingNote:    'Billed monthly',
  );
}

abstract final class PricingConfig {
  // ── Per-country localized pricing ──────────────────────────

  static const Map<String, CountryPricing> _countryPricing = {
    // ── South Asia (Ultra-Low) ────────────────────────────────
    'IN': CountryPricing(countryCode: 'IN', currencyCode: 'INR', currencySymbol: '₹',   monthlyPrice: '249',   annualPrice: '2,499',  savingsPercent: 16),
    'PK': CountryPricing(countryCode: 'PK', currencyCode: 'PKR', currencySymbol: 'Rs.',  monthlyPrice: '699',   annualPrice: '6,999',  savingsPercent: 17),
    'BD': CountryPricing(countryCode: 'BD', currencyCode: 'BDT', currencySymbol: '৳',    monthlyPrice: '499',   annualPrice: '4,999',  savingsPercent: 17),
    'LK': CountryPricing(countryCode: 'LK', currencyCode: 'LKR', currencySymbol: 'Rs.',  monthlyPrice: '1,499', annualPrice: '14,999', savingsPercent: 17),
    'NP': CountryPricing(countryCode: 'NP', currencyCode: 'NPR', currencySymbol: 'Rs.',  monthlyPrice: '399',   annualPrice: '3,999',  savingsPercent: 17),
    'AF': CountryPricing(countryCode: 'AF', currencyCode: 'AFN', currencySymbol: '؋',    monthlyPrice: '399',   annualPrice: '3,999',  savingsPercent: 17),

    // ── Southeast Asia (Ultra-Low) ────────────────────────────
    'ID': CountryPricing(countryCode: 'ID', currencyCode: 'IDR', currencySymbol: 'Rp',   monthlyPrice: '79,000',  annualPrice: '749,000', savingsPercent: 21),
    'PH': CountryPricing(countryCode: 'PH', currencyCode: 'PHP', currencySymbol: '₱',    monthlyPrice: '249',     annualPrice: '2,499',   savingsPercent: 16),
    'MM': CountryPricing(countryCode: 'MM', currencyCode: 'MMK', currencySymbol: 'K',    monthlyPrice: '9,999',   annualPrice: '99,999',  savingsPercent: 17),

    // ── Africa (Ultra-Low) ────────────────────────────────────
    'NG': CountryPricing(countryCode: 'NG', currencyCode: 'NGN', currencySymbol: '₦',    monthlyPrice: '2,999',  annualPrice: '29,999', savingsPercent: 17),
    'EG': CountryPricing(countryCode: 'EG', currencyCode: 'EGP', currencySymbol: 'E£',   monthlyPrice: '149',    annualPrice: '1,499',  savingsPercent: 16),
    'KE': CountryPricing(countryCode: 'KE', currencyCode: 'KES', currencySymbol: 'KSh',  monthlyPrice: '499',    annualPrice: '4,999',  savingsPercent: 17),
    'TZ': CountryPricing(countryCode: 'TZ', currencyCode: 'TZS', currencySymbol: 'TSh',  monthlyPrice: '9,999',  annualPrice: '99,999', savingsPercent: 17),
    'GH': CountryPricing(countryCode: 'GH', currencyCode: 'GHS', currencySymbol: 'GH₵',  monthlyPrice: '49',     annualPrice: '499',    savingsPercent: 15),
    'ET': CountryPricing(countryCode: 'ET', currencyCode: 'ETB', currencySymbol: 'Br',   monthlyPrice: '249',    annualPrice: '2,499',  savingsPercent: 17),
    'SD': CountryPricing(countryCode: 'SD', currencyCode: 'SDG', currencySymbol: 'SDG',  monthlyPrice: '2,999',  annualPrice: '29,999', savingsPercent: 17),
    'SO': CountryPricing(countryCode: 'SO', currencyCode: 'USD', currencySymbol: '\$',   monthlyPrice: '2.99',   annualPrice: '29.99',  savingsPercent: 17),

    // ── MENA Low ──────────────────────────────────────────────
    'TR': CountryPricing(countryCode: 'TR', currencyCode: 'TRY', currencySymbol: '₺',    monthlyPrice: '149',    annualPrice: '1,349',  savingsPercent: 25),
    'MY': CountryPricing(countryCode: 'MY', currencyCode: 'MYR', currencySymbol: 'RM',   monthlyPrice: '19.90',  annualPrice: '179',    savingsPercent: 25),
    'MA': CountryPricing(countryCode: 'MA', currencyCode: 'MAD', currencySymbol: 'MAD',  monthlyPrice: '49',     annualPrice: '449',    savingsPercent: 24),
    'DZ': CountryPricing(countryCode: 'DZ', currencyCode: 'DZD', currencySymbol: 'DA',   monthlyPrice: '699',    annualPrice: '6,299',  savingsPercent: 25),
    'TN': CountryPricing(countryCode: 'TN', currencyCode: 'TND', currencySymbol: 'DT',   monthlyPrice: '14.90',  annualPrice: '134',    savingsPercent: 25),
    'IQ': CountryPricing(countryCode: 'IQ', currencyCode: 'IQD', currencySymbol: 'IQD',  monthlyPrice: '5,999',  annualPrice: '53,999', savingsPercent: 25),
    'LB': CountryPricing(countryCode: 'LB', currencyCode: 'USD', currencySymbol: '\$',   monthlyPrice: '4.99',   annualPrice: '44.99',  savingsPercent: 25),
    'JO': CountryPricing(countryCode: 'JO', currencyCode: 'JOD', currencySymbol: 'JD',   monthlyPrice: '2.99',   annualPrice: '26.99',  savingsPercent: 25),
    'KZ': CountryPricing(countryCode: 'KZ', currencyCode: 'KZT', currencySymbol: '₸',    monthlyPrice: '2,499',  annualPrice: '22,499', savingsPercent: 25),

    // ── Gulf Premium ──────────────────────────────────────────
    'AE': CountryPricing(countryCode: 'AE', currencyCode: 'AED', currencySymbol: 'AED ', monthlyPrice: '24.99', annualPrice: '219',    savingsPercent: 27),
    'SA': CountryPricing(countryCode: 'SA', currencyCode: 'SAR', currencySymbol: 'SAR ', monthlyPrice: '24.99', annualPrice: '219',    savingsPercent: 27),
    'QA': CountryPricing(countryCode: 'QA', currencyCode: 'QAR', currencySymbol: 'QAR ', monthlyPrice: '24.99', annualPrice: '219',    savingsPercent: 27),
    'KW': CountryPricing(countryCode: 'KW', currencyCode: 'KWD', currencySymbol: 'KD',   monthlyPrice: '1.99',  annualPrice: '16.99',  savingsPercent: 29),
    'OM': CountryPricing(countryCode: 'OM', currencyCode: 'OMR', currencySymbol: 'OMR ', monthlyPrice: '2.49',  annualPrice: '21.99',  savingsPercent: 26),
    'BH': CountryPricing(countryCode: 'BH', currencyCode: 'BHD', currencySymbol: 'BD',   monthlyPrice: '2.49',  annualPrice: '21.99',  savingsPercent: 26),

    // ── Western Standard ──────────────────────────────────────
    'US': CountryPricing(countryCode: 'US', currencyCode: 'USD', currencySymbol: '\$',   monthlyPrice: '9.99',  annualPrice: '79.99',  savingsPercent: 33),
    'CA': CountryPricing(countryCode: 'CA', currencyCode: 'CAD', currencySymbol: 'CA\$', monthlyPrice: '12.99', annualPrice: '99.99',  savingsPercent: 36),
    'GB': CountryPricing(countryCode: 'GB', currencyCode: 'GBP', currencySymbol: '£',    monthlyPrice: '7.99',  annualPrice: '64.99',  savingsPercent: 32),
    'AU': CountryPricing(countryCode: 'AU', currencyCode: 'AUD', currencySymbol: 'A\$',  monthlyPrice: '14.99', annualPrice: '119.99', savingsPercent: 33),
    'DE': CountryPricing(countryCode: 'DE', currencyCode: 'EUR', currencySymbol: '€',    monthlyPrice: '8.99',  annualPrice: '74.99',  savingsPercent: 31),
    'FR': CountryPricing(countryCode: 'FR', currencyCode: 'EUR', currencySymbol: '€',    monthlyPrice: '8.99',  annualPrice: '74.99',  savingsPercent: 31),
    'NL': CountryPricing(countryCode: 'NL', currencyCode: 'EUR', currencySymbol: '€',    monthlyPrice: '8.99',  annualPrice: '74.99',  savingsPercent: 31),
    'SE': CountryPricing(countryCode: 'SE', currencyCode: 'SEK', currencySymbol: 'kr',   monthlyPrice: '99',    annualPrice: '799',    savingsPercent: 33),
    'NO': CountryPricing(countryCode: 'NO', currencyCode: 'NOK', currencySymbol: 'kr',   monthlyPrice: '99',    annualPrice: '799',    savingsPercent: 33),
    'NZ': CountryPricing(countryCode: 'NZ', currencyCode: 'NZD', currencySymbol: 'NZ\$', monthlyPrice: '14.99', annualPrice: '119.99', savingsPercent: 33),
    'CH': CountryPricing(countryCode: 'CH', currencyCode: 'CHF', currencySymbol: 'CHF ', monthlyPrice: '9.99',  annualPrice: '84.99',  savingsPercent: 29),
    'IE': CountryPricing(countryCode: 'IE', currencyCode: 'EUR', currencySymbol: '€',    monthlyPrice: '8.99',  annualPrice: '74.99',  savingsPercent: 31),
    'BE': CountryPricing(countryCode: 'BE', currencyCode: 'EUR', currencySymbol: '€',    monthlyPrice: '8.99',  annualPrice: '74.99',  savingsPercent: 31),
    'AT': CountryPricing(countryCode: 'AT', currencyCode: 'EUR', currencySymbol: '€',    monthlyPrice: '8.99',  annualPrice: '74.99',  savingsPercent: 31),
  };

  // ── Fallback tiers (for countries not in _countryPricing) ──

  static const _tierSets = {
    'IN', 'PK', 'BD', 'LK', 'NP', 'AF', 'ID', 'PH', 'MM',
    'NG', 'EG', 'KE', 'TZ', 'GH', 'ET', 'SD', 'SO',
    'YE', 'UZ', 'MV',
  };

  static const _lowSets = {
    'TR', 'MY', 'TH', 'MX', 'KZ', 'MA', 'DZ', 'TN',
    'IQ', 'SY', 'LY', 'LB', 'JO',
  };

  static const _gulfSets = {
    'AE', 'SA', 'QA', 'KW', 'OM', 'BH',
  };

  // ── Tier definitions (legacy, for fallback) ────────────────

  static const _tierUltraLow = PricingTier(
    monthlyPrice:    '₹249',
    annualPrice:     '₹2,499',
    monthlyCta:      'Subscribe — ₹249 / month',
    annualCta:       'Subscribe — ₹2,499 / year',
    savingsPercent:  16,
    billingNote:     'Billed monthly',
  );

  static const _tierLow = PricingTier(
    monthlyPrice:    '\$4.99',
    annualPrice:     '\$44.99',
    monthlyCta:      'Subscribe — \$4.99 / month',
    annualCta:       'Subscribe — \$44.99 / year',
    savingsPercent:  25,
    billingNote:     'Billed monthly',
  );

  static const _tierGulf = PricingTier(
    monthlyPrice:    '\$6.99',
    annualPrice:     '\$59.99',
    monthlyCta:      'Subscribe — \$6.99 / month',
    annualCta:       'Subscribe — \$59.99 / year',
    savingsPercent:  29,
    billingNote:     'Billed monthly',
  );

  // ignore: unused_field
  static const _tierStandard = PricingTier(
    monthlyPrice:    '\$9.99',
    annualPrice:     '\$79.99',
    monthlyCta:      'Subscribe — \$9.99 / month',
    annualCta:       'Subscribe — \$79.99 / year',
    savingsPercent:  33,
    billingNote:     'Billed monthly',
  );

  static const _tierDefault = PricingTier(
    monthlyPrice:    '\$4.99',
    annualPrice:     '\$44.99',
    monthlyCta:      'Subscribe — \$4.99 / month',
    annualCta:       'Subscribe — \$44.99 / year',
    savingsPercent:  25,
    billingNote:     'Billed monthly',
  );

  // ── Public API ───────────────────────────────────────────────

  /// Returns the correct [PricingTier] for a given country code.
  /// First checks per-country localized pricing, then falls back to tiers.
  static PricingTier getForCountryCode(String countryCode) {
    final code = countryCode.toUpperCase();

    // Try localized pricing first
    final localized = _countryPricing[code];
    if (localized != null) return localized.toPricingTier();

    // Fallback to tier sets
    if (_tierSets.contains(code)) return _tierUltraLow;
    if (_lowSets.contains(code))  return _tierLow;
    if (_gulfSets.contains(code)) return _tierGulf;
    return _tierDefault;
  }

  /// Returns the raw [CountryPricing] for a given country code, or null.
  static CountryPricing? getLocalizedPricing(String countryCode) {
    return _countryPricing[countryCode.toUpperCase()];
  }
}
