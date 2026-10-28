-- Silarah — festival greetings for Ramadan, the last ten nights, both Eids
-- and the Hijri new year.
--
-- About five greetings a year, sent at 09:00 in each member's own timezone on
-- the date that applies to their country. Dates come from the Umm al-Qura
-- calendar; South Asian rows default to one day later and are adjusted the
-- evening before when the local moon-sighting announcement differs:
--   UPDATE private.islamic_occasions SET occasion_date = date 'YYYY-MM-DD'
--   WHERE occasion_key = 'eid_al_fitr' AND hijri_year = 1448
--     AND country_code = 'IN';
-- Mawlid and Shab-e-Barat are deliberately absent: a share of members regard
-- them as innovation, and a greeting should never take a side.

ALTER TABLE public.notification_prefs
  ADD COLUMN IF NOT EXISTS festival_greetings boolean NOT NULL DEFAULT true;

CREATE TABLE IF NOT EXISTS private.islamic_occasions (
  occasion_key text NOT NULL CHECK (occasion_key IN ('ramadan_start', 'last_ten_nights', 'eid_al_fitr', 'eid_al_adha', 'islamic_new_year')),
  hijri_year integer NOT NULL CHECK (hijri_year BETWEEN 1440 AND 1500),
  -- '*' is the default date; a country row overrides it for that country.
  country_code text NOT NULL DEFAULT '*'
    CHECK (country_code = '*' OR country_code ~ '^[A-Z]{2}$'),
  occasion_date date NOT NULL,
  PRIMARY KEY (occasion_key, hijri_year, country_code)
);

CREATE INDEX IF NOT EXISTS idx_islamic_occasions_date
  ON private.islamic_occasions(occasion_date);

CREATE TABLE IF NOT EXISTS private.festival_greeting_copy (
  occasion_key text NOT NULL,
  language_code text NOT NULL,
  -- {year} in the title is replaced with the Hijri year.
  title text NOT NULL CHECK (char_length(title) BETWEEN 1 AND 160),
  body text NOT NULL CHECK (char_length(body) BETWEEN 1 AND 1000),
  PRIMARY KEY (occasion_key, language_code)
);

-- One greeting per member per occasion, however often the job runs.
CREATE TABLE IF NOT EXISTS private.festival_greetings_sent (
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  occasion_key text NOT NULL,
  hijri_year integer NOT NULL,
  sent_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, occasion_key, hijri_year)
);

ALTER TABLE private.islamic_occasions ENABLE ROW LEVEL SECURITY;
ALTER TABLE private.festival_greeting_copy ENABLE ROW LEVEL SECURITY;
ALTER TABLE private.festival_greetings_sent ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON private.islamic_occasions,
  private.festival_greeting_copy,
  private.festival_greetings_sent
  FROM PUBLIC, anon, authenticated;

