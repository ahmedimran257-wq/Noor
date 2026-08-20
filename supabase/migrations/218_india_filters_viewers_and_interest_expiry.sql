-- India Premium discovery completeness, profile-view identity surfaces, and
-- the complete pending-interest expiry lifecycle.

-- Small live populations must not shrink India-wide Premium filter choices.
ALTER TABLE public.discovery_filter_option_catalog
  DROP CONSTRAINT IF EXISTS discovery_filter_option_catalog_field_check;
ALTER TABLE public.discovery_filter_option_catalog
  ADD CONSTRAINT discovery_filter_option_catalog_field_check CHECK (
    field IN (
      'gender', 'sect', 'deen_level', 'education_rank', 'family_type',
      'marital_status', 'mother_tongue', 'community', 'living_expectation',
      'quran_memorization', 'marriage_timeline', 'willing_to_relocate'
    )
  );

INSERT INTO public.discovery_filter_option_catalog(
  field, value, sort_order, active
)
SELECT 'mother_tongue', language,
       100 + row_number() OVER (ORDER BY lower(language)), true
FROM (
  SELECT DISTINCT trim(language) AS language
  FROM public.india_state_mother_tongues
  WHERE nullif(trim(language), '') IS NOT NULL
) values_to_seed
ON CONFLICT (field, value) DO UPDATE
SET sort_order = EXCLUDED.sort_order,
    active = true,
    updated_at = now();

INSERT INTO public.discovery_filter_option_catalog(
  field, value, sort_order, active
)
SELECT 'community', value, ordinal * 10, true
FROM unnest(ARRAY[
  'Syed','Sheikh','Qureshi','Ansari','Khan','Pathan / Pashto','Mughal',
  'Mirza','Siddiqui','Alvi','Rajput','Taga','Tyagi','Julaaha (Ansari)',
  'Kasai / Qassab','Darzi','Nai / Hajjam','Dhobi / Hawari','Lohar / Saifi',
  'Teli','Fakir','Memon','Bohra (Dawoodi)','Bohra (Sulaimani)',
  'Khoja (Ismaili)','Khoja (Ithna Ashari)','Kutchi Memon',
  'Kathiawadi Memon','Mappila / Moplah','Labbai','Rowther','Marakkayar',
  'Lebbai','Deccan Muslim','Bengali Muslim','Bihari Muslim','Dehlavi',
  'Farooqi','Hashmi','Naqvi','Rizvi','Zaidi','Nomani','Thanvi','Chishti',
  'Kashmiri Muslim','Sindhi Muslim','Other','Prefer not to say'
]) WITH ORDINALITY seeded(value, ordinal)
ON CONFLICT (field, value) DO UPDATE
SET sort_order = EXCLUDED.sort_order,
    active = true,
    updated_at = now();

-- Seed every Indian State and Union Territory into the canonical region cache.
-- Cities remain provider-resolved so coordinates are never fabricated.
INSERT INTO public.regions(country_code, name)
SELECT 'IN', state_name
FROM public.india_state_mother_tongues
WHERE state_code <> 'ALL'
GROUP BY state_name
ON CONFLICT (country_code, name) DO NOTHING;

