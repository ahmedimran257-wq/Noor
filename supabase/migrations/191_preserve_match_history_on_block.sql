-- Blocking is a privacy boundary, not a rewrite of historical relationship
-- evidence. Only an active match is closed as blocked; already closed/expired
-- cycles retain their original closer, timestamp and reason.
CREATE OR REPLACE FUNCTION public.sever_ties_on_block()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  UPDATE public.matches
  SET status = 'blocked',
      closed_by = NEW.blocker_id,
      closed_at = now(),
      closure_reason = 'user_blocked'
  WHERE (
      (user_a = NEW.blocker_id AND user_b = NEW.blocked_id)
      OR (user_b = NEW.blocker_id AND user_a = NEW.blocked_id)
    )
    AND status = 'active';

  DELETE FROM public.interests
  WHERE status = 'pending'
    AND (
      (sender_id = NEW.blocker_id AND receiver_id = NEW.blocked_id)
      OR (sender_id = NEW.blocked_id AND receiver_id = NEW.blocker_id)
    );
  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.sever_ties_on_block() FROM PUBLIC;

COMMENT ON FUNCTION public.sever_ties_on_block() IS
  'Closes only an active relationship when blocked, retains prior match cycles, and removes pending interests.';
