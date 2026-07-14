-- Keep profile-tab actions server-enforced and aligned with instant publishing.

CREATE OR REPLACE FUNCTION public.set_profile_pause(p_paused boolean)
RETURNS TABLE (
  is_paused boolean,
  visibility text,
  message text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_profile public.profiles%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Please sign in again to update profile visibility.';
  END IF;

  SELECT * INTO v_profile
  FROM public.profiles
  WHERE user_id = auth.uid()
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Complete your profile before changing visibility.';
  END IF;
  IF v_profile.visibility IN ('suspended', 'deactivated') THEN
    RAISE EXCEPTION 'This profile cannot be made visible from settings.';
  END IF;

  IF coalesce(p_paused, false) THEN
    UPDATE public.profiles
    SET visibility = 'paused', updated_at = now()
    WHERE id = v_profile.id;
    RETURN QUERY SELECT true, 'paused'::text, 'Your profile is hidden.'::text;
    RETURN;
  END IF;

  IF coalesce(v_profile.onboarding_completed, false) IS DISTINCT FROM true THEN
    RAISE EXCEPTION 'Complete onboarding before making your profile visible.';
  END IF;
  IF NOT EXISTS (
    SELECT 1
    FROM public.photos ph
    WHERE ph.profile_id = v_profile.id
      AND ph.order_index = 0
      AND ph.status = 'active'
      AND ph.moderation_status = 'approved'
      AND ph.admin_approved = true
      AND ph.nsfw_cleared = true
  ) THEN
    RAISE EXCEPTION 'Add a primary photo that passes the safety scan before making your profile visible.';
  END IF;

  UPDATE public.profiles
  SET visibility = 'visible', updated_at = now()
  WHERE id = v_profile.id;
  RETURN QUERY SELECT false, 'visible'::text, 'Your profile is visible.'::text;
END;
$$;

REVOKE ALL ON FUNCTION public.set_profile_pause(boolean) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.set_profile_pause(boolean) TO authenticated;

-- Profile boosts affect discovery ranking, so clients must not grant them by
-- directly updating profile columns. The RPC validates the live entitlement.
CREATE OR REPLACE FUNCTION public.guard_profile_boost_mutation()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  IF (NEW.is_boosted, NEW.boost_expires_at)
       IS DISTINCT FROM
     (OLD.is_boosted, OLD.boost_expires_at)
     AND current_user NOT IN ('postgres', 'service_role', 'supabase_admin')
     AND current_setting('silarah.allow_boost_mutation', true) IS DISTINCT FROM 'yes'
  THEN
    RAISE EXCEPTION 'Use activate_profile_boost() to update boost status.';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS guard_profile_boost_mutation ON public.profiles;
CREATE TRIGGER guard_profile_boost_mutation
BEFORE UPDATE OF is_boosted, boost_expires_at ON public.profiles
FOR EACH ROW EXECUTE FUNCTION public.guard_profile_boost_mutation();

CREATE OR REPLACE FUNCTION public.activate_profile_boost()
RETURNS TABLE (boost_expires_at timestamptz)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_gender text;
  v_subscription text;
  v_subscription_expires timestamptz;
  v_profile public.profiles%ROWTYPE;
  v_expires timestamptz;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Please sign in again to activate a boost.';
  END IF;

  SELECT u.gender::text, u.subscription_status, u.subscription_expires_at
  INTO v_gender, v_subscription, v_subscription_expires
  FROM public.users u
  WHERE u.id = auth.uid();

  SELECT * INTO v_profile
  FROM public.profiles
  WHERE user_id = auth.uid()
  FOR UPDATE;

  IF NOT FOUND OR v_profile.visibility IS DISTINCT FROM 'visible' THEN
    RAISE EXCEPTION 'Your profile must be live before it can be boosted.';
  END IF;
  IF v_gender IS DISTINCT FROM 'female'
     AND NOT (
       v_subscription IN ('active', 'grace')
       AND (v_subscription_expires IS NULL OR v_subscription_expires > now())
     )
  THEN
    RAISE EXCEPTION 'An active subscription is required to boost this profile.';
  END IF;

  IF v_profile.is_boosted = true AND v_profile.boost_expires_at > now() THEN
    RETURN QUERY SELECT v_profile.boost_expires_at;
    RETURN;
  END IF;

  v_expires := now() + interval '2 hours';
  PERFORM set_config('silarah.allow_boost_mutation', 'yes', true);
  UPDATE public.profiles
  SET is_boosted = true,
      boost_expires_at = v_expires,
      updated_at = now()
  WHERE id = v_profile.id;

  RETURN QUERY SELECT v_expires;
END;
$$;

REVOKE ALL ON FUNCTION public.activate_profile_boost() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.activate_profile_boost() TO authenticated;