INSERT INTO private.islamic_occasions(
  occasion_key, hijri_year, country_code, occasion_date
)
VALUES
  ('ramadan_start', 1448, '*', date '2027-02-08'),
  ('ramadan_start', 1448, 'BD', date '2027-02-09'),
  ('ramadan_start', 1448, 'IN', date '2027-02-09'),
  ('ramadan_start', 1448, 'PK', date '2027-02-09'),
  ('last_ten_nights', 1448, '*', date '2027-02-27'),
  ('last_ten_nights', 1448, 'BD', date '2027-02-28'),
  ('last_ten_nights', 1448, 'IN', date '2027-02-28'),
  ('last_ten_nights', 1448, 'PK', date '2027-02-28'),
  ('eid_al_fitr', 1448, '*', date '2027-03-09'),
  ('eid_al_fitr', 1448, 'BD', date '2027-03-10'),
  ('eid_al_fitr', 1448, 'IN', date '2027-03-10'),
  ('eid_al_fitr', 1448, 'PK', date '2027-03-10'),
  ('eid_al_adha', 1448, '*', date '2027-05-16'),
  ('eid_al_adha', 1448, 'BD', date '2027-05-17'),
  ('eid_al_adha', 1448, 'IN', date '2027-05-17'),
  ('eid_al_adha', 1448, 'PK', date '2027-05-17'),
  ('islamic_new_year', 1449, '*', date '2027-06-06'),
  ('islamic_new_year', 1449, 'BD', date '2027-06-07'),
  ('islamic_new_year', 1449, 'IN', date '2027-06-07'),
  ('islamic_new_year', 1449, 'PK', date '2027-06-07'),
  ('ramadan_start', 1449, '*', date '2028-01-28'),
  ('ramadan_start', 1449, 'BD', date '2028-01-29'),
  ('ramadan_start', 1449, 'IN', date '2028-01-29'),
  ('ramadan_start', 1449, 'PK', date '2028-01-29'),
  ('last_ten_nights', 1449, '*', date '2028-02-16'),
  ('last_ten_nights', 1449, 'BD', date '2028-02-17'),
  ('last_ten_nights', 1449, 'IN', date '2028-02-17'),
  ('last_ten_nights', 1449, 'PK', date '2028-02-17'),
  ('eid_al_fitr', 1449, '*', date '2028-02-26'),
  ('eid_al_fitr', 1449, 'BD', date '2028-02-27'),
  ('eid_al_fitr', 1449, 'IN', date '2028-02-27'),
  ('eid_al_fitr', 1449, 'PK', date '2028-02-27'),
  ('eid_al_adha', 1449, '*', date '2028-05-05'),
  ('eid_al_adha', 1449, 'BD', date '2028-05-06'),
  ('eid_al_adha', 1449, 'IN', date '2028-05-06'),
  ('eid_al_adha', 1449, 'PK', date '2028-05-06'),
  ('islamic_new_year', 1450, '*', date '2028-05-25'),
  ('islamic_new_year', 1450, 'BD', date '2028-05-26'),
  ('islamic_new_year', 1450, 'IN', date '2028-05-26'),
  ('islamic_new_year', 1450, 'PK', date '2028-05-26'),
  ('ramadan_start', 1450, '*', date '2029-01-16'),
  ('ramadan_start', 1450, 'BD', date '2029-01-17'),
  ('ramadan_start', 1450, 'IN', date '2029-01-17'),
  ('ramadan_start', 1450, 'PK', date '2029-01-17'),
  ('last_ten_nights', 1450, '*', date '2029-02-04'),
  ('last_ten_nights', 1450, 'BD', date '2029-02-05'),
  ('last_ten_nights', 1450, 'IN', date '2029-02-05'),
  ('last_ten_nights', 1450, 'PK', date '2029-02-05'),
  ('eid_al_fitr', 1450, '*', date '2029-02-14'),
  ('eid_al_fitr', 1450, 'BD', date '2029-02-15'),
  ('eid_al_fitr', 1450, 'IN', date '2029-02-15'),
  ('eid_al_fitr', 1450, 'PK', date '2029-02-15'),
  ('eid_al_adha', 1450, '*', date '2029-04-24'),
  ('eid_al_adha', 1450, 'BD', date '2029-04-25'),
  ('eid_al_adha', 1450, 'IN', date '2029-04-25'),
  ('eid_al_adha', 1450, 'PK', date '2029-04-25'),
  ('islamic_new_year', 1451, '*', date '2029-05-14'),
  ('islamic_new_year', 1451, 'BD', date '2029-05-15'),
  ('islamic_new_year', 1451, 'IN', date '2029-05-15'),
  ('islamic_new_year', 1451, 'PK', date '2029-05-15'),
  ('ramadan_start', 1451, '*', date '2030-01-05'),
  ('ramadan_start', 1451, 'BD', date '2030-01-06'),
  ('ramadan_start', 1451, 'IN', date '2030-01-06'),
  ('ramadan_start', 1451, 'PK', date '2030-01-06'),
  ('last_ten_nights', 1451, '*', date '2030-01-24'),
  ('last_ten_nights', 1451, 'BD', date '2030-01-25'),
  ('last_ten_nights', 1451, 'IN', date '2030-01-25'),
  ('last_ten_nights', 1451, 'PK', date '2030-01-25'),
  ('eid_al_fitr', 1451, '*', date '2030-02-04'),
  ('eid_al_fitr', 1451, 'BD', date '2030-02-05'),
  ('eid_al_fitr', 1451, 'IN', date '2030-02-05'),
  ('eid_al_fitr', 1451, 'PK', date '2030-02-05'),
  ('eid_al_adha', 1451, '*', date '2030-04-13'),
  ('eid_al_adha', 1451, 'BD', date '2030-04-14'),
  ('eid_al_adha', 1451, 'IN', date '2030-04-14'),
  ('eid_al_adha', 1451, 'PK', date '2030-04-14'),
  ('islamic_new_year', 1452, '*', date '2030-05-04'),
  ('islamic_new_year', 1452, 'BD', date '2030-05-05'),
  ('islamic_new_year', 1452, 'IN', date '2030-05-05'),
  ('islamic_new_year', 1452, 'PK', date '2030-05-05')
