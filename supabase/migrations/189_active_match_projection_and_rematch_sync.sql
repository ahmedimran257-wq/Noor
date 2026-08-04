-- A closed match is relationship history, not an active match. Keep history in
-- the chat inbox and card context while exposing only active rows to the client
-- projection that drives Discovery's Open Chat state.
CREATE OR REPLACE FUNCTION public.get_my_matches(
  p_limit integer DEFAULT 100
)
RETURNS TABLE (
  id uuid,
  user_a uuid,
  user_b uuid,
  status text,
  created_at timestamptz
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT
    m.id,
    m.user_a,
    m.user_b,
    m.status::text,
    m.created_at
  FROM public.matches m
  WHERE auth.uid() IS NOT NULL
    AND (m.user_a = auth.uid() OR m.user_b = auth.uid())
    AND m.status = 'active'
  ORDER BY m.created_at DESC, m.id DESC
  LIMIT greatest(1, least(coalesce(p_limit, 100), 100));
$$;

REVOKE ALL ON FUNCTION public.get_my_matches(integer)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_matches(integer)
  TO authenticated;

COMMENT ON FUNCTION public.get_my_matches(integer) IS
  'Authenticated participant projection of active matches only. Closed history is served by the chat inbox and Discovery card-context RPC.';

-- Cooldown cards stay in the already-loaded feed. The app schedules one local
-- timer at the next visible countdown boundary, so expiry must not invalidate,
-- reload and re-sign the complete feed.
CREATE OR REPLACE FUNCTION private.discovery_rematch_cooldown_token(
  p_user_id uuid
)
RETURNS text
LANGUAGE sql
IMMUTABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT 'client_clock'::text;
$$;

REVOKE ALL ON FUNCTION private.discovery_rematch_cooldown_token(uuid)
  FROM PUBLIC;

COMMENT ON FUNCTION private.discovery_rematch_cooldown_token(uuid) IS
  'Stable revision component: rematch countdown expiry is derived locally from server-issued rematch_available_at.';

-- Notify the other participant about an explicit respectful closure. This is
-- separate from the final chat message so an open/backgrounded client can
-- reconcile its active-match projection and Discovery cooldown immediately.
CREATE OR REPLACE FUNCTION private.queue_match_ended_notification()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_recipient uuid;
BEGIN
  IF OLD.status = 'active'
    AND NEW.status = 'closed'
    AND NEW.closed_by IS NOT NULL THEN
    v_recipient := CASE
      WHEN NEW.closed_by = NEW.user_a THEN NEW.user_b
      ELSE NEW.user_a
    END;

    BEGIN
      PERFORM public.queue_notification(
        v_recipient,
        'match_ended',
        'Match ended',
        'Your match was respectfully closed. You can reconnect after the 7-day cooling-off period.',
        '/home?tab=0'
      );
    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING 'Match % closed without notification enqueue: %',
        NEW.id, SQLERRM;
    END;
  END IF;
  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION private.queue_match_ended_notification()
  FROM PUBLIC;

DROP TRIGGER IF EXISTS trg_queue_match_ended_notification ON public.matches;
CREATE TRIGGER trg_queue_match_ended_notification
  AFTER UPDATE OF status, closed_by ON public.matches
  FOR EACH ROW
  EXECUTE FUNCTION private.queue_match_ended_notification();
