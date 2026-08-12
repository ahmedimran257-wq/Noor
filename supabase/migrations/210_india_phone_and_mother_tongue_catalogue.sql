-- India-first phone verification and state-aware mother-tongue catalogue.
--
-- Language sources:
--   * Census of India C-16 (2011), distribution by mother tongue at
--     State/UT level: https://censusindia.gov.in/nada/index.php/catalog/10191
--   * Government of India Eighth Schedule language list:
--     https://rajbhasha.gov.in/en/languages-included-eighth-schedule-indian-constitution
--
-- A member's residence never determines their mother tongue. State/UT rows
-- only rank locally relevant options first; the India-wide catalogue is always
-- appended so migrants and linguistic minorities remain selectable.

CREATE TABLE IF NOT EXISTS public.india_state_mother_tongues (
  state_code text NOT NULL,
  state_name text NOT NULL,
  is_union_territory boolean NOT NULL DEFAULT false,
  language text NOT NULL,
  display_rank integer NOT NULL CHECK (display_rank BETWEEN 1 AND 200),
  source_key text NOT NULL DEFAULT 'census_2011_c16',
  PRIMARY KEY (state_code, language)
);

ALTER TABLE public.india_state_mother_tongues ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.india_state_mother_tongues
  FROM PUBLIC, anon, authenticated;

INSERT INTO public.india_state_mother_tongues(
  state_code, state_name, is_union_territory, language, display_rank
)
SELECT row_data.state_code,
       row_data.state_name,
       row_data.is_union_territory,
       row_data.language,
       row_data.display_rank
