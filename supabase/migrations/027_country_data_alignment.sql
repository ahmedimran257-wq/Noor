-- ============================================================
-- MIGRATION 027: COUNTRY DATA ALIGNMENT
--
-- Aligns the countries reference table with the expanded
-- 249-country client-side country_data.dart:
--   1. Adds phone_format column (nullable) for live number formatting
--   2. Adds display_priority column for popular-section ordering
--   3. Inserts all countries from the Flutter country_data.dart list
--      that are not yet in the countries table
-- ============================================================

-- ── Step 1: Add new columns ──────────────────────────────────

ALTER TABLE countries
  ADD COLUMN IF NOT EXISTS phone_format     text,          -- e.g. '##### #####' for India
  ADD COLUMN IF NOT EXISTS display_priority int NOT NULL DEFAULT 0;
                                                           -- 10 = Muslim-majority top markets
                                                           --  5 = diaspora destinations
                                                           --  0 = all others

COMMENT ON COLUMN countries.phone_format IS
  'National phone number format pattern. ''#'' = digit placeholder, '' '' = space, ''-'' = dash. '
  'Used by the Flutter app for live number formatting.';

COMMENT ON COLUMN countries.display_priority IS
  'Controls ordering in the country picker. 10 = Muslim-majority markets (shown first), '
  '5 = major diaspora destinations, 0 = alphabetical list.';

-- ── Step 2: Update existing Phase 1 countries with format + priority ──

UPDATE countries SET phone_format = '##### #####',    display_priority = 10 WHERE code = 'IN';
UPDATE countries SET phone_format = '### #######',    display_priority = 10 WHERE code = 'PK';
UPDATE countries SET phone_format = '####-######',    display_priority = 10 WHERE code = 'BD';
UPDATE countries SET phone_format = '### #### ####',  display_priority = 10 WHERE code = 'ID';
UPDATE countries SET phone_format = '## ### ####',    display_priority = 10 WHERE code = 'SA';
UPDATE countries SET phone_format = '## ### ####',    display_priority = 10 WHERE code = 'AE';
UPDATE countries SET phone_format = '##-#### ####',   display_priority = 10 WHERE code = 'MY';
UPDATE countries SET phone_format = '### ### ####',   display_priority = 10 WHERE code = 'TR';
UPDATE countries SET phone_format = '### #### ####',  display_priority = 10 WHERE code = 'EG';
UPDATE countries SET phone_format = '### ### ####',   display_priority = 10 WHERE code = 'NG';
UPDATE countries SET phone_format = '#### ######',    display_priority = 5  WHERE code = 'GB';
UPDATE countries SET phone_format = '(###) ###-####', display_priority = 5  WHERE code = 'US';
UPDATE countries SET phone_format = '(###) ###-####', display_priority = 5  WHERE code = 'CA';
UPDATE countries SET phone_format = '#### #######',   display_priority = 5  WHERE code = 'DE';
UPDATE countries SET phone_format = '# ## ## ## ##',  display_priority = 5  WHERE code = 'FR';

-- ── Step 3: Insert all remaining countries ───────────────────
-- Uses ON CONFLICT to skip any that already exist.
-- Countries without specific cultural config get sensible defaults.

INSERT INTO countries
  (code, name, dialing_code, currency, default_lang, rtl,
   show_sect, show_sub_sect, wali_requirement, pricing_tier,
   phone_format, display_priority)
