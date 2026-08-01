-- Cost-aware invalidation and fixed-work cleanup.
--
-- 1. Partition catalog revisions by candidate gender and, when discovery is
--    strictly country-scoped, by candidate gender + country.
-- 2. Expose the relationship-only revision to Interests and Chat.
-- 3. Stop refreshing the legacy discovery_pool materialized view, now that all
--    remaining consumers use live_discovery_pool.
-- 4. Avoid Edge Function invocations when notification/storage queues are idle.

-- ---------------------------------------------------------------------------
-- Segmented discovery catalog revisions.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS private.discovery_catalog_segment_revisions (
  segment_key text PRIMARY KEY,
  revision bigint NOT NULL DEFAULT 1 CHECK (revision > 0),
  changed_at timestamptz NOT NULL DEFAULT now()
);

REVOKE ALL ON private.discovery_catalog_segment_revisions
  FROM PUBLIC, anon, authenticated;

INSERT INTO private.discovery_catalog_segment_revisions(
  segment_key,
  revision,
  changed_at
)
SELECT seed.segment_key, catalog.revision, catalog.changed_at
FROM private.discovery_catalog_revision catalog
CROSS JOIN (VALUES ('global'), ('gender:male'), ('gender:female')) seed(segment_key)
WHERE catalog.singleton = true
ON CONFLICT (segment_key) DO NOTHING;

