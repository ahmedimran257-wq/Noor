# Supabase security sign-off

Date: 2026-08-30
Production project: `jukpscfxzwttgtxvrbmj`
Migration parity: local, staging and production through migration `254`

## Advisor snapshot

The last dashboard snapshot after migration 249 reported **1 error, 213 warnings, and 14 informational suggestions**. A direct production ACL/ownership recheck after migration 250 records the same managed-extension error boundary and **215 warning-equivalent findings**. The two additional authenticated findings are app-owned, owner-scoped RPCs introduced by the final profile/premium readback migrations. Database performance inspection after migration 250 found no blocking or long-running queries, with index and table cache hit rates both at 1.00. A refreshed dashboard screenshot remains a release-record task because Chrome automation was unavailable for this run.

| Advisor category | Count | Classification | Release treatment |
| --- | ---: | --- | --- |
| RLS disabled on `public.spatial_ref_sys` | 1 error | Supabase-managed PostGIS object | Accepted managed-extension exception. The table and extension are owned by `supabase_admin`; application migrations must not alter their ACL, ownership, schema, or RLS state. |
| Extension in public (`postgis`, `pg_net`) | 2 | Supabase-managed, non-relocatable extensions | Accepted managed-extension exceptions. The application does not own these extensions. Relocation is not attempted in release migrations. |
| Leaked Password Protection Disabled | 1 | Plan-gated and not used by the app | Supabase documents this control as Pro-only. Silarah uses passwordless email OTP and has no password sign-up/sign-in path, so leaked-password screening is not on the authentication path. Reassess and enable it before introducing passwords or when upgrading to Pro. |
| Public can execute `SECURITY DEFINER` | 6 | 3 extension-owned overloads plus 3 deliberate pre-auth RPCs | Accepted with controls. PostGIS owns the three `st_estimatedextent` overloads. The app-owned pre-auth RPCs are `begin_signup_consent_transaction`, `bind_signup_consent_transaction`, and `validate_referral_code`; they accept no authenticated authority and enforce server-side validation/rate limits. |
| Signed-in users can execute `SECURITY DEFINER` | 206 | 3 extension-owned overloads plus 203 app-owned authenticated RPCs | Accepted by design. App RPCs revoke `PUBLIC`/`anon`, scope member operations to `auth.uid()`, enforce staff roles inside admin RPCs, use fixed `search_path`, and are covered by database/security contract tests. The two `api_private` routines are explicit owner/guardian projections, not unrestricted helpers. |

The post-250 direct database counts reconciled to `2 + 1 + 6 + 206 = 215`
warning-equivalent findings. After migration 254, CLI database lint reports no
Silarah-owned routine findings; the remaining diagnostics are extension-owned
PostGIS routines. A refreshed dashboard snapshot is still required because its
advisor categories are not interchangeable with CLI lint output.

## Enforced controls

- Migration `183_resolve_security_advisor_findings.sql` verifies that `spatial_ref_sys` is managed by `supabase_admin` and fails closed if the ownership boundary changes.
- Migration `245_security_advisor_acl_and_postgis_boundary.sql` revokes `PUBLIC` and `anon` execution from every app-owned `SECURITY DEFINER` routine except the explicit pre-auth allowlist, and removes all Data API execution from private-schema helpers.
- Migration `249_release_gate_security_cost_and_index_hardening.sql` removes the legacy email-enumeration RPC, applies abuse/rate-limit controls, and performs release-gate index and scheduled-job hardening.
- Migration `250_india_inventory_and_availability_wake.sql` aligns persisted inventory with the canonical India state/city filter payload and wakes bounded availability delivery for both inserted and coalesced events.
- Migrations `251` and `252` add owner-scoped Premium compatibility, shortlist,
  incognito and relationship-privacy boundaries without widening anonymous access.
- Migrations `253` and `254` retire phone identity, scrub stored app-owned phone
  data, enforce null-only compatibility columns, and replace Guardian phone OTP
  with a verified-email-bound, hash-only, one-time invitation that expires after
  seven days and rate-limits failed acceptance attempts.
- `test/security_advisor_boundary_test.dart` prevents an application migration from mutating Supabase-owned PostGIS objects and verifies the anonymous allowlist boundary.
- Database contract tests cover role checks, ownership checks, message/match access, photo privacy, referrals, exports, account deletion, and rate limits.

## Release evidence

- [x] Local, staging and production migration history matches through 254.
- [x] Fresh version 2 post-254 production backup created at `supabase/backups/jukpscfxzwttgtxvrbmj/20260830T161209Z`; checksums, archive catalogue and 84-table snapshot inventory verified.
- [x] The post-254 production archive restored into the uniquely named staging-side database `silarah_restore_drill_20260830_161706`; all 84 archived table counts matched, and the exact ephemeral database was removed.
- [x] Leaked-password warning classified against the actual passwordless OTP architecture and current Free-plan limitation.
- [x] Post-migration database ACL/ownership counts recorded here; no application-owned warning-equivalent finding is left unclassified.
- [ ] Capture the refreshed post-254 Security and Performance Advisor dashboard totals for the release record.

## Managed-extension decision

Supabase documents PostGIS as a database extension and notes that modern PostGIS installations cannot be moved between schemas without dropping and recreating the extension and dependent objects. Because production ownership belongs to `supabase_admin`, the project treats these Advisor findings as platform-managed exceptions rather than weakening ownership or attempting a destructive migration. If Supabase changes this managed boundary, resolve it through Supabase Support before changing production.

References:

- https://supabase.com/docs/guides/database/extensions/postgis
- https://supabase.com/docs/guides/database/database-advisors
- https://supabase.com/docs/guides/auth/password-security
