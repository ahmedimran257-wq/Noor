-- Interest state owns Discovery card actions even though it no longer changes
-- feed membership. A tiny pair revision is inexpensive and lets both devices
-- reconcile send, withdraw, decline and expiry without re-running ranking.
DROP TRIGGER IF EXISTS trg_discovery_revision_interests ON public.interests;
CREATE TRIGGER trg_discovery_revision_interests
AFTER INSERT OR UPDATE OF status OR DELETE ON public.interests
FOR EACH ROW EXECUTE FUNCTION private.bump_discovery_pair_revision();

-- Skip reminder rows whose two idempotent events already exist. Without this
-- predicate the first 500 interests monopolized every hourly batch forever.
CREATE OR REPLACE FUNCTION private.process_interest_expiry_lifecycle(
  p_batch_size integer DEFAULT 2000
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_limit integer := greatest(1, least(coalesce(p_batch_size, 2000), 2000));
  v_interest record;
  v_inserted integer;
  v_reminders integer := 0;
  v_expired integer := 0;
BEGIN
  IF NOT pg_try_advisory_xact_lock(hashtext('interest_expiry_lifecycle')) THEN
    RETURN jsonb_build_object('busy', true, 'reminders', 0, 'expired', 0);
  END IF;

  FOR v_interest IN
    SELECT i.id, i.sender_id, i.receiver_id
    FROM public.interests i
    WHERE i.status = 'pending'
      AND i.expires_at > now()
      AND i.expires_at <= now() + interval '24 hours'
      AND (
        NOT EXISTS (
          SELECT 1 FROM private.interest_expiry_events event
          WHERE event.interest_id = i.id
            AND event.recipient_id = i.receiver_id
            AND event.event_type = 'receiver_reminder'
        )
        OR NOT EXISTS (
          SELECT 1 FROM private.interest_expiry_events event
          WHERE event.interest_id = i.id
            AND event.recipient_id = i.sender_id
            AND event.event_type = 'sender_reminder'
        )
      )
    ORDER BY i.expires_at, i.id
    LIMIT v_limit
  LOOP
    INSERT INTO private.interest_expiry_events(
      interest_id, recipient_id, event_type
    ) VALUES (v_interest.id, v_interest.receiver_id, 'receiver_reminder')
    ON CONFLICT DO NOTHING;
    GET DIAGNOSTICS v_inserted = ROW_COUNT;
    IF v_inserted > 0 THEN
      PERFORM public.queue_notification(
        v_interest.receiver_id,
        'interest_expiring',
        'Interest expires within 24 hours',
        'Accept or decline it before the response window closes.',
        'silarah://interests'
      );
      v_reminders := v_reminders + 1;
    END IF;

    INSERT INTO private.interest_expiry_events(
      interest_id, recipient_id, event_type
    ) VALUES (v_interest.id, v_interest.sender_id, 'sender_reminder')
    ON CONFLICT DO NOTHING;
    GET DIAGNOSTICS v_inserted = ROW_COUNT;
    IF v_inserted > 0 THEN
      PERFORM public.queue_notification(
        v_interest.sender_id,
        'interest_expiring',
        'Your interest expires within 24 hours',
        'It will close automatically if no response is received.',
        'silarah://interests'
      );
      v_reminders := v_reminders + 1;
    END IF;
  END LOOP;

  WITH due AS (
    SELECT i.id
    FROM public.interests i
    WHERE i.status = 'pending' AND i.expires_at <= now()
    ORDER BY i.expires_at, i.id
    LIMIT v_limit
    FOR UPDATE SKIP LOCKED
  )
  UPDATE public.interests i
  SET status = 'expired'
  FROM due
  WHERE i.id = due.id;
  GET DIAGNOSTICS v_expired = ROW_COUNT;

  RETURN jsonb_build_object(
    'busy', false,
    'reminders', v_reminders,
    'expired', v_expired
  );
END;
$$;

REVOKE ALL ON FUNCTION private.process_interest_expiry_lifecycle(integer)
  FROM PUBLIC, anon, authenticated;

DO $migration$
DECLARE v_job record;
BEGIN
  FOR v_job IN
    SELECT jobid FROM cron.job
    WHERE jobname = 'process_interest_expiry_hourly'
       OR jobname = 'process_interest_expiry_5m'
  LOOP
    PERFORM cron.unschedule(v_job.jobid);
  END LOOP;
END;
$migration$;

SELECT cron.schedule(
  'process_interest_expiry_5m',
  '*/5 * * * *',
  $$SELECT private.process_interest_expiry_lifecycle(2000);$$
);

COMMENT ON FUNCTION private.process_interest_expiry_lifecycle(integer) IS
  'Five-minute idempotent reminders and bounded expiry processing without batch starvation.';

NOTIFY pgrst, 'reload schema';