VALUES
  -- ── Popular — Muslim-majority (not already in Phase 1) ─────
  ('QA', 'Qatar',                '+974', 'QAR', 'ar', true,  false, false, 'mandatory',   'premium',  '#### ####',      10),
  ('KW', 'Kuwait',              '+965', 'KWD', 'ar', true,  false, false, 'mandatory',   'premium',  '#### ####',      10),
  ('BH', 'Bahrain',             '+973', 'BHD', 'ar', true,  false, false, 'mandatory',   'premium',  '#### ####',      10),
  ('OM', 'Oman',                '+968', 'OMR', 'ar', true,  false, false, 'mandatory',   'premium',  '#### ####',      10),

  -- ── Popular — Diaspora destinations (not already in Phase 1)
  ('AU', 'Australia',           '+61',  'AUD', 'en', false, true,  false, 'optional',    'tier_1',   '### ### ###',    5),
  ('NL', 'Netherlands',         '+31',  'EUR', 'nl', false, true,  false, 'optional',    'tier_1',   '## ### ####',    5),
  ('SE', 'Sweden',              '+46',  'SEK', 'sv', false, true,  false, 'optional',    'tier_1',   '## ### ## ##',   5),
  ('NO', 'Norway',              '+47',  'NOK', 'nb', false, true,  false, 'optional',    'tier_1',   '### ## ###',     5),
  ('SG', 'Singapore',           '+65',  'SGD', 'en', false, true,  false, 'optional',    'tier_1',   '#### ####',      5),
  ('ZA', 'South Africa',        '+27',  'ZAR', 'en', false, true,  false, 'optional',    'tier_2',   '## ### ####',    5),

  -- ── A ──────────────────────────────────────────────────────
  ('AF', 'Afghanistan',         '+93',  'AFN', 'ps', true,  true,  false, 'mandatory',   'tier_3',   '## ### ####',    0),
  ('AL', 'Albania',             '+355', 'ALL', 'sq', false, true,  false, 'optional',    'tier_3',   '## ### ####',    0),
  ('DZ', 'Algeria',             '+213', 'DZD', 'ar', true,  true,  false, 'recommended', 'tier_3',   '### ## ## ##',   0),
  ('AD', 'Andorra',             '+376', 'EUR', 'ca', false, true,  false, 'optional',    'tier_1',   '### ###',        0),
  ('AO', 'Angola',              '+244', 'AOA', 'pt', false, true,  false, 'optional',    'tier_3',   '### ### ###',    0),
  ('AG', 'Antigua & Barbuda',   '+1',   'XCD', 'en', false, true,  false, 'optional',    'tier_2',   NULL,             0),
  ('AR', 'Argentina',           '+54',  'ARS', 'es', false, true,  false, 'optional',    'tier_2',   '## ####-####',   0),
  ('AM', 'Armenia',             '+374', 'AMD', 'hy', false, true,  false, 'optional',    'tier_3',   '## ######',      0),
  ('AT', 'Austria',             '+43',  'EUR', 'de', false, true,  false, 'optional',    'tier_1',   '### #######',    0),
  ('AZ', 'Azerbaijan',          '+994', 'AZN', 'az', false, true,  false, 'optional',    'tier_3',   '## ### ## ##',   0),

  -- ── B ──────────────────────────────────────────────────────
  ('BS', 'Bahamas',             '+1',   'BSD', 'en', false, true,  false, 'optional',    'tier_2',   NULL,             0),
  ('BB', 'Barbados',            '+1',   'BBD', 'en', false, true,  false, 'optional',    'tier_2',   NULL,             0),
  ('BY', 'Belarus',             '+375', 'BYN', 'be', false, true,  false, 'optional',    'tier_3',   '## ###-##-##',   0),
  ('BE', 'Belgium',             '+32',  'EUR', 'nl', false, true,  false, 'optional',    'tier_1',   '### ## ## ##',   0),
  ('BZ', 'Belize',              '+501', 'BZD', 'en', false, true,  false, 'optional',    'tier_3',   '### ####',       0),
  ('BJ', 'Benin',               '+229', 'XOF', 'fr', false, true,  false, 'optional',    'tier_3',   '## ## ## ##',    0),
  ('BT', 'Bhutan',              '+975', 'BTN', 'dz', false, true,  false, 'optional',    'tier_3',   '## ### ###',     0),
  ('BO', 'Bolivia',             '+591', 'BOB', 'es', false, true,  false, 'optional',    'tier_3',   '# ### ####',     0),
  ('BA', 'Bosnia & Herzegovina','+387', 'BAM', 'bs', false, true,  false, 'optional',    'tier_3',   '## ### ###',     0),
  ('BW', 'Botswana',            '+267', 'BWP', 'en', false, true,  false, 'optional',    'tier_3',   '## ### ###',     0),
  ('BR', 'Brazil',              '+55',  'BRL', 'pt', false, true,  false, 'optional',    'tier_2',   '(##) # ####-####', 0),
  ('BN', 'Brunei',              '+673', 'BND', 'ms', true,  true,  false, 'mandatory',   'tier_2',   '### ####',       0),
  ('BG', 'Bulgaria',            '+359', 'BGN', 'bg', false, true,  false, 'optional',    'tier_3',   '## ### ####',    0),
  ('BF', 'Burkina Faso',        '+226', 'XOF', 'fr', false, true,  false, 'optional',    'tier_3',   '## ## ## ##',    0),
  ('BI', 'Burundi',             '+257', 'BIF', 'rn', false, true,  false, 'optional',    'tier_3',   '## ## ## ##',    0),

  -- ── C ──────────────────────────────────────────────────────
  ('CV', 'Cabo Verde',          '+238', 'CVE', 'pt', false, true,  false, 'optional',    'tier_3',   '### ## ##',      0),
  ('KH', 'Cambodia',            '+855', 'KHR', 'km', false, true,  false, 'optional',    'tier_3',   '## ### ###',     0),
  ('CM', 'Cameroon',            '+237', 'XAF', 'fr', false, true,  false, 'optional',    'tier_3',   '## ## ## ##',    0),
  ('CF', 'Central African Rep.','+236', 'XAF', 'fr', false, true,  false, 'optional',    'tier_3',   '## ## ## ##',    0),
  ('TD', 'Chad',                '+235', 'XAF', 'fr', false, true,  false, 'optional',    'tier_3',   '## ## ## ##',    0),
  ('CL', 'Chile',               '+56',  'CLP', 'es', false, true,  false, 'optional',    'tier_2',   '# #### ####',   0),
  ('CN', 'China',               '+86',  'CNY', 'zh', false, true,  false, 'optional',    'tier_2',   '### #### ####', 0),
  ('CO', 'Colombia',            '+57',  'COP', 'es', false, true,  false, 'optional',    'tier_2',   '### ### ####',  0),
  ('KM', 'Comoros',             '+269', 'KMF', 'ar', true,  true,  false, 'mandatory',   'tier_3',   '### ## ##',      0),
  ('CG', 'Congo',               '+242', 'XAF', 'fr', false, true,  false, 'optional',    'tier_3',   '## ### ####',   0),
  ('CD', 'Congo (DRC)',         '+243', 'CDF', 'fr', false, true,  false, 'optional',    'tier_3',   '### ### ###',   0),
  ('CR', 'Costa Rica',          '+506', 'CRC', 'es', false, true,  false, 'optional',    'tier_3',   '#### ####',     0),
  ('CI', 'Côte d''Ivoire',     '+225', 'XOF', 'fr', false, true,  false, 'optional',    'tier_3',   '## ## ## ##',   0),
  ('HR', 'Croatia',             '+385', 'EUR', 'hr', false, true,  false, 'optional',    'tier_2',   '## ### ###',    0),
  ('CU', 'Cuba',                '+53',  'CUP', 'es', false, true,  false, 'optional',    'tier_3',   '# ### ####',    0),
  ('CY', 'Cyprus',              '+357', 'EUR', 'el', false, true,  false, 'optional',    'tier_2',   '## ######',     0),
  ('CZ', 'Czech Republic',      '+420', 'CZK', 'cs', false, true,  false, 'optional',    'tier_2',   '### ### ###',   0),

  -- ── D ──────────────────────────────────────────────────────
  ('DK', 'Denmark',             '+45',  'DKK', 'da', false, true,  false, 'optional',    'tier_1',   '## ## ## ##',   0),
  ('DJ', 'Djibouti',            '+253', 'DJF', 'fr', false, true,  false, 'optional',    'tier_3',   '## ## ## ##',   0),
  ('DM', 'Dominica',            '+1',   'XCD', 'en', false, true,  false, 'optional',    'tier_3',   NULL,            0),
  ('DO', 'Dominican Republic',  '+1',   'DOP', 'es', false, true,  false, 'optional',    'tier_3',   NULL,            0),

  -- ── E ──────────────────────────────────────────────────────
  ('EC', 'Ecuador',             '+593', 'USD', 'es', false, true,  false, 'optional',    'tier_3',   '## ### ####',   0),
  ('SV', 'El Salvador',         '+503', 'USD', 'es', false, true,  false, 'optional',    'tier_3',   '#### ####',     0),
  ('GQ', 'Equatorial Guinea',   '+240', 'XAF', 'es', false, true,  false, 'optional',    'tier_3',   '## ### ####',   0),
  ('ER', 'Eritrea',             '+291', 'ERN', 'ti', false, true,  false, 'optional',    'tier_3',   '# ### ###',     0),
  ('EE', 'Estonia',             '+372', 'EUR', 'et', false, true,  false, 'optional',    'tier_2',   '## ## ####',    0),
  ('SZ', 'Eswatini',            '+268', 'SZL', 'en', false, true,  false, 'optional',    'tier_3',   '## ## ####',    0),
  ('ET', 'Ethiopia',            '+251', 'ETB', 'am', false, true,  false, 'optional',    'tier_3',   '## ### ####',   0),

  -- ── F ──────────────────────────────────────────────────────
  ('FJ', 'Fiji',                '+679', 'FJD', 'en', false, true,  false, 'optional',    'tier_3',   '### ####',      0),
  ('FI', 'Finland',             '+358', 'EUR', 'fi', false, true,  false, 'optional',    'tier_1',   '## ### ####',   0),

  -- ── G ──────────────────────────────────────────────────────
  ('GA', 'Gabon',               '+241', 'XAF', 'fr', false, true,  false, 'optional',    'tier_3',   '# ## ## ##',    0),
  ('GM', 'Gambia',              '+220', 'GMD', 'en', false, true,  false, 'optional',    'tier_3',   '### ####',      0),
  ('GE', 'Georgia',             '+995', 'GEL', 'ka', false, true,  false, 'optional',    'tier_3',   '### ## ## ##',  0),
  ('GH', 'Ghana',               '+233', 'GHS', 'en', false, true,  false, 'optional',    'tier_3',   '## ### ####',   0),
  ('GR', 'Greece',              '+30',  'EUR', 'el', false, true,  false, 'optional',    'tier_2',   '### ### ####',  0),
  ('GD', 'Grenada',             '+1',   'XCD', 'en', false, true,  false, 'optional',    'tier_3',   NULL,            0),
  ('GT', 'Guatemala',           '+502', 'GTQ', 'es', false, true,  false, 'optional',    'tier_3',   '#### ####',     0),
  ('GN', 'Guinea',              '+224', 'GNF', 'fr', false, true,  false, 'optional',    'tier_3',   '### ### ###',   0),
  ('GW', 'Guinea-Bissau',       '+245', 'XOF', 'pt', false, true,  false, 'optional',    'tier_3',   '# ## ####',     0),
  ('GY', 'Guyana',              '+592', 'GYD', 'en', false, true,  false, 'optional',    'tier_3',   '### ####',      0),

  -- ── H ──────────────────────────────────────────────────────
  ('HT', 'Haiti',               '+509', 'HTG', 'fr', false, true,  false, 'optional',    'tier_3',   '## ## ####',    0),
  ('HN', 'Honduras',            '+504', 'HNL', 'es', false, true,  false, 'optional',    'tier_3',   '#### ####',     0),
  ('HK', 'Hong Kong',           '+852', 'HKD', 'zh', false, true,  false, 'optional',    'tier_1',   '#### ####',     0),
  ('HU', 'Hungary',             '+36',  'HUF', 'hu', false, true,  false, 'optional',    'tier_2',   '## ### ####',   0),

  -- ── I ──────────────────────────────────────────────────────
  ('IS', 'Iceland',             '+354', 'ISK', 'is', false, true,  false, 'optional',    'tier_1',   '### ####',      0),
  ('IR', 'Iran',                '+98',  'IRR', 'fa', true,  true,  true,  'mandatory',   'tier_3',   '### ### ####',  0),
  ('IQ', 'Iraq',                '+964', 'IQD', 'ar', true,  true,  false, 'recommended', 'tier_3',   '### ### ####',  0),
  ('IE', 'Ireland',             '+353', 'EUR', 'en', false, true,  false, 'optional',    'tier_1',   '## ### ####',   0),
  ('IL', 'Israel',              '+972', 'ILS', 'he', true,  true,  false, 'optional',    'tier_1',   '##-### ####',   0),
  ('IT', 'Italy',               '+39',  'EUR', 'it', false, true,  false, 'optional',    'tier_1',   '### ### ####',  0),

  -- ── J ──────────────────────────────────────────────────────
  ('JM', 'Jamaica',             '+1',   'JMD', 'en', false, true,  false, 'optional',    'tier_3',   NULL,            0),
  ('JP', 'Japan',               '+81',  'JPY', 'ja', false, true,  false, 'optional',    'tier_1',   '## #### ####',  0),
  ('JO', 'Jordan',              '+962', 'JOD', 'ar', true,  true,  false, 'recommended', 'tier_3',   '# #### ####',   0),

  -- ── K ──────────────────────────────────────────────────────
  ('KZ', 'Kazakhstan',          '+7',   'KZT', 'kk', false, true,  false, 'optional',    'tier_3',   '### ###-##-##', 0),
  ('KE', 'Kenya',               '+254', 'KES', 'sw', false, true,  false, 'optional',    'tier_3',   '### ######',    0),
  ('KI', 'Kiribati',            '+686', 'AUD', 'en', false, true,  false, 'optional',    'tier_3',   '## ###',        0),
  ('XK', 'Kosovo',              '+383', 'EUR', 'sq', false, true,  false, 'optional',    'tier_3',   '## ### ###',    0),
  ('KG', 'Kyrgyzstan',          '+996', 'KGS', 'ky', false, true,  false, 'optional',    'tier_3',   '### ## ## ##',  0),
  ('KP', 'North Korea',         '+850', 'KPW', 'ko', false, true,  false, 'optional',    'tier_3',   '### ### ####',  0),
  ('KR', 'South Korea',         '+82',  'KRW', 'ko', false, true,  false, 'optional',    'tier_2',   '##-####-####',  0),

  -- ── L ──────────────────────────────────────────────────────
  ('LA', 'Laos',                '+856', 'LAK', 'lo', false, true,  false, 'optional',    'tier_3',   '## ## ### ###', 0),
  ('LV', 'Latvia',              '+371', 'EUR', 'lv', false, true,  false, 'optional',    'tier_2',   '## ### ###',    0),
  ('LB', 'Lebanon',             '+961', 'LBP', 'ar', true,  true,  true,  'recommended', 'tier_3',   '## ### ###',    0),
  ('LS', 'Lesotho',             '+266', 'LSL', 'en', false, true,  false, 'optional',    'tier_3',   '## ### ###',    0),
  ('LR', 'Liberia',             '+231', 'LRD', 'en', false, true,  false, 'optional',    'tier_3',   '## ### ###',    0),
  ('LY', 'Libya',               '+218', 'LYD', 'ar', true,  true,  false, 'recommended', 'tier_3',   '## ### ####',   0),
  ('LI', 'Liechtenstein',       '+423', 'CHF', 'de', false, true,  false, 'optional',    'tier_1',   '### ####',      0),
  ('LT', 'Lithuania',           '+370', 'EUR', 'lt', false, true,  false, 'optional',    'tier_2',   '### #####',     0),
  ('LU', 'Luxembourg',          '+352', 'EUR', 'lb', false, true,  false, 'optional',    'tier_1',   '## ## ##',      0),

  -- ── M ──────────────────────────────────────────────────────
  ('MO', 'Macau',               '+853', 'MOP', 'zh', false, true,  false, 'optional',    'tier_2',   '#### ####',     0),
  ('MG', 'Madagascar',          '+261', 'MGA', 'mg', false, true,  false, 'optional',    'tier_3',   '## ## ### ##',  0),
  ('MW', 'Malawi',              '+265', 'MWK', 'en', false, true,  false, 'optional',    'tier_3',   '## ### ####',   0),
  ('MV', 'Maldives',            '+960', 'MVR', 'dv', true,  true,  false, 'mandatory',   'tier_3',   '### ####',      0),
  ('ML', 'Mali',                '+223', 'XOF', 'fr', false, true,  false, 'optional',    'tier_3',   '## ## ## ##',   0),
  ('MT', 'Malta',               '+356', 'EUR', 'mt', false, true,  false, 'optional',    'tier_2',   '#### ####',     0),
  ('MH', 'Marshall Islands',    '+692', 'USD', 'mh', false, true,  false, 'optional',    'tier_3',   '### ####',      0),
  ('MR', 'Mauritania',          '+222', 'MRU', 'ar', true,  true,  false, 'recommended', 'tier_3',   '## ## ## ##',   0),
  ('MU', 'Mauritius',           '+230', 'MUR', 'en', false, true,  false, 'optional',    'tier_3',   '#### ####',     0),
  ('MX', 'Mexico',              '+52',  'MXN', 'es', false, true,  false, 'optional',    'tier_2',   '### ### ####',  0),
  ('FM', 'Micronesia',          '+691', 'USD', 'en', false, true,  false, 'optional',    'tier_3',   '### ####',      0),
  ('MD', 'Moldova',             '+373', 'MDL', 'ro', false, true,  false, 'optional',    'tier_3',   '## ### ###',    0),
  ('MC', 'Monaco',              '+377', 'EUR', 'fr', false, true,  false, 'optional',    'tier_1',   '## ## ## ##',   0),
  ('MN', 'Mongolia',            '+976', 'MNT', 'mn', false, true,  false, 'optional',    'tier_3',   '## ## ####',    0),
  ('ME', 'Montenegro',          '+382', 'EUR', 'sr', false, true,  false, 'optional',    'tier_3',   '## ### ###',    0),
  ('MA', 'Morocco',             '+212', 'MAD', 'ar', true,  true,  false, 'recommended', 'tier_3',   '##-### ## ##',  0),
  ('MZ', 'Mozambique',          '+258', 'MZN', 'pt', false, true,  false, 'optional',    'tier_3',   '## ### ####',   0),
  ('MM', 'Myanmar',             '+95',  'MMK', 'my', false, true,  false, 'optional',    'tier_3',   '## ### ####',   0),

  -- ── N ──────────────────────────────────────────────────────
  ('NA', 'Namibia',             '+264', 'NAD', 'en', false, true,  false, 'optional',    'tier_3',   '## ### ####',   0),
  ('NR', 'Nauru',               '+674', 'AUD', 'na', false, true,  false, 'optional',    'tier_3',   '### ####',      0),
  ('NP', 'Nepal',               '+977', 'NPR', 'ne', false, true,  false, 'optional',    'tier_3',   '##-### ####',   0),
  ('NZ', 'New Zealand',         '+64',  'NZD', 'en', false, true,  false, 'optional',    'tier_1',   '## ### ####',   0),
  ('NI', 'Nicaragua',           '+505', 'NIO', 'es', false, true,  false, 'optional',    'tier_3',   '#### ####',     0),
  ('NE', 'Niger',               '+227', 'XOF', 'fr', false, true,  false, 'optional',    'tier_3',   '## ## ## ##',   0),
  ('MK', 'North Macedonia',     '+389', 'MKD', 'mk', false, true,  false, 'optional',    'tier_3',   '## ### ###',    0),

  -- ── P ──────────────────────────────────────────────────────
  ('PW', 'Palau',               '+680', 'USD', 'en', false, true,  false, 'optional',    'tier_3',   '### ####',      0),
  ('PS', 'Palestine',           '+970', 'ILS', 'ar', true,  true,  false, 'recommended', 'tier_3',   '### ### ###',   0),
  ('PA', 'Panama',              '+507', 'PAB', 'es', false, true,  false, 'optional',    'tier_3',   '### ####',      0),
  ('PG', 'Papua New Guinea',    '+675', 'PGK', 'en', false, true,  false, 'optional',    'tier_3',   '### ####',      0),
  ('PY', 'Paraguay',            '+595', 'PYG', 'es', false, true,  false, 'optional',    'tier_3',   '### ######',    0),
  ('PE', 'Peru',                '+51',  'PEN', 'es', false, true,  false, 'optional',    'tier_3',   '### ### ###',   0),
  ('PH', 'Philippines',         '+63',  'PHP', 'en', false, true,  false, 'optional',    'tier_2',   '### ### ####',  0),
  ('PL', 'Poland',              '+48',  'PLN', 'pl', false, true,  false, 'optional',    'tier_2',   '### ### ###',   0),
  ('PT', 'Portugal',            '+351', 'EUR', 'pt', false, true,  false, 'optional',    'tier_2',   '### ### ###',   0),

  -- ── R ──────────────────────────────────────────────────────
  ('RO', 'Romania',             '+40',  'RON', 'ro', false, true,  false, 'optional',    'tier_2',   '## ### ####',   0),
  ('RU', 'Russia',              '+7',   'RUB', 'ru', false, true,  false, 'optional',    'tier_2',   '### ###-##-##', 0),
  ('RW', 'Rwanda',              '+250', 'RWF', 'rw', false, true,  false, 'optional',    'tier_3',   '### ### ###',   0),

  -- ── S ──────────────────────────────────────────────────────
  ('KN', 'Saint Kitts & Nevis', '+1',   'XCD', 'en', false, true,  false, 'optional',    'tier_3',   NULL,            0),
  ('LC', 'Saint Lucia',         '+1',   'XCD', 'en', false, true,  false, 'optional',    'tier_3',   NULL,            0),
  ('VC', 'Saint Vincent & Grenadines', '+1', 'XCD', 'en', false, true, false, 'optional', 'tier_3', NULL,            0),
  ('WS', 'Samoa',               '+685', 'WST', 'sm', false, true,  false, 'optional',    'tier_3',   '## ####',       0),
  ('SM', 'San Marino',          '+378', 'EUR', 'it', false, true,  false, 'optional',    'tier_2',   '## ######',     0),
  ('ST', 'São Tomé & Príncipe', '+239', 'STN', 'pt', false, true,  false, 'optional',    'tier_3',   '## #####',      0),
  ('SN', 'Senegal',             '+221', 'XOF', 'fr', false, true,  false, 'optional',    'tier_3',   '## ### ## ##',  0),
  ('RS', 'Serbia',              '+381', 'RSD', 'sr', false, true,  false, 'optional',    'tier_3',   '## ### ####',   0),
  ('SC', 'Seychelles',          '+248', 'SCR', 'en', false, true,  false, 'optional',    'tier_3',   '# ### ###',     0),
  ('SL', 'Sierra Leone',        '+232', 'SLE', 'en', false, true,  false, 'optional',    'tier_3',   '## ######',     0),
  ('SK', 'Slovakia',            '+421', 'EUR', 'sk', false, true,  false, 'optional',    'tier_2',   '### ### ###',   0),
  ('SI', 'Slovenia',            '+386', 'EUR', 'sl', false, true,  false, 'optional',    'tier_2',   '## ### ###',    0),
  ('SB', 'Solomon Islands',     '+677', 'SBD', 'en', false, true,  false, 'optional',    'tier_3',   '## ###',        0),
  ('SO', 'Somalia',             '+252', 'SOS', 'so', true,  true,  false, 'recommended', 'tier_3',   '## ### ###',    0),
  ('SS', 'South Sudan',         '+211', 'SSP', 'en', false, true,  false, 'optional',    'tier_3',   '## ### ####',   0),
  ('ES', 'Spain',               '+34',  'EUR', 'es', false, true,  false, 'optional',    'tier_1',   '### ### ###',   0),
  ('LK', 'Sri Lanka',           '+94',  'LKR', 'si', false, true,  false, 'optional',    'tier_3',   '## # ######',   0),
  ('SD', 'Sudan',               '+249', 'SDG', 'ar', true,  true,  false, 'recommended', 'tier_3',   '## ### ####',   0),
  ('SR', 'Suriname',            '+597', 'SRD', 'nl', false, true,  false, 'optional',    'tier_3',   '### ####',      0),
  ('CH', 'Switzerland',         '+41',  'CHF', 'de', false, true,  false, 'optional',    'tier_1',   '## ### ## ##',  0),
  ('SY', 'Syria',               '+963', 'SYP', 'ar', true,  true,  false, 'recommended', 'tier_3',   '### ### ###',   0),

  -- ── T ──────────────────────────────────────────────────────
  ('TW', 'Taiwan',              '+886', 'TWD', 'zh', false, true,  false, 'optional',    'tier_2',   '#### ### ###',  0),
  ('TJ', 'Tajikistan',          '+992', 'TJS', 'tg', false, true,  false, 'optional',    'tier_3',   '## ### ####',   0),
  ('TZ', 'Tanzania',            '+255', 'TZS', 'sw', false, true,  false, 'optional',    'tier_3',   '### ### ###',   0),
  ('TH', 'Thailand',            '+66',  'THB', 'th', false, true,  false, 'optional',    'tier_3',   '## ### ####',   0),
  ('TL', 'Timor-Leste',         '+670', 'USD', 'pt', false, true,  false, 'optional',    'tier_3',   '### ####',      0),
  ('TG', 'Togo',                '+228', 'XOF', 'fr', false, true,  false, 'optional',    'tier_3',   '## ## ## ##',   0),
  ('TO', 'Tonga',               '+676', 'TOP', 'to', false, true,  false, 'optional',    'tier_3',   '### ####',      0),
  ('TT', 'Trinidad & Tobago',   '+1',   'TTD', 'en', false, true,  false, 'optional',    'tier_3',   NULL,            0),
  ('TN', 'Tunisia',             '+216', 'TND', 'ar', true,  true,  false, 'recommended', 'tier_3',   '## ### ###',    0),
  ('TM', 'Turkmenistan',        '+993', 'TMT', 'tk', false, true,  false, 'optional',    'tier_3',   '## ######',     0),
  ('TV', 'Tuvalu',              '+688', 'AUD', 'en', false, true,  false, 'optional',    'tier_3',   '## ###',        0),

  -- ── U ──────────────────────────────────────────────────────
  ('UG', 'Uganda',              '+256', 'UGX', 'en', false, true,  false, 'optional',    'tier_3',   '### ######',    0),
  ('UA', 'Ukraine',             '+380', 'UAH', 'uk', false, true,  false, 'optional',    'tier_3',   '## ### ## ##',  0),
  ('UY', 'Uruguay',             '+598', 'UYU', 'es', false, true,  false, 'optional',    'tier_3',   '## ### ####',   0),
  ('UZ', 'Uzbekistan',          '+998', 'UZS', 'uz', false, true,  false, 'optional',    'tier_3',   '## ### ## ##',  0),

  -- ── V ──────────────────────────────────────────────────────
  ('VU', 'Vanuatu',             '+678', 'VUV', 'en', false, true,  false, 'optional',    'tier_3',   '### ####',      0),
  ('VE', 'Venezuela',           '+58',  'VES', 'es', false, true,  false, 'optional',    'tier_3',   '###-### ####',  0),
  ('VN', 'Vietnam',             '+84',  'VND', 'vi', false, true,  false, 'optional',    'tier_3',   '### ### ####',  0),

  -- ── Y ──────────────────────────────────────────────────────
  ('YE', 'Yemen',               '+967', 'YER', 'ar', true,  true,  false, 'recommended', 'tier_3',   '### ### ###',   0),

  -- ── Z ──────────────────────────────────────────────────────
  ('ZM', 'Zambia',              '+260', 'ZMW', 'en', false, true,  false, 'optional',    'tier_3',   '## ### ####',   0),
  ('ZW', 'Zimbabwe',            '+263', 'ZWL', 'en', false, true,  false, 'optional',    'tier_3',   '## ### ####',   0)

ON CONFLICT (code) DO UPDATE SET
  name             = EXCLUDED.name,
  dialing_code     = EXCLUDED.dialing_code,
  phone_format     = COALESCE(EXCLUDED.phone_format, countries.phone_format),
  display_priority = GREATEST(EXCLUDED.display_priority, countries.display_priority);

-- ── Step 4: Create index for priority-based sorting ──────────

CREATE INDEX IF NOT EXISTS idx_countries_priority
  ON countries(display_priority DESC, name ASC);
