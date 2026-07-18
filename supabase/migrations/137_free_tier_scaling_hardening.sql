-- Free-tier scaling hardening.
--
-- This migration removes fixed background waste, bounds interactive discovery
-- work, fixes the live performance-advisor findings, and wakes push delivery
-- only when there is work (with a five-minute recovery sweep).

-- ---------------------------------------------------------------------------
-- 1. Stop the unused recommendation rebuild.
-- ---------------------------------------------------------------------------
-- Interactive discovery has used live_discovery_pool since migration 132, so
-- the old 300-viewer x 700-candidate refresh no longer serves the app.
DO $migration$
DECLARE
  v_job_id bigint;
BEGIN
  SELECT jobid INTO v_job_id
  FROM cron.job
  WHERE jobname = 'refresh_recommendations_recent_viewers_10m';

  IF v_job_id IS NOT NULL THEN
    PERFORM cron.unschedule(v_job_id);
  END IF;
END;
$migration$;

-- Bound preference scoring before the two directional scoring calls run.
-- The app can return at most 20 rows and free discovery exposes 15 profiles per
-- day, so scoring 300 already-filtered candidates preserves ranking diversity
-- without permitting thousands of nested profile/preference lookups per page.
DO $migration$
DECLARE
  v_signature regprocedure :=
    'public.get_discovery_feed(uuid,double precision,uuid,integer,jsonb)'::regprocedure;
  v_definition text;
  v_updated text;
BEGIN
  SELECT pg_get_functiondef(v_signature) INTO v_definition;
  v_updated := replace(v_definition, 'LIMIT 1500', 'LIMIT 300');

  IF v_updated = v_definition THEN
    RAISE EXCEPTION
      'get_discovery_feed shortlist contract changed; scaling bound was not installed';
  END IF;

  EXECUTE v_updated;
END;
$migration$;

COMMENT ON FUNCTION public.get_discovery_feed(
  uuid, double precision, uuid, integer, jsonb
) IS
  'Live, cursor-paginated discovery with a bounded 300-candidate scoring shortlist and authoritative geographic filters.';

-- Cover the anti-joins and live photo lookup used by every discovery request.
CREATE INDEX IF NOT EXISTS idx_blocks_blocked_blocker
  ON public.blocks(blocked_id, blocker_id);

CREATE INDEX IF NOT EXISTS idx_interests_active_pair
  ON public.interests(sender_id, receiver_id)
  WHERE status IN ('pending', 'accepted');

CREATE INDEX IF NOT EXISTS idx_photos_live_profile_slot
  ON public.photos(profile_id, order_index, created_at DESC)
  WHERE status = 'active'
    AND admin_approved = true
    AND nsfw_cleared = true;

-- ---------------------------------------------------------------------------
-- 2. Collapse overlapping RLS policies without changing authorization.
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS admin_memberships_manage_super_admin
  ON public.admin_memberships;
DROP POLICY IF EXISTS admin_memberships_select_self_or_super_admin
  ON public.admin_memberships;

CREATE POLICY admin_memberships_select_self_or_super_admin
  ON public.admin_memberships
  FOR SELECT TO authenticated
  USING (
    user_id = (SELECT auth.uid())
    OR public.is_active_admin(ARRAY['super_admin'])
  );

CREATE POLICY admin_memberships_super_admin_insert
  ON public.admin_memberships
  FOR INSERT TO authenticated
  WITH CHECK (public.is_active_admin(ARRAY['super_admin']));

CREATE POLICY admin_memberships_super_admin_update
  ON public.admin_memberships
  FOR UPDATE TO authenticated
  USING (public.is_active_admin(ARRAY['super_admin']))
  WITH CHECK (public.is_active_admin(ARRAY['super_admin']));

CREATE POLICY admin_memberships_super_admin_delete
  ON public.admin_memberships
  FOR DELETE TO authenticated
  USING (public.is_active_admin(ARRAY['super_admin']));

