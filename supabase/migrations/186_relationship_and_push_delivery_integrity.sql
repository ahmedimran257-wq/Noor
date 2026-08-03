-- Relationship notification producers and reliable FCM worker wake-ups.
--
-- The database remains the source of truth for relationship state. Push is a
-- best-effort projection of durable in-app notification rows and must never
-- block an interest, profile view, message, or moderation transaction.

-- Profile-view pushes are independently controllable and generic: viewer
-- identity remains a Premium-only read enforced by get_my_profile_viewers().
ALTER TABLE public.notification_prefs
  ADD COLUMN IF NOT EXISTS profile_view boolean NOT NULL DEFAULT true;

CREATE INDEX IF NOT EXISTS idx_notifications_profile_view_throttle
  ON public.notifications(user_id, created_at DESC)
  WHERE type = 'profile_view';

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
    WHEN p_type IN ('interest_accepted', 'photo_access_granted')
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
    ELSE true
  END
  FROM (SELECT p_user_id AS user_id) target
  LEFT JOIN public.notification_prefs np ON np.user_id = target.user_id;
$$;

REVOKE ALL ON FUNCTION public.notification_push_enabled(uuid, text)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.notification_push_enabled(uuid, text)
  TO service_role;

-- Interest creation/acceptance previously changed relationship state without
-- producing an in-app or device notification. Withdrawal remains silent.
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
        '/home?tab=1'
      );
    ELSIF TG_OP = 'UPDATE'
      AND OLD.status IS DISTINCT FROM NEW.status
      AND NEW.status = 'accepted' THEN
      PERFORM public.queue_notification(
        NEW.sender_id,
        'interest_accepted',
        'Interest accepted',
        'You can now start a conversation.',
        '/home?tab=1'
      );
    END IF;
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'Interest % committed without notification enqueue: %',
      NEW.id, SQLERRM;
  END;
  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION private.queue_interest_lifecycle_notification()
  FROM PUBLIC;

DROP TRIGGER IF EXISTS trg_queue_interest_created_notification
  ON public.interests;
CREATE TRIGGER trg_queue_interest_created_notification
  AFTER INSERT ON public.interests
  FOR EACH ROW
  EXECUTE FUNCTION private.queue_interest_lifecycle_notification();

DROP TRIGGER IF EXISTS trg_queue_interest_status_notification
  ON public.interests;
CREATE TRIGGER trg_queue_interest_status_notification
  AFTER UPDATE OF status ON public.interests
  FOR EACH ROW
  EXECUTE FUNCTION private.queue_interest_lifecycle_notification();

-- Only an explicit profile-detail open asks for a notification. Discovery
-- carousel impressions still consume the existing daily view allowance but do
-- not generate pushes. One generic notification per owner per six hours keeps
-- this signal useful without leaking viewer identity or creating push spam.
CREATE OR REPLACE FUNCTION private.maybe_queue_profile_view_notification(
  p_viewer_user_id uuid,
  p_viewed_user_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF p_viewer_user_id IS NULL
    OR p_viewed_user_id IS NULL
    OR p_viewer_user_id = p_viewed_user_id THEN
    RETURN;
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.blocks b
    WHERE (b.blocker_id = p_viewer_user_id AND b.blocked_id = p_viewed_user_id)
       OR (b.blocker_id = p_viewed_user_id AND b.blocked_id = p_viewer_user_id)
  ) THEN
    RETURN;
  END IF;

  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(p_viewed_user_id::text, 186)
  );

  IF EXISTS (
    SELECT 1
    FROM public.notifications n
    WHERE n.user_id = p_viewed_user_id
      AND n.type = 'profile_view'
      AND n.created_at >= now() - interval '6 hours'
  ) THEN
    RETURN;
  END IF;

  PERFORM public.queue_notification(
    p_viewed_user_id,
    'profile_view',
    'New profile activity',
    'Someone viewed your profile.',
    'silarah://profile-views'
  );
END;
$$;

