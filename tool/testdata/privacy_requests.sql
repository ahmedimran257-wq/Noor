BEGIN;
INSERT INTO auth.users(id) VALUES
 ('00000000-0000-4000-8000-000000000001'),
 ('00000000-0000-4000-8000-000000000002'),
 ('00000000-0000-4000-8000-000000000003');
INSERT INTO public.admin_memberships VALUES ('00000000-0000-4000-8000-000000000003','support','active');
SELECT test.assert(NOT has_function_privilege('anon', 'public.submit_my_privacy_request(uuid,text,text)', 'EXECUTE'), 'anonymous intake denied');
SELECT test.assert(NOT has_table_privilege('authenticated', 'public.privacy_requests', 'INSERT,UPDATE,DELETE'), 'raw member writes denied');
SELECT test.assert(NOT has_table_privilege('authenticated', 'private.privacy_request_events', 'SELECT,INSERT,UPDATE,DELETE'), 'audit trail private');
SET LOCAL ROLE authenticated;
SELECT test.reject($q$SELECT public.submit_my_privacy_request(gen_random_uuid(), 'access', 'Export my information')$q$, 'authentication_required');
SET LOCAL request.jwt.claim.sub = '00000000-0000-4000-8000-000000000001';
SET LOCAL request.jwt.claim.aal = 'aal1';
SELECT test.reject($q$SELECT public.submit_my_privacy_request(gen_random_uuid(), 'invalid', 'Export my information')$q$, 'invalid_privacy_request');
SELECT test.reject($q$SELECT public.submit_my_privacy_request(gen_random_uuid(), 'access', repeat('a',2001))$q$, 'invalid_privacy_request');
SELECT test.reject($q$SELECT public.submit_my_privacy_request(gen_random_uuid(), 'access', 'short')$q$, 'invalid_privacy_request');
SELECT public.submit_my_privacy_request('00000000-0000-4000-8000-000000000010', 'access', 'Export my information') AS request_id \gset
SELECT updated_at AS original_updated FROM public.privacy_requests WHERE id = :'request_id' \gset
SELECT test.assert(public.submit_my_privacy_request('00000000-0000-4000-8000-000000000010', 'access', ' Export my information ') = :'request_id', 'same payload retry preserves reference');
SELECT test.reject($q$SELECT public.submit_my_privacy_request('00000000-0000-4000-8000-000000000010', 'erasure', 'Export my information')$q$, 'request_key_conflict');
SELECT test.assert((SELECT count(*) = 1 FROM public.privacy_requests), 'retry does not duplicate');
SELECT test.reject($q$INSERT INTO public.privacy_requests(request_key,kind,details) VALUES (gen_random_uuid(),'access','Export my information')$q$, 'permission denied');
SELECT test.reject(format('SELECT public.review_privacy_request(%L, %L, %L, now())', :'request_id','resolved','Completed requested action'), 'privacy_staff_required');
SELECT public.submit_my_privacy_request(gen_random_uuid(), 'correction', 'Please correct my information') FROM generate_series(1,4);
SELECT test.reject($q$SELECT public.submit_my_privacy_request(gen_random_uuid(), 'access', 'Export my information')$q$, 'privacy_request_daily_limit');
SELECT test.assert(public.submit_my_privacy_request('00000000-0000-4000-8000-000000000010', 'access', 'Export my information') = :'request_id', 'retry still works at daily limit');
SET LOCAL request.jwt.claim.sub = '00000000-0000-4000-8000-000000000002';
SELECT test.assert((SELECT count(*) = 0 FROM public.privacy_requests), 'second member cannot read first member requests');
SELECT test.assert(public.submit_my_privacy_request('00000000-0000-4000-8000-000000000010', 'access', 'Export my information') <> :'request_id', 'retry keys isolated by member');
SELECT test.assert((SELECT count(*) = 1 FROM public.privacy_requests), 'second member only sees own request');
SET LOCAL request.jwt.claim.sub = '00000000-0000-4000-8000-000000000003';
SELECT test.assert((SELECT count(*) = 0 FROM public.privacy_requests), 'staff without MFA cannot read queue');
SELECT test.reject(format('SELECT public.review_privacy_request(%L, %L, %L, now())', :'request_id','resolved','Completed requested action'), 'privacy_staff_required');
SET LOCAL request.jwt.claim.aal = 'aal2';
SELECT test.assert((SELECT count(*) = 6 FROM public.privacy_requests), 'MFA support can read queue');
SELECT test.reject(format('SELECT public.review_privacy_request(%L, %L, %L, NULL)', :'request_id','reviewing','We are reviewing your request'), 'privacy_request_changed_reload');
SELECT public.review_privacy_request(:'request_id','reviewing','We are reviewing your request',:'original_updated');
SELECT test.reject(format('SELECT public.review_privacy_request(%L, %L, %L, %L)', :'request_id','resolved','Completed requested action',:'original_updated'), 'privacy_request_changed_reload');
SELECT updated_at AS reviewed_updated FROM public.privacy_requests WHERE id = :'request_id' \gset
SELECT public.review_privacy_request(:'request_id','resolved','Completed requested action',:'reviewed_updated');
SELECT public.review_privacy_request(:'request_id','resolved','Completed requested action',:'reviewed_updated');
SELECT updated_at AS resolved_updated FROM public.privacy_requests WHERE id = :'request_id' \gset
SELECT test.reject(format('SELECT public.review_privacy_request(%L, %L, %L, %L)', :'request_id','reviewing','Reopen the resolved request',:'resolved_updated'), 'privacy_request_already_resolved');
RESET ROLE;
SELECT test.assert((SELECT count(*) = 2 FROM private.privacy_request_events WHERE request_id = :'request_id'), 'exact review retry does not duplicate audit events');
UPDATE public.admin_memberships SET status = 'revoked';
SET LOCAL ROLE authenticated;
SELECT test.assert((SELECT count(*) = 0 FROM public.privacy_requests), 'revoked staff loses queue access');
SELECT test.reject(format('SELECT public.review_privacy_request(%L, %L, %L, %L)', :'request_id','resolved','Completed requested action',:'resolved_updated'), 'privacy_staff_required');
RESET ROLE;
UPDATE public.admin_memberships SET status = 'active', role = 'moderator';
SET LOCAL ROLE authenticated;
SELECT test.assert((SELECT count(*) = 0 FROM public.privacy_requests), 'moderator cannot read privacy queue');
SET LOCAL request.jwt.claim.sub = '00000000-0000-4000-8000-000000000001';
SELECT test.assert((SELECT response = 'Completed requested action' FROM public.privacy_requests WHERE id = :'request_id'), 'member sees staff response');
RESET ROLE;
DELETE FROM auth.users WHERE id = '00000000-0000-4000-8000-000000000001';
SELECT test.assert((SELECT user_id IS NULL FROM public.privacy_requests WHERE id = :'request_id'), 'account erasure detaches requester without blocking deletion');
ROLLBACK;