FROM (VALUES
  ('AP','Andhra Pradesh',false,'Telugu',1),('AP','Andhra Pradesh',false,'Urdu',2),('AP','Andhra Pradesh',false,'Tamil',3),('AP','Andhra Pradesh',false,'Kannada',4),('AP','Andhra Pradesh',false,'Odia',5),('AP','Andhra Pradesh',false,'Hindi',6),
  ('AR','Arunachal Pradesh',false,'Nyishi',1),('AR','Arunachal Pradesh',false,'Adi',2),('AR','Arunachal Pradesh',false,'Galo',3),('AR','Arunachal Pradesh',false,'Monpa',4),('AR','Arunachal Pradesh',false,'Apatani',5),('AR','Arunachal Pradesh',false,'Hindi',6),('AR','Arunachal Pradesh',false,'Nepali',7),('AR','Arunachal Pradesh',false,'Assamese',8),
  ('AS','Assam',false,'Assamese',1),('AS','Assam',false,'Bengali',2),('AS','Assam',false,'Bodo',3),('AS','Assam',false,'Hindi',4),('AS','Assam',false,'Nepali',5),('AS','Assam',false,'Mising',6),('AS','Assam',false,'Karbi',7),('AS','Assam',false,'Rabha',8),
  ('BR','Bihar',false,'Hindi',1),('BR','Bihar',false,'Bhojpuri',2),('BR','Bihar',false,'Maithili',3),('BR','Bihar',false,'Magahi',4),('BR','Bihar',false,'Urdu',5),('BR','Bihar',false,'Angika',6),('BR','Bihar',false,'Bengali',7),
  ('CG','Chhattisgarh',false,'Chhattisgarhi',1),('CG','Chhattisgarh',false,'Hindi',2),('CG','Chhattisgarh',false,'Gondi',3),('CG','Chhattisgarh',false,'Halbi',4),('CG','Chhattisgarh',false,'Odia',5),('CG','Chhattisgarh',false,'Marathi',6),('CG','Chhattisgarh',false,'Kurukh',7),
  ('GA','Goa',false,'Konkani',1),('GA','Goa',false,'Marathi',2),('GA','Goa',false,'Hindi',3),('GA','Goa',false,'Kannada',4),('GA','Goa',false,'Urdu',5),
  ('GJ','Gujarat',false,'Gujarati',1),('GJ','Gujarat',false,'Hindi',2),('GJ','Gujarat',false,'Urdu',3),('GJ','Gujarat',false,'Sindhi',4),('GJ','Gujarat',false,'Marathi',5),('GJ','Gujarat',false,'Kutchi',6),
  ('HR','Haryana',false,'Hindi',1),('HR','Haryana',false,'Haryanvi',2),('HR','Haryana',false,'Punjabi',3),('HR','Haryana',false,'Urdu',4),
  ('HP','Himachal Pradesh',false,'Hindi',1),('HP','Himachal Pradesh',false,'Pahari',2),('HP','Himachal Pradesh',false,'Kangri',3),('HP','Himachal Pradesh',false,'Punjabi',4),('HP','Himachal Pradesh',false,'Tibetan',5),
  ('JH','Jharkhand',false,'Hindi',1),('JH','Jharkhand',false,'Santali',2),('JH','Jharkhand',false,'Bengali',3),('JH','Jharkhand',false,'Urdu',4),('JH','Jharkhand',false,'Ho',5),('JH','Jharkhand',false,'Mundari',6),('JH','Jharkhand',false,'Kurukh',7),('JH','Jharkhand',false,'Khortha',8),('JH','Jharkhand',false,'Nagpuri',9),
  ('KA','Karnataka',false,'Kannada',1),('KA','Karnataka',false,'Urdu',2),('KA','Karnataka',false,'Telugu',3),('KA','Karnataka',false,'Tamil',4),('KA','Karnataka',false,'Marathi',5),('KA','Karnataka',false,'Tulu',6),('KA','Karnataka',false,'Konkani',7),('KA','Karnataka',false,'Hindi',8),('KA','Karnataka',false,'Kodava',9),('KA','Karnataka',false,'Malayalam',10),
  ('KL','Kerala',false,'Malayalam',1),('KL','Kerala',false,'Tamil',2),('KL','Kerala',false,'Kannada',3),('KL','Kerala',false,'Urdu',4),('KL','Kerala',false,'Konkani',5),('KL','Kerala',false,'Tulu',6),
  ('MP','Madhya Pradesh',false,'Hindi',1),('MP','Madhya Pradesh',false,'Malvi',2),('MP','Madhya Pradesh',false,'Bundeli',3),('MP','Madhya Pradesh',false,'Bagheli',4),('MP','Madhya Pradesh',false,'Nimadi',5),('MP','Madhya Pradesh',false,'Gondi',6),('MP','Madhya Pradesh',false,'Bhili',7),('MP','Madhya Pradesh',false,'Urdu',8),
  ('MH','Maharashtra',false,'Marathi',1),('MH','Maharashtra',false,'Hindi',2),('MH','Maharashtra',false,'Urdu',3),('MH','Maharashtra',false,'Gujarati',4),('MH','Maharashtra',false,'Kannada',5),('MH','Maharashtra',false,'Telugu',6),('MH','Maharashtra',false,'Konkani',7),('MH','Maharashtra',false,'Sindhi',8),
  ('MN','Manipur',false,'Manipuri (Meitei)',1),('MN','Manipur',false,'Thadou',2),('MN','Manipur',false,'Tangkhul',3),('MN','Manipur',false,'Paite',4),('MN','Manipur',false,'Hmar',5),('MN','Manipur',false,'Rongmei',6),('MN','Manipur',false,'Nepali',7),('MN','Manipur',false,'Bengali',8),
  ('ML','Meghalaya',false,'Khasi',1),('ML','Meghalaya',false,'Garo',2),('ML','Meghalaya',false,'Bengali',3),('ML','Meghalaya',false,'Hindi',4),('ML','Meghalaya',false,'Nepali',5),('ML','Meghalaya',false,'Assamese',6),
  ('MZ','Mizoram',false,'Mizo',1),('MZ','Mizoram',false,'Hmar',2),('MZ','Mizoram',false,'Chakma',3),('MZ','Mizoram',false,'Lai',4),('MZ','Mizoram',false,'Mara',5),('MZ','Mizoram',false,'Bengali',6),('MZ','Mizoram',false,'Hindi',7),
  ('NL','Nagaland',false,'Nagamese',1),('NL','Nagaland',false,'Ao',2),('NL','Nagaland',false,'Angami',3),('NL','Nagaland',false,'Sumi',4),('NL','Nagaland',false,'Lotha',5),('NL','Nagaland',false,'Konyak',6),('NL','Nagaland',false,'Chakhesang',7),('NL','Nagaland',false,'Hindi',8),('NL','Nagaland',false,'Assamese',9),
  ('OD','Odisha',false,'Odia',1),('OD','Odisha',false,'Santali',2),('OD','Odisha',false,'Kui',3),('OD','Odisha',false,'Telugu',4),('OD','Odisha',false,'Bengali',5),('OD','Odisha',false,'Hindi',6),('OD','Odisha',false,'Urdu',7),('OD','Odisha',false,'Ho',8),('OD','Odisha',false,'Mundari',9),
  ('PB','Punjab',false,'Punjabi',1),('PB','Punjab',false,'Hindi',2),('PB','Punjab',false,'Urdu',3),
  ('RJ','Rajasthan',false,'Hindi',1),('RJ','Rajasthan',false,'Rajasthani',2),('RJ','Rajasthan',false,'Marwari',3),('RJ','Rajasthan',false,'Mewari',4),('RJ','Rajasthan',false,'Dhundhari',5),('RJ','Rajasthan',false,'Harauti',6),('RJ','Rajasthan',false,'Mewati',7),('RJ','Rajasthan',false,'Sindhi',8),('RJ','Rajasthan',false,'Punjabi',9),('RJ','Rajasthan',false,'Urdu',10),
  ('SK','Sikkim',false,'Nepali',1),('SK','Sikkim',false,'Bhutia',2),('SK','Sikkim',false,'Lepcha',3),('SK','Sikkim',false,'Limbu',4),('SK','Sikkim',false,'Hindi',5),('SK','Sikkim',false,'Bengali',6),
  ('TN','Tamil Nadu',false,'Tamil',1),('TN','Tamil Nadu',false,'Telugu',2),('TN','Tamil Nadu',false,'Kannada',3),('TN','Tamil Nadu',false,'Urdu',4),('TN','Tamil Nadu',false,'Malayalam',5),('TN','Tamil Nadu',false,'Hindi',6),('TN','Tamil Nadu',false,'Saurashtra',7),
  ('TS','Telangana',false,'Telugu',1),('TS','Telangana',false,'Urdu',2),('TS','Telangana',false,'Hindi',3),('TS','Telangana',false,'Marathi',4),('TS','Telangana',false,'Kannada',5),('TS','Telangana',false,'Lambadi',6),('TS','Telangana',false,'Tamil',7),
  ('TR','Tripura',false,'Bengali',1),('TR','Tripura',false,'Kokborok',2),('TR','Tripura',false,'Manipuri (Meitei)',3),('TR','Tripura',false,'Chakma',4),('TR','Tripura',false,'Hindi',5),
  ('UP','Uttar Pradesh',false,'Hindi',1),('UP','Uttar Pradesh',false,'Urdu',2),('UP','Uttar Pradesh',false,'Awadhi',3),('UP','Uttar Pradesh',false,'Bhojpuri',4),('UP','Uttar Pradesh',false,'Braj',5),('UP','Uttar Pradesh',false,'Bundeli',6),('UP','Uttar Pradesh',false,'Punjabi',7),('UP','Uttar Pradesh',false,'Bengali',8),
  ('UK','Uttarakhand',false,'Hindi',1),('UK','Uttarakhand',false,'Garhwali',2),('UK','Uttarakhand',false,'Kumaoni',3),('UK','Uttarakhand',false,'Jaunsari',4),('UK','Uttarakhand',false,'Urdu',5),('UK','Uttarakhand',false,'Punjabi',6),('UK','Uttarakhand',false,'Nepali',7),
  ('WB','West Bengal',false,'Bengali',1),('WB','West Bengal',false,'Hindi',2),('WB','West Bengal',false,'Urdu',3),('WB','West Bengal',false,'Nepali',4),('WB','West Bengal',false,'Santali',5),('WB','West Bengal',false,'Odia',6),('WB','West Bengal',false,'Punjabi',7),('WB','West Bengal',false,'Bhojpuri',8),
  ('AN','Andaman and Nicobar Islands',true,'Bengali',1),('AN','Andaman and Nicobar Islands',true,'Hindi',2),('AN','Andaman and Nicobar Islands',true,'Tamil',3),('AN','Andaman and Nicobar Islands',true,'Telugu',4),('AN','Andaman and Nicobar Islands',true,'Malayalam',5),('AN','Andaman and Nicobar Islands',true,'Nicobarese',6),
  ('CH','Chandigarh',true,'Hindi',1),('CH','Chandigarh',true,'Punjabi',2),
  ('DH','Dadra and Nagar Haveli and Daman and Diu',true,'Gujarati',1),('DH','Dadra and Nagar Haveli and Daman and Diu',true,'Hindi',2),('DH','Dadra and Nagar Haveli and Daman and Diu',true,'Marathi',3),('DH','Dadra and Nagar Haveli and Daman and Diu',true,'Konkani',4),('DH','Dadra and Nagar Haveli and Daman and Diu',true,'Bhili',5),
  ('DL','Delhi',true,'Hindi',1),('DL','Delhi',true,'Punjabi',2),('DL','Delhi',true,'Urdu',3),('DL','Delhi',true,'Bengali',4),('DL','Delhi',true,'Bhojpuri',5),
  ('JK','Jammu and Kashmir',true,'Kashmiri',1),('JK','Jammu and Kashmir',true,'Dogri',2),('JK','Jammu and Kashmir',true,'Urdu',3),('JK','Jammu and Kashmir',true,'Hindi',4),('JK','Jammu and Kashmir',true,'Gojri',5),('JK','Jammu and Kashmir',true,'Pahari',6),('JK','Jammu and Kashmir',true,'Punjabi',7),
  ('LA','Ladakh',true,'Ladakhi',1),('LA','Ladakh',true,'Balti',2),('LA','Ladakh',true,'Shina',3),('LA','Ladakh',true,'Urdu',4),('LA','Ladakh',true,'Hindi',5),('LA','Ladakh',true,'Tibetan',6),
  ('LD','Lakshadweep',true,'Malayalam',1),('LD','Lakshadweep',true,'Mahl',2),('LD','Lakshadweep',true,'Tamil',3),
  ('PY','Puducherry',true,'Tamil',1),('PY','Puducherry',true,'Telugu',2),('PY','Puducherry',true,'Malayalam',3),('PY','Puducherry',true,'Urdu',4),('PY','Puducherry',true,'French',5),
  ('ALL','India',false,'Hindi',1),('ALL','India',false,'Urdu',2),('ALL','India',false,'English',3),('ALL','India',false,'Bengali',4),('ALL','India',false,'Telugu',5),('ALL','India',false,'Marathi',6),('ALL','India',false,'Tamil',7),('ALL','India',false,'Gujarati',8),('ALL','India',false,'Kannada',9),('ALL','India',false,'Malayalam',10),('ALL','India',false,'Odia',11),('ALL','India',false,'Punjabi',12),('ALL','India',false,'Assamese',13),('ALL','India',false,'Maithili',14),('ALL','India',false,'Santali',15),('ALL','India',false,'Kashmiri',16),('ALL','India',false,'Nepali',17),('ALL','India',false,'Sindhi',18),('ALL','India',false,'Konkani',19),('ALL','India',false,'Dogri',20),('ALL','India',false,'Manipuri (Meitei)',21),('ALL','India',false,'Bodo',22),('ALL','India',false,'Sanskrit',23),('ALL','India',false,'Bhojpuri',24),('ALL','India',false,'Rajasthani',25),('ALL','India',false,'Chhattisgarhi',26),('ALL','India',false,'Awadhi',27),('ALL','India',false,'Bhili',28),('ALL','India',false,'Gondi',29),('ALL','India',false,'Tulu',30),('ALL','India',false,'Khasi',31),('ALL','India',false,'Mizo',32),('ALL','India',false,'Kokborok',33),('ALL','India',false,'Garhwali',34),('ALL','India',false,'Kumaoni',35),('ALL','India',false,'Haryanvi',36),('ALL','India',false,'Marwari',37),('ALL','India',false,'Pahari',38),('ALL','India',false,'Lambadi',39),('ALL','India',false,'Mundari',40),('ALL','India',false,'Ho',41),('ALL','India',false,'Kurukh',42),('ALL','India',false,'Nagamese',43),('ALL','India',false,'Ladakhi',44)
) AS row_data(state_code,state_name,is_union_territory,language,display_rank)
ON CONFLICT (state_code, language) DO UPDATE SET
  state_name = EXCLUDED.state_name,
  is_union_territory = EXCLUDED.is_union_territory,
  display_rank = EXCLUDED.display_rank,
  source_key = 'census_2011_c16';