REVOKE ALL ON FUNCTION private.maybe_queue_profile_view_notification(uuid, uuid)
  FROM PUBLIC;

DROP FUNCTION IF EXISTS public.record_profile_view(uuid);
CREATE FUNCTION public.record_profile_view(
  p_viewed_user_id uuid,
  p_notify_owner boolean DEFAULT false
)
RETURNS TABLE (
  allowed boolean,
  views_today integer,
  daily_limit integer,
  remaining integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_me uuid := auth.uid();
  v_viewer_profile_id uuid;
  v_viewed_profile_id uuid;
  v_limit integer;
  v_count integer;
  v_inserted boolean := false;
BEGIN
  IF v_me IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = 'P0001';
  END IF;

  IF p_viewed_user_id IS NULL OR p_viewed_user_id = v_me THEN
    v_limit := coalesce(public.profile_view_daily_limit(v_me), 15);
    SELECT count(*)::integer INTO v_count
    FROM public.profile_view_daily_seen seen
    WHERE seen.viewer_user_id = v_me
      AND seen.viewed_on = current_date;
    RETURN QUERY SELECT true, v_count, v_limit,
      greatest(v_limit - v_count, 0);
    RETURN;
  END IF;

  SELECT p.id INTO v_viewer_profile_id
  FROM public.profiles p
  WHERE p.user_id = v_me
  LIMIT 1;

  SELECT p.id INTO v_viewed_profile_id
  FROM public.profiles p
  WHERE p.user_id = p_viewed_user_id
  LIMIT 1;

  IF v_viewer_profile_id IS NULL OR v_viewed_profile_id IS NULL THEN
    RAISE EXCEPTION 'Profile not found' USING ERRCODE = 'P0001';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.blocks b
    WHERE (b.blocker_id = v_me AND b.blocked_id = p_viewed_user_id)
       OR (b.blocker_id = p_viewed_user_id AND b.blocked_id = v_me)
  ) THEN
    RAISE EXCEPTION 'Profile not found' USING ERRCODE = 'P0001';
  END IF;

  v_limit := coalesce(public.profile_view_daily_limit(v_me), 15);

  SELECT count(*)::integer INTO v_count
  FROM public.profile_view_daily_seen seen
  WHERE seen.viewer_user_id = v_me
    AND seen.viewed_on = current_date;

  IF v_count >= v_limit AND NOT EXISTS (
    SELECT 1
    FROM public.profile_view_daily_seen seen
    WHERE seen.viewer_user_id = v_me
      AND seen.viewed_profile_id = v_viewed_profile_id
      AND seen.viewed_on = current_date
  ) THEN
    RETURN QUERY SELECT false, v_count, v_limit, 0;
    RETURN;
  END IF;

  INSERT INTO public.profile_view_daily_seen(
    viewer_user_id, viewed_profile_id, viewed_on
  )
  VALUES (v_me, v_viewed_profile_id, current_date)
  ON CONFLICT DO NOTHING;

  GET DIAGNOSTICS v_count = ROW_COUNT;
  v_inserted := v_count > 0;

  IF v_inserted THEN
    INSERT INTO public.profile_views(viewer_profile_id, viewed_profile_id)
    VALUES (v_viewer_profile_id, v_viewed_profile_id);
  END IF;

  IF coalesce(p_notify_owner, false) THEN
    BEGIN
      PERFORM private.maybe_queue_profile_view_notification(
        v_me,
        p_viewed_user_id
      );
    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING 'Profile view committed without notification enqueue: %',
        SQLERRM;
    END;
  END IF;

  SELECT count(*)::integer INTO v_count
  FROM public.profile_view_daily_seen seen
  WHERE seen.viewer_user_id = v_me
    AND seen.viewed_on = current_date;

  RETURN QUERY SELECT true, v_count, v_limit,
    greatest(v_limit - v_count, 0);
END;
$$;

