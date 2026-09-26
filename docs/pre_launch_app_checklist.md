# Silarah pre-launch checklist

Updated: 26 September 2026. Applies to the next release candidate, not a claim
that the existing AAB contains the pending cleanup/security fixes.

Status meanings: **PASS (local)** means the named local check passed, not that
production was verified. **IN PROGRESS** means implementation or verification
is incomplete. **PENDING** means evidence is still needed. No item may be
marked complete from source inspection alone when it requires runtime testing.

| # | Gate | Current status and required evidence |
| --- | --- | --- |
| 0 | Remove test data | Production registry checked 25 Sep: zero fixture batches and zero registered fixture members. Nothing identified there required deletion. Broader staging/manual-fixture inventory PENDING; preserve real users, payment QA accounts, audit evidence, backups and project memory. No production deletion performed. |
| 1 | Hide API keys | PASS (local secret scan, 24 Sep); production verification PENDING. Keep service-role/provider/signing secrets server-side and out of Git, logs and bundles. Supabase publishable/anon and RevenueCat public SDK keys are intentionally client-visible; protect their APIs with authorization, not obfuscation. Rotate any actually exposed secret. |
| 2 | Protect admin routes | IN PROGRESS. Migration 265 is deployed to staging (26 Sep) after a CLI dry run showing only that migration. All 23 staff-session assertions pass against the deployed functions; readback confirms migration 265, the private helper's denied client access, and zero retained test users/schema. Production deployment and alternate API/server-action verification remain pending. |
| 3 | Check auth and permissions | IN PROGRESS. Callback account-substitution reproduced and patched locally. Six callback tests plus nearby regression tests pass; Flutter analysis passes. Test sign-in/sign-out, account switching, MFA, revoked sessions and real-device deep links. |
| 4 | Secure database rules | IN PROGRESS. Complete effective RLS, view, definer-function and grant review; run fresh Supabase reset/database tests and advisors. Source migration count alone is not authorization proof. Never reset production. |
| 5 | Validate user inputs | PENDING full coverage. Include malformed/oversized inputs, unexpected JSON keys, duplicate query parameters, ownership fields, pagination and boundary values; enforce server-side. Callback malformed/ambiguous input tests pass locally. |
| 6 | Add API rate limits | IN PROGRESS review. Shared distributed rate limiting and authenticated media limits exist. Verify all costly/public endpoints, atomic concurrency behavior and failure handling; do not trust client throttles. |
| 7 | Test file uploads | IN PROGRESS. Upload-token metadata reflects two hours; reservation deadlines and five-minute read TTL are unchanged. Pre-decode JPEG geometry enforcement passes the before/after regression, four real-format controls and 23 nearby Flutter tests. Live staging signed upload, oversized-image rejection/removal, owner isolation, finalization and idempotent replay pass (26 Sep). Production, reservation expiry, revoked-photo/CDN access and peak-memory behavior for allowed images remain PENDING. No memory-exhaustion test was run. |
| 8 | Handle API errors | PENDING final runtime QA. Verify timeouts, offline/slow responses, retries, duplicate actions and cancellation without data loss or false success. |
| 9 | Remove debug logs | IN PROGRESS. Removed routine signed-media success logs containing member/viewer/owner IDs; retained error and security signals. Release-device/provider log review for tokens, links, messages and PII remains PENDING. |
| 10 | Hide sensitive errors | IN PROGRESS. Callback errors do not print the URI or exception. Both admin live-API RPC failure paths now return a generic message rather than raw database diagnostics; executable regression checks reproduced the old leak and pass after the fix, with successful payload/status behavior preserved. Other boundaries and deployed verification remain PENDING. |
| 11 | Test mobile layouts | PENDING exact-build QA. Small/large devices, all themes/locales, text scaling, keyboard/safe areas, accessibility and back-navigation motion. |
| 12 | Test slow internet | PENDING exact-build device tests. Airplane mode, connection loss mid-write, slow responses, app resume and repeated taps. Existing offline-session regression checks pass locally. |
| 13 | Test payments and webhooks | Play purchase testing BLOCKED pending fresh internal build and successful RevenueCat package validation. Fifteen rollback-only billing database assertions pass on staging, including duplicates, stale events, expiry and cross-account replay. Provider sandbox purchases/restores/renewals/cancellation/refunds, webhook delivery and concurrency remain PENDING. No real-money purchase authorized. |
| 14 | Try to break the app | IN PROGRESS. Source audit has two validated findings being repaired; repository coverage remains partial. A separate boundary investigator and bypass/regression reviewer examined the JPEG fix on 26 Sep; the review's real-format test gap was addressed. Use isolated fixtures/staging for adversarial tests; no production load/destructive testing. |
| 15 | Configure CORS | PENDING endpoint-by-endpoint verification. Distinguish browser origin restrictions from authentication; CORS alone does not authorize native/API callers. Test preflight, allowed origins and rejected origins. |
| 16 | Verify environment variables | PENDING exact-release validation. Fail closed on placeholders; verify production Supabase project, RevenueCat Google key, webhook environment/app/product allowlists and admin server-only settings without exposing values. |
| 17 | Set up error tracking | PENDING runtime verification. Crashlytics and operational telemetry exist; verify receipt of a safe staging event, redaction, source/symbol retention and access controls. |
| 18 | Review database indexes | IN PROGRESS. Review actual query/RLS paths, foreign keys, uniqueness and idempotency constraints; run advisors and representative EXPLAIN checks. Do not add indexes merely for count. |
| 19 | Configure automated backups | PARTIAL PASS. Weekly production backup is enabled; next run 27 Sep at 03:00 IST. The 25 Sep backup passes all three checksums/archive verification. On 26 Sep, 450 archive entries restored into a separate ephemeral staging database and all 87 app-owned table counts matched the manifest; the temporary database was removed and absence verified. Managed Auth/Storage/Vault, routines/policies/triggers and full-service recovery remain outside this drill. Retention/access review remains PENDING; this is not complete disaster recovery. |
| 20 | Legal and privacy compliance | PENDING qualified review. Verify truthful consent, retention/deletion/export handling, store declarations and actual processor/data flows. Operator/grievance legal identity remains unresolved; the generic desk label is not proof of compliance or protection from fines. |
| 21 | Audit dependency vulnerabilities | Admin PASS (local, 25 Sep): full locked audit and isolated npm ci report zero advisories after updating js-yaml to 4.3.2 and Browserslist to 4.29.1 with its metadata dependencies. The previous full audit had three high-severity package entries in development tooling; production-only audit was already zero. CI now audits development dependencies too. Flutter/native and Edge dependency advisory review remains PENDING; an empty npm audit is not proof of complete application security. |
| 22 | Set cache-control headers | IN PROGRESS. Admin session middleware explicitly sets private/no-store after cookie refresh; login and privacy routes are included. Local Cloudflare worker responses verify login 200, protected-route redirects and unauthenticated live API 401 with private/no-store. Shared Edge response defaults now set no-store, including signed photo links and upload tokens; new regression tests failed before the fix and pass after it. Explicit private location caching and public static assets are unchanged. Production readback and actual Storage object/CDN cache-revocation behavior remain PENDING; API response headers do not control cached image bytes. |