CREATE OR REPLACE FUNCTION private.touch_discovery_catalog_segment(
  p_gender text,
  p_country_code text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_gender text := nullif(lower(trim(p_gender)), '');
  v_country text := nullif(upper(trim(p_country_code)), '');
  v_key text;
BEGIN
  INSERT INTO private.discovery_catalog_segment_revisions(segment_key)
  VALUES ('global')
  ON CONFLICT (segment_key) DO UPDATE
  SET revision = private.discovery_catalog_segment_revisions.revision + 1,
      changed_at = now();

  IF v_gender IS NULL THEN
    RETURN;
  END IF;

  v_key := 'gender:' || v_gender;
  INSERT INTO private.discovery_catalog_segment_revisions(segment_key)
  VALUES (v_key)
  ON CONFLICT (segment_key) DO UPDATE
  SET revision = private.discovery_catalog_segment_revisions.revision + 1,
      changed_at = now();

  IF v_country IS NOT NULL THEN
    v_key := 'country:' || v_gender || ':' || v_country;
    INSERT INTO private.discovery_catalog_segment_revisions(segment_key)
    VALUES (v_key)
    ON CONFLICT (segment_key) DO UPDATE
    SET revision = private.discovery_catalog_segment_revisions.revision + 1,
        changed_at = now();
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION private.touch_discovery_catalog_segment(text, text)
  FROM PUBLIC;

CREATE OR REPLACE FUNCTION private.bump_discovery_catalog_revision()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_old_gender text;
  v_old_country text;
  v_new_gender text;
  v_new_country text;
  v_profile_id uuid;
  v_user_id uuid;
BEGIN
  -- Preserve the original monotonic global revision for backwards
  -- compatibility and operational visibility. Segment-aware clients do not
  -- include it unless their target gender cannot be resolved.
  UPDATE private.discovery_catalog_revision
  SET revision = revision + 1,
      changed_at = now()
  WHERE singleton = true;

  IF TG_TABLE_NAME = 'profiles' THEN
    IF TG_OP <> 'INSERT' THEN
      v_old_gender := OLD.gender::text;
      v_old_country := OLD.country_code::text;
    END IF;
    IF TG_OP <> 'DELETE' THEN
      v_new_gender := NEW.gender::text;
      v_new_country := NEW.country_code::text;
    END IF;
  ELSIF TG_TABLE_NAME = 'photos' THEN
    v_profile_id := CASE WHEN TG_OP = 'DELETE' THEN OLD.profile_id ELSE NEW.profile_id END;
    SELECT p.gender::text, p.country_code::text
    INTO v_new_gender, v_new_country
    FROM public.profiles p
    WHERE p.id = v_profile_id;
  ELSIF TG_TABLE_NAME = 'profile_preferences' THEN
    v_profile_id := CASE WHEN TG_OP = 'DELETE' THEN OLD.profile_id ELSE NEW.profile_id END;
    SELECT p.gender::text, p.country_code::text
    INTO v_new_gender, v_new_country
    FROM public.profiles p
    WHERE p.id = v_profile_id;
  ELSIF TG_TABLE_NAME = 'users' THEN
    IF TG_OP <> 'INSERT' THEN
      v_old_gender := OLD.gender::text;
      v_user_id := OLD.id;
      SELECT p.country_code::text INTO v_old_country
      FROM public.profiles p WHERE p.user_id = v_user_id;
    END IF;
    IF TG_OP <> 'DELETE' THEN
      v_new_gender := NEW.gender::text;
      v_user_id := NEW.id;
      SELECT p.country_code::text INTO v_new_country
      FROM public.profiles p WHERE p.user_id = v_user_id;
    END IF;
  END IF;

  IF TG_TABLE_NAME IN ('photos', 'profile_preferences') THEN
    -- Photo/preference rows resolve one owning profile segment.
    PERFORM private.touch_discovery_catalog_segment(v_new_gender, v_new_country);
  ELSE
    IF TG_OP <> 'INSERT' THEN
      PERFORM private.touch_discovery_catalog_segment(v_old_gender, v_old_country);
    END IF;
    IF TG_OP <> 'DELETE' AND (
      TG_OP = 'INSERT'
      OR v_new_gender IS DISTINCT FROM v_old_gender
      OR v_new_country IS DISTINCT FROM v_old_country
    ) THEN
      PERFORM private.touch_discovery_catalog_segment(v_new_gender, v_new_country);
    END IF;
  END IF;

  IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
  RETURN NEW;
END;
$$;

-- Replace the zero-argument function with a backwards-compatible defaulted
-- filter argument. PostgREST can still call it without parameters.
DROP FUNCTION IF EXISTS public.get_my_discovery_revision();
DROP FUNCTION IF EXISTS public.get_my_discovery_revision(jsonb);

CREATE FUNCTION public.get_my_discovery_revision(
  p_filters jsonb DEFAULT '{}'::jsonb
)
RETURNS TABLE (
  revision_token text,
  catalog_revision bigint,
  member_revision bigint,
  changed_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_me uuid := auth.uid();
  v_viewer_gender text;
  v_viewer_country text;
  v_target_gender text;
  v_countries text[] := ARRAY[]::text[];
  v_catalog_revision bigint := 0;
  v_catalog_token text := '';
  v_catalog_changed_at timestamptz;
  v_member_revision bigint := 0;
  v_member_changed_at timestamptz;
BEGIN
  IF v_me IS NULL THEN
    RAISE EXCEPTION 'authentication_required' USING ERRCODE = '42501';
  END IF;

  SELECT lower(p.gender::text), upper(p.country_code::text)
  INTO v_viewer_gender, v_viewer_country
  FROM public.profiles p
  WHERE p.user_id = v_me;

  v_target_gender := nullif(lower(trim(p_filters->>'gender_pref')), '');
  IF v_target_gender IS NULL THEN
    v_target_gender := CASE v_viewer_gender
      WHEN 'male' THEN 'female'
      WHEN 'female' THEN 'male'
      ELSE NULL
    END;
  END IF;

  IF jsonb_typeof(p_filters->'country_codes') = 'array' THEN
    SELECT coalesce(array_agg(DISTINCT upper(trim(value))), ARRAY[]::text[])
    INTO v_countries
    FROM jsonb_array_elements_text(p_filters->'country_codes') value
    WHERE nullif(trim(value), '') IS NOT NULL;
  ELSIF coalesce((p_filters->>'same_country')::boolean, false)
    OR lower(coalesce(p_filters->>'location_scope', '')) IN (
      'same_country', 'same_city', 'same_region'
    ) THEN
    IF v_viewer_country IS NOT NULL THEN
      v_countries := ARRAY[v_viewer_country];
    END IF;
  END IF;

  IF v_target_gender IS NULL THEN
    SELECT r.revision, 'global=' || r.revision::text, r.changed_at
    INTO v_catalog_revision, v_catalog_token, v_catalog_changed_at
    FROM private.discovery_catalog_segment_revisions r
    WHERE r.segment_key = 'global';
  ELSIF coalesce(array_length(v_countries, 1), 0) > 0 THEN
    SELECT
      coalesce(max(r.revision), 0),
      string_agg(
        country.code || '=' || coalesce(r.revision, 0)::text,
        ',' ORDER BY country.code
      ),
      max(r.changed_at)
    INTO v_catalog_revision, v_catalog_token, v_catalog_changed_at
    FROM unnest(v_countries) country(code)
    LEFT JOIN private.discovery_catalog_segment_revisions r
      ON r.segment_key = 'country:' || v_target_gender || ':' || country.code;
    v_catalog_token := 'countries:' || v_target_gender || ':' || coalesce(v_catalog_token, '');
  ELSE
    SELECT r.revision,
      'gender:' || v_target_gender || '=' || r.revision::text,
      r.changed_at
    INTO v_catalog_revision, v_catalog_token, v_catalog_changed_at
    FROM private.discovery_catalog_segment_revisions r
    WHERE r.segment_key = 'gender:' || v_target_gender;
  END IF;

  SELECT coalesce(r.revision, 0), r.changed_at
  INTO v_member_revision, v_member_changed_at
  FROM private.discovery_member_revisions r
  WHERE r.user_id = v_me;

  RETURN QUERY SELECT
    coalesce(v_catalog_token, 'catalog=0') || ':member=' || v_member_revision::text,
    coalesce(v_catalog_revision, 0),
    v_member_revision,
    greatest(
      coalesce(v_catalog_changed_at, '-infinity'::timestamptz),
      coalesce(v_member_changed_at, '-infinity'::timestamptz)
    );
END;
$$;

REVOKE ALL ON FUNCTION public.get_my_discovery_revision(jsonb)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_discovery_revision(jsonb)
  TO authenticated;

COMMENT ON FUNCTION public.get_my_discovery_revision(jsonb) IS
  'Low-cost filter-aware catalog segment plus member revision used to invalidate Discovery without global fan-out.';

CREATE OR REPLACE FUNCTION public.get_my_relationship_revision()
RETURNS TABLE(revision_token text, changed_at timestamptz)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT
    coalesce(r.revision, 0)::text,
    r.changed_at
  FROM (SELECT auth.uid() AS user_id) me
  LEFT JOIN private.discovery_member_revisions r ON r.user_id = me.user_id
  WHERE me.user_id IS NOT NULL;
$$;

REVOKE ALL ON FUNCTION public.get_my_relationship_revision()
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_relationship_revision()
  TO authenticated;

-- ---------------------------------------------------------------------------
-- The interactive and admin consumers now use live_discovery_pool. The legacy
-- materialized view can remain for rollback compatibility without a daily
-- full refresh.
-- ---------------------------------------------------------------------------
DO $$
DECLARE v_job record;
BEGIN
  FOR v_job IN
    SELECT jobid FROM cron.job WHERE jobname = 'refresh_discovery_pool_daily'
  LOOP
    PERFORM cron.unschedule(v_job.jobid);
  END LOOP;
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_match_metrics()
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT CASE WHEN public.is_active_admin() THEN jsonb_build_object(
    'activeMatches', (SELECT count(*) FROM public.matches),
    'interestsThirtyDays', (SELECT count(*) FROM public.interests WHERE created_at >= now() - interval '30 days'),
    'acceptedThirtyDays', (SELECT count(*) FROM public.interests WHERE status = 'accepted' AND created_at >= now() - interval '30 days'),
    'messagesThirtyDays', (SELECT count(*) FROM public.messages WHERE created_at >= now() - interval '30 days'),
    'discoveryProfiles', (SELECT count(*) FROM public.live_discovery_pool)
  ) ELSE NULL END;
$$;

REVOKE ALL ON FUNCTION public.admin_match_metrics() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_match_metrics() TO authenticated;

-- ---------------------------------------------------------------------------
-- Empty-queue guards prevent two fixed Edge invocations every five minutes.
-- Immediate notification inserts still wake the dispatcher through the
-- existing statement trigger; the cron remains only as recovery.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION private.invoke_notification_dispatch()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_secret text;
  v_url text;
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM public.notifications n
    WHERE n.sent_at IS NULL
      AND n.scheduled_at <= now()
    LIMIT 1
  ) THEN
    RETURN;
  END IF;

  v_url := nullif(current_setting('app.supabase_url', true), '');
  SELECT decrypted_secret INTO v_secret
  FROM vault.decrypted_secrets
  WHERE name IN ('silarah_edge_cron_secret', 'mithaq_edge_cron_secret')
  ORDER BY (name = 'silarah_edge_cron_secret') DESC
  LIMIT 1;

  IF v_url IS NULL OR nullif(v_secret, '') IS NULL THEN
    PERFORM private.set_operational_alert(
      'edge_cron_configuration',
      'Notification worker configuration is incomplete. Set app.supabase_url and the private cron credential.',
      1,
      true
    );
    RETURN;
  END IF;

  PERFORM private.set_operational_alert(
    'edge_cron_configuration',
    'Notification worker configuration is healthy.',
    0,
    false
  );

  PERFORM net.http_post(
    url := v_url || '/functions/v1/dispatch-notifications',
    body := '{}'::jsonb,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-cron-secret', v_secret
    ),
    timeout_milliseconds := 10000
  );