REVOKE ALL ON FUNCTION public.record_profile_view(uuid, boolean)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.record_profile_view(uuid, boolean)
  TO authenticated;

-- Repair historical token fan-out and make registration self-healing. The
-- current device is always retained, followed by the four freshest devices.
WITH ranked AS (
  SELECT id,
         row_number() OVER (
           PARTITION BY user_id
           ORDER BY updated_at DESC, id DESC
         ) AS position
  FROM public.user_fcm_tokens
)
DELETE FROM public.user_fcm_tokens token
USING ranked
WHERE token.id = ranked.id
  AND ranked.position > 5;

CREATE OR REPLACE FUNCTION public.register_my_fcm_token(
  p_device_id text,
  p_fcm_token text,
  p_platform text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'authentication_required' USING ERRCODE = '42501';
  END IF;
  IF nullif(trim(p_device_id), '') IS NULL
    OR char_length(p_device_id) > 200
    OR nullif(trim(p_fcm_token), '') IS NULL
    OR char_length(p_fcm_token) > 4096
    OR p_platform NOT IN ('android', 'ios') THEN
    RAISE EXCEPTION 'invalid_device_token' USING ERRCODE = 'P0001';
  END IF;

  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(v_user_id::text, 73)
  );

  DELETE FROM public.user_fcm_tokens
  WHERE fcm_token = p_fcm_token
    AND user_id <> v_user_id;

  INSERT INTO public.user_fcm_tokens(
    user_id, device_id, fcm_token, platform, updated_at
  )
  VALUES (v_user_id, p_device_id, p_fcm_token, p_platform, now())
  ON CONFLICT (user_id, device_id) DO UPDATE SET
    fcm_token = EXCLUDED.fcm_token,
    platform = EXCLUDED.platform,
    updated_at = now();

  WITH ranked AS (
    SELECT id,
           row_number() OVER (
             ORDER BY
               CASE WHEN device_id = p_device_id THEN 0 ELSE 1 END,
               updated_at DESC,
               id DESC
           ) AS position
    FROM public.user_fcm_tokens
    WHERE user_id = v_user_id
  )
  DELETE FROM public.user_fcm_tokens token
  USING ranked
  WHERE token.id = ranked.id
    AND ranked.position > 5;
END;
$$;

REVOKE ALL ON FUNCTION public.register_my_fcm_token(text, text, text)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.register_my_fcm_token(text, text, text)
  TO authenticated;

