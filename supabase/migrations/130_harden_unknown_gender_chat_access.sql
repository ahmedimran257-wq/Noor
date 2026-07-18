-- Only an explicitly female account receives free messaging. An incomplete or
-- malformed gender value must not become a paywall bypass.

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

  IF v_gender IS DISTINCT FROM 'female'
    AND NOT public.has_active_premium(v_me) THEN
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

  IF v_gender IS DISTINCT FROM 'female'
    AND NOT public.has_active_premium(NEW.sender_id) THEN
    RAISE EXCEPTION 'subscription_required' USING ERRCODE = 'P0001';
  END IF;

  RETURN NEW;
END;
$$;
