-- ============================================================
-- SEED 002: INCOME BRACKETS
-- Per-country income ranges. The profile stores income_bracket
-- as an integer FK to income_brackets.id.
-- Labels shown in the app's local language/currency.
-- add label_local translations at runtime or in a later seed.
-- ============================================================

-- NOTE: After this INSERT the income_brackets.id (serial) values
-- will be 1–25 in insertion order. The Flutter app always
-- fetches brackets by country_code — never hardcodes IDs.

INSERT INTO income_brackets (country_code, rank, label_en, label_local) VALUES

-- ── INDIA (INR, annual) ──────────────────────────────────────
('IN', 1, 'Below ₹3 Lakh / year',    'Rs 3 لاکھ سے کم / سال'),
('IN', 2, '₹3–6 Lakh / year',        'Rs 3–6 لاکھ / سال'),
('IN', 3, '₹6–12 Lakh / year',       'Rs 6–12 لاکھ / سال'),
('IN', 4, '₹12–25 Lakh / year',      'Rs 12–25 لاکھ / سال'),
('IN', 5, 'Above ₹25 Lakh / year',   'Rs 25 لاکھ سے زیادہ / سال'),

-- ── PAKISTAN (PKR, monthly) ──────────────────────────────────
('PK', 1, 'Below PKR 50,000 / month',     NULL),
('PK', 2, 'PKR 50,000–1,00,000 / month',  NULL),
('PK', 3, 'PKR 1,00,000–2,00,000 / month',NULL),
('PK', 4, 'PKR 2,00,000–5,00,000 / month',NULL),
('PK', 5, 'Above PKR 5,00,000 / month',   NULL),

-- ── BANGLADESH (BDT, monthly) ────────────────────────────────
('BD', 1, 'Below BDT 30,000 / month', NULL),
('BD', 2, 'BDT 30,000–60,000 / month',NULL),
('BD', 3, 'BDT 60,000–1,20,000 / month', NULL),
('BD', 4, 'BDT 1,20,000–2,50,000 / month', NULL),
('BD', 5, 'Above BDT 2,50,000 / month', NULL),

-- ── UNITED KINGDOM (GBP, annual) ─────────────────────────────
('GB', 1, 'Below £20,000 / year',  NULL),
('GB', 2, '£20,000–35,000 / year', NULL),
('GB', 3, '£35,000–60,000 / year', NULL),
('GB', 4, '£60,000–100,000 / year',NULL),
('GB', 5, 'Above £100,000 / year', NULL),

-- ── UNITED STATES (USD, annual) ──────────────────────────────
('US', 1, 'Below $30,000 / year',   NULL),
('US', 2, '$30,000–60,000 / year',  NULL),
('US', 3, '$60,000–100,000 / year', NULL),
('US', 4, '$100,000–200,000 / year',NULL),
('US', 5, 'Above $200,000 / year',  NULL),

-- ── CANADA (CAD, annual) ─────────────────────────────────────
('CA', 1, 'Below CAD 40,000 / year',  NULL),
('CA', 2, 'CAD 40,000–75,000 / year', NULL),
('CA', 3, 'CAD 75,000–120,000 / year',NULL),
('CA', 4, 'CAD 120,000–200,000 / year',NULL),
('CA', 5, 'Above CAD 200,000 / year', NULL),

-- ── UAE (AED, monthly) ───────────────────────────────────────
('AE', 1, 'Below AED 8,000 / month',  NULL),
('AE', 2, 'AED 8,000–15,000 / month', NULL),
('AE', 3, 'AED 15,000–30,000 / month',NULL),
('AE', 4, 'AED 30,000–60,000 / month',NULL),
('AE', 5, 'Above AED 60,000 / month', NULL),

-- ── SAUDI ARABIA: income display disabled per country config ─
-- (wali_requirement = mandatory, income culturally sensitive)
-- No brackets inserted for SA

-- ── MALAYSIA (MYR, monthly) ──────────────────────────────────
('MY', 1, 'Below MYR 3,000 / month',   NULL),
('MY', 2, 'MYR 3,000–6,000 / month',   NULL),
('MY', 3, 'MYR 6,000–12,000 / month',  NULL),
('MY', 4, 'MYR 12,000–20,000 / month', NULL),
('MY', 5, 'Above MYR 20,000 / month',  NULL),

-- ── INDONESIA (IDR, monthly) ─────────────────────────────────
('ID', 1, 'Below IDR 5,000,000 / month',   NULL),
('ID', 2, 'IDR 5–10 Million / month',      NULL),
('ID', 3, 'IDR 10–25 Million / month',     NULL),
('ID', 4, 'IDR 25–50 Million / month',     NULL),
('ID', 5, 'Above IDR 50 Million / month',  NULL),

-- ── TURKEY (TRY, monthly) ────────────────────────────────────
('TR', 1, 'Below TRY 20,000 / month',  NULL),
('TR', 2, 'TRY 20,000–50,000 / month', NULL),
('TR', 3, 'TRY 50,000–100,000 / month',NULL),
('TR', 4, 'TRY 100,000–250,000 / month',NULL),
('TR', 5, 'Above TRY 250,000 / month', NULL),

-- ── EGYPT (EGP, monthly) ─────────────────────────────────────
('EG', 1, 'Below EGP 5,000 / month',   NULL),
('EG', 2, 'EGP 5,000–10,000 / month',  NULL),
('EG', 3, 'EGP 10,000–25,000 / month', NULL),
('EG', 4, 'EGP 25,000–50,000 / month', NULL),
('EG', 5, 'Above EGP 50,000 / month',  NULL),

-- ── NIGERIA (NGN, monthly) ───────────────────────────────────
('NG', 1, 'Below NGN 100,000 / month',  NULL),
('NG', 2, 'NGN 100,000–250,000 / month',NULL),
('NG', 3, 'NGN 250,000–500,000 / month',NULL),
('NG', 4, 'NGN 500,000–1M / month',     NULL),
('NG', 5, 'Above NGN 1 Million / month',NULL),

-- ── GERMANY (EUR, annual) ────────────────────────────────────
('DE', 1, 'Below €25,000 / year',  NULL),
('DE', 2, '€25,000–45,000 / year', NULL),
('DE', 3, '€45,000–75,000 / year', NULL),
('DE', 4, '€75,000–120,000 / year',NULL),
('DE', 5, 'Above €120,000 / year', NULL),

-- ── FRANCE (EUR, annual) ─────────────────────────────────────
('FR', 1, 'Moins de 25 000 € / an',  NULL),
('FR', 2, '25 000–40 000 € / an',    NULL),
('FR', 3, '40 000–70 000 € / an',    NULL),
('FR', 4, '70 000–120 000 € / an',   NULL),
('FR', 5, 'Plus de 120 000 € / an',  NULL)

ON CONFLICT (country_code, rank) DO UPDATE SET
  label_en    = EXCLUDED.label_en,
  label_local = EXCLUDED.label_local;