## Verification already observed on the isolated fix branch

- All four CI jobs passed on 7b57697 (run 36222756797), including the JPEG
  patch, full Flutter suite, clean database reset/tests, admin audit and
  CI-signed Android bundle. The new billing/privacy test-only follow-up needs
  its own CI run; no new production upload-signed AAB has been built.
- 26 Sep live staging: validate-photo-upload version 5 retains JWT protection.
  Unauthenticated calls return 401; cross-owner paths 400; oversized JPEGs
  return 422 and their objects are removed. A real 320x320 JPEG uploads through
  a signed URL and finalizes with 202; replay returns 200 and the same single
  photo. Fixture Auth/public users, reservations and objects were removed and
  zero residue verified. Reservation expiry, revocation/CDN caching and allowed
  maximum-image resource use are still pending; production is unchanged.
- 26 Sep: 15 new billing assertions pass against staging in a rolled-back
  transaction: member/anon denial, duplicate delivery, single ledger/outbox,
  stale expiry preservation, newer expiry, cross-account event reuse and
  unknown subscriber. These are database tests, not Play sandbox purchases or
  a concurrent-delivery test; no payment/email provider was contacted.
- The privacy fixture's old AAL2-only staff identity failed after migration
  265, as expected for a missing Auth session. Fixtures now supply a real
  staging session and session_id claim; native tests load the current 265
  predicate. Native privacy/retention and all three staging privacy/retention/
  policy-2.5 suites pass. Staging transactions roll back without replacing
  Auth functions. Fixture membership updates target only their synthetic user.
- Play Console checked 26 Sep: latest uploaded bundle remains 42042 and the
  internal release is still a draft. No old draft was published.
