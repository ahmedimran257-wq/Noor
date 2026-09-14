-- Keep message notifications aligned with the chat lifecycle. A notification
-- can outlive its match when an account is purged or a member privately hides
-- a conversation; those rows must not keep routing to an inaccessible UUID.

CREATE OR REPLACE FUNCTION private.neutralize_chat_notifications(
  p_match_id uuid,
  p_user_id uuid
)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path = ''
AS $$
  UPDATE public.notifications n
  SET title = 'Conversation unavailable',
      body = 'This conversation is no longer available.',
      deep_link = 'silarah://chat',
      read_at = coalesce(n.read_at, now()),
      sent_at = coalesce(n.sent_at, now()),
      delivery_status = CASE
        WHEN n.sent_at IS NULL THEN 'in_app_only'
        ELSE n.delivery_status
      END,
      processing_at = NULL,
      lease_token = NULL,
      last_error_code = CASE
        WHEN n.sent_at IS NULL THEN 'match_unavailable_before_delivery'
        ELSE n.last_error_code
      END
  WHERE n.user_id = p_user_id
    AND n.type = 'new_message'
    AND n.deep_link IN (
      '/chat/' || p_match_id::text,
      'silarah://chat/' || p_match_id::text,
      'mithaq://chat/' || p_match_id::text
    );
$$;

REVOKE ALL ON FUNCTION private.neutralize_chat_notifications(uuid, uuid)
  FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION private.sync_chat_notification_lifecycle()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    PERFORM private.neutralize_chat_notifications(OLD.id, OLD.user_a);
    PERFORM private.neutralize_chat_notifications(OLD.id, OLD.user_b);
    RETURN OLD;
  END IF;

  IF NEW.hidden_by_a_at IS NOT NULL
    AND OLD.hidden_by_a_at IS DISTINCT FROM NEW.hidden_by_a_at THEN
    PERFORM private.neutralize_chat_notifications(NEW.id, NEW.user_a);
  END IF;
  IF NEW.hidden_by_b_at IS NOT NULL
    AND OLD.hidden_by_b_at IS DISTINCT FROM NEW.hidden_by_b_at THEN
    PERFORM private.neutralize_chat_notifications(NEW.id, NEW.user_b);
  END IF;
  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION private.sync_chat_notification_lifecycle()
  FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_sync_chat_notification_lifecycle
  ON public.matches;
CREATE TRIGGER trg_sync_chat_notification_lifecycle
AFTER UPDATE OF hidden_by_a_at, hidden_by_b_at OR DELETE
ON public.matches
FOR EACH ROW
EXECUTE FUNCTION private.sync_chat_notification_lifecycle();

-- Repair historical rows, including the stale production notification that
-- exposed this issue. Already-delivered device payloads are handled by the
-- app's explicit not-found route; the in-app copy now returns to Messages.
UPDATE public.notifications n
SET title = 'Conversation unavailable',
    body = 'This conversation is no longer available.',
    deep_link = 'silarah://chat',
    read_at = coalesce(n.read_at, now()),
    sent_at = coalesce(n.sent_at, now()),
    delivery_status = CASE
      WHEN n.sent_at IS NULL THEN 'in_app_only'
      ELSE n.delivery_status
    END,
    processing_at = NULL,
    lease_token = NULL,
    last_error_code = CASE
      WHEN n.sent_at IS NULL THEN 'match_unavailable_before_delivery'
      ELSE n.last_error_code
    END
WHERE n.type = 'new_message'
  AND (
    n.deep_link LIKE '/chat/%'
    OR n.deep_link LIKE 'silarah://chat/%'
    OR n.deep_link LIKE 'mithaq://chat/%'
  )
  AND NOT EXISTS (
    SELECT 1
    FROM public.matches m
    WHERE n.deep_link IN (
      '/chat/' || m.id::text,
      'silarah://chat/' || m.id::text,
      'mithaq://chat/' || m.id::text
    )
  );
