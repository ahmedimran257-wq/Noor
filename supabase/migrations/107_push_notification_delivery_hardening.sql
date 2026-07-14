-- Server-side push delivery hardening.
-- Notification rows remain available in-app, but FCM dispatch respects the
-- user's notification preferences before sending a device push.

CREATE OR REPLACE FUNCTION public.notification_push_enabled(
  p_user_id uuid,
  p_type text
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT CASE
    WHEN p_type IN ('new_message', 'guardian_message_mirror', 'guardian_sent_message')
      THEN coalesce(np.new_message, true)
    WHEN p_type IN ('interest_received', 'new_interest', 'photo_access_request')
      THEN coalesce(np.new_interest, true)
    WHEN p_type IN ('interest_accepted', 'photo_access_granted')
      THEN coalesce(np.interest_accepted, true)
    WHEN p_type IN ('profile_approved', 'profile_returned_to_review')
      THEN coalesce(np.profile_approved, true)
    WHEN p_type = 'interest_expiring'
      THEN coalesce(np.interest_expiring, true)
    WHEN p_type = 'inactive_nudge'
      THEN coalesce(np.inactive_nudge, true)
    WHEN p_type IN ('boost_ready', 'boost_available', 'referral_reward', 'referral_completed')
      THEN coalesce(np.boost_available, true)
    ELSE true
  END
  FROM (SELECT p_user_id AS user_id) u
  LEFT JOIN public.notification_prefs np ON np.user_id = u.user_id;
$$;

REVOKE ALL ON FUNCTION public.notification_push_enabled(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.notification_push_enabled(uuid, text) TO service_role;

DROP FUNCTION IF EXISTS public.checkout_notifications(integer);

CREATE OR REPLACE FUNCTION public.checkout_notifications(batch_size int DEFAULT 500)
RETURNS TABLE (
  id uuid,
  user_id uuid,
  type text,
  title text,
  body text,
  deep_link text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Rows whose category is disabled should remain in the in-app inbox, but
  -- should not be retried forever by the FCM dispatcher.
  UPDATE public.notifications n
  SET sent_at = NOW()
  WHERE n.scheduled_at <= NOW()
    AND n.sent_at IS NULL
    AND NOT public.notification_push_enabled(n.user_id, n.type);

  RETURN QUERY
  UPDATE public.notifications n
  SET sent_at = NOW()
  WHERE n.id IN (
    SELECT n2.id
    FROM public.notifications n2
    WHERE n2.scheduled_at <= NOW()
      AND n2.sent_at IS NULL
      AND public.notification_push_enabled(n2.user_id, n2.type)
    ORDER BY n2.scheduled_at ASC
    LIMIT batch_size
    FOR UPDATE SKIP LOCKED
  )
  RETURNING n.id, n.user_id, n.type, n.title, n.body, n.deep_link;
END;
$$;

REVOKE ALL ON FUNCTION public.checkout_notifications(integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.checkout_notifications(integer) TO service_role;
