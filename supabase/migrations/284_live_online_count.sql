-- Silarah — "Online now" is live and means the app is open
--
-- The dashboard number came from the 15-minute snapshot, so a member who
-- opened the app at 12:09 still showed as 0 until 12:15, while the online
-- list below it (read live) disagreed. It also counted members whose app
-- had already gone to the background, for up to 12 minutes.
--
-- One definition is now shared by the live number, the online list, the
-- snapshot and the 24-hour peak: the app is in the foreground and has sent
-- its heartbeat (every 10 minutes while open) in the last 12 minutes. The
-- live count is a range read on idx_user_presence_last_seen and runs only
-- when staff load the dashboard.

CREATE OR REPLACE FUNCTION private.count_online_members()
RETURNS integer
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT count(*)::integer
  FROM public.user_presence
  WHERE last_seen_at >= now() - interval '12 minutes'
    AND app_state = 'foreground';
$$;
REVOKE ALL ON FUNCTION private.count_online_members()
  FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.admin_online_users(p_limit integer DEFAULT 25)
RETURNS TABLE(
  user_id uuid, profile_id uuid, name text, email text, country_code text,
  gender text, last_seen_at timestamp with time zone, app_state text,
  platform text, visibility text, verification_status text,
  subscription_status text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
  IF NOT public.is_active_admin() THEN
    RAISE EXCEPTION 'aal2_staff_required' USING ERRCODE = 'P0001';
  END IF;
  RETURN QUERY
  SELECT
    up.user_id,
    p.id,
    public.mask_admin_name(concat_ws(' ', p.first_name, p.last_name)),
    public.mask_admin_email(u.email),
    coalesce(p.country_code, u.country_code)::text,
    coalesce(p.gender, u.gender)::text,
    up.last_seen_at,
    up.app_state,
    up.platform,
    coalesce(p.visibility, 'profile_pending')::text,
    coalesce(p.verification_status, 'unverified')::text,
    coalesce(u.subscription_status, 'none')::text
  FROM public.user_presence up
  JOIN public.users u ON u.id = up.user_id
  LEFT JOIN public.profiles p ON p.user_id = up.user_id
  WHERE up.last_seen_at >= now() - interval '12 minutes'
    AND up.app_state = 'foreground'
  ORDER BY up.last_seen_at DESC
  LIMIT least(greatest(coalesce(p_limit, 25), 1), 100);
END;
$function$;

CREATE OR REPLACE FUNCTION public.admin_dashboard_overview(p_online_limit integer DEFAULT 12)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
  IF NOT public.is_active_admin() THEN
    RAISE EXCEPTION 'staff_authorization_required' USING ERRCODE = '42501';
  END IF;

  RETURN jsonb_build_object(
    'metrics', (
      SELECT snapshot.payload - 'pendingKyc' - 'pendingPhotoChecks'
      FROM private.admin_metric_snapshots snapshot
      WHERE snapshot.metric_name = 'dashboard'
    ),
    -- Snapshot figures, with the online count replaced by a live read.
    'live', (
      SELECT jsonb_set(
        snapshot.payload,
        '{traffic,onlineNow}',
        to_jsonb(private.count_online_members()),
        true
      ) || jsonb_build_object('onlineReadAt', extract(epoch FROM now())::bigint)
      FROM private.admin_metric_snapshots snapshot
      WHERE snapshot.metric_name = 'live_operations'
    ),
    'onlineUsers', coalesce((
      SELECT jsonb_agg(to_jsonb(online) ORDER BY online.last_seen_at DESC)
      FROM public.admin_online_users(least(greatest(coalesce(p_online_limit, 12), 1), 50)) online
    ), '[]'::jsonb)
  );
END;
$function$;

-- The snapshot, the free-plan card and the peak tracking use the same rule.
DO $migration$
DECLARE
  v_signature regprocedure;
  v_original text;
  v_updated text;
  v_pattern text :=
    'SELECT count\(\*\) FROM public\.user_presence\s+WHERE last_seen_at >= now\(\) - interval ''12 minutes''';
BEGIN
  FOREACH v_signature IN ARRAY ARRAY[
    'private.refresh_admin_metric_snapshots()'::regprocedure,
    'private.capture_operational_health()'::regprocedure
  ] LOOP
    SELECT replace(pg_get_functiondef(v_signature), E'\r\n', E'\n') INTO v_original;
    v_updated := regexp_replace(
      v_original, v_pattern, 'SELECT private.count_online_members()', 'g'
    );
    -- capture_operational_health selects INTO a variable.
    v_updated := regexp_replace(
      v_updated,
      'SELECT count\(\*\) INTO v_online\s+FROM public\.user_presence\s+WHERE last_seen_at >= now\(\) - interval ''12 minutes'';',
      'v_online := private.count_online_members();',
      'g'
    );
    IF v_updated = v_original THEN
      RAISE EXCEPTION 'online_count_anchor_missing in %', v_signature;
    END IF;
    EXECUTE v_updated;
  END LOOP;
END;
$migration$;
