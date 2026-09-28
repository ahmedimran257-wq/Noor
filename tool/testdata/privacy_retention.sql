BEGIN;
INSERT INTO auth.users(id) VALUES ('00000000-0000-4000-8000-000000000003');
INSERT INTO public.admin_memberships VALUES ('00000000-0000-4000-8000-000000000003','support','active');
INSERT INTO auth.sessions(id, user_id, created_at) VALUES
 ('00000000-0000-4000-8000-000000000013','00000000-0000-4000-8000-000000000003',now());
INSERT INTO public.privacy_requests(id, request_key, kind, details, status, resolved_at)
VALUES
 ('00000000-0000-4000-8000-000000000101',gen_random_uuid(),'access','Synthetic old resolved request','resolved',now()-interval '13 months'),
 ('00000000-0000-4000-8000-000000000102',gen_random_uuid(),'access','Synthetic held resolved request','resolved',now()-interval '13 months'),
 ('00000000-0000-4000-8000-000000000103',gen_random_uuid(),'access','Synthetic recent resolved request','resolved',now()-interval '11 months'),
 ('00000000-0000-4000-8000-000000000104',gen_random_uuid(),'access','Synthetic unresolved request','received',NULL);
SELECT test.assert(NOT has_function_privilege('authenticated','private.purge_expired_privacy_requests()','EXECUTE'), 'members cannot run retention purge');
SET LOCAL request.jwt.claim.sub = '00000000-0000-4000-8000-000000000003';
SET LOCAL request.jwt.claim.aal = 'aal2';
SET LOCAL request.jwt.claim.session_id = '00000000-0000-4000-8000-000000000013';
SET LOCAL ROLE authenticated;
SELECT test.reject($q$SELECT public.set_privacy_request_hold('00000000-0000-4000-8000-000000000102', now()+interval '7 days','Synthetic legal hold reference')$q$, 'privacy_super_admin_required');
RESET ROLE;
UPDATE public.admin_memberships SET role='super_admin' WHERE user_id = '00000000-0000-4000-8000-000000000003';
SET LOCAL ROLE authenticated;
SELECT test.reject($q$SELECT public.set_privacy_request_hold('00000000-0000-4000-8000-000000000102', now()+interval '2 years','Synthetic legal hold reference')$q$, 'invalid_privacy_hold');
SELECT test.reject($q$SELECT public.set_privacy_request_hold('00000000-0000-4000-8000-000000000102', now()+interval '7 days','short')$q$, 'invalid_privacy_hold');
SELECT public.set_privacy_request_hold('00000000-0000-4000-8000-000000000102', now()+interval '7 days','Synthetic legal hold reference');
SELECT public.set_privacy_request_hold('00000000-0000-4000-8000-000000000102', now()+interval '7 days','Synthetic legal hold reference');
SELECT test.assert((SELECT count(*)=1 FROM public.get_privacy_request_holds(ARRAY['00000000-0000-4000-8000-000000000102']::uuid[])), 'super admin can retrieve documented hold');
SET LOCAL request.jwt.claim.aal = 'aal1';
SELECT test.reject($q$SELECT * FROM public.get_privacy_request_holds(ARRAY['00000000-0000-4000-8000-000000000102']::uuid[])$q$, 'privacy_super_admin_required');
RESET ROLE;
SELECT test.assert((SELECT count(*)=1 FROM private.privacy_retention_events), 'hold retry audit is idempotent');
SELECT test.assert(private.purge_expired_privacy_requests() = 1, 'purge removes only expired unheld case');
SELECT test.assert((SELECT count(*)=3 FROM public.privacy_requests), 'held, recent, and unresolved cases retained');
SELECT test.assert(private.purge_expired_privacy_requests() = 0, 'purge repeat safe');
SET LOCAL request.jwt.claim.aal = 'aal2';
SET LOCAL ROLE authenticated;
SELECT public.set_privacy_request_hold('00000000-0000-4000-8000-000000000102', NULL,'Synthetic hold release reference');
RESET ROLE;
SELECT test.assert(private.purge_expired_privacy_requests() = 1, 'released expired hold permits deletion');
SELECT test.assert((SELECT count(*)=0 FROM private.privacy_retention_events), 'expired case audit contains no lingering free text');
ROLLBACK;
