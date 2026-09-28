BEGIN;
INSERT INTO auth.users(id) VALUES
  ('00000000-0000-4000-8000-000000000001'),
  ('00000000-0000-4000-8000-000000000002');
INSERT INTO public.admin_memberships(user_id, role, status) VALUES
  ('00000000-0000-4000-8000-000000000001', 'support', 'active');
INSERT INTO auth.sessions(id, user_id, created_at) VALUES
  ('00000000-0000-4000-8000-000000000011', '00000000-0000-4000-8000-000000000001', now() - interval '1 hour'),
  ('00000000-0000-4000-8000-000000000012', '00000000-0000-4000-8000-000000000002', now());

SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claim.role = 'authenticated';
SET LOCAL request.jwt.claim.sub = '00000000-0000-4000-8000-000000000001';
SET LOCAL request.jwt.claim.aal = 'aal2';
SET LOCAL request.jwt.claim.session_id = '00000000-0000-4000-8000-000000000011';
SELECT test.assert(public.is_active_admin(), 'fresh MFA staff session allowed');
SELECT test.assert(public.is_active_admin(ARRAY['support']), 'permitted staff role allowed');
SELECT test.assert(NOT public.is_active_admin(ARRAY['super_admin']), 'role escalation denied');
SELECT test.assert(public.assert_admin_session_boundary('00000000-0000-4000-8000-000000000011'), 'own current session accepted');
SELECT test.assert(public.assert_admin_session_boundary('00000000-0000-4000-8000-000000000011'), 'session registration retry succeeds');

RESET ROLE;
SELECT test.assert((SELECT count(*) = 1 FROM private.admin_session_boundaries WHERE session_id = '00000000-0000-4000-8000-000000000011'), 'session registration retry does not duplicate');
UPDATE auth.sessions SET created_at = now() - interval '13 hours'
WHERE id = '00000000-0000-4000-8000-000000000011';
SET LOCAL ROLE authenticated;
SELECT test.assert(NOT public.is_active_admin(), 'direct RPC guard rejects an expired staff session');
SELECT test.assert(NOT public.assert_admin_session_boundary('00000000-0000-4000-8000-000000000011'), 'refresh cannot restart the absolute clock');
SELECT test.assert(NOT public.assert_admin_session_boundary('00000000-0000-4000-8000-000000000099'), 'invented session cannot reset expiry');

RESET ROLE;
UPDATE auth.sessions SET created_at = now() - interval '1 hour'
WHERE id = '00000000-0000-4000-8000-000000000011';
SET LOCAL ROLE authenticated;
SELECT test.assert(NOT public.assert_admin_session_boundary('00000000-0000-4000-8000-000000000012'), 'other session parameter denied');
SELECT test.assert(NOT public.assert_admin_session_boundary(NULL), 'null session parameter denied');
SET LOCAL request.jwt.claim.session_id = '';
SELECT test.assert(public.is_active_admin() IS FALSE, 'missing session fails closed, not NULL');
SET LOCAL request.jwt.claim.session_id = '00000000-0000-4000-8000-000000000099';
SELECT test.assert(public.is_active_admin() IS FALSE, 'unknown session fails closed');
SET LOCAL request.jwt.claim.session_id = '00000000-0000-4000-8000-000000000012';
SELECT test.assert(public.is_active_admin() IS FALSE, 'another users session fails closed');
SET LOCAL request.jwt.claim.session_id = '00000000-0000-4000-8000-000000000011';
SET LOCAL request.jwt.claim.aal = 'aal1';
SELECT test.assert(NOT public.is_active_admin(), 'MFA still required');
SELECT test.assert(public.assert_admin_session_boundary('00000000-0000-4000-8000-000000000011'), 'MFA enrollment remains reachable');
SET LOCAL request.jwt.claim.aal = 'aal2';

RESET ROLE;
UPDATE auth.sessions SET not_after = now() - interval '1 minute'
WHERE id = '00000000-0000-4000-8000-000000000011';
SET LOCAL ROLE authenticated;
SELECT test.assert(NOT public.is_active_admin(), 'Auth not_after deadline respected');
RESET ROLE;
UPDATE auth.sessions SET not_after = NULL, created_at = now() - interval '12 hours'
WHERE id = '00000000-0000-4000-8000-000000000011';
SET LOCAL ROLE authenticated;
SELECT test.assert(NOT public.is_active_admin(), 'exact 12-hour deadline denied');
RESET ROLE;
UPDATE auth.sessions SET created_at = now() - interval '1 hour'
WHERE id = '00000000-0000-4000-8000-000000000011';
UPDATE public.admin_memberships SET status = 'revoked';
SET LOCAL ROLE authenticated;
SELECT test.assert(NOT public.is_active_admin(), 'revoked membership denied');
RESET ROLE;
UPDATE public.admin_memberships SET status = 'active';
DELETE FROM auth.sessions WHERE id = '00000000-0000-4000-8000-000000000011';
SET LOCAL ROLE authenticated;
SELECT test.assert(NOT public.is_active_admin(), 'signed-out Auth session denied despite JWT');
SELECT test.assert(NOT public.assert_admin_session_boundary('00000000-0000-4000-8000-000000000011'), 'signed-out session cannot be re-registered');
SELECT test.reject('SELECT private.admin_session_deadline()', 'permission denied');
RESET ROLE;
SELECT test.assert(NOT has_function_privilege('authenticated', 'private.admin_session_deadline()', 'EXECUTE'), 'private deadline helper not directly exposed');
ROLLBACK;
