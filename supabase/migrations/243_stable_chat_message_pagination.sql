-- Timestamp-only cursors can skip messages created in the same database
-- clock tick. Use the existing (match_id, created_at DESC, id DESC) index and
-- a composite cursor for lossless, bounded pagination.
CREATE OR REPLACE FUNCTION public.get_chat_messages_v2(
  p_match_id uuid,
  p_limit integer DEFAULT 50,
  p_before_created_at timestamptz DEFAULT NULL,
  p_before_id uuid DEFAULT NULL
)
RETURNS TABLE (
  id uuid,
  sender_id uuid,
  receiver_id uuid,
  content text,
  created_at timestamptz,
  read_at timestamptz,
  delivered_at timestamptz,
  status text,
  sent_by_guardian boolean,
  translations jsonb
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_me uuid := private.assert_authenticated();
  v_access record;
BEGIN
  IF (p_before_created_at IS NULL) <> (p_before_id IS NULL) THEN
    RAISE EXCEPTION 'complete_message_cursor_required'
      USING ERRCODE = '22023';
  END IF;

  SELECT * INTO v_access FROM public.can_open_chat(p_match_id);
  IF v_access.allowed IS DISTINCT FROM true THEN
    RAISE EXCEPTION '%', coalesce(v_access.reason, 'chat_unavailable')
      USING ERRCODE = 'P0001';
  END IF;

  UPDATE public.messages msg
  SET delivered_at = coalesce(msg.delivered_at, now()),
      status = CASE WHEN msg.status = 'sent' THEN 'delivered' ELSE msg.status END
  WHERE msg.match_id = p_match_id
    AND msg.receiver_id = v_me
    AND msg.delivered_at IS NULL;

  RETURN QUERY
  SELECT page.*
  FROM (
    SELECT
      msg.id,
      msg.sender_id,
      msg.receiver_id,
      msg.content,
      msg.created_at,
      msg.read_at,
      msg.delivered_at,
      msg.status::text,
      coalesce(msg.sent_by_guardian, false),
      coalesce(msg.translations, '{}'::jsonb)
    FROM public.messages msg
    WHERE msg.match_id = p_match_id
      AND (
        p_before_created_at IS NULL
        OR (msg.created_at, msg.id) < (p_before_created_at, p_before_id)
      )
    ORDER BY msg.created_at DESC, msg.id DESC
    LIMIT greatest(1, least(coalesce(p_limit, 50), 100))
  ) page
  ORDER BY page.created_at ASC, page.id ASC;
END;
$$;

REVOKE ALL ON FUNCTION public.get_chat_messages_v2(
  uuid, integer, timestamptz, uuid
) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_chat_messages_v2(
  uuid, integer, timestamptz, uuid
) TO authenticated;

COMMENT ON FUNCTION public.get_chat_messages_v2(
  uuid, integer, timestamptz, uuid
) IS 'Entitlement-checked, stable composite-cursor chat history pagination.';

NOTIFY pgrst, 'reload schema';