CREATE OR REPLACE FUNCTION public.get_mother_tongues_for_location(
  p_country_code text,
  p_state_name text DEFAULT NULL,
  p_city_name text DEFAULT NULL
)
RETURNS TABLE(language text, relevance text, display_order integer)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_country text := upper(trim(coalesce(p_country_code, '')));
  v_raw_state text := coalesce(
    nullif(trim(p_state_name), ''),
    nullif(trim(split_part(coalesce(p_city_name, ''), ',', 2)), ''),
    ''
  );
  v_state_key text;
  v_state_code text;
BEGIN
  IF v_country <> 'IN' THEN
    RETURN;
  END IF;

  v_state_key := lower(regexp_replace(v_raw_state, '[^a-zA-Z0-9]+', '', 'g'));
  v_state_code := CASE v_state_key
    WHEN 'andhrapradesh' THEN 'AP' WHEN 'arunachalpradesh' THEN 'AR'
    WHEN 'assam' THEN 'AS' WHEN 'bihar' THEN 'BR'
    WHEN 'chhattisgarh' THEN 'CG' WHEN 'goa' THEN 'GA'
    WHEN 'gujarat' THEN 'GJ' WHEN 'haryana' THEN 'HR'
    WHEN 'himachalpradesh' THEN 'HP' WHEN 'jharkhand' THEN 'JH'
    WHEN 'karnataka' THEN 'KA' WHEN 'kerala' THEN 'KL'
    WHEN 'madhyapradesh' THEN 'MP' WHEN 'maharashtra' THEN 'MH'
    WHEN 'manipur' THEN 'MN' WHEN 'meghalaya' THEN 'ML'
    WHEN 'mizoram' THEN 'MZ' WHEN 'nagaland' THEN 'NL'
    WHEN 'odisha' THEN 'OD' WHEN 'orissa' THEN 'OD'
    WHEN 'punjab' THEN 'PB' WHEN 'rajasthan' THEN 'RJ'
    WHEN 'sikkim' THEN 'SK' WHEN 'tamilnadu' THEN 'TN'
    WHEN 'telangana' THEN 'TS' WHEN 'tripura' THEN 'TR'
    WHEN 'uttarpradesh' THEN 'UP' WHEN 'uttarakhand' THEN 'UK'
    WHEN 'uttaranchal' THEN 'UK' WHEN 'westbengal' THEN 'WB'
    WHEN 'andamanandnicobarislands' THEN 'AN' WHEN 'andamannicobar' THEN 'AN'
    WHEN 'chandigarh' THEN 'CH'
    WHEN 'dadraandnagarhavelianddamananddiu' THEN 'DH'
    WHEN 'delhi' THEN 'DL' WHEN 'nctofdelhi' THEN 'DL'
    WHEN 'nationalcapitalterritoryofdelhi' THEN 'DL'
    WHEN 'jammuandkashmir' THEN 'JK' WHEN 'ladakh' THEN 'LA'
    WHEN 'lakshadweep' THEN 'LD' WHEN 'puducherry' THEN 'PY'
    WHEN 'pondicherry' THEN 'PY'
    ELSE NULL
  END;

  RETURN QUERY
  WITH ranked AS (
    SELECT mt.language,
           CASE WHEN mt.state_code = v_state_code THEN 0 ELSE 1 END AS tier,
           min(mt.display_rank) AS language_rank
    FROM public.india_state_mother_tongues mt
    WHERE mt.state_code = 'ALL' OR mt.state_code = v_state_code
    GROUP BY mt.language,
             CASE WHEN mt.state_code = v_state_code THEN 0 ELSE 1 END
  ), deduplicated AS (
    SELECT DISTINCT ON (ranked.language)
           ranked.language,
           ranked.tier,
           ranked.language_rank
    FROM ranked
    ORDER BY ranked.language, ranked.tier, ranked.language_rank
  )
  SELECT d.language,
         CASE WHEN d.tier = 0 THEN 'state'::text ELSE 'india'::text END,
         row_number() OVER (ORDER BY d.tier, d.language_rank, d.language)::integer
  FROM deduplicated d
  ORDER BY d.tier, d.language_rank, d.language;