DROP POLICY IF EXISTS messages_guardian_insert ON public.messages;
DROP POLICY IF EXISTS messages_insert ON public.messages;

CREATE POLICY messages_participant_or_guardian_insert
  ON public.messages
  FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.matches m
      WHERE m.id = messages.match_id
        AND m.status = 'active'
    )
    AND (
      sender_id = (SELECT auth.uid())
      OR (
        EXISTS (
          SELECT 1
          FROM public.guardian_chat_mirrors gcm
          WHERE gcm.match_id = messages.match_id
            AND gcm.guardian_id = (SELECT auth.uid())
            AND gcm.mode = 'active'
        )
        AND sender_id = (
          SELECT gcm.ward_id
          FROM public.guardian_chat_mirrors gcm
          WHERE gcm.match_id = messages.match_id
            AND gcm.guardian_id = (SELECT auth.uid())
            AND gcm.mode = 'active'
          LIMIT 1
        )
      )
    )
  );

DROP POLICY IF EXISTS par_owner_select ON public.photo_access_requests;
DROP POLICY IF EXISTS par_requester_select ON public.photo_access_requests;

CREATE POLICY par_participant_select
  ON public.photo_access_requests
  FOR SELECT TO authenticated
  USING (
    owner_id = (SELECT auth.uid())
    OR requester_id = (SELECT auth.uid())
  );

DROP POLICY IF EXISTS consents_insert ON public.user_consents;
DROP POLICY IF EXISTS user_consents_insert ON public.user_consents;
DROP POLICY IF EXISTS consents_select ON public.user_consents;
DROP POLICY IF EXISTS user_consents_select ON public.user_consents;

CREATE POLICY user_consents_insert
  ON public.user_consents
  FOR INSERT TO authenticated
  WITH CHECK (user_id = (SELECT auth.uid()));

CREATE POLICY user_consents_select
  ON public.user_consents
  FOR SELECT TO authenticated
  USING (user_id = (SELECT auth.uid()));

-- Convert per-row auth helper calls in every remaining public policy into one
-- statement-level init plan. Policy names, commands, roles and predicates stay
-- unchanged; only the evaluation strategy changes.
DO $migration$
DECLARE
  v_policy record;
  v_qual text;
  v_check text;
  v_sql text;
BEGIN
  FOR v_policy IN
    SELECT schemaname, tablename, policyname, qual, with_check
    FROM pg_policies
    WHERE schemaname = 'public'
      AND (
        coalesce(qual, '') ~ 'auth\.(uid|role|jwt)\(\)'
        OR coalesce(with_check, '') ~ 'auth\.(uid|role|jwt)\(\)'
      )
  LOOP
    v_qual := v_policy.qual;
    v_check := v_policy.with_check;

    IF v_qual IS NOT NULL THEN
      v_qual := replace(v_qual, 'auth.uid()', '(SELECT auth.uid())');
      v_qual := replace(v_qual, 'auth.role()', '(SELECT auth.role())');
      v_qual := replace(v_qual, 'auth.jwt()', '(SELECT auth.jwt())');
    END IF;
    IF v_check IS NOT NULL THEN
      v_check := replace(v_check, 'auth.uid()', '(SELECT auth.uid())');
      v_check := replace(v_check, 'auth.role()', '(SELECT auth.role())');
      v_check := replace(v_check, 'auth.jwt()', '(SELECT auth.jwt())');
    END IF;

    v_sql := format(
      'ALTER POLICY %I ON %I.%I',
      v_policy.policyname,
      v_policy.schemaname,
      v_policy.tablename
    );
    IF v_qual IS NOT NULL THEN
      v_sql := v_sql || format(' USING (%s)', v_qual);
    END IF;
    IF v_check IS NOT NULL THEN
      v_sql := v_sql || format(' WITH CHECK (%s)', v_check);
    END IF;
    EXECUTE v_sql;
  END LOOP;
END;
$migration$;

