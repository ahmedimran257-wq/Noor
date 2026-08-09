-- Premium discovery preferences must be entitlements, not client-side locks.
-- The location scopes were already enforced by get_discovery_feed; this closes
-- the remaining verified, language, community and living-preference bypasses.

CREATE OR REPLACE FUNCTION private.assert_discovery_filter_entitlement(
  p_user_id uuid,
  p_filters jsonb
)
RETURNS void
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_features text[] := ARRAY[]::text[];
BEGIN
  IF public.has_active_premium(p_user_id) THEN
    RETURN;
  END IF;

  IF coalesce((p_filters->>'verified_only')::boolean, false) THEN
    v_features := array_append(v_features, 'verified_only');
  END IF;
  IF nullif(trim(p_filters->>'mother_tongue'), '') IS NOT NULL THEN
    v_features := array_append(v_features, 'mother_tongue');
  END IF;
  IF nullif(trim(p_filters->>'community'), '') IS NOT NULL THEN
    v_features := array_append(v_features, 'community');
  END IF;
  IF nullif(trim(p_filters->>'living_expectation'), '') IS NOT NULL THEN
    v_features := array_append(v_features, 'living_expectation');
  END IF;

  IF cardinality(v_features) > 0 THEN
    RAISE EXCEPTION 'premium_filter_required'
      USING ERRCODE = 'P0001',
            DETAIL = json_build_object(
              'feature', 'premium_preferences',
              'filters', v_features
            )::text;
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION private.assert_discovery_filter_entitlement(uuid, jsonb)
  FROM PUBLIC, anon, authenticated;

DO $migration$
DECLARE
  v_signature regprocedure :=
    'public.get_discovery_feed(uuid,double precision,uuid,integer,jsonb)'::regprocedure;
  v_definition text;
  v_updated text;
  v_anchor text := $anchor$  IF auth.uid() IS DISTINCT FROM p_viewer_id THEN
    RAISE EXCEPTION 'Discovery can only be requested for the signed-in user.';
  END IF;$anchor$;
  v_replacement text := $replacement$  IF auth.uid() IS DISTINCT FROM p_viewer_id THEN
    RAISE EXCEPTION 'Discovery can only be requested for the signed-in user.';
  END IF;

  PERFORM private.assert_discovery_filter_entitlement(
    p_viewer_id,
    coalesce(p_filters, '{}'::jsonb)
  );$replacement$;
BEGIN
  SELECT pg_get_functiondef(v_signature) INTO v_definition;

  IF position('private.assert_discovery_filter_entitlement(' IN v_definition) > 0 THEN
    RETURN;
  END IF;
  IF position(v_anchor IN v_definition) = 0 THEN
    RAISE EXCEPTION 'discovery_entitlement_injection_anchor_not_found'
      USING ERRCODE = 'P0001';
  END IF;

  v_updated := replace(v_definition, v_anchor, v_replacement);
  EXECUTE v_updated;

  SELECT pg_get_functiondef(v_signature) INTO v_definition;
  IF position('private.assert_discovery_filter_entitlement(' IN v_definition) = 0 THEN
    RAISE EXCEPTION 'discovery_entitlement_injection_failed'
      USING ERRCODE = 'P0001';
  END IF;
END;
$migration$;

COMMENT ON FUNCTION private.assert_discovery_filter_entitlement(uuid, jsonb) IS
  'Server-side entitlement guard for every discovery preference presented as Premium in the app.';

NOTIFY pgrst, 'reload schema';
