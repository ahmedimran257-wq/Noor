-- `p_state_name` and `p_postal_code` remain in this public RPC signature for
-- backwards compatibility. The authoritative city id already owns normalized
-- location data, so consume the legacy hints explicitly without persisting
-- unverified client text. This also removes the two app-owned lint warnings.
DO $migration$
DECLARE
  v_function regprocedure :=
    'public.save_basic_identity_step(text,text,text,text,text,text,text,text,text,text,date,text,integer,text,text,text,text,text,text,text,text,text,numeric,numeric)'::regprocedure;
  v_definition text;
  v_marker constant text := E'\nBEGIN\n';
  v_replacement constant text := E'\nBEGIN\n  -- Legacy hints are accepted for RPC compatibility; the verified city id is authoritative.\n  PERFORM\n    nullif(trim(coalesce(p_state_name, '''')), ''''),\n    nullif(trim(coalesce(p_postal_code, '''')), '''');\n';
  v_occurrences integer;
BEGIN
  SELECT pg_get_functiondef(v_function)
  INTO v_definition;

  IF v_definition LIKE '%Legacy hints are accepted for RPC compatibility%' THEN
    RETURN;
  END IF;

  v_occurrences := (
    length(v_definition) - length(replace(v_definition, v_marker, ''))
  ) / length(v_marker);

  IF v_occurrences <> 1 THEN
    RAISE EXCEPTION 'unexpected_save_basic_identity_definition';
  END IF;

  EXECUTE replace(v_definition, v_marker, v_replacement);
END;
$migration$;