- 26 Sep: the JPEG guard, actual handler regression and parser boundary tests
  pass: all 17 Edge tests, including five handler subtests, with frozen lock.
  Formatting (24 files), lint (23 files), all 12 entrypoint typechecks, secret
  scan, migration validation and 23 selected Flutter photo tests pass.
  The lockfile now also records runtime SDK modules exercised by the handler
  test; no dependency version or application dependency was added.
- 26 Sep: only migration 265 applied to staging. The 23-assertion readback test
  uses the deployed functions without replacing them; synthetic rows/schema
  are rolled back. Production was not migrated. The isolated fix checkout is
  now linked to staging; do not assume its CLI link targets production.
- Staging reports PostgreSQL 17.6. Review the newly announced 15.19/17.11
  security update and extension compatibility before scheduling an upgrade;
  no database engine upgrade or extension relocation was attempted.
- Original callback regression failed: an attacker-token callback returned true.
- After the fix, 26 tests across callback, audit contracts, offline recovery,
  session cleanup and routing passed. The callback suite was then expanded to
  six tests and passed, including numeric OTP and rejected-code compatibility.
- `flutter analyze --no-pub`: no issues (24 Sep).
- Migration filename/content validation: 265 migrations passed again (25 Sep).
- Repository secret scan and `git diff --check`: passed again (25 Sep).
- Dart formatting: 306 files checked, zero changes (25 Sep).
- Original staff database predicate failed the expired-session denial test.
  After correcting a test-only schema-permission assertion, all 23 isolated
  PostgreSQL assertions pass (25 Sep), including registration idempotency,
  exact expiry, revoked sessions, MFA/role controls and private helper denial.
  The same 23 assertions also pass against real Supabase staging Auth/session
  functions with migration 265 applied inside a rollback-only transaction.
  That 25 Sep readback confirmed migration history remained at 264, zero fixture users,
  no test schema and no temporary deadline helper. The full Supabase clean
  reset and database CI subsequently passed on commit 739a7a6; permanent
  deployment verification was subsequently completed on staging on 26 Sep;
  production deployment remains pending.
- `node admin/scripts/test-session-cache.mjs`: passed (25 Sep), including
  the response replacement performed during cookie refresh.
- First full Windows Flutter run: 613 passed, six failures. Normalizing tracked
  source line endings fixed the source-contract failures without weakening
  assertions. Full rerun: **619 passed, zero failures** (25 Sep, 6m55s).
  `.gitattributes` pins consistent checkout endings; no bulk content rewrite
  is included in the Git diff.
- Edge Functions: formatting (21 files), lint (20 files), typechecks for all
  12 entrypoints, and all 13 tests pass with the frozen lockfile (25 Sep).
- The shared cache regression reproduced two failures before the header fix;
  all three new checks now pass, including preflight and the existing explicit
  private location-cache override. The five selected Flutter photo suites
  pass all 23 tests after upload-expiry metadata/log cleanup.
- Existing deployed admin security-header test passes (25 Sep). This verifies
  the current deployed headers, not the pending no-cache middleware patch.
- Admin full lint, session-cache regression test, TypeScript check and
  production build pass with the updated isolated dependencies (25 Sep).
  The build emits upstream Next/Supabase Edge-runtime compatibility warnings;
  OpenNext Cloudflare build also passes on 30126b9. A local worker preview
  verifies private/no-store for login, protected redirects and unauthenticated
  live API responses, then was stopped. Production readback remains pending.
- All four GitHub CI jobs passed on commit 30126b9 (run 36143463090), as well
  as 739a7a6 (run 36117145817): secret
  scan, Flutter/release build, admin, and Supabase migrations/functions.
  Later exact-head CI for 7a2478e and 7b57697 also passed. Every CI bundle uses
  a CI-only signing identity; it is not a production upload-signed AAB.
- Existing Task Scheduler backup test completed at 09:15 UTC on 25 Sep;
  `20260925T091335Z` contains 87 app-owned tables and passes the backup verifier.
- Staging Security Advisor results still need triage. They include extension
  placement/PostGIS reference-table warnings and callable definer functions;
  warnings are not automatically exploitable findings, and blanket revocation
  would break the application's checked RPC interfaces.

## Release ordering

Fix and test confirmed issues incrementally. Preserve the immutable audit
snapshot separately. Merge only reviewed changes, freeze one exact commit,
check the highest Play version code and assign a greater permanent version,
then run the complete release gate from `pre_play_revenuecat_checklist.md`.
Build and verify a newly signed production AAB, upload to Internal Testing,
obtain approval for publishing the internal release, install through Play and
perform sandbox payment tests. Do not publish the old 42042 draft or imply the
historical 42043 bundle includes these fixes.
