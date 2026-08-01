-- Audit 2 constrained notifications.deep_link to registered Silarah links,
-- while several trusted notification producers still pass legacy app paths.
-- Canonicalize those internal paths at the single queue boundary so admin
-- actions remain atomic without weakening the storage allowlist.

CREATE OR REPLACE FUNCTION public.queue_notification(
  p_user_id uuid,
  p_type text,
  p_title text,
  p_body text,
  p_deep_link text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_tz text;
  v_start time;
  v_end time;
  v_local timestamp;
  v_local_time time;
  v_local_date date;
  v_deliver_local timestamp;
  v_deliver_at timestamptz;
  v_quiet boolean;
  v_deep_link text := nullif(pg_catalog.btrim(p_deep_link), '');
BEGIN
  IF v_deep_link IS NOT NULL AND v_deep_link NOT LIKE 'silarah://%' THEN
    v_deep_link := CASE
      WHEN v_deep_link = '/help-support' THEN 'silarah://help-support'
      WHEN v_deep_link = '/home?tab=0' THEN 'silarah://discover'
      WHEN v_deep_link = '/home?tab=1' THEN 'silarah://interests'
      WHEN v_deep_link = '/home?tab=2' THEN 'silarah://chat'
      WHEN v_deep_link = '/home?tab=3' THEN 'silarah://profile'
      WHEN v_deep_link = '/profile' THEN 'silarah://profile'
      WHEN v_deep_link = '/verify' THEN 'silarah://verify-identity'
      WHEN v_deep_link = '/badge-verification' THEN 'silarah://verify'
      WHEN v_deep_link = '/photo-requests' THEN 'silarah://photo-requests'
      WHEN v_deep_link = '/notifications' THEN 'silarah://notifications'
      WHEN v_deep_link = '/subscription' THEN 'silarah://subscription'
      WHEN v_deep_link = '/edit-profile' THEN 'silarah://complete-profile'
      WHEN v_deep_link = '/edit-profile?section=photos' THEN 'silarah://photos'
      WHEN v_deep_link ~ '^/chat/[A-Za-z0-9_-]+$'
        THEN 'silarah://chat/' || pg_catalog.substr(v_deep_link, 7)
      WHEN v_deep_link ~ '^/profile/[A-Za-z0-9_-]+$'
        THEN 'silarah://profile/' || pg_catalog.substr(v_deep_link, 10)
      ELSE NULL
    END;

    IF v_deep_link IS NULL THEN
      RAISE EXCEPTION 'Unsupported notification deep link'
        USING ERRCODE = '22023';
    END IF;
  END IF;

  SELECT
    CASE WHEN EXISTS (
      SELECT 1
      FROM pg_catalog.pg_timezone_names
      WHERE name = u.timezone
    ) THEN u.timezone ELSE 'UTC' END,
    coalesce(np.quiet_start, time '23:00'),
    coalesce(np.quiet_end, time '08:00')
  INTO v_tz, v_start, v_end
  FROM public.users u
  LEFT JOIN public.notification_prefs np ON np.user_id = u.id
  WHERE u.id = p_user_id;

  IF v_tz IS NULL THEN
    v_tz := 'UTC';
  END IF;

  v_local := pg_catalog.now() AT TIME ZONE v_tz;
  v_local_time := v_local::time;
  v_local_date := v_local::date;
  v_quiet := CASE
    WHEN v_start = v_end THEN false
    WHEN v_start < v_end
      THEN v_local_time >= v_start AND v_local_time < v_end
    ELSE v_local_time >= v_start OR v_local_time < v_end
  END;

  IF NOT v_quiet THEN
    v_deliver_at := pg_catalog.now();
  ELSE
    v_deliver_local := CASE
      WHEN v_start < v_end THEN v_local_date + v_end
      WHEN v_local_time >= v_start THEN (v_local_date + 1) + v_end
      ELSE v_local_date + v_end
    END;
    v_deliver_at := v_deliver_local AT TIME ZONE v_tz;
  END IF;

  INSERT INTO public.notifications(
    user_id,
    type,
    title,
    body,
    deep_link,
    scheduled_at,
    next_attempt_at
  )
  VALUES (
    p_user_id,
    p_type,
    pg_catalog.left(p_title, 160),
    pg_catalog.left(p_body, 1000),
    v_deep_link,
    v_deliver_at,
    v_deliver_at
  );
END;
$$;

-- Normalize pending legacy rows so in-app and push delivery share one route
-- representation. Historical delivered rows remain untouched.
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
WHERE sent_at IS NULL
  AND (
    deep_link IN (
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
    OR deep_link ~ '^/profile/[A-Za-z0-9_-]+$'
  );

REVOKE ALL ON FUNCTION public.queue_notification(
  uuid,
  text,
  text,
  text,
  text
) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.queue_notification(
  uuid,
  text,
  text,
  text,
  text
) TO service_role;
