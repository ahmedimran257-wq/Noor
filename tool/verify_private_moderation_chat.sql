\set ON_ERROR_STOP on
SET ROLE postgres;
BEGIN;

SET LOCAL session_replication_role = replica;
INSERT INTO auth.users(id, email, email_confirmed_at)
VALUES
  ('10000000-0000-0000-0000-000000000001', 'moderation-female@staging.silarah.invalid', now()),
  ('20000000-0000-0000-0000-000000000002', 'moderation-male@staging.silarah.invalid', now());

INSERT INTO public.users(
  id, email, gender, country_code, onboarding_step, onboarding_completed,
  subscription_status, is_banned
)
VALUES
  ('10000000-0000-0000-0000-000000000001', 'moderation-female@staging.silarah.invalid', 'female', 'IN', 5, true, 'none', false),
  ('20000000-0000-0000-0000-000000000002', 'moderation-male@staging.silarah.invalid', 'male', 'IN', 5, true, 'active', false);

INSERT INTO public.profiles(
  id, user_id, first_name, last_name, date_of_birth, gender, country_code,
  visibility, onboarding_step, onboarding_completed, completeness_score
)
VALUES
  ('30000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000001', 'Staging', 'Female', '1998-01-01', 'female', 'IN', 'visible', 14, true, 100),
  ('40000000-0000-0000-0000-000000000004', '20000000-0000-0000-0000-000000000002', 'Staging', 'Male', '1995-01-01', 'male', 'IN', 'visible', 14, true, 100);

INSERT INTO public.matches(id, user_a, user_b, status)
VALUES (
  '50000000-0000-0000-0000-000000000005',
  '10000000-0000-0000-0000-000000000001',
  '20000000-0000-0000-0000-000000000002',
  'active'
);
INSERT INTO public.messages(id, match_id, sender_id, receiver_id, content, status)
VALUES (
  '60000000-0000-0000-0000-000000000006',
  '50000000-0000-0000-0000-000000000005',
  '20000000-0000-0000-0000-000000000002',
  '10000000-0000-0000-0000-000000000001',
  'Existing authorized history',
  'sent'
);
SET LOCAL session_replication_role = origin;

SELECT set_config(
  'request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000001',
  true
);

DO $$
DECLARE decision record;
BEGIN
  SELECT * INTO decision
  FROM public.can_open_chat('50000000-0000-0000-0000-000000000005');
  IF decision.allowed IS DISTINCT FROM true OR decision.reason <> 'allowed' THEN
    RAISE EXCEPTION 'active chat baseline failed: %', decision.reason;
  END IF;
END;
$$;

UPDATE public.users
SET is_banned = true, banned_at = now(), banned_reason = 'staging_contract'
WHERE id = '20000000-0000-0000-0000-000000000002';
UPDATE public.profiles
SET visibility = 'suspended', suspended_reason = 'staging_contract'
WHERE user_id = '20000000-0000-0000-0000-000000000002';

DO $$
DECLARE
  decision record;
  inbox record;
  rejected boolean := false;
BEGIN
  SELECT * INTO decision
  FROM public.can_open_chat('50000000-0000-0000-0000-000000000005');
  IF decision.allowed IS DISTINCT FROM true
    OR decision.reason <> 'member_unavailable_read_only' THEN
    RAISE EXCEPTION 'neutral read-only decision failed: %', decision.reason;
  END IF;

  SELECT * INTO inbox FROM public.get_chat_inbox(50, NULL)
  WHERE match_id = '50000000-0000-0000-0000-000000000005';
  IF inbox.member_unavailable IS DISTINCT FROM true
    OR inbox.other_user_id IS NOT NULL
    OR inbox.other_first_name <> 'Silarah member'
    OR inbox.closure_reason IS NOT NULL
    OR inbox.last_message_content <> 'Existing authorized history' THEN
    RAISE EXCEPTION 'inbox did not neutralize the unavailable member';
  END IF;

  BEGIN
    PERFORM * FROM public.send_chat_message(
      '50000000-0000-0000-0000-000000000005',
      'This must not be sent'
    );
  EXCEPTION WHEN OTHERS THEN
    rejected := SQLERRM IN ('member_unavailable_read_only', 'account_restricted');
    IF NOT rejected THEN RAISE; END IF;
  END;
  IF NOT rejected THEN
    RAISE EXCEPTION 'message write was accepted for unavailable recipient';
  END IF;
END;
$$;

ROLLBACK;
SELECT 'PASS: private moderation chat contract' AS result;
