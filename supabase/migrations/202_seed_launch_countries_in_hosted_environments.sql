-- Hosted Supabase deployments run migrations but do not execute local seed
-- files. Migration 027 assumed these original launch countries already
-- existed, leaving major markets absent on clean hosted projects.

INSERT INTO public.countries (
  iso_code, name, dialing_code, currency, default_lang, rtl,
  show_sect, show_sub_sect, wali_requirement, pricing_tier,
  phone_format, display_priority
)
VALUES
  ('IN', 'India', '+91', 'INR', 'en', false, true, true, 'recommended', 'tier_3', '##### #####', 10),
  ('PK', 'Pakistan', '+92', 'PKR', 'ur', true, true, true, 'recommended', 'tier_3', '### #######', 10),
  ('BD', 'Bangladesh', '+880', 'BDT', 'en', false, true, false, 'recommended', 'tier_3', '####-######', 10),
  ('GB', 'United Kingdom', '+44', 'GBP', 'en', false, true, true, 'optional', 'tier_1', '#### ######', 5),
  ('US', 'United States', '+1', 'USD', 'en', false, true, true, 'optional', 'tier_1', '(###) ###-####', 5),
  ('CA', 'Canada', '+1', 'CAD', 'en', false, true, true, 'optional', 'tier_1', '(###) ###-####', 5),
  ('AE', 'United Arab Emirates', '+971', 'AED', 'ar', true, false, false, 'mandatory', 'premium', '## ### ####', 10),
  ('SA', 'Saudi Arabia', '+966', 'SAR', 'ar', true, false, false, 'mandatory', 'premium', '## ### ####', 10),
  ('MY', 'Malaysia', '+60', 'MYR', 'ms', false, true, false, 'recommended', 'tier_2', '##-#### ####', 10),
  ('ID', 'Indonesia', '+62', 'IDR', 'id', false, true, false, 'recommended', 'tier_3', '### #### ####', 10),
  ('TR', 'Turkey', '+90', 'TRY', 'tr', false, true, false, 'optional', 'tier_2', '### ### ####', 10),
  ('EG', 'Egypt', '+20', 'EGP', 'ar', true, true, false, 'recommended', 'tier_3', '### #### ####', 10),
  ('NG', 'Nigeria', '+234', 'NGN', 'en', false, true, false, 'recommended', 'tier_3', '### ### ####', 10),
  ('DE', 'Germany', '+49', 'EUR', 'de', false, true, true, 'optional', 'tier_1', '#### #######', 5),
  ('FR', 'France', '+33', 'EUR', 'fr', false, true, false, 'optional', 'tier_1', '# ## ## ## ##', 5)
ON CONFLICT (iso_code) DO UPDATE SET
  name = EXCLUDED.name,
  dialing_code = EXCLUDED.dialing_code,
  currency = EXCLUDED.currency,
  default_lang = EXCLUDED.default_lang,
  rtl = EXCLUDED.rtl,
  show_sect = EXCLUDED.show_sect,
  show_sub_sect = EXCLUDED.show_sub_sect,
  wali_requirement = EXCLUDED.wali_requirement,
  pricing_tier = EXCLUDED.pricing_tier,
  phone_format = EXCLUDED.phone_format,
  display_priority = EXCLUDED.display_priority;

DO $migration$
BEGIN
  IF (
    SELECT count(*)
    FROM public.countries
    WHERE iso_code IN (
      'IN', 'PK', 'BD', 'GB', 'US', 'CA', 'AE', 'SA', 'MY', 'ID',
      'TR', 'EG', 'NG', 'DE', 'FR'
    )
  ) <> 15 THEN
    RAISE EXCEPTION 'hosted_launch_country_seed_incomplete';
  END IF;
END;
$migration$;