-- Migration 180 accidentally removed the Vault URL fallback introduced in
-- migration 141. Hosted projects therefore accumulated durable in-app rows but
-- never woke the FCM worker when app.supabase_url was intentionally unset.
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
      AND (
        (
          n.delivery_status = 'processing'
          AND n.processing_at < now() - interval '5 minutes'
        )
        OR (
          n.delivery_status = 'pending'
          AND (
            NOT public.notification_push_enabled(n.user_id, n.type)
            OR (n.next_attempt_at <= now() AND n.attempt_count < 8)
          )
        )
      )
    LIMIT 1
  ) THEN
    RETURN;
  END IF;

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

  IF v_url IS NULL OR nullif(v_secret, '') IS NULL THEN
    PERFORM private.set_operational_alert(
      'edge_cron_configuration',
      'Notification worker configuration is incomplete. Configure the project URL and private cron credential in Vault.',
      1,
      true
    );
    RETURN;
  END IF;
  IF v_url !~ '^https://[a-z0-9-]+[.]supabase[.]co$' THEN
    PERFORM private.set_operational_alert(
      'edge_cron_configuration',
      'Notification worker URL is invalid. No request was sent.',
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

REVOKE ALL ON FUNCTION private.invoke_notification_dispatch()
  FROM PUBLIC;

-- Keep the recovery path and immediate wake trigger present even if a hosted
-- project was created before the cost-aware scheduling migrations.
DROP TRIGGER IF EXISTS trg_wake_notification_dispatch
  ON public.notifications;
CREATE TRIGGER trg_wake_notification_dispatch
  AFTER INSERT ON public.notifications
  FOR EACH STATEMENT
  EXECUTE FUNCTION private.wake_notification_dispatch();

DO $migration$
DECLARE
  v_job record;
BEGIN
  FOR v_job IN
    SELECT jobid FROM cron.job
    WHERE jobname = 'dispatch_notifications_fallback_5m'
  LOOP
    PERFORM cron.unschedule(v_job.jobid);
  END LOOP;

  PERFORM cron.schedule(
    'dispatch_notifications_fallback_5m',
    '*/5 * * * *',
    'SELECT private.invoke_notification_dispatch();'
  );
END;
$migration$;

-- Old rows that were completed before delivery_status existed should not look
-- pending forever. For conflicting moderation changes, only the newest state
-- is eligible for a device push; the full audit trail remains in-app.
-- Migration 173 intentionally left already-delivered legacy routes untouched.
-- PostgreSQL rechecks NOT VALID constraints when any column in those rows is
-- updated, so canonicalize the small legacy route set before repairing their
-- delivery metadata.
UPDATE public.notifications
SET deep_link = CASE
  WHEN deep_link = '/help-support' THEN 'silarah://help-support'
  WHEN deep_link = '/home?tab=0' THEN 'silarah://discover'
  WHEN deep_link = '/home?tab=1' THEN 'silarah://interests'
  WHEN deep_link = '/home?tab=2' THEN 'silarah://chat'
  WHEN deep_link = '/home?tab=3' THEN 'silarah://profile'
  WHEN deep_link = '/profile' THEN 'silarah://profile'
  WHEN deep_link = '/verify' THEN 'silarah://verify-identity'
  WHEN deep_link = '/badge-verification' THEN 'silarah://verify'
  WHEN deep_link = '/photo-requests' THEN 'silarah://photo-requests'
  WHEN deep_link = '/notifications' THEN 'silarah://notifications'
  WHEN deep_link = '/subscription' THEN 'silarah://subscription'
  WHEN deep_link = '/edit-profile' THEN 'silarah://complete-profile'
  WHEN deep_link = '/edit-profile?section=photos' THEN 'silarah://photos'
  WHEN deep_link ~ '^/chat/[A-Za-z0-9_-]+$'
    THEN 'silarah://chat/' || pg_catalog.substr(deep_link, 7)
  WHEN deep_link ~ '^/profile/[A-Za-z0-9_-]+$'
    THEN 'silarah://profile/' || pg_catalog.substr(deep_link, 10)
  ELSE deep_link
END
WHERE deep_link IN (
    '/help-support',
    '/home?tab=0',
    '/home?tab=1',
    '/home?tab=2',
    '/home?tab=3',
    '/profile',
    '/verify',
    '/badge-verification',
    '/photo-requests',
    '/notifications',
    '/subscription',
    '/edit-profile',
    '/edit-profile?section=photos'
  )
  OR deep_link ~ '^/chat/[A-Za-z0-9_-]+$'
  OR deep_link ~ '^/profile/[A-Za-z0-9_-]+$';

UPDATE public.notifications
SET delivery_status = 'sent'
WHERE sent_at IS NOT NULL
  AND delivery_status = 'pending';

WITH ranked AS (
  SELECT id,
         row_number() OVER (
           PARTITION BY user_id
           ORDER BY created_at DESC, id DESC
         ) AS position
  FROM public.notifications
  WHERE sent_at IS NULL
    AND type IN (
      'account_suspended', 'account_banned',
      'account_restored', 'account_limited'
    )
)
UPDATE public.notifications notification
SET sent_at = now(),
    delivery_status = 'in_app_only',
    last_error_code = 'superseded_by_newer_account_state'
FROM ranked
WHERE notification.id = ranked.id
  AND ranked.position > 1;

-- Wake the repaired worker for any already-due notification. pg_net sends the
-- request asynchronously after the migration transaction commits.
SELECT private.invoke_notification_dispatch();
