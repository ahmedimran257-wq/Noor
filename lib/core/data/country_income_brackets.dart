// lib/core/data/country_income_brackets.dart
// ============================================================
// MITHAQ — Multi-Currency Income Brackets for 15 Countries
// ============================================================

class IncomeBracketData {
  final int id;
  final String label;
  const IncomeBracketData(this.id, this.label);
}

/// Returns null for countries where income is hidden (SA — culturally sensitive).
/// Falls back to 'IN' brackets for any unrecognised country code.
const Map<String, List<IncomeBracketData>?> kCountryIncomeBrackets = {
  'IN': [ IncomeBracketData(1, '< ₹3 Lakh/year'),   IncomeBracketData(2, '₹3–6 Lakh/year'),   IncomeBracketData(3, '₹6–12 Lakh/year'),  IncomeBracketData(4, '₹12–25 Lakh/year'), IncomeBracketData(5, '> ₹25 Lakh/year') ],
  'PK': [ IncomeBracketData(1, '< PKR 6 Lakh/year'), IncomeBracketData(2, 'PKR 6–12 Lakh/year'), IncomeBracketData(3, 'PKR 12–25 Lakh/year'), IncomeBracketData(4, 'PKR 25–50 Lakh/year'), IncomeBracketData(5, '> PKR 50 Lakh/year') ],
  'GB': [ IncomeBracketData(1, '< £20k/year'),       IncomeBracketData(2, '£20–35k/year'),      IncomeBracketData(3, '£35–60k/year'),     IncomeBracketData(4, '£60–100k/year'),    IncomeBracketData(5, '> £100k/year') ],
  'US': [ IncomeBracketData(1, '< \$30k/year'),      IncomeBracketData(2, '\$30–60k/year'),     IncomeBracketData(3, '\$60–100k/year'),   IncomeBracketData(4, '\$100–200k/year'),  IncomeBracketData(5, '> \$200k/year') ],
  'AE': [ IncomeBracketData(1, '< AED 60k/year'),    IncomeBracketData(2, 'AED 60–120k/year'),  IncomeBracketData(3, 'AED 120–240k/year'), IncomeBracketData(4, 'AED 240–500k/year'), IncomeBracketData(5, '> AED 500k/year') ],
  'CA': [ IncomeBracketData(1, '< CAD 35k/year'),    IncomeBracketData(2, 'CAD 35–65k/year'),   IncomeBracketData(3, 'CAD 65–110k/year'),  IncomeBracketData(4, 'CAD 110–200k/year'), IncomeBracketData(5, '> CAD 200k/year') ],
  'AU': [ IncomeBracketData(1, '< AUD 40k/year'),    IncomeBracketData(2, 'AUD 40–75k/year'),   IncomeBracketData(3, 'AUD 75–130k/year'),  IncomeBracketData(4, 'AUD 130–250k/year'), IncomeBracketData(5, '> AUD 250k/year') ],
  'DE': [ IncomeBracketData(1, '< €25k/year'),       IncomeBracketData(2, '€25–45k/year'),      IncomeBracketData(3, '€45–80k/year'),     IncomeBracketData(4, '€80–150k/year'),    IncomeBracketData(5, '> €150k/year') ],
  'FR': [ IncomeBracketData(1, '< €22k/year'),       IncomeBracketData(2, '€22–40k/year'),      IncomeBracketData(3, '€40–70k/year'),     IncomeBracketData(4, '€70–130k/year'),    IncomeBracketData(5, '> €130k/year') ],
  'TR': [ IncomeBracketData(1, '< ₺300k/year'),      IncomeBracketData(2, '₺300–600k/year'),    IncomeBracketData(3, '₺600k–1.2M/year'), IncomeBracketData(4, '₺1.2–3M/year'),     IncomeBracketData(5, '> ₺3M/year') ],
  'BD': [ IncomeBracketData(1, '< BDT 3 Lakh/year'), IncomeBracketData(2, 'BDT 3–6 Lakh/year'), IncomeBracketData(3, 'BDT 6–15 Lakh/year'), IncomeBracketData(4, 'BDT 15–30 Lakh/year'), IncomeBracketData(5, '> BDT 30 Lakh/year') ],
  'MY': [ IncomeBracketData(1, '< MYR 30k/year'),    IncomeBracketData(2, 'MYR 30–60k/year'),   IncomeBracketData(3, 'MYR 60–120k/year'),  IncomeBracketData(4, 'MYR 120–250k/year'), IncomeBracketData(5, '> MYR 250k/year') ],
  'NG': [ IncomeBracketData(1, '< ₦1.5M/year'),      IncomeBracketData(2, '₦1.5–4M/year'),      IncomeBracketData(3, '₦4–10M/year'),      IncomeBracketData(4, '₦10–25M/year'),     IncomeBracketData(5, '> ₦25M/year') ],
  'EG': [ IncomeBracketData(1, '< EGP 60k/year'),    IncomeBracketData(2, 'EGP 60–150k/year'),  IncomeBracketData(3, 'EGP 150–350k/year'), IncomeBracketData(4, 'EGP 350–700k/year'), IncomeBracketData(5, '> EGP 700k/year') ],
  'SA': null, // Hidden entirely — culturally sensitive
};

/// Helper: returns brackets for a country, falling back to 'IN'.
List<IncomeBracketData>? bracketsFor(String? countryCode) =>
    kCountryIncomeBrackets[countryCode ?? 'IN'] ?? kCountryIncomeBrackets['IN'];

/// Helper: returns the currency code string for the given country code.
String currencyFor(String? countryCode) {
  switch (countryCode) {
    case 'IN': return 'INR';
    case 'PK': return 'PKR';
    case 'GB': return 'GBP';
    case 'US': return 'USD';
    case 'AE': return 'AED';
    case 'CA': return 'CAD';
    case 'AU': return 'AUD';
    case 'DE':
    case 'FR': return 'EUR';
    case 'TR': return 'TRY';
    case 'BD': return 'BDT';
    case 'MY': return 'MYR';
    case 'NG': return 'NGN';
    case 'EG': return 'EGP';
    default: return 'INR';
  }
}
