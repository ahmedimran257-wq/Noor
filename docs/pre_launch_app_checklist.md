# Silarah pre-launch checklist

Updated: 25 September 2026. Applies to the next release candidate, not a claim
that the existing AAB contains the pending cleanup/security fixes.

Status meanings: **PASS (local)** means the named local check passed, not that
production was verified. **IN PROGRESS** means implementation or verification
is incomplete. **PENDING** means evidence is still needed. No item may be
marked complete from source inspection alone when it requires runtime testing.

| # | Gate | Current status and required evidence |
| --- | --- | --- |
| 0 | Remove test data | Production registry checked 25 Sep: zero fixture batches and zero registered fixture members. Nothing identified there required deletion. Broader staging/manual-fixture inventory PENDING; preserve real users, payment QA accounts, audit evidence, backups and project memory. No production deletion performed. |
| 1 | Hide API keys | PASS (local secret scan, 24 Sep); production verification PENDING. Keep service-role/provider/signing secrets server-side and out of Git, logs and bundles. Supabase publishable/anon and RevenueCat public SDK keys are intentionally client-visible; protect their APIs with authorization, not obfuscation. Rotate any actually exposed secret. |
| 2 | Protect admin routes | IN PROGRESS. Existing staff layout/MFA checks inspected. Migration 265 adds Auth-session-bound expiry to the shared database guard, covering direct RPC/RLS paths too. Complete database tests and deployment readback; verify alternate API/server-action routes. |
| 3 | Check auth and permissions | IN PROGRESS. Callback account-substitution reproduced and patched locally. Six callback tests plus nearby regression tests pass; Flutter analysis passes. Test sign-in/sign-out, account switching, MFA, revoked sessions and real-device deep links. |
| 4 | Secure database rules | IN PROGRESS. Complete effective RLS, view, definer-function and grant review; run fresh Supabase reset/database tests and advisors. Source migration count alone is not authorization proof. Never reset production. |
| 5 | Validate user inputs | PENDING full coverage. Include malformed/oversized inputs, unexpected JSON keys, duplicate query parameters, ownership fields, pagination and boundary values; enforce server-side. Callback malformed/ambiguous input tests pass locally. |
| 6 | Add API rate limits | IN PROGRESS review. Shared distributed rate limiting and authenticated media limits exist. Verify all costly/public endpoints, atomic concurrency behavior and failure handling; do not trust client throttles. |
| 7 | Test file uploads | PENDING. Verify MIME/magic bytes, decoder limits, oversized files, slot quotas, reservation replay/expiry, ownership and revoked private-photo access. Test actual upload/finalization, not extension checks alone. |
| 8 | Handle API errors | PENDING final runtime QA. Verify timeouts, offline/slow responses, retries, duplicate actions and cancellation without data loss or false success. |
| 9 | Remove debug logs | PENDING release log review. Remove sensitive/noisy debug output, not useful sanitized operational events. Inspect release-device logs and provider logs for tokens, links, messages and PII. |
| 10 | Hide sensitive errors | IN PROGRESS. Callback errors do not print the URI or exception. Both admin live-API RPC failure paths now return a generic message rather than raw database diagnostics; executable regression checks reproduced the old leak and pass after the fix, with successful payload/status behavior preserved. Other boundaries and deployed verification remain PENDING. |
| 11 | Test mobile layouts | PENDING exact-build QA. Small/large devices, all themes/locales, text scaling, keyboard/safe areas, accessibility and back-navigation motion. |
| 12 | Test slow internet | PENDING exact-build device tests. Airplane mode, connection loss mid-write, slow responses, app resume and repeated taps. Existing offline-session regression checks pass locally. |
| 13 | Test payments and webhooks | BLOCKED pending fresh Play-delivered internal build and successful RevenueCat Play package validation. Test license/sandbox purchases, restores, renewals, cancellation, expiry, refund/revocation, replay and out-of-order events. No real-money purchase authorized. |
| 14 | Try to break the app | IN PROGRESS. Source audit has two validated findings being repaired; scope is still partial. Use isolated fixtures/staging for adversarial tests; no production load/destructive testing. Independent audit worker unavailable due usage limits. |
| 15 | Configure CORS | PENDING endpoint-by-endpoint verification. Distinguish browser origin restrictions from authentication; CORS alone does not authorize native/API callers. Test preflight, allowed origins and rejected origins. |
| 16 | Verify environment variables | PENDING exact-release validation. Fail closed on placeholders; verify production Supabase project, RevenueCat Google key, webhook environment/app/product allowlists and admin server-only settings without exposing values. |
| 17 | Set up error tracking | PENDING runtime verification. Crashlytics and operational telemetry exist; verify receipt of a safe staging event, redaction, source/symbol retention and access controls. |
| 18 | Review database indexes | IN PROGRESS. Review actual query/RLS paths, foreign keys, uniqueness and idempotency constraints; run advisors and representative EXPLAIN checks. Do not add indexes merely for count. |
| 19 | Configure automated backups | PARTIAL PASS. Existing weekly production task is enabled; next run 27 Sep at 03:00 IST. A Task Scheduler-triggered test completed successfully on 25 Sep (exit 0), and all three file checksums plus the archive catalogue verify for 87 app-owned tables. The earlier 20 Sep attempt had a nonzero result. Auth/Storage/Vault recovery, retention/access and a full restore drill remain PENDING; an application-only backup is not complete disaster recovery. |
| 20 | Legal and privacy compliance | PENDING qualified review. Verify truthful consent, retention/deletion/export handling, store declarations and actual processor/data flows. Operator/grievance legal identity remains unresolved; the generic desk label is not proof of compliance or protection from fines. |
| 21 | Audit dependency vulnerabilities | Admin PASS (local, 25 Sep): full locked audit and isolated npm ci report zero advisories after updating js-yaml to 4.3.2 and Browserslist to 4.29.1 with its metadata dependencies. The previous full audit had three high-severity package entries in development tooling; production-only audit was already zero. CI now audits development dependencies too. Flutter/native and Edge dependency advisory review remains PENDING; an empty npm audit is not proof of complete application security. |
| 22 | Set cache-control headers | IN PROGRESS. Admin session middleware now explicitly sets private/no-store after cookie refresh; login and privacy routes are included. Executable mock-boundary tests pass for refreshed and unchanged sessions. CDN/deployed readback and media/API coverage remain PENDING. Public static-asset caching was not disabled. |

