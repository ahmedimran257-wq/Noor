-- A small authenticated preflight lets the official client recover safely
-- when a previously saved Premium geographic filter outlives a subscription.
-- The feed RPC in migration 131 remains the final enforcement boundary.

CREATE OR REPLACE FUNCTION public.get_discovery_filter_access()
RETURNS TABLE (allowed boolean, tier text)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_allowed boolean;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = 'P0001';
  END IF;

  v_allowed := public.has_active_premium(v_user_id);
  RETURN QUERY SELECT
    v_allowed,
    CASE WHEN v_allowed THEN 'premium'::text ELSE 'free'::text END;
END;
$$;

REVOKE ALL ON FUNCTION public.get_discovery_filter_access() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_discovery_filter_access()
  TO authenticated;

COMMENT ON FUNCTION public.get_discovery_filter_access() IS
  'Authoritative client preflight for Premium geographic discovery filters.';