CREATE OR REPLACE FUNCTION public.get_india_discovery_filter_facets(
  p_viewer_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_result jsonb;
  v_mother_tongues jsonb;
  v_communities jsonb;
BEGIN
  IF auth.uid() IS DISTINCT FROM p_viewer_id THEN
    RAISE EXCEPTION
      'Discovery filters can only be requested for the signed-in user.'
      USING ERRCODE = '42501';
  END IF;

  v_result := public.get_discovery_filter_facets(p_viewer_id);

  SELECT coalesce(jsonb_agg(value ORDER BY sort_order, lower(value)), '[]')
  INTO v_mother_tongues
  FROM (
    SELECT value, min(sort_order) AS sort_order
    FROM (
      SELECT c.value, c.sort_order
      FROM public.discovery_filter_option_catalog c
      WHERE c.field = 'mother_tongue' AND c.active = true
      UNION ALL
      SELECT live.value, 1000
      FROM jsonb_array_elements_text(
        coalesce(v_result->'mother_tongues', '[]'::jsonb)
      ) live(value)
    ) merged
    GROUP BY value
  ) values_to_return;

  SELECT coalesce(jsonb_agg(value ORDER BY sort_order, lower(value)), '[]')
  INTO v_communities
  FROM (
    SELECT value, min(sort_order) AS sort_order
    FROM (
      SELECT c.value, c.sort_order
      FROM public.discovery_filter_option_catalog c
      WHERE c.field = 'community' AND c.active = true
      UNION ALL
      SELECT live.value, 1000
      FROM jsonb_array_elements_text(
        coalesce(v_result->'communities', '[]'::jsonb)
      ) live(value)
    ) merged
    GROUP BY value
  ) values_to_return;

  RETURN jsonb_set(
    jsonb_set(coalesce(v_result, '{}'::jsonb), '{mother_tongues}',
      v_mother_tongues, true),
    '{communities}', v_communities, true
  );
END;
$$;

REVOKE ALL ON FUNCTION public.get_india_discovery_filter_facets(uuid)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_india_discovery_filter_facets(uuid)
  TO authenticated;

-- Exact State/City targeting is Premium and server-authoritative.
CREATE OR REPLACE FUNCTION private.assert_discovery_filter_entitlement(
  p_user_id uuid,
  p_filters jsonb
)
RETURNS void
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_features text[] := ARRAY[]::text[];
  v_trust_filter text := nullif(lower(trim(p_filters->>'trust_filter')), '');
  v_state_name text := nullif(trim(p_filters->>'state_name'), '');
  v_city_id_text text := nullif(trim(p_filters->>'city_id'), '');
  v_city_id integer;
BEGIN
  IF v_trust_filter IS NOT NULL
    AND v_trust_filter NOT IN ('photo', 'phone', 'both', 'guardian') THEN
    RAISE EXCEPTION 'invalid_trust_filter' USING ERRCODE = '22023';
  END IF;
  IF v_state_name IS NOT NULL THEN
    IF char_length(v_state_name) > 100 OR NOT EXISTS (
      SELECT 1 FROM public.regions r
      WHERE r.country_code = 'IN' AND lower(r.name) = lower(v_state_name)
    ) THEN
      RAISE EXCEPTION 'invalid_state_filter' USING ERRCODE = '22023';
    END IF;
  END IF;
  IF v_city_id_text IS NOT NULL THEN
    IF v_city_id_text !~ '^[0-9]+$' THEN
      RAISE EXCEPTION 'invalid_city_filter' USING ERRCODE = '22023';
    END IF;
    v_city_id := v_city_id_text::integer;
    IF NOT EXISTS (
      SELECT 1
      FROM public.cities c
      JOIN public.regions r ON r.id = c.region_id
      WHERE c.id = v_city_id
        AND r.country_code = 'IN'
        AND (v_state_name IS NULL OR lower(r.name) = lower(v_state_name))
    ) THEN
      RAISE EXCEPTION 'invalid_city_filter' USING ERRCODE = '22023';
    END IF;
  END IF;

  IF public.has_active_premium(p_user_id) THEN RETURN; END IF;
  IF coalesce((p_filters->>'verified_only')::boolean, false)
    OR v_trust_filter IS NOT NULL THEN
    v_features := array_append(v_features, 'trust_filter');
  END IF;
  IF nullif(trim(p_filters->>'mother_tongue'), '') IS NOT NULL THEN
    v_features := array_append(v_features, 'mother_tongue');
  END IF;
  IF nullif(trim(p_filters->>'community'), '') IS NOT NULL THEN
    v_features := array_append(v_features, 'community');
  END IF;
  IF nullif(trim(p_filters->>'living_expectation'), '') IS NOT NULL THEN
    v_features := array_append(v_features, 'living_expectation');
  END IF;
  IF v_state_name IS NOT NULL OR v_city_id IS NOT NULL THEN
    v_features := array_append(v_features, 'india_location');
  END IF;
  IF cardinality(v_features) > 0 THEN
    RAISE EXCEPTION 'premium_filter_required'
      USING ERRCODE = 'P0001', DETAIL = json_build_object(
        'feature', 'premium_preferences', 'filters', v_features
      )::text;
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION private.assert_discovery_filter_entitlement(uuid, jsonb)
  FROM PUBLIC, anon, authenticated;

DO $migration$
DECLARE
  v_signature regprocedure :=
    'public.get_discovery_feed(uuid,double precision,uuid,integer,jsonb)'::regprocedure;
  v_definition text;
  v_old text := $old$      AND (nullif(p_filters->>'community', '') IS NULL
        OR lower(coalesce(dp.community::text, '')) = lower(p_filters->>'community'))$old$;
  v_new text := $new$      AND (nullif(p_filters->>'community', '') IS NULL
        OR lower(coalesce(dp.community::text, '')) = lower(p_filters->>'community'))
      AND (nullif(trim(p_filters->>'state_name'), '') IS NULL
        OR EXISTS (
          SELECT 1 FROM public.regions selected_region
          WHERE selected_region.id = candidate_city.region_id
            AND selected_region.country_code = 'IN'
            AND lower(selected_region.name) = lower(trim(p_filters->>'state_name'))
        ))
      AND (nullif(trim(p_filters->>'city_id'), '') IS NULL
        OR candidate_profile.city_id = CASE
          WHEN trim(p_filters->>'city_id') ~ '^[0-9]+$'
            THEN trim(p_filters->>'city_id')::integer
          ELSE -1
        END)$new$;
BEGIN
  SELECT replace(pg_get_functiondef(v_signature), E'\r\n', E'\n')
  INTO v_definition;
  IF position($needle$p_filters->>'state_name'$needle$ IN v_definition) = 0 THEN
    IF position(v_old IN v_definition) = 0 THEN
      RAISE EXCEPTION 'india_location_filter_patch_anchor_not_found';
    END IF;
    EXECUTE replace(v_definition, v_old, v_new);
  END IF;
END;
$migration$;

-- A recent viewer is an explicit Premium relationship: it must authorize the
-- same member projection and signed-photo path used by the detail route.
DO $migration$
DECLARE
  v_signature regprocedure :=
    'public.get_authorized_member_profiles(uuid[])'::regprocedure;
  v_definition text;
  v_old text := '      OR p.guardian_user_id = v_me';
  v_new text := $new$      OR (
        public.has_active_premium(v_me)
        AND EXISTS (
          SELECT 1
          FROM public.profile_views recent_view
          JOIN public.profiles mine
            ON mine.id = recent_view.viewed_profile_id
          WHERE mine.user_id = v_me
            AND recent_view.viewer_profile_id = p.id
            AND recent_view.viewed_at >= now() - interval '7 days'
        )
        AND NOT EXISTS (
          SELECT 1 FROM public.blocks blocked_pair
          WHERE (blocked_pair.blocker_id = v_me
                 AND blocked_pair.blocked_id = p.user_id)
             OR (blocked_pair.blocker_id = p.user_id
                 AND blocked_pair.blocked_id = v_me)
        )
      )
      OR p.guardian_user_id = v_me$new$;
BEGIN
  SELECT replace(pg_get_functiondef(v_signature), E'\r\n', E'\n')
  INTO v_definition;
  IF position('recent_view.viewer_profile_id = p.id' IN v_definition) = 0 THEN
    IF position(v_old IN v_definition) = 0 THEN
      RAISE EXCEPTION 'viewer_profile_projection_patch_anchor_not_found';
    END IF;
    EXECUTE replace(v_definition, v_old, v_new);
  END IF;
END;
$migration$;

DO $migration$
DECLARE
  v_signature regprocedure :=
    'public.get_authorized_photo_paths(uuid,uuid[],integer)'::regprocedure;
  v_definition text;
  v_old text := '      OR owner.guardian_user_id = p_viewer_user_id';
  v_new text := $new$      OR (
        public.has_active_premium(p_viewer_user_id)
        AND EXISTS (
          SELECT 1
          FROM public.profile_views recent_view
          JOIN public.profiles mine
            ON mine.id = recent_view.viewed_profile_id
          WHERE mine.user_id = p_viewer_user_id
            AND recent_view.viewer_profile_id = owner.id
            AND recent_view.viewed_at >= now() - interval '7 days'
        )
        AND NOT EXISTS (
          SELECT 1 FROM public.blocks blocked_pair
          WHERE (blocked_pair.blocker_id = p_viewer_user_id
                 AND blocked_pair.blocked_id = owner.user_id)
             OR (blocked_pair.blocker_id = owner.user_id
                 AND blocked_pair.blocked_id = p_viewer_user_id)
        )
      )
      OR owner.guardian_user_id = p_viewer_user_id$new$;
BEGIN
  SELECT replace(pg_get_functiondef(v_signature), E'\r\n', E'\n')
  INTO v_definition;
  IF position('recent_view.viewer_profile_id = owner.id' IN v_definition) = 0 THEN
    IF position(v_old IN v_definition) = 0 THEN
      RAISE EXCEPTION 'viewer_photo_projection_patch_anchor_not_found';
    END IF;
    EXECUTE replace(v_definition, v_old, v_new);
  END IF;
END;
$migration$;

-- One durable, idempotent reminder per participant. The receiver gets an
-- actionable reminder before expiry; only the sender gets the neutral final
-- expiry notice, avoiding blame or pressure on the receiver.
CREATE TABLE IF NOT EXISTS private.interest_expiry_events (
  interest_id uuid NOT NULL REFERENCES public.interests(id) ON DELETE CASCADE,
  recipient_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  event_type text NOT NULL CHECK (
    event_type IN ('sender_reminder', 'receiver_reminder')
  ),
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (interest_id, recipient_id, event_type)
);

REVOKE ALL ON private.interest_expiry_events
  FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION private.queue_interest_lifecycle_notification()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  BEGIN
    IF TG_OP = 'INSERT' AND NEW.status = 'pending' THEN
      PERFORM public.queue_notification(
        NEW.receiver_id,
        'interest_received',
        'New interest',
        'Someone is interested in your profile.',
        'silarah://interests'
      );
    ELSIF TG_OP = 'UPDATE'
      AND OLD.status IS DISTINCT FROM NEW.status
      AND NEW.status = 'accepted' THEN
      PERFORM public.queue_notification(
        NEW.sender_id,
        'interest_accepted',
        'Interest accepted',
        'You can now start a conversation.',
        'silarah://interests'
      );
    ELSIF TG_OP = 'UPDATE'
      AND OLD.status IS DISTINCT FROM NEW.status
      AND NEW.status = 'expired' THEN
      PERFORM public.queue_notification(
        NEW.sender_id,
        'interest_expired',
        'Your interest expired',
        'No response was received during the 14-day response window.',
        'silarah://interests'
      );
    END IF;
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'Interest % committed without notification enqueue: %',
      NEW.id, SQLERRM;
  END;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION private.process_interest_expiry_lifecycle(
  p_batch_size integer DEFAULT 500
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_limit integer := greatest(1, least(coalesce(p_batch_size, 500), 2000));
  v_interest record;
  v_inserted integer;
  v_reminders integer := 0;
  v_expired integer := 0;
BEGIN
  IF NOT pg_try_advisory_xact_lock(hashtext('interest_expiry_lifecycle')) THEN
    RETURN jsonb_build_object('busy', true, 'reminders', 0, 'expired', 0);
  END IF;

  FOR v_interest IN
    SELECT i.id, i.sender_id, i.receiver_id
    FROM public.interests i
    WHERE i.status = 'pending'
      AND i.expires_at > now()
      AND i.expires_at <= now() + interval '24 hours'
    ORDER BY i.expires_at, i.id
    LIMIT v_limit
  LOOP
    INSERT INTO private.interest_expiry_events(
      interest_id, recipient_id, event_type
    ) VALUES (v_interest.id, v_interest.receiver_id, 'receiver_reminder')
    ON CONFLICT DO NOTHING;
    GET DIAGNOSTICS v_inserted = ROW_COUNT;
    IF v_inserted > 0 THEN
      PERFORM public.queue_notification(
        v_interest.receiver_id,
        'interest_expiring',
        'Interest expires within 24 hours',
        'Accept or decline it before the response window closes.',
        'silarah://interests'
      );
      v_reminders := v_reminders + 1;
    END IF;

    INSERT INTO private.interest_expiry_events(
      interest_id, recipient_id, event_type
    ) VALUES (v_interest.id, v_interest.sender_id, 'sender_reminder')
    ON CONFLICT DO NOTHING;
    GET DIAGNOSTICS v_inserted = ROW_COUNT;
    IF v_inserted > 0 THEN
      PERFORM public.queue_notification(
        v_interest.sender_id,
        'interest_expiring',
        'Your interest expires within 24 hours',
        'It will close automatically if no response is received.',
        'silarah://interests'
      );
      v_reminders := v_reminders + 1;
    END IF;
  END LOOP;

  WITH due AS (
    SELECT i.id
    FROM public.interests i
    WHERE i.status = 'pending' AND i.expires_at <= now()
    ORDER BY i.expires_at, i.id
    LIMIT v_limit
    FOR UPDATE SKIP LOCKED
  )
  UPDATE public.interests i
  SET status = 'expired'
  FROM due
  WHERE i.id = due.id;
  GET DIAGNOSTICS v_expired = ROW_COUNT;

  RETURN jsonb_build_object(
    'busy', false,
    'reminders', v_reminders,
    'expired', v_expired
  );
END;
$$;

REVOKE ALL ON FUNCTION private.process_interest_expiry_lifecycle(integer)
  FROM PUBLIC, anon, authenticated;

DO $migration$
DECLARE
  v_signature regprocedure :=
    'public.notification_push_enabled(uuid,text)'::regprocedure;
  v_definition text;
  v_old text := $$WHEN p_type = 'interest_expiring'$$;
  v_new text := $$WHEN p_type IN ('interest_expiring', 'interest_expired')$$;
BEGIN
  SELECT pg_get_functiondef(v_signature) INTO v_definition;
  IF position($needle$'interest_expired'$needle$ IN v_definition) = 0 THEN
    IF position(v_old IN v_definition) = 0 THEN
      RAISE EXCEPTION 'interest_expiry_preference_patch_anchor_not_found';
    END IF;
    EXECUTE replace(v_definition, v_old, v_new);
  END IF;
END;
$migration$;

DO $migration$
DECLARE
  v_job record;
BEGIN
  FOR v_job IN
    SELECT jobid FROM cron.job
    WHERE jobname IN ('expire_interests_hourly',
                      'process_interest_expiry_hourly')
  LOOP
    PERFORM cron.unschedule(v_job.jobid);
  END LOOP;
END;
$migration$;

SELECT cron.schedule(
  'process_interest_expiry_hourly',
  '5 * * * *',
  $$SELECT private.process_interest_expiry_lifecycle(500);$$
);

SELECT private.process_interest_expiry_lifecycle(500);

COMMENT ON FUNCTION public.get_india_discovery_filter_facets(uuid) IS
  'India-wide discovery facets merged with live values; never collapses when the live population is small.';
COMMENT ON FUNCTION private.process_interest_expiry_lifecycle(integer) IS
  'Hourly idempotent 24-hour reminders and expiry for the 14-day pending-interest response window.';

NOTIFY pgrst, 'reload schema';