## Verification already observed on the isolated fix branch

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
  Readback confirms migration history remains at 264, zero fixture users,
  no test schema and no temporary deadline helper. The full Supabase clean
  reset and database CI subsequently passed on commit 739a7a6; permanent
  deployment verification remains required.
- `node admin/scripts/test-session-cache.mjs`: passed (25 Sep), including
  the response replacement performed during cookie refresh.
- First full Windows Flutter run: 613 passed, six failures. Normalizing tracked
  source line endings fixed the source-contract failures without weakening
  assertions. Full rerun: **619 passed, zero failures** (25 Sep, 6m55s).
  `.gitattributes` pins consistent checkout endings; no bulk content rewrite
  is included in the Git diff.
- Edge Functions: formatting (20 files), lint (19 files), typechecks for all
  12 entrypoints, and all 10 existing tests pass with the frozen lockfile.
- Existing deployed admin security-header test passes (25 Sep). This verifies
  the current deployed headers, not the pending no-cache middleware patch.
- Admin full lint, session-cache regression test, TypeScript check and
  production build pass with the updated isolated dependencies (25 Sep).
  The build emits upstream Next/Supabase Edge-runtime compatibility warnings;
  Cloudflare-adapter/deployed verification is still required before deployment.
- All four GitHub CI jobs passed on commit 739a7a6 (run 36117145817): secret
  scan, Flutter/release build, admin, and Supabase migrations/functions.
  The CI bundle uses a CI-only signing identity; it is not a production AAB.
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
