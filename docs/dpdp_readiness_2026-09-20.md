# Privacy readiness — 20 September 2026

Status: engineering hardening in progress; not a legal compliance certification.

## Updated engineering checkpoint — 23 September 2026

This checkpoint supersedes the historical implementation status below.

- Staging has migrations 260–264. The authenticated rights-request, staff
  access, retention/hold and policy-version fixtures passed again on 23 September
  using real Supabase auth functions in rollback-only transactions.
- Migration 263 implements the owner-approved 12-month retention after
  resolution, excluding documented, time-bounded legal holds. Unresolved cases
  are retained. Private hold/audit tables have RLS and deny ordinary client roles.
- Migration 264 accepts actual 2.4.0 or 2.5.0 signup evidence during the
  compatibility window; it does not fabricate upgraded consent or reverse
  withdrawal. Both app and website notices are versioned 2.5.0 in source.
- Full Flutter suite: 603 tests passed after localization fixes. Analysis has
  no findings. Privacy UI tests include all ten locales, all three themes,
  enlarged text, retry/conflict handling and verbatim staff responses.
- Production was last checked at migration 259. Backup, deployment of 260–264
  and post-deployment verification remain required; staging success is not a
  claim of production rollout or complete legal compliance.
- Operational fulfilment, processor erasure, working mailboxes, legal identity
  and counsel review remain open. The earlier retention decision request below
  is historical; the policy is now approved and implemented, pending rollout.

## Primary authority and commencement

Final Rules: https://www.meity.gov.in/static/uploads/2025/11/53450e6e5dc0bfa85ebd78686cadad39.pdf

Rule 1 staggers commencement: rules 1, 2 and 17–21 on publication; rule 4 one year later; rules 3, 5–16, 22 and 23 eighteen months later. Do not rely on the January 2025 draft or describe every substantive requirement as already operative. Verify the Act commencement notification, subsequent corrigenda and transfer orders with Indian counsel before launch and before the 2027 substantive commencement.

## Evidence and remaining gaps

| Area | Evidence / state | Required follow-through |
| --- | --- | --- |
| Consent evidence | Versioned signup transactions, explicit acceptance fields; member provisioning requires consent | Review actual screen copy and whether every purpose is necessary; maintain notice language options and separate optional consent |
| Rights requests | Migration 262 adds authenticated intake, member-only visibility, retry keys, rate limit, due index, staff AAL2 checks, optimistic concurrency and event trail; app and admin UI added | Deploy after database tests; review daily, acknowledge within 24h, respond against the 7-day operational target; a queue is not automated fulfilment |
| Withdrawal | Existing visibility/notification controls and deletion; new assisted withdrawal intake | Assisted requests do not instantly stop all processing. Complete an explicit self-service withdrawal design for each consent purpose and processor propagation |
| Nomination | Dedicated authenticated request category and verification instructions | Verify authority and nominee identity proportionately; record/revoke nominations securely; do not collect identity documents through free text |
| Operator/contact | Current public identity is “Silarah” / “Silarah Grievance Desk” | Owner requested leaving this unchanged on 20 September. Remains an open legal review item; do not infer that it is sufficient |
| Public notice | Existing data categories, processors, visibility and retention notices | Indian processing must use consent or a specific statutory legitimate use; generic contract/legitimate-interest language is not a substitute under DPDP. Review and version both app/site notices together before publication |
| Account deletion | Leased storage → auth → database purge, recovery period, separate store cancellation disclosure | Verify live schedules, dead-letter/retry handling, processor deletion, backup rotation and restored-backup suppression. Thirty-day recovery is a product choice, not a blanket statutory exemption |
| Retention | Temporary verification captures <=48h, active data lifecycle and security evidence | Obtain a purpose/category schedule with legal basis, owner, duration, disposal evidence and holds. Reconcile Rule 6/8 one-year requirements before they apply. Do not globally retain all profile data forever or blindly delete required evidence |
| Security | RLS, private media, signed URLs, staff MFA/session boundary, rate limits | Test access denial, secret rotation, monitoring, restore drills and actual provider settings; source code alone is insufficient evidence |
| Children | Adult-only product and onboarding age gate | Exercise server-side age boundaries and underage-report response; adult guardians cannot authorize child matrimonial profiles |
| Processors/transfers | Supabase, Cloudflare, Firebase, Brevo, RevenueCat/Google Play appear in stack | Keep actual data inventory, DPAs, regions, subprocessors, retention and deletion capabilities; confirm mailbox delivery for every published rights address |
| Breach response | General policy exists | Use runbook below; name a human owner and run a tabletop exercise |
| Rights request retention | Request body may include sensitive member details; auth deletion detaches user ID | Add approved request retention/hold schedule and purge job. A detached user ID does not anonymize free text. No automatic purge enabled until schedule approved |

## Incident runbook

1. Record awareness time in UTC, affected systems, incident owner and scope. Restrict access, revoke compromised credentials and preserve necessary evidence with a custody trail.
2. Determine applicable reporting regimes immediately. Under DPDP Rule 7 when in force, initial Board and affected-person notices are without delay; the detailed Board update follows within 72 hours (or a written extension). Do not wait 72 hours before initial notice.
3. Assess separate CERT-In and other obligations with counsel; the DPDP clock does not replace a shorter applicable reporting clock.
4. Prepare plain-language affected-person notice: nature/timing, likely consequences, containment, protective steps and a working contact. Never include unrelated people's records.
5. Record notices, decisions and acknowledgements. Follow with remediation, verification and recurrence prevention. Test recovery without restoring deleted profiles to discovery.

## Release evidence still required

Full-stack rights-request isolation/retry tests; live request/response exercise; export and deletion exercise; processor erasure evidence; working privacy and grievance mailboxes; retention/hold decisions; notice/version rollout; business identity/contact review; cross-border and adult-guardian assessment. Keep public release blocked on unresolved material items, not on an assertion that “all compliance is done”.

## Engineering validation recorded this session

- `tool/test_privacy_requests.ps1` passed on disposable native PostgreSQL 17, without Docker. It uses synthetic auth/JWT plumbing and the actual migration-147 staff predicate, then runs migration 262. Covers member isolation, anonymous/raw-write denial, AAL2 and role/revocation restrictions, payload validation, retry-key conflicts, daily limits, optimistic review conflicts, terminal resolution, audit retry safety, member responses and auth-deletion detachment. This is not a full Supabase reset or a production smoke test; simultaneous multi-connection races still need integration coverage.
- Flutter analysis: zero findings. Targeted legal/site/settings/export/billing regression suite: 41 tests passed. New privacy screen widget tests: 3 passed across Black & White, OLED and Ivory & Emerald, at phone width and 150% text scale, including empty-request validation. These do not exercise authenticated network submission.
- Admin typecheck, lint, security-header verification and production Next.js build passed. Privacy queue now defaults to open requests; resolved requests are separate. Background refresh is disabled on the reply page to protect unfinished replies.
- Website browser check: phone and desktop layouts without horizontal overflow, menu Escape behavior, no console warnings/errors observed, and live reduced-motion preference disables reveal mode. Existing ivory/emerald identity preserved.
- Migration 262 and the new UI are local changes, not a claimed live rollout. Retention/fulfilment decisions, translation review and authenticated end-to-end smoke tests remain release gates.
