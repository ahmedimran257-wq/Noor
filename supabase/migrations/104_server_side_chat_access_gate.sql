-- Server-side chat access gate for UI decisions.
-- The messages trigger remains the final enforcement point for forged sends.

CREATE OR REPLACE FUNCTION public.can_open_chat(p_match_id uuid)
RETURNS TABLE (
  allowed boolean,
  reason text
)
LANGUAGE plpgsql
SECURITY INVOKER
AS $$
DECLARE
  v_me uuid := auth.uid();
  v_match public.matches%rowtype;
  v_gender text;
  v_sub text;
  v_expires timestamptz;
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
    RETURN QUERY SELECT false, 'not_found';
    RETURN;
  END IF;

  IF coalesce(v_match.status, 'active') <> 'active' THEN
    RETURN QUERY SELECT false, 'closed';
    RETURN;
  END IF;

  SELECT gender, subscription_status, subscription_expires_at, messaging_suspended_until
  INTO v_gender, v_sub, v_expires, v_suspended_until
  FROM public.users
  WHERE id = v_me;

  IF v_suspended_until IS NOT NULL AND v_suspended_until > now() THEN
    RETURN QUERY SELECT false, 'suspended';
    RETURN;
  END IF;

  IF v_gender = 'male' THEN
    IF v_sub = 'active' THEN
      RETURN QUERY SELECT true, 'allowed';
      RETURN;
    END IF;

    IF v_sub = 'grace'
      AND v_expires IS NOT NULL
      AND v_expires > now() - interval '24 hours' THEN
      RETURN QUERY SELECT true, 'allowed';
      RETURN;
    END IF;

    RETURN QUERY SELECT false, 'subscription_required';
    RETURN;
  END IF;

  RETURN QUERY SELECT true, 'allowed';
END;
$$;

REVOKE ALL ON FUNCTION public.can_open_chat(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.can_open_chat(uuid) TO authenticated;