ON CONFLICT (occasion_key, hijri_year, country_code) DO NOTHING;

INSERT INTO private.festival_greeting_copy(
  occasion_key, language_code, title, body
)
VALUES
  ('ramadan_start', 'en', 'Ramadan Mubarak', 'May Allah accept your fasts and prayers this Ramadan. Warm wishes from Silarah.'),
  ('ramadan_start', 'ar', 'رمضان مبارك', 'تقبّل الله صيامكم وقيامكم في هذا الشهر الكريم. أطيب التمنيات من Silarah.'),
  ('ramadan_start', 'bn', 'রমজান মোবারক', 'আল্লাহ এই রমজানে আপনার রোজা ও নামাজ কবুল করুন। Silarah-এর পক্ষ থেকে আন্তরিক শুভেচ্ছা।'),
  ('ramadan_start', 'de', 'Ramadan Mubarak', 'Möge Allah dein Fasten und deine Gebete in diesem Ramadan annehmen. Herzliche Grüße von Silarah.'),
  ('ramadan_start', 'fr', 'Ramadan Moubarak', 'Qu''Allah accepte vos jeûnes et vos prières durant ce Ramadan. Chaleureuses pensées de Silarah.'),
  ('ramadan_start', 'hi', 'रमज़ान मुबारक', 'अल्लाह इस रमज़ान में आपके रोज़े और नमाज़ें क़ुबूल करे। Silarah की ओर से दिली शुभकामनाएँ।'),
  ('ramadan_start', 'id', 'Selamat Menunaikan Ibadah Puasa', 'Semoga Allah menerima puasa dan salat Anda di bulan Ramadan ini. Salam hangat dari Silarah.'),
  ('ramadan_start', 'ms', 'Salam Ramadan', 'Semoga Allah menerima puasa dan solat anda pada Ramadan ini. Salam mesra daripada Silarah.'),
  ('ramadan_start', 'tr', 'Hayırlı Ramazanlar', 'Allah bu Ramazan''da oruçlarınızı ve dualarınızı kabul etsin. Silarah''tan sevgilerle.'),
  ('ramadan_start', 'ur', 'رمضان مبارک', 'اللہ اس رمضان میں آپ کے روزے اور نمازیں قبول فرمائے۔ Silarah کی طرف سے دلی نیک خواہشات۔'),
  ('last_ten_nights', 'en', 'The last ten nights begin tonight', 'May you reach Laylat al-Qadr and may your duas be accepted.'),
  ('last_ten_nights', 'ar', 'تبدأ الليالي العشر الأواخر الليلة', 'بلّغكم الله ليلة القدر وتقبّل دعاءكم.'),
  ('last_ten_nights', 'bn', 'আজ রাত থেকে শেষ দশ রাত শুরু', 'আল্লাহ আপনাকে লাইলাতুল কদর নসিব করুন এবং আপনার দোয়া কবুল করুন।'),
  ('last_ten_nights', 'de', 'Heute Nacht beginnen die letzten zehn Nächte', 'Möge Allah dich Laylat al-Qadr erreichen lassen und deine Bittgebete annehmen.'),
  ('last_ten_nights', 'fr', 'Les dix dernières nuits commencent ce soir', 'Qu''Allah vous fasse atteindre Laylat al-Qadr et exauce vos invocations.'),
  ('last_ten_nights', 'hi', 'आज रात से आख़िरी दस रातें शुरू', 'अल्लाह आपको शब-ए-क़द्र नसीब करे और आपकी दुआएँ क़ुबूल करे।'),
  ('last_ten_nights', 'id', 'Sepuluh malam terakhir dimulai malam ini', 'Semoga Allah mempertemukan Anda dengan Lailatul Qadar dan mengabulkan doa-doa Anda.'),
  ('last_ten_nights', 'ms', 'Sepuluh malam terakhir bermula malam ini', 'Semoga Allah mempertemukan anda dengan Lailatulqadar dan memakbulkan doa anda.'),
  ('last_ten_nights', 'tr', 'Son on gece bu akşam başlıyor', 'Allah Kadir Gecesi''ne ulaştırsın, dualarınızı kabul etsin.'),
  ('last_ten_nights', 'ur', 'آج رات سے آخری دس راتیں شروع', 'اللہ آپ کو شبِ قدر نصیب فرمائے اور آپ کی دعائیں قبول فرمائے۔'),
  ('eid_al_fitr', 'en', 'Eid Mubarak', 'Taqabbal Allahu minna wa minkum. Wishing you and your family a joyful Eid al-Fitr.'),
  ('eid_al_fitr', 'ar', 'عيد مبارك', 'تقبّل الله منا ومنكم. نتمنى لكم ولعائلتكم عيد فطر سعيدًا.'),
  ('eid_al_fitr', 'bn', 'ঈদ মোবারক', 'তাকাব্বালাল্লাহু মিন্না ওয়া মিনকুম। আপনাকে ও আপনার পরিবারকে ঈদুল ফিতরের আন্তরিক শুভেচ্ছা।'),
  ('eid_al_fitr', 'de', 'Eid Mubarak', 'Taqabbal Allahu minna wa minkum. Wir wünschen dir und deiner Familie ein frohes Eid al-Fitr.'),
  ('eid_al_fitr', 'fr', 'Aïd Moubarak', 'Taqabbal Allahu minna wa minkum. Nous vous souhaitons, à vous et à votre famille, un joyeux Aïd al-Fitr.'),
  ('eid_al_fitr', 'hi', 'ईद मुबारक', 'तक़ब्बलल्लाहु मिन्ना व मिनकुम। आपको और आपके परिवार को ईद-उल-फ़ित्र की दिली मुबारकबाद।'),
  ('eid_al_fitr', 'id', 'Selamat Hari Raya Idulfitri', 'Taqabbalallahu minna wa minkum. Semoga Anda dan keluarga merayakan Idulfitri dengan penuh kebahagiaan.'),
  ('eid_al_fitr', 'ms', 'Selamat Hari Raya Aidilfitri', 'Taqabbalallahu minna wa minkum. Semoga anda dan keluarga menyambut Aidilfitri dengan penuh kegembiraan.'),
  ('eid_al_fitr', 'tr', 'Ramazan Bayramınız mübarek olsun', 'Allah bizden ve sizden kabul etsin. Size ve ailenize neşeli bir bayram dileriz.'),
  ('eid_al_fitr', 'ur', 'عید مبارک', 'تقبل اللہ منا ومنکم۔ آپ کو اور آپ کے اہلِ خانہ کو عید الفطر کی دلی مبارکباد۔'),
  ('eid_al_adha', 'en', 'Eid al-Adha Mubarak', 'May Allah accept your sacrifice and fill your home with blessings.'),
  ('eid_al_adha', 'ar', 'عيد أضحى مبارك', 'تقبّل الله أضاحيكم وملأ بيوتكم بالبركة.'),
  ('eid_al_adha', 'bn', 'ঈদুল আযহা মোবারক', 'আল্লাহ আপনার কোরবানি কবুল করুন এবং আপনার ঘর বরকতে ভরে দিন।'),
  ('eid_al_adha', 'de', 'Eid al-Adha Mubarak', 'Möge Allah dein Opfer annehmen und dein Zuhause mit Segen füllen.'),
  ('eid_al_adha', 'fr', 'Aïd al-Adha Moubarak', 'Qu''Allah accepte votre sacrifice et remplisse votre foyer de bénédictions.'),
  ('eid_al_adha', 'hi', 'ईद-उल-अज़हा मुबारक', 'अल्लाह आपकी क़ुर्बानी क़ुबूल करे और आपके घर को बरकतों से भर दे।'),
  ('eid_al_adha', 'id', 'Selamat Hari Raya Iduladha', 'Semoga Allah menerima kurban Anda dan melimpahkan keberkahan bagi keluarga Anda.'),
  ('eid_al_adha', 'ms', 'Selamat Hari Raya Aidiladha', 'Semoga Allah menerima korban anda dan melimpahkan keberkatan kepada keluarga anda.'),
  ('eid_al_adha', 'tr', 'Kurban Bayramınız mübarek olsun', 'Allah kurbanınızı kabul etsin, evinizi bereketle doldursun.'),
  ('eid_al_adha', 'ur', 'عید الاضحیٰ مبارک', 'اللہ آپ کی قربانی قبول فرمائے اور آپ کے گھر کو برکتوں سے بھر دے۔'),
  ('islamic_new_year', 'en', 'The Hijri year {year} begins', 'May this new year bring you peace, barakah and good companionship.'),
  ('islamic_new_year', 'ar', 'بداية العام الهجري {year}', 'جعله الله عامًا مليئًا بالسكينة والبركة والصحبة الصالحة.'),
  ('islamic_new_year', 'bn', 'হিজরি {year} সালের সূচনা', 'নতুন বছর আপনার জন্য শান্তি, বরকত ও উত্তম সঙ্গ বয়ে আনুক।'),
  ('islamic_new_year', 'de', 'Das Hidschra-Jahr {year} beginnt', 'Möge dieses neue Jahr dir Frieden, Segen und gute Gesellschaft bringen.'),
  ('islamic_new_year', 'fr', 'Début de l''année hégirienne {year}', 'Que cette nouvelle année vous apporte paix, baraka et bonne compagnie.'),
  ('islamic_new_year', 'hi', 'हिजरी साल {year} की शुरुआत', 'यह नया साल आपके लिए सुकून, बरकत और अच्छी संगत लेकर आए।'),
  ('islamic_new_year', 'id', 'Tahun Baru Hijriah {year}', 'Semoga tahun baru ini membawa ketenangan, keberkahan, dan sahabat yang baik.'),
  ('islamic_new_year', 'ms', 'Awal Tahun Hijrah {year}', 'Semoga tahun baharu ini membawa ketenangan, keberkatan dan teman yang baik.'),
  ('islamic_new_year', 'tr', 'Hicri {year} yılı başlıyor', 'Bu yeni yıl size huzur, bereket ve hayırlı arkadaşlık getirsin.'),
  ('islamic_new_year', 'ur', 'ہجری سال {year} کا آغاز', 'یہ نیا سال آپ کے لیے سکون، برکت اور اچھی صحبت لائے۔')
