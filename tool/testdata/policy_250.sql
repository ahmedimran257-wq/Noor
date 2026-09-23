-- Rollback-only STAGING/disposable PostgreSQL test. Run as database owner with
-- test.assert(boolean,text)/test.reject(text,text) already installed.
-- No CLI commands, network calls, credentials, emails or real account fixtures.
-- Uses temporary deferral of the user_consents -> users FK to construct the
-- otherwise unreachable first-provisioning mixed-version fixture. This takes a
-- table DDL lock until ROLLBACK; run on staging, never on a busy production DB.
BEGIN;
SET LOCAL lock_timeout = '3s';
SET LOCAL statement_timeout = '30s';
SET LOCAL request.headers = '{"x-forwarded-for":"198.51.100.250","user-agent":"policy-250-rollback-test"}';
SET LOCAL request.jwt.claim.role = 'authenticated';
INSERT INTO auth.users(id,email,email_confirmed_at) VALUES
 ('25000000-0000-4000-8000-000000000001','policy250-old@example.invalid',now()),
 ('25000000-0000-4000-8000-000000000002','policy250-new@example.invalid',now()),
 ('25000000-0000-4000-8000-000000000003','policy250-mixed@example.invalid',now()),
 ('25000000-0000-4000-8000-000000000004','policy250-unverified@example.invalid',null);
CREATE TEMP TABLE policy_250_transactions(label text PRIMARY KEY,id uuid);
GRANT SELECT,INSERT ON policy_250_transactions TO anon,authenticated;
SELECT test.assert(NOT has_function_privilege('anon','public.finalize_signup_consents(uuid)','EXECUTE'), 'anonymous finalization denied');
SELECT test.assert(NOT has_function_privilege('anon','public.acknowledge_policy_reminder(text)','EXECUTE'), 'anonymous acknowledgement denied');
SET LOCAL ROLE anon;
SELECT test.reject($q$SELECT public.begin_signup_consent_transaction('2.5.0',NULL)$q$, 'required_consent_missing');
SELECT test.reject($q$SELECT public.begin_signup_consent_transaction('2.5.0','null')$q$, 'required_consent_missing');
SELECT test.reject($q$SELECT public.begin_signup_consent_transaction('2.5.0','[]')$q$, 'required_consent_missing');
SELECT test.reject($q$SELECT public.begin_signup_consent_transaction('2.5.0','{"a":true,"b":true,"c":true,"d":true,"e":true}')$q$, 'required_consent_missing');
SELECT test.reject($q$SELECT public.begin_signup_consent_transaction('2.5.0','{"terms_of_service":true,"privacy_policy":null,"community_guidelines":true,"age_verification":true,"special_category_religious":true}')$q$, 'required_consent_missing');
SELECT test.reject($q$SELECT public.begin_signup_consent_transaction('2.5.0','{"terms_of_service":true,"privacy_policy":"true","community_guidelines":true,"age_verification":true,"special_category_religious":true}')$q$, 'required_consent_missing');
SELECT test.reject($q$SELECT public.begin_signup_consent_transaction('2.5.0','{"terms_of_service":true,"privacy_policy":false,"community_guidelines":true,"age_verification":true,"special_category_religious":true}')$q$, 'required_consent_missing');
SELECT test.reject($q$SELECT public.begin_signup_consent_transaction('2.5.0','{"terms_of_service":true,"community_guidelines":true,"age_verification":true,"special_category_religious":true}')$q$, 'required_consent_missing');
SELECT test.reject($q$SELECT public.begin_signup_consent_transaction('2.5.0','{"terms_of_service":true,"privacy_policy":true,"community_guidelines":true,"age_verification":true,"special_category_religious":true,"extra":true}')$q$, 'required_consent_missing');
SELECT test.reject($q$SELECT public.begin_signup_consent_transaction('2.3.0','{}')$q$, 'invalid_consent_transaction');
SELECT test.reject($q$SELECT public.begin_signup_consent_transaction(NULL,'{}')$q$, 'invalid_consent_transaction');
INSERT INTO pg_temp.policy_250_transactions SELECT 'old',public.begin_signup_consent_transaction('2.4.0',
 '{"terms_of_service":true,"privacy_policy":true,"community_guidelines":true,"age_verification":true,"special_category_religious":true}');
INSERT INTO pg_temp.policy_250_transactions SELECT 'new',public.begin_signup_consent_transaction('2.5.0',
 '{"terms_of_service":true,"privacy_policy":true,"community_guidelines":true,"age_verification":true,"special_category_religious":true}');
