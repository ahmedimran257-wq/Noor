-- Profile-completion nudges share the user's activity-nudge push preference.
-- Rows remain visible in the in-app inbox when push is disabled.

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
    WHEN p_type IN ('profile_approved', 'profile_returned_to_review', 'profile_live')
      THEN coalesce(np.profile_approved, true)
    WHEN p_type = 'interest_expiring'
      THEN coalesce(np.interest_expiring, true)
    WHEN p_type IN ('inactive_nudge', 'profile_nudge')
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
