-- The global city migration intentionally uses varchar keys/names, while the
-- public discovery RPC promises JSON-friendly text fields. PostgreSQL does not
-- implicitly coerce varchar to text for RETURNS TABLE, so make that boundary
-- explicit without duplicating the full feed implementation from migration 112.

DO $migration$
DECLARE
  v_signature regprocedure :=
    'public.get_discovery_feed(uuid,double precision,uuid,integer,jsonb)'::regprocedure;
  v_definition text;
  v_updated_definition text;
BEGIN
  SELECT pg_get_functiondef(v_signature) INTO v_definition;

  v_updated_definition := replace(
    v_definition,
    E'    dp.city_name,\n    dp.country_code,',
    E'    dp.city_name::text,\n    dp.country_code::text,'
  );

  IF v_updated_definition = v_definition THEN
    RAISE EXCEPTION
      'Discovery feed text contract patch did not match the expected function body';
  END IF;

  EXECUTE v_updated_definition;
END;
$migration$;

REVOKE ALL ON FUNCTION public.get_discovery_feed(
  uuid, double precision, uuid, integer, jsonb
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_discovery_feed(
  uuid, double precision, uuid, integer, jsonb
) TO authenticated;
