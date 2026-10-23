-- Silarah — cache valid IANA zone names for notification scheduling
--
-- queue_notification() runs inside chat sends, interests, profile views and
-- every other notification producer. Its quiet-hours lookup validated the
-- member timezone against pg_timezone_names, a view that re-reads the whole
-- zone database from disk on each call (~400-950 ms measured on staging).
-- Keep identical validation semantics with an indexed private copy, refreshed
-- weekly because the zone list only changes with a Postgres upgrade.

CREATE TABLE private.timezone_names (
  name text PRIMARY KEY
);

ALTER TABLE private.timezone_names ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE private.timezone_names FROM PUBLIC, anon, authenticated;

CREATE FUNCTION private.refresh_timezone_names()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_changed integer := 0;
  v_count integer;
BEGIN
  INSERT INTO private.timezone_names(name)
  SELECT tz.name FROM pg_catalog.pg_timezone_names tz
  ON CONFLICT (name) DO NOTHING;
  GET DIAGNOSTICS v_count = ROW_COUNT;
  v_changed := v_changed + v_count;

  DELETE FROM private.timezone_names cached
  WHERE NOT EXISTS (
    SELECT 1 FROM pg_catalog.pg_timezone_names tz WHERE tz.name = cached.name
  );
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_changed + v_count;
END;
$$;

REVOKE ALL ON FUNCTION private.refresh_timezone_names()
  FROM PUBLIC, anon, authenticated;

SELECT private.refresh_timezone_names();

-- Replace only the zone-validation source inside the deployed function so
-- every other part of the notification contract stays byte-for-byte intact.
DO $migration$
DECLARE v_original text; v_updated text;
BEGIN
  SELECT replace(pg_get_functiondef(
    'public.queue_notification(uuid,text,text,text,text)'::regprocedure
  ), E'\r\n', E'\n') INTO v_original;
  v_updated := replace(v_original,
    'FROM pg_catalog.pg_timezone_names',
    'FROM private.timezone_names');
  IF v_updated = v_original
    OR position('pg_timezone_names' IN v_updated) > 0 THEN
    RAISE EXCEPTION 'queue_notification_timezone_anchor_missing';
  END IF;
  EXECUTE v_updated;
END;
$migration$;

DO $$
BEGIN
  IF to_regclass('cron.job') IS NOT NULL THEN
    PERFORM cron.schedule('refresh_timezone_names_weekly', '41 3 * * 0',
      'SELECT private.refresh_timezone_names();');
  END IF;
END;
$$;

COMMENT ON TABLE private.timezone_names IS
  'Indexed copy of pg_timezone_names for hot-path notification quiet-hours validation.';
COMMENT ON FUNCTION private.refresh_timezone_names() IS
  'Reconciles the cached zone list with pg_timezone_names; scheduled weekly.';