ON CONFLICT (occasion_key, language_code) DO UPDATE
SET title = EXCLUDED.title,
    body = EXCLUDED.body;

CREATE OR REPLACE FUNCTION private.process_festival_greetings(
  p_batch_size integer DEFAULT 80
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  -- The dispatcher sends 100 pushes per run, so a small batch every five
  -- minutes never queues greetings ahead of chat or interest notifications.
  v_limit integer := greatest(1, least(coalesce(p_batch_size, 80), 500));
  v_today date := (now() AT TIME ZONE 'UTC')::date;
  v_member record;
  v_queued integer := 0;
BEGIN
  IF NOT pg_try_advisory_xact_lock(
    hashtextextended('festival_greetings', 279)
  ) THEN
    RETURN jsonb_build_object('busy', true, 'queued', 0);
  END IF;

  -- Every local date is within a day of UTC, so most days end here.
  IF NOT EXISTS (
    SELECT 1 FROM private.islamic_occasions o
    WHERE o.occasion_date BETWEEN v_today - 1 AND v_today + 1
  ) THEN
    RETURN jsonb_build_object('occasion', false, 'queued', 0);
  END IF;

  FOR v_member IN
    WITH members AS (
      SELECT
        u.id,
        coalesce(upper(nullif(btrim(u.country_code), '')), '*') AS country,
        coalesce(lower(left(nullif(btrim(u.preferred_language), ''), 2)), 'en')
          AS lang,
        now() AT TIME ZONE coalesce(tz.name, 'UTC') AS local_ts
      FROM public.users u
      LEFT JOIN private.timezone_names tz ON tz.name = u.timezone
      LEFT JOIN public.notification_prefs prefs ON prefs.user_id = u.id
      WHERE u.deleted_at IS NULL
        AND coalesce(u.is_banned, false) = false
        AND coalesce(prefs.festival_greetings, true) = true
    )
    SELECT m.id, m.lang, o.occasion_key, o.hijri_year
    FROM members m
    CROSS JOIN LATERAL (
      -- The member's own country row wins over the default date.
      SELECT DISTINCT ON (occ.occasion_key, occ.hijri_year)
        occ.occasion_key, occ.hijri_year, occ.occasion_date
      FROM private.islamic_occasions occ
      WHERE occ.country_code IN (m.country, '*')
        AND occ.occasion_date BETWEEN v_today - 3 AND v_today + 3
      ORDER BY occ.occasion_key, occ.hijri_year, (occ.country_code = '*')
    ) o
    WHERE o.occasion_date = m.local_ts::date
      AND m.local_ts::time >= time '09:00'
      AND m.local_ts::time < time '21:00'
      AND NOT EXISTS (
        SELECT 1 FROM private.festival_greetings_sent sent
        WHERE sent.user_id = m.id
          AND sent.occasion_key = o.occasion_key
          AND sent.hijri_year = o.hijri_year
      )
    ORDER BY m.id
    LIMIT v_limit
  LOOP
    INSERT INTO private.festival_greetings_sent(user_id, occasion_key, hijri_year)
    VALUES (v_member.id, v_member.occasion_key, v_member.hijri_year)
    ON CONFLICT DO NOTHING;
    IF NOT FOUND THEN
      CONTINUE;
    END IF;

    PERFORM public.queue_notification(
      v_member.id,
      'festival_greeting',
      replace(greeting.title, '{year}', v_member.hijri_year::text),
      greeting.body,
      'silarah://notifications'
    )
    FROM (
      SELECT c.title, c.body
      FROM private.festival_greeting_copy c
      WHERE c.occasion_key = v_member.occasion_key
        AND c.language_code IN (v_member.lang, 'en')
      ORDER BY (c.language_code = v_member.lang) DESC
      LIMIT 1
    ) greeting;
    v_queued := v_queued + 1;
  END LOOP;

  RETURN jsonb_build_object('occasion', true, 'queued', v_queued);
END;
$$;

REVOKE ALL ON FUNCTION private.process_festival_greetings(integer)
  FROM PUBLIC, anon, authenticated;

-- Members who switch greetings off get nothing at all from the job above;
-- this keeps the push routing honest for anything already queued.
CREATE OR REPLACE FUNCTION public.notification_push_enabled(
  p_user_id uuid,
  p_type text
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT CASE
    WHEN p_type IN (
      'new_message', 'guardian_message_mirror', 'guardian_sent_message'
    ) THEN coalesce(np.new_message, true)
    WHEN p_type IN (
      'interest_received', 'new_interest', 'photo_access_request'
    ) THEN coalesce(np.new_interest, true)
    WHEN p_type IN (
      'interest_accepted', 'photo_access_granted', 'match', 'match_accepted'
    ) THEN coalesce(np.interest_accepted, true)
    WHEN p_type = 'profile_view' THEN coalesce(np.profile_view, true)
    WHEN p_type IN (
      'profile_returned_to_review', 'profile_live',
      'photo_approved', 'photo_rejected'
    ) THEN coalesce(np.profile_live, true)
    WHEN p_type = 'interest_expiring'
      THEN coalesce(np.interest_expiring, true)
    WHEN p_type IN ('inactive_nudge', 'profile_nudge')
      THEN coalesce(np.inactive_nudge, true)
    WHEN p_type IN ('boost_ready', 'boost_available')
      THEN coalesce(np.boost_available, true)
    WHEN p_type IN ('referral_reward', 'referral_completed') THEN true
    WHEN p_type = 'new_compatible_profiles'
      THEN coalesce(np.new_compatible_profiles, true)
    WHEN p_type = 'festival_greeting'
      THEN coalesce(np.festival_greetings, true)
    ELSE true
  END
  FROM (SELECT p_user_id AS user_id) target
  LEFT JOIN public.notification_prefs np ON np.user_id = target.user_id;
$$;

REVOKE ALL ON FUNCTION public.notification_push_enabled(uuid, text)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.notification_push_enabled(uuid, text)
  TO service_role;

DO $migration$
DECLARE
  v_job record;
BEGIN
  IF to_regclass('cron.job') IS NULL THEN
    RETURN;
  END IF;
  FOR v_job IN
    SELECT jobid FROM cron.job WHERE jobname = 'process_festival_greetings_5m'
  LOOP
    PERFORM cron.unschedule(v_job.jobid);
  END LOOP;
  PERFORM cron.schedule(
    'process_festival_greetings_5m',
    '*/5 * * * *',
    $job$SELECT private.run_guarded_sql(
      'process_festival_greetings_5m',
      'SELECT private.process_festival_greetings(80)',
      60
    );$job$
  );
END;
$migration$;

COMMENT ON TABLE private.islamic_occasions IS
  'Festival dates per Hijri year; a country row overrides the * default.';
COMMENT ON FUNCTION private.process_festival_greetings(integer) IS
  'Queues one localized festival greeting per member at 09:00 local time.';
