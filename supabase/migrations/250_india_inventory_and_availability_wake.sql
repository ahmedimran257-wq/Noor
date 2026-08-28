-- Keep the background inventory contract identical to the India filter JSON
-- emitted by Flutter. The stale plural keys were never sent by the app and
-- caused state/city empty-feed alerts to be rejected after a successful load.
DO $migration$
DECLARE
  v_signature regprocedure :=
    'public.record_discovery_inventory(jsonb,boolean)'::regprocedure;
  v_definition text;
  v_stale text :=
    '''verified_only'', ''trust_filter'', ''state_codes'', ''city_ids'', ''family_type''';
  v_canonical text :=
    '''verified_only'', ''trust_filter'', ''state_name'', ''city_id'', ''family_type''';
BEGIN
  SELECT pg_get_functiondef(v_signature) INTO v_definition;
  IF position(v_canonical IN v_definition) = 0 THEN
    IF position(v_stale IN v_definition) = 0 THEN
      RAISE EXCEPTION 'discovery_inventory_india_filter_anchor_not_found';
    END IF;
    EXECUTE replace(v_definition, v_stale, v_canonical);
  END IF;
END;
$migration$;

-- enqueue_discovery_availability_event coalesces repeated transitions with
-- ON CONFLICT UPDATE. Wake the worker for both a new row and an event_at reset;
-- cursor/lease progress updates do not touch event_at and therefore cannot
-- recursively wake the worker.
DROP TRIGGER IF EXISTS trg_wake_discovery_notification_worker
  ON private.discovery_availability_events;
CREATE TRIGGER trg_wake_discovery_notification_worker
  AFTER INSERT OR UPDATE OF event_at
  ON private.discovery_availability_events
  FOR EACH STATEMENT
  EXECUTE FUNCTION private.wake_discovery_notification_worker();

COMMENT ON TRIGGER trg_wake_discovery_notification_worker
  ON private.discovery_availability_events IS
  'Wakes bounded delivery for new and coalesced availability transitions; progress-only updates do not recurse.';

NOTIFY pgrst, 'reload schema';
