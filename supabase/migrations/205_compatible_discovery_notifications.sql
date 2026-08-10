-- Privacy-safe, cost-bounded notifications for newly available Discovery
-- inventory. The client records only its authoritative empty/non-empty feed
-- result and filters. A service-role worker re-runs the canonical feed before
-- sending anything, so notifications can never bypass discovery, moderation,
-- relationship, block, report, location, or Premium-filter rules.

ALTER TABLE public.notification_prefs
  ADD COLUMN IF NOT EXISTS new_compatible_profiles boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS discovery_digest_frequency text NOT NULL DEFAULT 'off';

ALTER TABLE public.notification_prefs
  DROP CONSTRAINT IF EXISTS notification_prefs_discovery_digest_frequency_check;
ALTER TABLE public.notification_prefs
  ADD CONSTRAINT notification_prefs_discovery_digest_frequency_check
  CHECK (discovery_digest_frequency IN ('off', 'daily', 'weekly'));

CREATE TABLE IF NOT EXISTS private.discovery_notification_state (
  user_id uuid PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
  filters jsonb NOT NULL DEFAULT '{}'::jsonb,
  target_gender text,
  candidate_country_codes text[] NOT NULL DEFAULT ARRAY[]::text[],
  inventory_empty boolean NOT NULL DEFAULT false,
  last_feed_opened_at timestamptz NOT NULL DEFAULT now(),
  last_alerted_at timestamptz,
  last_digest_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CHECK (target_gender IS NULL OR target_gender IN ('male', 'female')),
  CHECK (pg_catalog.jsonb_typeof(filters) = 'object'),
  CHECK (pg_catalog.octet_length(filters::text) <= 4096)
);

CREATE INDEX IF NOT EXISTS idx_discovery_notification_empty_audience
  ON private.discovery_notification_state(
    target_gender,
    last_feed_opened_at DESC,
    user_id
  )
  WHERE inventory_empty = true;

CREATE INDEX IF NOT EXISTS idx_discovery_notification_digest_audience
  ON private.discovery_notification_state(last_digest_at, user_id)
  WHERE inventory_empty = false;

