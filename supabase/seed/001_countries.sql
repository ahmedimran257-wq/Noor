-- ============================================================
-- SEED 001: COUNTRIES
-- All 15 Phase 1 markets with their cultural configuration.
-- Data matches the Country Configuration Matrix in the Blueprint.
-- ============================================================

INSERT INTO countries
  (code, name, dialing_code, currency, default_lang, rtl,
   show_sect, show_sub_sect, wali_requirement, pricing_tier)
VALUES
  -- South Asia
  ('IN', 'India',       '+91',  'INR', 'en',  false, true,  true,  'recommended', 'tier_3'),
  ('PK', 'Pakistan',    '+92',  'PKR', 'ur',  true,  true,  true,  'recommended', 'tier_3'),
  ('BD', 'Bangladesh',  '+880', 'BDT', 'en',  false, true,  false, 'recommended', 'tier_3'),

  -- Western Anglophone
  ('GB', 'United Kingdom',  '+44', 'GBP', 'en', false, true,  true,  'optional', 'tier_1'),
  ('US', 'United States',   '+1',  'USD', 'en', false, true,  true,  'optional', 'tier_1'),
  ('CA', 'Canada',          '+1',  'CAD', 'en', false, true,  true,  'optional', 'tier_1'),

  -- Gulf (wali mandatory, sect hidden per blueprint)
  ('AE', 'United Arab Emirates', '+971', 'AED', 'ar', true, false, false, 'mandatory', 'premium'),
  ('SA', 'Saudi Arabia',         '+966', 'SAR', 'ar', true, false, false, 'mandatory', 'premium'),

  -- Southeast Asia
  ('MY', 'Malaysia',    '+60',  'MYR', 'ms',  false, true,  false, 'recommended', 'tier_2'),
  ('ID', 'Indonesia',   '+62',  'IDR', 'id',  false, true,  false, 'recommended', 'tier_3'),

  -- Tier 2 / Other
  ('TR', 'Turkey',      '+90',  'TRY', 'tr',  false, true,  false, 'optional',    'tier_2'),
  ('EG', 'Egypt',       '+20',  'EGP', 'ar',  true,  true,  false, 'recommended', 'tier_3'),
  ('NG', 'Nigeria',     '+234', 'NGN', 'en',  false, true,  false, 'recommended', 'tier_3'),

  -- Europe
  ('DE', 'Germany',     '+49',  'EUR', 'de',  false, true,  true,  'optional', 'tier_1'),
  ('FR', 'France',      '+33',  'EUR', 'fr',  false, true,  false, 'optional', 'tier_1')

ON CONFLICT (code) DO UPDATE SET
  name             = EXCLUDED.name,
  dialing_code     = EXCLUDED.dialing_code,
  currency         = EXCLUDED.currency,
  default_lang     = EXCLUDED.default_lang,
  rtl              = EXCLUDED.rtl,
  show_sect        = EXCLUDED.show_sect,
  show_sub_sect    = EXCLUDED.show_sub_sect,
  wali_requirement = EXCLUDED.wali_requirement,
  pricing_tier     = EXCLUDED.pricing_tier;