END;
$$;

REVOKE ALL ON FUNCTION private.invoke_notification_dispatch() FROM PUBLIC;

CREATE OR REPLACE FUNCTION private.invoke_storage_lifecycle_worker()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_secret text;
  v_url text;
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM private.storage_deletion_jobs j
    WHERE j.status IN ('pending', 'failed')
      AND j.next_attempt_at <= now()
    LIMIT 1
  ) AND NOT EXISTS (
    SELECT 1
    FROM private.upload_reservations r
    WHERE r.status = 'reserved'
      AND r.expires_at <= now()
    LIMIT 1
  ) THEN
    RETURN;
  END IF;

  v_url := nullif(current_setting('app.supabase_url', true), '');
  SELECT decrypted_secret INTO v_secret
  FROM vault.decrypted_secrets
  WHERE name IN ('silarah_edge_cron_secret', 'mithaq_edge_cron_secret')
  ORDER BY (name = 'silarah_edge_cron_secret') DESC
  LIMIT 1;

  IF v_url ~ '^https://[a-z0-9-]+[.]supabase[.]co$'
    AND nullif(v_secret, '') IS NOT NULL THEN
    PERFORM net.http_post(
      url := v_url || '/functions/v1/storage-lifecycle-worker',
      body := '{}'::jsonb,
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-cron-secret', v_secret
      ),
      timeout_milliseconds := 10000
    );
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION private.invoke_storage_lifecycle_worker() FROM PUBLIC;
