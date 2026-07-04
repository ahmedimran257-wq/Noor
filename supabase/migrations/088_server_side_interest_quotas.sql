-- ============================================================
-- MITHAQ — Server-side interest quotas
-- ============================================================

CREATE OR REPLACE FUNCTION public.interest_daily_limit(p_user_id uuid)
RETURNS integer
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_gender text;
  v_sub_status text;
  v_sub_expires_at timestamptz;
  v_approved_at timestamptz;
BEGIN
  SELECT u.gender, u.subscription_status, u.subscription_expires_at, p.approved_at
  INTO v_gender, v_sub_status, v_sub_expires_at, v_approved_at
  FROM public.users u
  LEFT JOIN public.profiles p ON p.user_id = u.id
  WHERE u.id = p_user_id
  LIMIT 1;

  IF v_approved_at IS NULL OR now() - v_approved_at < interval '7 days' THEN
    RETURN 3;
  END IF;

  IF v_gender = 'female' THEN
    RETURN 10;
  END IF;

  IF v_sub_status IN ('active', 'grace')
    AND (v_sub_expires_at IS NULL OR v_sub_expires_at > now()) THEN
    RETURN 20;
  END IF;

  RETURN 3;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_interest_quota()
RETURNS TABLE (
  sent_today integer,
  daily_limit integer,
  remaining integer,
  is_limited boolean
)
LANGUAGE plpgsql
SECURITY INVOKER
AS $$
DECLARE
  v_me uuid := auth.uid();
  v_limit integer;
  v_count integer;
BEGIN
  IF v_me IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = 'P0001';
  END IF;

  v_limit := coalesce(public.interest_daily_limit(v_me), 3);

  SELECT count(*)::integer INTO v_count
  FROM public.interests
  WHERE sender_id = v_me
    AND created_at::date = current_date;

  RETURN QUERY SELECT
    v_count,
    v_limit,
    greatest(v_limit - v_count, 0),
    v_count >= v_limit;
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
BEGIN
  PERFORM pg_advisory_xact_lock(hashtext(NEW.sender_id::text));

  v_daily_limit := coalesce(public.interest_daily_limit(NEW.sender_id), 3);

  SELECT count(*) INTO v_today_count
  FROM public.interests
  WHERE sender_id = NEW.sender_id
    AND created_at::date = current_date;

  IF v_today_count >= v_daily_limit THEN
    RAISE EXCEPTION 'Daily interest limit reached. You can send more interests tomorrow.';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.interests
    WHERE sender_id = NEW.sender_id
      AND receiver_id = NEW.receiver_id
      AND status IN ('pending', 'accepted')
  ) THEN
    RAISE EXCEPTION 'You have already sent an interest to this person.';
  END IF;

  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.interest_daily_limit(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_interest_quota() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_interest_quota() TO authenticated;