END;
$$;

REVOKE ALL ON FUNCTION public.get_mother_tongues_for_location(text,text,text)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_mother_tongues_for_location(text,text,text)
  TO anon, authenticated;

CREATE OR REPLACE FUNCTION public.assert_my_phone_country_enabled(
  p_country_code text
)
RETURNS void
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid := private.assert_authenticated();
  v_country_code text := upper(trim(coalesce(p_country_code, '')));
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM public.launch_countries lc
    WHERE lc.country_code = v_country_code
      AND lc.enabled
  ) THEN
    RAISE EXCEPTION 'launch_country_unavailable' USING ERRCODE = 'P0001';
  END IF;

  IF NOT public.has_active_premium(v_user_id) THEN
    RAISE EXCEPTION 'subscription_required' USING ERRCODE = 'P0001';
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.assert_my_phone_country_enabled(text)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.assert_my_phone_country_enabled(text)
  TO authenticated;

CREATE OR REPLACE FUNCTION public.confirm_my_verified_phone(
  p_country_code text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid := private.assert_authenticated();
  v_phone text;
  v_phone_confirmed_at timestamptz;
  v_country_code text := upper(trim(coalesce(p_country_code, '')));
  v_dialing_code text;
BEGIN
  PERFORM public.assert_my_phone_country_enabled(v_country_code);

  SELECT c.dialing_code
  INTO v_dialing_code
  FROM public.countries c
  WHERE c.iso_code = v_country_code;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'invalid_phone_country' USING ERRCODE = '22023';
  END IF;

  SELECT au.phone, au.phone_confirmed_at
  INTO v_phone, v_phone_confirmed_at
  FROM auth.users au
  WHERE au.id = v_user_id;

  IF nullif(v_phone, '') IS NULL OR v_phone_confirmed_at IS NULL THEN
    RAISE EXCEPTION 'phone_not_verified' USING ERRCODE = 'P0001';
  END IF;
  IF v_phone NOT LIKE v_dialing_code || '%' THEN
    RAISE EXCEPTION 'phone_country_mismatch' USING ERRCODE = 'P0001';
  END IF;

  UPDATE public.users
  SET phone = v_phone,
      phone_country_code = v_country_code,
      phone_verified_at = now()
  WHERE id = v_user_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.confirm_my_verified_phone()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid := private.assert_authenticated();
  v_country_code text;
BEGIN
  SELECT coalesce(u.phone_country_code, u.country_code)
  INTO v_country_code
  FROM public.users u
  WHERE u.id = v_user_id;

  PERFORM public.confirm_my_verified_phone(v_country_code);
END;
$$;

REVOKE ALL ON FUNCTION public.confirm_my_verified_phone(text)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.confirm_my_verified_phone(text)
  TO authenticated;
REVOKE ALL ON FUNCTION public.confirm_my_verified_phone()
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.confirm_my_verified_phone()
  TO authenticated;

COMMENT ON TABLE public.india_state_mother_tongues IS
  'Server-owned India mother-tongue ranking seeded from Census C-16/state context. State residence ranks options but never removes the India-wide catalogue.';
COMMENT ON FUNCTION public.assert_my_phone_country_enabled(text) IS
  'Requires an authenticated Premium member and a server-enabled launch country before phone OTP can start or be confirmed.';

NOTIFY pgrst, 'reload schema';