CREATE TABLE IF NOT EXISTS private.discovery_eligible_members (
  user_id uuid PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
  profile_id uuid NOT NULL UNIQUE REFERENCES public.profiles(id) ON DELETE CASCADE,
  gender text NOT NULL CHECK (gender IN ('male', 'female')),
  country_code text,
  tracked_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS private.discovery_availability_events (
  candidate_user_id uuid PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
  candidate_profile_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  candidate_gender text NOT NULL CHECK (candidate_gender IN ('male', 'female')),
  candidate_country_code text,
  cursor_user_id uuid,
  remaining_recipient_budget integer NOT NULL DEFAULT 500
    CHECK (remaining_recipient_budget BETWEEN 0 AND 500),
  event_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_discovery_availability_events_due
  ON private.discovery_availability_events(event_at, candidate_user_id);

CREATE TABLE IF NOT EXISTS private.discovery_notification_copy (
  language_code text PRIMARY KEY,
  title text NOT NULL CHECK (char_length(title) BETWEEN 1 AND 160),
  body text NOT NULL CHECK (char_length(body) BETWEEN 1 AND 1000)
);

INSERT INTO private.discovery_notification_copy(language_code, title, body)
VALUES
  ('en', 'New compatible profiles are available', 'Open Discovery to view profiles selected for your preferences.'),
  ('ar', 'تتوفر ملفات شخصية متوافقة جديدة', 'افتح قسم الاستكشاف لعرض الملفات الشخصية المختارة وفق تفضيلاتك.'),
  ('bn', 'নতুন উপযুক্ত প্রোফাইল পাওয়া যাচ্ছে', 'আপনার পছন্দ অনুযায়ী বাছাই করা প্রোফাইল দেখতে ডিসকভারি খুলুন।'),
  ('de', 'Neue passende Profile sind verfügbar', 'Öffne Entdecken, um Profile zu sehen, die deinen Einstellungen entsprechen.'),
  ('fr', 'De nouveaux profils compatibles sont disponibles', 'Ouvrez Découvrir pour voir les profils sélectionnés selon vos préférences.'),
  ('hi', 'नए अनुकूल प्रोफ़ाइल उपलब्ध हैं', 'आपकी पसंद के अनुसार चुनी गई प्रोफ़ाइल देखने के लिए डिस्कवरी खोलें।'),
  ('id', 'Profil baru yang cocok tersedia', 'Buka Temukan untuk melihat profil yang dipilih sesuai preferensi Anda.'),
  ('ms', 'Profil baharu yang serasi tersedia', 'Buka Teroka untuk melihat profil yang dipilih mengikut pilihan anda.'),
  ('tr', 'Yeni uyumlu profiller mevcut', 'Tercihlerinize göre seçilen profilleri görmek için Keşfet''i açın.'),
  ('ur', 'نئے موزوں پروفائلز دستیاب ہیں', 'اپنی ترجیحات کے مطابق منتخب پروفائلز دیکھنے کے لیے ڈسکوری کھولیں۔')
ON CONFLICT (language_code) DO UPDATE
SET title = EXCLUDED.title,
    body = EXCLUDED.body;

REVOKE ALL ON private.discovery_notification_state,
  private.discovery_eligible_members,
  private.discovery_availability_events,
  private.discovery_notification_copy
  FROM PUBLIC, anon, authenticated;

-- Allow the bounded worker to reuse the exact member feed. Interactive callers
-- remain restricted to their own user id, and Premium entitlements are still
-- checked for both member and service-role calls.
DO $migration$
DECLARE
  v_signature regprocedure :=
    'public.get_discovery_feed(uuid,double precision,uuid,integer,jsonb)'::regprocedure;
  v_definition text;
  v_updated text;
  v_anchor text := 'IF auth.uid() IS DISTINCT FROM p_viewer_id THEN';
  v_replacement text :=
    'IF auth.role() <> ''service_role'' AND auth.uid() IS DISTINCT FROM p_viewer_id THEN';
BEGIN
  SELECT pg_get_functiondef(v_signature) INTO v_definition;
  IF position(v_replacement IN v_definition) = 0 THEN
    IF position(v_anchor IN v_definition) = 0 THEN
      RAISE EXCEPTION 'discovery_service_role_anchor_not_found'
        USING ERRCODE = 'P0001';
    END IF;
    v_updated := replace(v_definition, v_anchor, v_replacement);
    EXECUTE v_updated;
  END IF;
END;
$migration$;

REVOKE ALL ON FUNCTION public.get_discovery_feed(
  uuid, double precision, uuid, integer, jsonb
) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_discovery_feed(
  uuid, double precision, uuid, integer, jsonb
) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.record_discovery_inventory(
  p_filters jsonb,
  p_has_profiles boolean
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_filters jsonb := coalesce(p_filters, '{}'::jsonb);
  v_viewer_gender text;
  v_viewer_country text;
  v_target_gender text;
  v_countries text[] := ARRAY[]::text[];
  v_unknown_key text;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'authentication_required' USING ERRCODE = '42501';
  END IF;
  IF jsonb_typeof(v_filters) <> 'object'
    OR octet_length(v_filters::text) > 4096 THEN
    RAISE EXCEPTION 'invalid_discovery_filters' USING ERRCODE = '22023';
  END IF;

  SELECT key INTO v_unknown_key
  FROM jsonb_object_keys(v_filters) key
  WHERE key NOT IN (
    'location_scope', 'max_distance_km', 'same_city', 'same_region',
    'same_country', 'anywhere', 'country_codes', 'diaspora_mode',
    'diaspora_countries', 'age_min', 'age_max', 'active_recently',
    'gender_pref', 'sect', 'deen_level', 'verified_only', 'family_type',
    'marital_status', 'open_to_divorced', 'education_min',
    'mother_tongue', 'community', 'living_expectation',
    'quran_memorization', 'marriage_timeline', 'willing_to_relocate',
    'has_children'
  )
  LIMIT 1;
  IF v_unknown_key IS NOT NULL THEN
    RAISE EXCEPTION 'unsupported_discovery_filter: %', v_unknown_key
      USING ERRCODE = '22023';
  END IF;

  PERFORM private.assert_discovery_filter_entitlement(v_user_id, v_filters);

  SELECT lower(p.gender::text), upper(p.country_code::text)
  INTO v_viewer_gender, v_viewer_country
  FROM public.profiles p
  WHERE p.user_id = v_user_id;

  v_target_gender := nullif(lower(trim(v_filters->>'gender_pref')), '');
  IF v_target_gender IS NULL THEN
    v_target_gender := CASE v_viewer_gender
      WHEN 'male' THEN 'female'
      WHEN 'female' THEN 'male'
      ELSE NULL
    END;
  END IF;
  IF v_target_gender NOT IN ('male', 'female') THEN
    v_target_gender := NULL;
  END IF;

  IF jsonb_typeof(v_filters->'country_codes') = 'array' THEN
    SELECT coalesce(array_agg(DISTINCT upper(trim(value))), ARRAY[]::text[])
    INTO v_countries
    FROM jsonb_array_elements_text(v_filters->'country_codes') value
    WHERE nullif(trim(value), '') IS NOT NULL;
  ELSIF coalesce((v_filters->>'same_country')::boolean, false)
    OR coalesce((v_filters->>'same_city')::boolean, false)
    OR coalesce((v_filters->>'same_region')::boolean, false)
    OR lower(coalesce(v_filters->>'location_scope', '')) IN (
      'same_country', 'same_city', 'same_region'
    ) THEN
    IF v_viewer_country IS NOT NULL THEN
      v_countries := ARRAY[v_viewer_country];
    END IF;
  END IF;

  INSERT INTO private.discovery_notification_state(
    user_id,
    filters,
    target_gender,
    candidate_country_codes,
    inventory_empty,
    last_feed_opened_at,
    last_digest_at,
    updated_at
  )
  VALUES (
    v_user_id,
    v_filters,
    v_target_gender,
    v_countries,
    NOT p_has_profiles,
    now(),
    now(),
    now()
  )
  ON CONFLICT (user_id) DO UPDATE
  SET filters = EXCLUDED.filters,
      target_gender = EXCLUDED.target_gender,
      candidate_country_codes = EXCLUDED.candidate_country_codes,
      inventory_empty = EXCLUDED.inventory_empty,
      last_feed_opened_at = EXCLUDED.last_feed_opened_at,
      last_digest_at = EXCLUDED.last_digest_at,
      updated_at = EXCLUDED.updated_at;
END;
$$;

REVOKE ALL ON FUNCTION public.record_discovery_inventory(jsonb, boolean)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.record_discovery_inventory(jsonb, boolean)
  TO authenticated;

CREATE OR REPLACE FUNCTION private.enqueue_discovery_availability_event(
  p_user_id uuid,
  p_profile_id uuid,
  p_gender text,
  p_country_code text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF p_user_id IS NULL OR p_profile_id IS NULL
    OR lower(p_gender) NOT IN ('male', 'female') THEN
    RETURN;
  END IF;

  INSERT INTO private.discovery_availability_events(
    candidate_user_id,
    candidate_profile_id,
    candidate_gender,
    candidate_country_code
  )
  VALUES (
    p_user_id,
    p_profile_id,
    lower(p_gender),
    nullif(upper(trim(p_country_code)), '')
  )
  ON CONFLICT (candidate_user_id) DO UPDATE
  SET candidate_profile_id = EXCLUDED.candidate_profile_id,
      candidate_gender = EXCLUDED.candidate_gender,
      candidate_country_code = EXCLUDED.candidate_country_code,
      cursor_user_id = NULL,
      remaining_recipient_budget = 500,
      event_at = now(),
      updated_at = now();
END;
$$;

REVOKE ALL ON FUNCTION private.enqueue_discovery_availability_event(
  uuid, uuid, text, text
) FROM PUBLIC;

CREATE OR REPLACE FUNCTION private.reconcile_discovery_eligible_member(
  p_user_id uuid,
  p_force_event boolean DEFAULT false
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_current record;
  v_previous record;
BEGIN
  IF p_user_id IS NULL THEN RETURN; END IF;

  SELECT pool.profile_id, pool.user_id, lower(pool.gender::text) AS gender,
    nullif(upper(trim(pool.country_code::text)), '') AS country_code
  INTO v_current
  FROM public.live_discovery_pool pool
  WHERE pool.user_id = p_user_id
  LIMIT 1;

  SELECT tracked.user_id, tracked.profile_id, tracked.gender,
    tracked.country_code
  INTO v_previous
  FROM private.discovery_eligible_members tracked
  WHERE tracked.user_id = p_user_id;

  IF v_current.user_id IS NULL THEN
    DELETE FROM private.discovery_eligible_members
    WHERE user_id = p_user_id;
    RETURN;
  END IF;

  INSERT INTO private.discovery_eligible_members(
    user_id, profile_id, gender, country_code, tracked_at
  )
  VALUES (
    v_current.user_id,
    v_current.profile_id,
    v_current.gender,
    v_current.country_code,
    now()
  )
  ON CONFLICT (user_id) DO UPDATE
  SET profile_id = EXCLUDED.profile_id,
      gender = EXCLUDED.gender,
      country_code = EXCLUDED.country_code,
      tracked_at = EXCLUDED.tracked_at;

  IF v_previous.user_id IS NULL
    OR v_previous.gender IS DISTINCT FROM v_current.gender
    OR v_previous.country_code IS DISTINCT FROM v_current.country_code
    OR p_force_event THEN
    PERFORM private.enqueue_discovery_availability_event(
      v_current.user_id,
      v_current.profile_id,
      v_current.gender,
      v_current.country_code
    );
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION private.reconcile_discovery_eligible_member(uuid, boolean)
  FROM PUBLIC;

CREATE OR REPLACE FUNCTION private.reconcile_discovery_profile_trigger()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    PERFORM private.reconcile_discovery_eligible_member(OLD.user_id, false);
    RETURN OLD;
  END IF;
  PERFORM private.reconcile_discovery_eligible_member(
    NEW.user_id,
    TG_OP = 'UPDATE'
  );
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION private.reconcile_discovery_photo_trigger()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_profile_id uuid := CASE WHEN TG_OP = 'DELETE' THEN OLD.profile_id ELSE NEW.profile_id END;
  v_user_id uuid;
BEGIN
  SELECT p.user_id INTO v_user_id
  FROM public.profiles p WHERE p.id = v_profile_id;
  PERFORM private.reconcile_discovery_eligible_member(v_user_id, false);
  IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION private.reconcile_discovery_user_trigger()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  PERFORM private.reconcile_discovery_eligible_member(NEW.id, false);
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_discovery_availability_profiles ON public.profiles;
CREATE TRIGGER trg_discovery_availability_profiles
  AFTER INSERT OR UPDATE OF gender, country_code, city_id, location,
    date_of_birth, sect, deen_level, marriage_timeline, mother_tongue,
    community, living_expectation, quran_memorization,
    willing_to_relocate, previously_married, family_type, children_count,
    education_rank, visibility, onboarding_completed, approved_at
  ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION private.reconcile_discovery_profile_trigger();

DROP TRIGGER IF EXISTS trg_discovery_availability_profile_delete ON public.profiles;
CREATE TRIGGER trg_discovery_availability_profile_delete
  AFTER DELETE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION private.reconcile_discovery_profile_trigger();

DROP TRIGGER IF EXISTS trg_discovery_availability_photos ON public.photos;
CREATE TRIGGER trg_discovery_availability_photos
  AFTER INSERT OR DELETE OR UPDATE OF order_index, status, admin_approved,
    nsfw_cleared
  ON public.photos
  FOR EACH ROW EXECUTE FUNCTION private.reconcile_discovery_photo_trigger();

DROP TRIGGER IF EXISTS trg_discovery_availability_accounts ON public.users;
CREATE TRIGGER trg_discovery_availability_accounts
  AFTER UPDATE OF gender, is_banned, is_shadowbanned, deleted_at
  ON public.users
  FOR EACH ROW EXECUTE FUNCTION private.reconcile_discovery_user_trigger();

-- Existing live members establish the baseline without generating a launch
-- notification storm.
INSERT INTO private.discovery_eligible_members(
  user_id, profile_id, gender, country_code
)
SELECT pool.user_id, pool.profile_id, lower(pool.gender::text),
  nullif(upper(trim(pool.country_code::text)), '')
FROM public.live_discovery_pool pool
WHERE lower(pool.gender::text) IN ('male', 'female')
ON CONFLICT (user_id) DO UPDATE
SET profile_id = EXCLUDED.profile_id,
    gender = EXCLUDED.gender,
    country_code = EXCLUDED.country_code,
    tracked_at = now();

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
    WHEN p_type IN ('interest_accepted', 'photo_access_granted', 'match', 'match_accepted')
      THEN coalesce(np.interest_accepted, true)
    WHEN p_type = 'profile_view'
      THEN coalesce(np.profile_view, true)
    WHEN p_type IN (
      'profile_returned_to_review', 'profile_live',
      'photo_approved', 'photo_rejected'
    ) THEN coalesce(np.profile_live, true)
    WHEN p_type = 'interest_expiring'
      THEN coalesce(np.interest_expiring, true)
    WHEN p_type IN ('inactive_nudge', 'profile_nudge')
      THEN coalesce(np.inactive_nudge, true)
    WHEN p_type IN (
      'boost_ready', 'boost_available',
      'referral_reward', 'referral_completed'
    ) THEN coalesce(np.boost_available, true)
    WHEN p_type = 'new_compatible_profiles'
      THEN coalesce(np.new_compatible_profiles, true)
    ELSE true
  END
  FROM (SELECT p_user_id AS user_id) target
  LEFT JOIN public.notification_prefs np ON np.user_id = target.user_id;
$$;

REVOKE ALL ON FUNCTION public.notification_push_enabled(uuid, text)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.notification_push_enabled(uuid, text)
  TO service_role;

CREATE OR REPLACE FUNCTION public.process_discovery_availability_notifications(
  p_batch_size integer DEFAULT 40
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_limit integer := greatest(1, least(coalesce(p_batch_size, 40), 100));
  v_event_limit integer;
  v_event record;
  v_state record;
  v_candidate record;
  v_copy record;
  v_processed integer := 0;
  v_queued integer := 0;
  v_event_processed integer := 0;
  v_digest_processed integer := 0;
  v_any boolean;
  v_new boolean;
  v_event_candidates integer := 0;
  v_more boolean := false;
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'service_role_required' USING ERRCODE = '42501';
  END IF;
  IF NOT pg_try_advisory_xact_lock(hashtext('discovery_availability_notifications')) THEN
    RETURN jsonb_build_object('processed', 0, 'queued', 0, 'busy', true);
  END IF;

  DELETE FROM private.discovery_availability_events
  WHERE event_at < now() - interval '24 hours'
    OR remaining_recipient_budget <= 0;

  v_event_limit := least(v_limit, 30);
  SELECT event.* INTO v_event
  FROM private.discovery_availability_events event
  ORDER BY event.event_at, event.candidate_user_id
  FOR UPDATE SKIP LOCKED
  LIMIT 1;

  IF v_event.candidate_user_id IS NOT NULL THEN
    FOR v_state IN
      SELECT state.*
      FROM private.discovery_notification_state state
      JOIN public.users account ON account.id = state.user_id
      JOIN public.profiles viewer ON viewer.user_id = state.user_id
      LEFT JOIN public.notification_prefs prefs ON prefs.user_id = state.user_id
      WHERE state.inventory_empty = true
        AND state.target_gender = v_event.candidate_gender
        AND state.user_id <> v_event.candidate_user_id
        AND (v_event.cursor_user_id IS NULL OR state.user_id > v_event.cursor_user_id)
        AND (
          cardinality(state.candidate_country_codes) = 0
          OR v_event.candidate_country_code = ANY(state.candidate_country_codes)
        )
        AND state.last_feed_opened_at >= now() - interval '30 days'
        AND coalesce(viewer.last_active_at, state.last_feed_opened_at)
          >= now() - interval '30 days'
        AND account.deleted_at IS NULL
        AND coalesce(account.is_banned, false) = false
        AND coalesce(account.is_shadowbanned, false) = false
        AND coalesce(prefs.new_compatible_profiles, true) = true
        AND (
          state.last_alerted_at IS NULL
          OR state.last_alerted_at < now() - interval '24 hours'
        )
      ORDER BY state.user_id
      FOR UPDATE OF state SKIP LOCKED
      LIMIT v_event_limit
    LOOP
      v_event_candidates := v_event_candidates + 1;
      v_processed := v_processed + 1;
      v_event_processed := v_event_processed + 1;
      v_event.cursor_user_id := v_state.user_id;
      BEGIN
        SELECT EXISTS (
          SELECT 1
          FROM public.get_discovery_feed(
            v_state.user_id,
            NULL,
            NULL,
            1,
            v_state.filters
          ) feed
        ) INTO v_any;

        IF v_any AND v_event.remaining_recipient_budget > 0 THEN
          SELECT copy.title, copy.body INTO v_copy
          FROM public.users account
          LEFT JOIN private.discovery_notification_copy copy
            ON copy.language_code = lower(account.preferred_language)
          WHERE account.id = v_state.user_id;
          IF v_copy.title IS NULL THEN
            SELECT copy.title, copy.body INTO v_copy
            FROM private.discovery_notification_copy copy
            WHERE copy.language_code = 'en';
          END IF;

          PERFORM public.queue_notification(
            v_state.user_id,
            'new_compatible_profiles',
            v_copy.title,
            v_copy.body,
            'silarah://discover'
          );
          UPDATE private.discovery_notification_state
          SET inventory_empty = false,
              last_alerted_at = now(),
              last_digest_at = now(),
              updated_at = now()
          WHERE user_id = v_state.user_id;
          v_event.remaining_recipient_budget :=
            v_event.remaining_recipient_budget - 1;
          v_queued := v_queued + 1;
        END IF;
      EXCEPTION WHEN OTHERS THEN
        -- A stale Premium filter or malformed historical state must not abort
        -- delivery for unrelated members. The client will replace it on the
        -- next successful Discovery load.
        UPDATE private.discovery_notification_state
        SET updated_at = now()
        WHERE user_id = v_state.user_id;
      END;
    END LOOP;

    SELECT EXISTS (
      SELECT 1
      FROM private.discovery_notification_state state
      JOIN public.users account ON account.id = state.user_id
      JOIN public.profiles viewer ON viewer.user_id = state.user_id
      LEFT JOIN public.notification_prefs prefs ON prefs.user_id = state.user_id
      WHERE state.inventory_empty = true
        AND state.target_gender = v_event.candidate_gender
        AND state.user_id <> v_event.candidate_user_id
        AND (v_event.cursor_user_id IS NULL OR state.user_id > v_event.cursor_user_id)
        AND (
          cardinality(state.candidate_country_codes) = 0
          OR v_event.candidate_country_code = ANY(state.candidate_country_codes)
        )
        AND state.last_feed_opened_at >= now() - interval '30 days'
        AND account.deleted_at IS NULL
        AND coalesce(account.is_banned, false) = false
        AND coalesce(account.is_shadowbanned, false) = false
        AND coalesce(prefs.new_compatible_profiles, true) = true
      LIMIT 1
    ) INTO v_more;

    IF NOT v_more OR v_event.remaining_recipient_budget <= 0
      OR v_event_candidates = 0 THEN
      DELETE FROM private.discovery_availability_events
      WHERE candidate_user_id = v_event.candidate_user_id;
    ELSE
      UPDATE private.discovery_availability_events
      SET cursor_user_id = v_event.cursor_user_id,
          remaining_recipient_budget = v_event.remaining_recipient_budget,
          updated_at = now()
      WHERE candidate_user_id = v_event.candidate_user_id;
    END IF;
  END IF;

  -- Digests are deliberately opt-in. They are evaluated at most once per
  -- selected interval and only claim "new" when an exact feed result belongs
  -- to a profile approved after the last evaluation.
  FOR v_state IN
    SELECT state.*, prefs.discovery_digest_frequency
    FROM private.discovery_notification_state state
    JOIN public.users account ON account.id = state.user_id
    JOIN public.profiles viewer ON viewer.user_id = state.user_id
    JOIN public.notification_prefs prefs ON prefs.user_id = state.user_id
    WHERE state.inventory_empty = false
      AND prefs.new_compatible_profiles = true
      AND prefs.discovery_digest_frequency IN ('daily', 'weekly')
      AND state.last_feed_opened_at >= now() - interval '30 days'
      AND coalesce(viewer.last_active_at, state.last_feed_opened_at)
        >= now() - interval '30 days'
      AND account.deleted_at IS NULL
      AND coalesce(account.is_banned, false) = false
      AND coalesce(account.is_shadowbanned, false) = false
      AND state.last_digest_at <= now() - CASE prefs.discovery_digest_frequency
        WHEN 'daily' THEN interval '1 day'
        ELSE interval '7 days'
      END
    ORDER BY state.last_digest_at, state.user_id
    FOR UPDATE OF state SKIP LOCKED
    LIMIT greatest(0, v_limit - v_event_processed)
  LOOP
    v_processed := v_processed + 1;
    v_digest_processed := v_digest_processed + 1;
    v_any := false;
    v_new := false;
    BEGIN
      FOR v_candidate IN
        SELECT feed.profile_id
        FROM public.get_discovery_feed(
          v_state.user_id,
          NULL,
          NULL,
          50,
          v_state.filters
        ) feed
      LOOP
        v_any := true;
        IF EXISTS (
          SELECT 1 FROM public.profiles candidate
          WHERE candidate.id = v_candidate.profile_id
            AND candidate.approved_at > v_state.last_digest_at
        ) THEN
          v_new := true;
          EXIT;
        END IF;
      END LOOP;

      IF v_new AND (
        v_state.last_alerted_at IS NULL
        OR v_state.last_alerted_at < now() - interval '24 hours'
      ) THEN
        SELECT copy.title, copy.body INTO v_copy
        FROM public.users account
        LEFT JOIN private.discovery_notification_copy copy
          ON copy.language_code = lower(account.preferred_language)
        WHERE account.id = v_state.user_id;
        IF v_copy.title IS NULL THEN
          SELECT copy.title, copy.body INTO v_copy
          FROM private.discovery_notification_copy copy
          WHERE copy.language_code = 'en';
        END IF;
        PERFORM public.queue_notification(
          v_state.user_id,
          'new_compatible_profiles',
          v_copy.title,
          v_copy.body,
          'silarah://discover'
        );
        v_queued := v_queued + 1;
      END IF;

      UPDATE private.discovery_notification_state
      SET inventory_empty = NOT v_any,
          last_alerted_at = CASE WHEN v_new THEN now() ELSE last_alerted_at END,
          last_digest_at = now(),
          updated_at = now()
      WHERE user_id = v_state.user_id;
    EXCEPTION WHEN OTHERS THEN
      UPDATE private.discovery_notification_state
      SET last_digest_at = now(), updated_at = now()
      WHERE user_id = v_state.user_id;
    END;
  END LOOP;

  RETURN jsonb_build_object(
    'processed', v_processed,
    'event_processed', v_event_processed,
    'digest_processed', v_digest_processed,
    'queued', v_queued,
    'busy', false
  );
END;
$$;

REVOKE ALL ON FUNCTION public.process_discovery_availability_notifications(integer)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.process_discovery_availability_notifications(integer)
  TO service_role;

CREATE OR REPLACE FUNCTION private.discovery_notification_work_due()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1 FROM private.discovery_availability_events
    WHERE event_at >= now() - interval '24 hours'
      AND remaining_recipient_budget > 0
  ) OR EXISTS (
    SELECT 1
    FROM private.discovery_notification_state state
    JOIN public.notification_prefs prefs ON prefs.user_id = state.user_id
    WHERE state.inventory_empty = false
      AND prefs.new_compatible_profiles = true
      AND prefs.discovery_digest_frequency IN ('daily', 'weekly')
      AND state.last_feed_opened_at >= now() - interval '30 days'
      AND state.last_digest_at <= now() - CASE prefs.discovery_digest_frequency
        WHEN 'daily' THEN interval '1 day'
        ELSE interval '7 days'
      END
  );
$$;

REVOKE ALL ON FUNCTION private.discovery_notification_work_due() FROM PUBLIC;

CREATE OR REPLACE FUNCTION private.invoke_discovery_notification_worker()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_secret text;
  v_url text;
BEGIN
  IF NOT private.discovery_notification_work_due() THEN RETURN; END IF;

  v_url := nullif(current_setting('app.supabase_url', true), '');
  IF v_url IS NULL THEN
    SELECT decrypted_secret INTO v_url
    FROM vault.decrypted_secrets
    WHERE name = 'silarah_supabase_url'
    LIMIT 1;
  END IF;
  SELECT decrypted_secret INTO v_secret
  FROM vault.decrypted_secrets
  WHERE name IN ('silarah_edge_cron_secret', 'mithaq_edge_cron_secret')
  ORDER BY (name = 'silarah_edge_cron_secret') DESC
  LIMIT 1;

  IF v_url IS NULL OR nullif(v_secret, '') IS NULL
    OR v_url !~ '^https://[a-z0-9-]+[.]supabase[.]co$' THEN
    PERFORM private.set_operational_alert(
      'discovery_notification_worker_configuration',
      'Discovery notification worker URL or private cron credential is missing or invalid.',
      1,
      true
    );
    RETURN;
  END IF;

  PERFORM private.set_operational_alert(
    'discovery_notification_worker_configuration',
    'Discovery notification worker configuration is healthy.',
    0,
    false
  );
  PERFORM net.http_post(
    url := v_url || '/functions/v1/dispatch-notifications',
    body := jsonb_build_object('source', 'discovery_availability'),
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-cron-secret', v_secret
    ),
    timeout_milliseconds := 10000
  );
END;
$$;

REVOKE ALL ON FUNCTION private.invoke_discovery_notification_worker()
  FROM PUBLIC;

CREATE OR REPLACE FUNCTION private.wake_discovery_notification_worker()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  PERFORM private.invoke_discovery_notification_worker();
  RETURN NULL;
END;
$$;

REVOKE ALL ON FUNCTION private.wake_discovery_notification_worker()
  FROM PUBLIC;

DROP TRIGGER IF EXISTS trg_wake_discovery_notification_worker
  ON private.discovery_availability_events;
CREATE TRIGGER trg_wake_discovery_notification_worker
  AFTER INSERT ON private.discovery_availability_events
  FOR EACH STATEMENT
  EXECUTE FUNCTION private.wake_discovery_notification_worker();

DO $migration$
DECLARE
  v_job record;
BEGIN
  FOR v_job IN
    SELECT jobid FROM cron.job
    WHERE jobname = 'discovery_notifications_bounded_5m'
  LOOP
    PERFORM cron.unschedule(v_job.jobid);
  END LOOP;
  PERFORM cron.schedule(
    'discovery_notifications_bounded_5m',
    '*/5 * * * *',
    'SELECT private.invoke_discovery_notification_worker();'
  );
END;
$migration$;

COMMENT ON FUNCTION public.record_discovery_inventory(jsonb, boolean) IS
  'Records the signed-in member''s authoritative feed result for privacy-safe zero-to-available alerts.';
COMMENT ON FUNCTION public.process_discovery_availability_notifications(integer) IS
  'Service-role-only, exact-feed, bounded-fanout worker for compatible-profile alerts and opt-in digests.';

NOTIFY pgrst, 'reload schema';
