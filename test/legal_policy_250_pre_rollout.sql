INSERT INTO auth.users(id,email,email_confirmed_at) VALUES
 ('00000000-0000-4000-8000-000000000001','old@example.invalid',now()),
 ('00000000-0000-4000-8000-000000000002','new@example.invalid',now()),
 ('00000000-0000-4000-8000-000000000003','bad@example.invalid',now()),
 ('00000000-0000-4000-8000-000000000004','unverified@example.invalid',null),
 ('00000000-0000-4000-8000-000000000005','mixed@example.invalid',now());
-- A valid pending 2.4.0 transaction created and bound BEFORE migration 264.
SET ROLE anon;
SELECT public.begin_signup_consent_transaction('2.4.0',
 '{"terms_of_service":true,"privacy_policy":true,"community_guidelines":true,"age_verification":true,"special_category_religious":true}') AS pending \gset
SELECT public.bind_signup_consent_transaction(:'pending','old@example.invalid');
RESET ROLE;
CREATE TABLE test.pending(id uuid);
INSERT INTO test.pending VALUES (:'pending');
GRANT SELECT ON test.pending TO authenticated;
-- A malformed historical transaction must NOT become consent after rollout.
INSERT INTO private.signup_consent_transactions(id,policy_version,acceptances,bound_email_hash)
VALUES ('00000000-0000-4000-8000-000000000099','2.4.0',
 '{"a":true,"b":true,"c":true,"d":true,"e":true}',
 encode(extensions.digest(convert_to('bad@example.invalid','UTF8'),'sha256'),'hex'));