-- Keep one copy of each identical chat index.
DROP INDEX IF EXISTS public.idx_messages_match_created_desc;
DROP INDEX IF EXISTS public.idx_messages_match_receiver_unread;

-- ---------------------------------------------------------------------------
-- 3. Event-driven push dispatch with a five-minute recovery sweep.
-- ---------------------------------------------------------------------------
CREATE SCHEMA IF NOT EXISTS private;
REVOKE ALL ON SCHEMA private FROM PUBLIC, anon, authenticated;

CREATE TABLE IF NOT EXISTS private.notification_dispatch_state (
  singleton boolean PRIMARY KEY DEFAULT true CHECK (singleton),
  last_wake_at timestamptz
);

INSERT INTO private.notification_dispatch_state(singleton, last_wake_at)
VALUES (true, NULL)
ON CONFLICT (singleton) DO NOTHING;

REVOKE ALL ON private.notification_dispatch_state
  FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION private.wake_notification_dispatch()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = private, public, net, vault
AS $$
DECLARE
  v_secret text;
  v_url text;
BEGIN
  UPDATE private.notification_dispatch_state
  SET last_wake_at = clock_timestamp()
  WHERE singleton = true
    AND (
      last_wake_at IS NULL
      OR last_wake_at < clock_timestamp() - interval '20 seconds'
    );

  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  v_url := current_setting('app.supabase_url', true);
  SELECT decrypted_secret INTO v_secret
  FROM vault.decrypted_secrets
  WHERE name IN ('silarah_edge_cron_secret', 'mithaq_edge_cron_secret')
  ORDER BY (name = 'silarah_edge_cron_secret') DESC
  LIMIT 1;

  IF nullif(v_url, '') IS NOT NULL AND nullif(v_secret, '') IS NOT NULL THEN
    PERFORM net.http_post(
      url := v_url || '/functions/v1/dispatch-notifications',
      body := '{}'::jsonb,
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-cron-secret', v_secret
      )
    );
  END IF;

  RETURN NULL;
END;
$$;

REVOKE ALL ON FUNCTION private.wake_notification_dispatch() FROM PUBLIC;

DROP TRIGGER IF EXISTS trg_wake_notification_dispatch
  ON public.notifications;
CREATE TRIGGER trg_wake_notification_dispatch
AFTER INSERT ON public.notifications
FOR EACH STATEMENT
EXECUTE FUNCTION private.wake_notification_dispatch();

DO $migration$
DECLARE
  v_job_id bigint;
BEGIN
  SELECT jobid INTO v_job_id
  FROM cron.job
  WHERE jobname = 'dispatch_notifications_minutely';
  IF v_job_id IS NOT NULL THEN
    PERFORM cron.unschedule(v_job_id);
  END IF;

  SELECT jobid INTO v_job_id
  FROM cron.job
  WHERE jobname = 'dispatch_notifications_fallback_5m';
  IF v_job_id IS NOT NULL THEN
    PERFORM cron.unschedule(v_job_id);
  END IF;

  PERFORM cron.schedule(
    'dispatch_notifications_fallback_5m',
    '*/5 * * * *',
    $job$
      SELECT net.http_post(
        url := current_setting('app.supabase_url', true) || '/functions/v1/dispatch-notifications',
        body := '{}'::jsonb,
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'x-cron-secret', (
            SELECT decrypted_secret
            FROM vault.decrypted_secrets
            WHERE name IN ('silarah_edge_cron_secret', 'mithaq_edge_cron_secret')
            ORDER BY (name = 'silarah_edge_cron_secret') DESC
            LIMIT 1
          )
        )
      );
    $job$
  );
END;
$migration$;

-- ---------------------------------------------------------------------------
-- 4. Keep profile-photo objects small on the Free plan.
-- ---------------------------------------------------------------------------
UPDATE storage.buckets
SET file_size_limit = 2097152,
    allowed_mime_types = ARRAY['image/webp']::text[]
WHERE id = 'profile-photos';
