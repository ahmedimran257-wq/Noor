-- Silarah interest entitlements and authoritative chat access.
--
-- Product policy:
--   * Free members (all genders): 5 interests per UTC day.
--   * Premium members (all genders): 25 interests per UTC day.
--   * Women can message without Premium.
--   * Men require an active subscription or the existing 24-hour grace window.
--
-- Interest limits are intentionally finite on Premium to protect members from
-- bulk outreach and to keep notification/moderation costs predictable.

CREATE OR REPLACE FUNCTION public.has_active_premium(p_user_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT coalesce((
    SELECT
      subscription_status = 'active'
      OR (
        subscription_status = 'grace'
        AND subscription_expires_at IS NOT NULL
        AND subscription_expires_at > now() - interval '24 hours'
      )
    FROM public.users
    WHERE id = p_user_id
  ), false);
$$;

CREATE OR REPLACE FUNCTION public.interest_daily_limit(p_user_id uuid)
RETURNS integer
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT CASE WHEN public.has_active_premium(p_user_id) THEN 25 ELSE 5 END;
$$;

DROP FUNCTION IF EXISTS public.get_interest_quota();
CREATE FUNCTION public.get_interest_quota()
RETURNS TABLE (
  sent_today integer,
  daily_limit integer,
  remaining integer,
  is_limited boolean,
  is_premium boolean,
  tier text,
  resets_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_me uuid := auth.uid();
  v_limit integer;
  v_count integer;
  v_premium boolean;
  v_period_start timestamptz;
  v_resets_at timestamptz;
BEGIN
  IF v_me IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = 'P0001';
  END IF;

  v_premium := public.has_active_premium(v_me);
  v_limit := CASE WHEN v_premium THEN 25 ELSE 5 END;
  v_period_start := date_trunc('day', now() AT TIME ZONE 'UTC') AT TIME ZONE 'UTC';
  v_resets_at := v_period_start + interval '1 day';

  SELECT count(*)::integer
  INTO v_count
  FROM public.interests
  WHERE sender_id = v_me
    AND created_at >= v_period_start
    AND created_at < v_resets_at;

  RETURN QUERY SELECT
    v_count,
    v_limit,
    greatest(v_limit - v_count, 0),
    v_count >= v_limit,
    v_premium,
    CASE WHEN v_premium THEN 'premium'::text ELSE 'free'::text END,
    v_resets_at;
END;
$$;

CREATE OR REPLACE FUNCTION public.enforce_interest_limits()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_today_count integer;
  v_daily_limit integer;
  v_period_start timestamptz;
  v_resets_at timestamptz;
BEGIN
  IF auth.uid() IS NOT NULL AND NEW.sender_id <> auth.uid() THEN
    RAISE EXCEPTION 'You cannot send an interest for another member.'
      USING ERRCODE = '42501';
  END IF;

  -- The timestamp is server-owned. This prevents a modified client from
  -- backdating rows to bypass a daily quota.
  NEW.created_at := now();
  v_period_start := date_trunc('day', now() AT TIME ZONE 'UTC') AT TIME ZONE 'UTC';
  v_resets_at := v_period_start + interval '1 day';

  PERFORM pg_advisory_xact_lock(hashtext(NEW.sender_id::text));
  v_daily_limit := public.interest_daily_limit(NEW.sender_id);

  SELECT count(*)::integer
  INTO v_today_count
  FROM public.interests
  WHERE sender_id = NEW.sender_id
    AND created_at >= v_period_start
    AND created_at < v_resets_at;

  IF v_today_count >= v_daily_limit THEN
    RAISE EXCEPTION 'interest_quota_exhausted'
      USING ERRCODE = 'P0001',
            DETAIL = json_build_object(
              'daily_limit', v_daily_limit,
              'resets_at', v_resets_at
            )::text;
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.interests
    WHERE sender_id = NEW.sender_id
      AND receiver_id = NEW.receiver_id
      AND status IN ('pending', 'accepted')
  ) THEN
    RAISE EXCEPTION 'interest_already_exists' USING ERRCODE = 'P0001';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_enforce_interest_limits ON public.interests;
CREATE TRIGGER trg_enforce_interest_limits
  BEFORE INSERT ON public.interests
  FOR EACH ROW
  EXECUTE FUNCTION public.enforce_interest_limits();

-- Keep the UI decision and the final messages trigger on identical rules.
CREATE OR REPLACE FUNCTION public.can_open_chat(p_match_id uuid)
RETURNS TABLE (allowed boolean, reason text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_me uuid := auth.uid();
  v_match public.matches%rowtype;
  v_gender text;
  v_suspended_until timestamptz;
BEGIN
  IF v_me IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = 'P0001';
  END IF;

  SELECT * INTO v_match
  FROM public.matches
  WHERE id = p_match_id
    AND (user_a = v_me OR user_b = v_me);

  IF NOT FOUND THEN
    RETURN QUERY SELECT false, 'not_found'::text;
    RETURN;
  END IF;

  IF coalesce(v_match.status, 'active') <> 'active' THEN
    RETURN QUERY SELECT false, 'closed'::text;
    RETURN;
  END IF;

  SELECT gender, messaging_suspended_until
  INTO v_gender, v_suspended_until
  FROM public.users
  WHERE id = v_me;

  IF v_suspended_until IS NOT NULL AND v_suspended_until > now() THEN
    RETURN QUERY SELECT false, 'suspended'::text;
    RETURN;
  END IF;

  IF v_gender = 'male' AND NOT public.has_active_premium(v_me) THEN
    RETURN QUERY SELECT false, 'subscription_required'::text;
    RETURN;
  END IF;

  RETURN QUERY SELECT true, 'allowed'::text;
END;
$$;

CREATE OR REPLACE FUNCTION public.assert_messaging_allowed()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_gender text;
  v_suspended_until timestamptz;
BEGIN
  IF auth.uid() IS NOT NULL AND NEW.sender_id <> auth.uid() THEN
    RAISE EXCEPTION 'You cannot send a message for another member.'
      USING ERRCODE = '42501';
  END IF;

  SELECT gender, messaging_suspended_until
  INTO v_gender, v_suspended_until
  FROM public.users
  WHERE id = NEW.sender_id;

  IF v_suspended_until IS NOT NULL AND v_suspended_until > now() THEN
    RAISE EXCEPTION 'messaging_suspended'
      USING ERRCODE = 'P0001',
            DETAIL = json_build_object('until', v_suspended_until)::text;
  END IF;

  IF v_gender = 'male' AND NOT public.has_active_premium(NEW.sender_id) THEN
    RAISE EXCEPTION 'subscription_required' USING ERRCODE = 'P0001';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_assert_messaging_allowed ON public.messages;
CREATE TRIGGER trg_assert_messaging_allowed
  BEFORE INSERT ON public.messages
  FOR EACH ROW
  EXECUTE FUNCTION public.assert_messaging_allowed();

REVOKE ALL ON FUNCTION public.has_active_premium(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.interest_daily_limit(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_interest_quota() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.can_open_chat(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_interest_quota() TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_open_chat(uuid) TO authenticated;

COMMENT ON FUNCTION public.get_interest_quota() IS
  'Authoritative UTC-day interest quota. Free: 5/day; Premium: 25/day.';
