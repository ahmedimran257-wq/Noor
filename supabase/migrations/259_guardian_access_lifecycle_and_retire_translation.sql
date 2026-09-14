-- Durable, content-free invalidation: one row per Guardian, not polling or
-- one new connection per conversation. Revoked Guardians can read only their
-- own revision, never a ward's profile or message through this table.
CREATE TABLE public.guardian_access_state (
  guardian_id uuid PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
  revision bigint NOT NULL DEFAULT 1
);
ALTER TABLE public.guardian_access_state ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.guardian_access_state FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.guardian_access_state TO authenticated;
CREATE POLICY guardian_access_state_self ON public.guardian_access_state
  FOR SELECT TO authenticated USING (guardian_id = (SELECT auth.uid()));
ALTER PUBLICATION supabase_realtime ADD TABLE public.guardian_access_state;

CREATE FUNCTION private.invalidate_guardian_access()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_id uuid;
BEGIN
  FOR v_id IN
    SELECT DISTINCT id FROM unnest(ARRAY[OLD.guardian_user_id, NEW.guardian_user_id]) id
    WHERE id IS NOT NULL
  LOOP
    INSERT INTO public.guardian_access_state(guardian_id)
      SELECT id FROM public.users WHERE id = v_id
      ON CONFLICT (guardian_id) DO UPDATE
        SET revision = public.guardian_access_state.revision + 1;
  END LOOP;
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION private.invalidate_guardian_access() FROM PUBLIC, anon, authenticated;
CREATE TRIGGER guardian_access_invalidated
  AFTER UPDATE OF guardian_user_id, guardian_mode ON public.profiles
  FOR EACH ROW WHEN (
    OLD.guardian_user_id IS DISTINCT FROM NEW.guardian_user_id OR
    OLD.guardian_mode IS DISTINCT FROM NEW.guardian_mode
  ) EXECUTE FUNCTION private.invalidate_guardian_access();
INSERT INTO public.guardian_access_state(guardian_id)
  SELECT DISTINCT guardian_user_id FROM public.profiles
  WHERE guardian_user_id IS NOT NULL ON CONFLICT DO NOTHING;

CREATE FUNCTION public.has_my_linked_wards()
RETURNS boolean LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_id uuid := private.assert_authenticated();
BEGIN
  PERFORM private.assert_active_member(v_id, false);
  RETURN EXISTS(SELECT 1 FROM public.profiles
    WHERE guardian_user_id = v_id AND guardian_mode IN ('active','passive'));
END;
$$;
REVOKE ALL ON FUNCTION public.has_my_linked_wards() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.has_my_linked_wards() TO authenticated;

-- Suppress only the actual sender's mirror alert. The other party's Guardian
-- still receives the message; normal ward messages still notify their Guardian.
CREATE OR REPLACE FUNCTION public.mirror_messages_to_guardian()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_ward_id uuid; v_guardian_user_id uuid; v_guardian_mode text; v_other_name text;
BEGIN
  FOR v_ward_id, v_guardian_user_id, v_guardian_mode IN
    SELECT p.user_id, p.guardian_user_id, p.guardian_mode FROM public.profiles p
    WHERE p.user_id IN (NEW.sender_id, NEW.receiver_id)
      AND p.guardian_mode IN ('passive','active') AND p.guardian_user_id IS NOT NULL
  LOOP
    INSERT INTO public.guardian_chat_mirrors(match_id, guardian_id, ward_id, mode)
      VALUES (NEW.match_id, v_guardian_user_id, v_ward_id, v_guardian_mode)
      ON CONFLICT (match_id, guardian_id) DO NOTHING;
    IF v_guardian_user_id = auth.uid() THEN CONTINUE; END IF;
    SELECT p.first_name INTO v_other_name FROM public.profiles p
      WHERE p.user_id = CASE WHEN NEW.sender_id = v_ward_id THEN NEW.receiver_id ELSE NEW.sender_id END;
    PERFORM public.queue_notification(v_guardian_user_id, 'guardian_message_mirror',
      CASE WHEN NEW.sender_id = v_ward_id THEN 'Your ward sent a message'
        ELSE format('New message from %s', coalesce(v_other_name, 'someone')) END,
      'Open Silarah to review the conversation.',
      format('silarah://chat/%s', NEW.match_id));
  END LOOP;
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.mirror_messages_to_guardian() FROM PUBLIC, anon, authenticated;

-- Keep schema compatibility for installed clients, but stop all cache writes.
-- Original messages are preserved. Only derived translation caches are erased.
REVOKE ALL ON FUNCTION public.store_message_translation(uuid,text,text)
  FROM PUBLIC, anon, authenticated, service_role;
UPDATE public.messages SET translations = '{}'::jsonb
  WHERE translations IS NOT NULL AND translations <> '{}'::jsonb;