SELECT test.assert(public.bind_signup_consent_transaction((SELECT id FROM pg_temp.policy_250_transactions WHERE label='old'),'policy250-old@example.invalid'),'old transaction bound');
SELECT test.assert(public.bind_signup_consent_transaction((SELECT id FROM pg_temp.policy_250_transactions WHERE label='new'),'policy250-new@example.invalid'),'new transaction bound');
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claim.sub = '25000000-0000-4000-8000-000000000004';
SELECT test.reject($q$SELECT public.finalize_signup_and_provision_my_user((SELECT id FROM pg_temp.policy_250_transactions WHERE label='new'))$q$,'verified_signup_identity_required');
SET LOCAL request.jwt.claim.sub = '25000000-0000-4000-8000-000000000002';
SELECT test.reject($q$SELECT public.finalize_signup_and_provision_my_user((SELECT id FROM pg_temp.policy_250_transactions WHERE label='old'))$q$,'signup_consent_transaction_unavailable');
SELECT public.finalize_signup_and_provision_my_user((SELECT id FROM pg_temp.policy_250_transactions WHERE label='new'));
SET LOCAL request.jwt.claim.sub = '25000000-0000-4000-8000-000000000001';
SELECT public.finalize_signup_and_provision_my_user((SELECT id FROM pg_temp.policy_250_transactions WHERE label='old'));
SELECT test.assert((SELECT policy_version='2.5.0' AND reminder_due FROM public.get_my_policy_reminder_state()),'old consent does not acknowledge current 2.5 notice');
SELECT public.acknowledge_policy_reminder('2.4.0');
SELECT test.assert((SELECT reminder_due FROM public.get_my_policy_reminder_state()),'old sheet can close without falsely acknowledging 2.5');
RESET ROLE;
SELECT test.assert((SELECT count(*)=5 AND bool_and(version='2.4.0') FROM public.user_consents WHERE user_id='25000000-0000-4000-8000-000000000001'),'old evidence stays 2.4');
SELECT test.assert((SELECT count(*)=5 AND bool_and(version='2.5.0') FROM public.user_consents WHERE user_id='25000000-0000-4000-8000-000000000002'),'new evidence is 2.5');
SELECT test.assert((SELECT bool_and(policy_digest=encode(extensions.digest(convert_to('silarah-launch-policy:'||version||':terms|privacy|community|age|religious','UTF8'),'sha256'),'hex')) FROM public.user_consents WHERE user_id IN ('25000000-0000-4000-8000-000000000001','25000000-0000-4000-8000-000000000002')),'digests follow actual consent version');
CREATE TEMP TABLE policy_250_evidence AS SELECT * FROM public.user_consents WHERE user_id='25000000-0000-4000-8000-000000000001';
UPDATE public.user_consents SET revoked_at=now() WHERE user_id='25000000-0000-4000-8000-000000000001' AND consent_type='privacy_policy';
SET LOCAL ROLE authenticated;
SELECT public.finalize_signup_and_provision_my_user((SELECT id FROM pg_temp.policy_250_transactions WHERE label='old'));
INSERT INTO pg_temp.policy_250_transactions SELECT 'old-reaccept',public.begin_signup_consent_transaction('2.4.0',
 '{"terms_of_service":true,"privacy_policy":true,"community_guidelines":true,"age_verification":true,"special_category_religious":true}');
SELECT public.bind_signup_consent_transaction((SELECT id FROM pg_temp.policy_250_transactions WHERE label='old-reaccept'),'policy250-old@example.invalid');
SELECT public.finalize_signup_consents((SELECT id FROM pg_temp.policy_250_transactions WHERE label='old-reaccept'));
RESET ROLE;
SELECT test.assert((SELECT revoked_at IS NOT NULL FROM public.user_consents WHERE user_id='25000000-0000-4000-8000-000000000001' AND consent_type='privacy_policy'),'retry and second signup transaction do not unrevoke');
SELECT test.assert(NOT EXISTS(SELECT 1 FROM public.user_consents c JOIN pg_temp.policy_250_evidence old USING(user_id,consent_type,version) WHERE c.granted_at IS DISTINCT FROM old.granted_at OR c.evidence_source IS DISTINCT FROM old.evidence_source OR c.policy_digest IS DISTINCT FROM old.policy_digest),'retry preserves original evidence');
SET LOCAL ROLE authenticated;
SELECT public.acknowledge_policy_reminder('2.5.0');
SELECT public.acknowledge_policy_reminder('2.4.0');
SELECT test.assert((SELECT NOT reminder_due AND policy_version='2.5.0' FROM public.get_my_policy_reminder_state()),'old acknowledgement does not downgrade new');
SELECT test.reject($q$SELECT public.acknowledge_policy_reminder('9.0.0')$q$,'policy_version_mismatch');
RESET ROLE;
SELECT test.assert((SELECT count(*)=5 AND bool_and(version='2.4.0') FROM public.user_consents WHERE user_id='25000000-0000-4000-8000-000000000001'),'reminder never writes 2.5 consent');
-- Exercise sync_my_user with orphan consent rows solely in a deferred fixture.
DO $$ DECLARE fk record; BEGIN
  FOR fk IN SELECT conname FROM pg_constraint WHERE contype='f'
    AND conrelid='public.user_consents'::regclass AND confrelid='public.users'::regclass LOOP
    EXECUTE format('ALTER TABLE public.user_consents ALTER CONSTRAINT %I DEFERRABLE INITIALLY DEFERRED',fk.conname);
  END LOOP;
END $$;
SET CONSTRAINTS ALL DEFERRED;
INSERT INTO public.user_consents(user_id,consent_type,version,granted_at)
SELECT '25000000-0000-4000-8000-000000000003',kind,
 CASE WHEN kind='privacy_policy' THEN '2.5.0' ELSE '2.4.0' END,now()
FROM unnest(ARRAY['terms_of_service','privacy_policy','community_guidelines','age_verification','special_category_religious']) kind;
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claim.sub = '25000000-0000-4000-8000-000000000003';
SELECT test.reject($q$SELECT public.sync_my_user()$q$,'required_signup_consents_missing');
RESET ROLE;
SELECT test.assert(NOT EXISTS(SELECT 1 FROM public.users WHERE id='25000000-0000-4000-8000-000000000003'),'mixed version rejection creates no user');
UPDATE public.user_consents SET version='2.4.0' WHERE user_id='25000000-0000-4000-8000-000000000003';
SET LOCAL ROLE authenticated;
SELECT public.sync_my_user();
RESET ROLE;
SELECT test.assert(EXISTS(SELECT 1 FROM public.users WHERE id='25000000-0000-4000-8000-000000000003'),'complete 2.4 bundle still provisions');
-- No permanent changes, including FK deferral, auth fixtures or evidence.
ROLLBACK;
