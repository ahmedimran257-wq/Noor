// lib/core/config/pricing_config.dart
// ============================================================
// NOOR — Regional Pricing Configuration (Item 23)
//
// Country code is stored in SharedPreferences under key:
//   'user_country_code'  (set during onboarding city selection)
//
// Pricing tiers:
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

abstract final class PricingConfig {
  // ── Country code → tier mapping ──────────────────────────────

  static const _ultraLow = {
    'IN', 'PK', 'BD', 'ID', 'NG', 'EG',
    'PH', 'MM', 'SD', 'YE', 'ET', 'GH',
    'TZ', 'KE', 'UZ', 'AF',
  };

  static const _low = {
    'TR', 'MY', 'TH', 'MX', 'KZ', 'MA', 'DZ', 'TN',
    'IQ', 'SY', 'LY', 'SO', 'LB',
  };

  static const _gulf = {
    'AE', 'SA', 'QA', 'KW', 'OM', 'BH',
  };

  static const _standard = {
    'GB', 'US', 'CA', 'AU', 'DE', 'FR', 'NL',
    'BE', 'SE', 'NO', 'IE', 'NZ', 'CH', 'AT',
  };

  // ── Tier definitions ─────────────────────────────────────────

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

  /// Returns the correct PricingTier for a given country code.
  /// Pass an empty string to get the default tier.
  static PricingTier getForCountryCode(String countryCode) {
    final code = countryCode.toUpperCase();
    if (_ultraLow.contains(code)) return _tierUltraLow;
    if (_low.contains(code))      return _tierLow;
    if (_gulf.contains(code))     return _tierGulf;
    if (_standard.contains(code)) return _tierStandard;
    return _tierDefault;
  }
}
