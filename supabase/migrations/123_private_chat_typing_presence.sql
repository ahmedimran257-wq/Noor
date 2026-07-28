-- Private, participant-only Realtime broadcast authorization for chat typing.
-- Typing events are ephemeral and never stored in application tables.

CREATE OR REPLACE FUNCTION public.can_access_chat_realtime_topic(
  p_topic text,
  p_user_id uuid DEFAULT auth.uid()
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT p_user_id IS NOT NULL AND EXISTS (
    SELECT 1
    FROM public.matches m
    WHERE p_topic = 'chat:' || m.id::text
      AND (m.user_a = p_user_id OR m.user_b = p_user_id)
      AND coalesce(m.status, 'active') = 'active'
  );
$$;

REVOKE ALL ON FUNCTION public.can_access_chat_realtime_topic(text, uuid)
  FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.can_access_chat_realtime_topic(text, uuid)
  TO authenticated;

-- Hosted projects permit tenant policies on this managed table. Some local
-- Supabase images retain ownership under the Realtime service role and reject
-- tenant DDL. Keep clean-database migrations portable while failing closed:
-- private broadcasts remain unavailable locally if the managed relation cannot
-- accept the participant policies.
DO $$
BEGIN
  BEGIN
    ALTER TABLE realtime.messages ENABLE ROW LEVEL SECURITY;

    DROP POLICY IF EXISTS "chat participants can receive typing broadcasts"
      ON realtime.messages;
    CREATE POLICY "chat participants can receive typing broadcasts"
      ON realtime.messages
      FOR SELECT
      TO authenticated
      USING (
        realtime.messages.extension = 'broadcast'
        AND public.can_access_chat_realtime_topic(
          (SELECT realtime.topic()),
          (SELECT auth.uid())
        )
      );

    DROP POLICY IF EXISTS "chat participants can send typing broadcasts"
      ON realtime.messages;
    CREATE POLICY "chat participants can send typing broadcasts"
      ON realtime.messages
      FOR INSERT
      TO authenticated
      WITH CHECK (
        realtime.messages.extension = 'broadcast'
        AND public.can_access_chat_realtime_topic(
          (SELECT realtime.topic()),
          (SELECT auth.uid())
        )
      );
  EXCEPTION
    WHEN insufficient_privilege THEN
      RAISE NOTICE
        'Managed realtime.messages ownership prevented local policy install';
  END;
END;
$$;

COMMENT ON FUNCTION public.can_access_chat_realtime_topic(text, uuid) IS
  'Authorizes active match participants for private chat Realtime topics.';
