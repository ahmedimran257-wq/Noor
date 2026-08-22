-- A respectful closure message and the match transition are one operation.
-- The operation key makes a lost client response safe to retry without
-- duplicating the farewell message.
CREATE TABLE IF NOT EXISTS private.match_closure_operations (
  operation_id uuid PRIMARY KEY,
  match_id uuid NOT NULL REFERENCES public.matches(id) ON DELETE CASCADE,
  actor_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  message_id uuid NOT NULL REFERENCES public.messages(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (match_id, actor_id)
);

REVOKE ALL ON private.match_closure_operations
  FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.send_and_close_match(
  p_match_id uuid,
  p_closure_reason text,
  p_operation_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_me uuid := private.assert_authenticated();
  v_message_id uuid;
  v_existing private.match_closure_operations%ROWTYPE;
BEGIN
  IF p_operation_id IS NULL THEN
    RAISE EXCEPTION 'operation_id_required' USING ERRCODE = 'P0001';
  END IF;

  SELECT * INTO v_existing
  FROM private.match_closure_operations operation
  WHERE operation.operation_id = p_operation_id;
  IF FOUND THEN
    IF v_existing.actor_id <> v_me OR v_existing.match_id <> p_match_id THEN
      RAISE EXCEPTION 'operation_id_conflict' USING ERRCODE = 'P0001';
    END IF;
    RETURN jsonb_build_object(
      'closed', true,
      'message_id', v_existing.message_id,
      'replayed', true
    );
  END IF;

  SELECT result.message_id INTO v_message_id
  FROM public.send_chat_message(p_match_id, p_closure_reason) result;

  PERFORM public.close_chat_match(p_match_id, p_closure_reason);

  INSERT INTO private.match_closure_operations(
    operation_id, match_id, actor_id, message_id
  ) VALUES (p_operation_id, p_match_id, v_me, v_message_id);

  RETURN jsonb_build_object(
    'closed', true,
    'message_id', v_message_id,
    'replayed', false
  );
END;
$$;

REVOKE ALL ON FUNCTION public.send_and_close_match(uuid, text, uuid)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.send_and_close_match(uuid, text, uuid)
  TO authenticated;

NOTIFY pgrst, 'reload schema';
