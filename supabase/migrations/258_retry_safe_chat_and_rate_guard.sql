-- Additive: old installed clients keep their existing RPCs. New clients reuse
-- an operation UUID after an uncertain network outcome; a retry never sends twice.
CREATE TABLE private.chat_send_receipts (
  actor_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  operation_id uuid NOT NULL,
  match_id uuid NOT NULL REFERENCES public.matches(id) ON DELETE CASCADE,
  content_hash bytea NOT NULL,
  as_guardian boolean NOT NULL,
  message_id uuid NOT NULL REFERENCES public.messages(id) ON DELETE CASCADE,
  PRIMARY KEY (actor_id, operation_id)
);
REVOKE ALL ON private.chat_send_receipts FROM PUBLIC, anon, authenticated;
CREATE INDEX chat_send_receipts_message_idx ON private.chat_send_receipts(message_id);
CREATE INDEX chat_send_receipts_match_idx ON private.chat_send_receipts(match_id);

CREATE OR REPLACE FUNCTION private.guard_chat_send_rate()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  IF auth.uid() IS NOT NULL THEN
    -- Actor-bound, atomic, all conversations combined; applies to old clients
    -- and guardian sends too. Server maintenance is not a user send.
    PERFORM private.enforce_member_feature_rate_limit('chat_send', auth.uid(), 60, 60);
  END IF;
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION private.guard_chat_send_rate() FROM PUBLIC, anon, authenticated;
CREATE TRIGGER guard_chat_send_rate BEFORE INSERT ON public.messages
FOR EACH ROW EXECUTE FUNCTION private.guard_chat_send_rate();

CREATE OR REPLACE FUNCTION public.send_chat_message_idempotent(
  p_match_id uuid,
  p_content text,
  p_operation_id uuid,
  p_as_guardian boolean DEFAULT false
)
RETURNS TABLE(message_id uuid, created_at timestamptz, safety_status text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_actor uuid := private.assert_authenticated();
  v_receipt private.chat_send_receipts%ROWTYPE;
  v_message public.messages%ROWTYPE;
  v_id uuid;
  v_hash bytea;
BEGIN
  PERFORM private.assert_active_member(v_actor, false);
  IF p_operation_id IS NULL OR p_match_id IS NULL OR p_as_guardian IS NULL
     OR char_length(trim(coalesce(p_content, ''))) NOT BETWEEN 1 AND 4000 THEN
    RAISE EXCEPTION 'invalid_message_request' USING ERRCODE = '22023';
  END IF;
  PERFORM private.enforce_member_feature_rate_limit('chat_send_request', v_actor, 120, 60);
  v_hash := pg_catalog.sha256(pg_catalog.convert_to(p_content, 'UTF8'));
  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('chat-send:' || v_actor::text || ':' || p_operation_id::text, 0)
  );
  SELECT r.* INTO v_receipt FROM private.chat_send_receipts r
  WHERE r.actor_id = v_actor AND r.operation_id = p_operation_id;
  IF FOUND THEN
    IF v_receipt.match_id <> p_match_id OR v_receipt.content_hash <> v_hash
       OR v_receipt.as_guardian <> p_as_guardian THEN
      RAISE EXCEPTION 'message_request_conflict' USING ERRCODE = '22023';
    END IF;
    -- Return only the original acknowledgement, never resend or disclose text.
    SELECT m.* INTO STRICT v_message FROM public.messages m WHERE m.id = v_receipt.message_id;
  ELSE
    IF p_as_guardian THEN
      v_id := public.send_guardian_chat_message(p_match_id, p_content);
    ELSE
      SELECT sent.message_id INTO v_id FROM public.send_chat_message(p_match_id, p_content) sent;
    END IF;
    SELECT m.* INTO STRICT v_message FROM public.messages m WHERE m.id = v_id;
    INSERT INTO private.chat_send_receipts(actor_id, operation_id, match_id, content_hash, as_guardian, message_id)
    VALUES (v_actor, p_operation_id, p_match_id, v_hash, p_as_guardian, v_message.id);
  END IF;
  RETURN QUERY SELECT v_message.id, v_message.created_at, v_message.safety_status::text;
END;
$$;
REVOKE ALL ON FUNCTION public.send_chat_message_idempotent(uuid, text, uuid, boolean)
FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.send_chat_message_idempotent(uuid, text, uuid, boolean)
TO authenticated;
