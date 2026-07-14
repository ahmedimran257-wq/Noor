-- Align account preferences and historical copy with instant profile publishing.
-- Legal identity verification remains separate from the passive photo badge.

ALTER TABLE public.notification_prefs
  ADD COLUMN IF NOT EXISTS profile_live boolean NOT NULL DEFAULT true;

-- Keep the deprecated storage field synchronized during the installed-client
-- transition. It is intentionally absent from all current UI and Dart APIs.
UPDATE public.notification_prefs
SET profile_live = profile_approved
WHERE profile_live IS DISTINCT FROM profile_approved;

CREATE OR REPLACE FUNCTION public.sync_profile_live_preference()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    NEW.profile_live := coalesce(NEW.profile_live, NEW.profile_approved, true);
    NEW.profile_approved := NEW.profile_live;
  ELSIF NEW.profile_live IS DISTINCT FROM OLD.profile_live THEN
    NEW.profile_approved := NEW.profile_live;
  ELSIF NEW.profile_approved IS DISTINCT FROM OLD.profile_approved THEN
    NEW.profile_live := NEW.profile_approved;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS sync_profile_live_preference
  ON public.notification_prefs;
CREATE TRIGGER sync_profile_live_preference
BEFORE INSERT OR UPDATE OF profile_live, profile_approved
ON public.notification_prefs
FOR EACH ROW EXECUTE FUNCTION public.sync_profile_live_preference();

UPDATE public.notifications
SET type = 'profile_live',
    title = 'Your profile is now live!',
    body = 'Your Silarah profile is visible in discovery.',
    deep_link = 'silarah://profile'
WHERE type = 'profile_approved';

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
    WHEN p_type IN ('profile_returned_to_review', 'profile_live')
      THEN coalesce(np.profile_live, true)
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

COMMENT ON COLUMN public.notification_prefs.profile_live IS
  'Push preference for instant profile-live and related visibility updates.';
