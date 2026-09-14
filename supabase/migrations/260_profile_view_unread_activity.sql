-- Silarah — truthful unread profile-view activity
--
-- The existing weekly summary is an aggregate, not an unread counter, and
-- profile-view push notifications are intentionally throttled. Keep an
-- authoritative per-member read cursor so the profile header can show unseen
-- viewers without reusing either misleading number.

CREATE TABLE private.profile_view_activity_state (
  user_id uuid PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
  last_seen_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE private.profile_view_activity_state ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE private.profile_view_activity_state
  FROM PUBLIC, anon, authenticated;

-- Existing members begin with a clean activity rail instead of receiving an
-- artificial unread burst for profile views that predate this feature.
INSERT INTO private.profile_view_activity_state(user_id, last_seen_at, updated_at)
SELECT p.user_id, now(), now()
FROM public.profiles p
ON CONFLICT (user_id) DO NOTHING;

DROP FUNCTION public.get_my_profile_view_summary();
CREATE FUNCTION public.get_my_profile_view_summary()
RETURNS TABLE(viewer_count bigint, unseen_viewer_count bigint)
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid := private.assert_authenticated();
  v_last_seen_at timestamptz;
BEGIN
  INSERT INTO private.profile_view_activity_state(user_id)
  VALUES (v_user_id)
  ON CONFLICT (user_id) DO NOTHING;

  SELECT state.last_seen_at
  INTO v_last_seen_at
  FROM private.profile_view_activity_state state
  WHERE state.user_id = v_user_id;

  RETURN QUERY
  SELECT
    count(DISTINCT pv.viewer_profile_id)::bigint AS viewer_count,
    count(DISTINCT pv.viewer_profile_id)
      FILTER (WHERE pv.viewed_at > v_last_seen_at)::bigint
      AS unseen_viewer_count
  FROM public.profile_views pv
  JOIN public.profiles mine ON mine.id = pv.viewed_profile_id
  WHERE mine.user_id = v_user_id
    AND pv.viewed_at >= now() - interval '7 days';
END;
$$;

CREATE FUNCTION public.mark_profile_views_seen()
RETURNS integer
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid := private.assert_authenticated();
  v_marked_notifications integer := 0;
  v_seen_at timestamptz := now();
BEGIN
  INSERT INTO private.profile_view_activity_state(
    user_id,
    last_seen_at,
    updated_at
  ) VALUES (
    v_user_id,
    v_seen_at,
    v_seen_at
  )
  ON CONFLICT (user_id) DO UPDATE
  SET last_seen_at = greatest(
        private.profile_view_activity_state.last_seen_at,
        EXCLUDED.last_seen_at
      ),
      updated_at = EXCLUDED.updated_at;

  -- Profile-view alerts remain visible in notification history, but opening
  -- the dedicated activity surface clears their unread state so the bell and
  -- eye never claim the same activity.
  UPDATE public.notifications
  SET read_at = coalesce(read_at, v_seen_at)
  WHERE user_id = v_user_id
    AND type = 'profile_view'
    AND read_at IS NULL;
  GET DIAGNOSTICS v_marked_notifications = ROW_COUNT;

  RETURN v_marked_notifications;
END;
$$;

REVOKE ALL ON FUNCTION public.get_my_profile_view_summary()
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.mark_profile_views_seen()
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_profile_view_summary()
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_profile_views_seen()
  TO authenticated;

COMMENT ON TABLE private.profile_view_activity_state IS
  'Server-owned read cursor for the authenticated member profile-view rail.';
COMMENT ON FUNCTION public.get_my_profile_view_summary() IS
  'Seven-day distinct viewer total plus distinct viewers unseen since the member last opened profile activity.';
COMMENT ON FUNCTION public.mark_profile_views_seen() IS
  'Advances the member profile-view read cursor and clears duplicate profile-view notification unread state.';
