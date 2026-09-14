# Production architecture deployment — 6 September 2026

## Scope and result

Owner explicitly requested production deployment and deferred signed APK
installation because the OnePlus was disconnected. Deployed only these pending
migrations to `jukpscfxzwttgtxvrbmj`:

- **256** — correct row identity in the Premium/incognito entitlement trigger.
- **257** — avoid recreating a Discovery revision for an account being deleted.
- **258** — private chat retry receipts, authenticated idempotent-send RPC and
  a shared actor-bound send-rate trigger for legacy/member/guardian chat.

Production was at migration 255 before deployment. The explicit-production
dry-run listed exactly 256–258, without seed or role changes. The push succeeded
for all three; Vault synchronization was explicitly skipped. No paid-plan,
spend-cap, billing-product, user-account, message-content or device changes were
performed. No production load test or artificial authenticated message was run.

## Backup gate

Command: `tool/backup_supabase.ps1 -ProjectRef jukpscfxzwttgtxvrbmj`.

Backup directory:
`supabase/backups/jukpscfxzwttgtxvrbmj/20260906T001425Z/`.
Manifest completed at `2026-09-06T00:18:25.7972800Z`.

`tool/verify_supabase_backup.ps1` passed all three file checksums, sizes and
archive catalogue checks. The archive contains 85 app-owned tables.

| File | Bytes | SHA-256 |
| --- | ---: | --- |
| app.dump | 1212721 | 027169c027af2f89085679ffc318eef11f8b311480629e168d745bd12b2b076b |
| app_schema.sql | 761170 | 44f57542427d2d87f544624fea9a02b98e22625d18fec1c314b4485ef9610b0d |
| app_data.sql | 1045875 | 542efce0722f04adb246a1e7a232e1b3d86e71e697dba92f22f9af2a50e426f9 |

Scope is app-owned `public`, `private` and `api_private` schemas. This does not
back up managed Auth, Storage objects/metadata or Vault secrets and is **not a
fresh restore drill**. Backup files remain local and gitignored. The backup
script restored the normal staging CLI link after completing.

## Live verification

Ran `tool/verify_architecture_release.sql` using explicit `--project-ref` values
on staging and production. Both returned the same inspected definitions,
privileges, indexes, constraints and enabled rate trigger:

| Function | Definition digest (MD5 for equality only) |
| --- | --- |
| private.guard_chat_send_rate() | eea843eedf895404722c81c69f4dbaa9 |
| private.sync_incognito_entitlement_trigger() | 5786d739dffe44edad49257f917d5280 |
| private.touch_discovery_member(uuid) | 6f125aa1e4bf3a9724c90125918cdc6f |
| send_chat_message_idempotent(uuid,text,uuid,boolean) | 689cd37e2c308e69da257b507893e373 |
| send_chat_message(uuid,text) | 50e9418c099c4a3f7c35ff15089e04fc |
| send_guardian_chat_message(uuid,text) | 60320943b1a36e661b0d49064c67dea5 |

- All inspected functions use a fixed empty search path.
- Anonymous execution is denied for all six; only the three public send RPCs
  allow authenticated execution. Private trigger helpers remain inaccessible.
- Neither anonymous nor authenticated roles can SELECT private retry receipts.
- The actor/operation primary key and actor/match/message cascading foreign
  keys exist. Both supporting indexes and the primary-key index exist.
- `guard_chat_send_rate` is enabled on `public.messages` and points to the
  intended private helper.
- Production Auth public settings responded **HTTP 200**.
- Anonymous POST to the new RPC responded **HTTP 401 / SQLSTATE 42501**, with
  permission denied for the function. This also confirms the HTTP schema cache
  recognizes the endpoint. No message was created.
- Post-deployment inventory matched the pre-deployment backup for users (5),
  profiles (5), messages (16), matches (5) and interests (11). Receipts and orphan
  receipts were both zero.
- The final explicit-production dry-run returned `upToDate: true` with no
  pending migrations, seeds or roles. The local CLI link remains staging.

## What this does and does not establish

This verifies that the staging-tested backend changes are deployed, protected
and reachable in production; it is not a production two-account send, purchase,
account-deletion exercise or a zero-bug certification. Existing apps retain
their legacy send endpoints and immediately receive the shared 60-successful-
sends-per-account-per-fixed-minute guard. New-client sends also have a
120-successful-send/acknowledgement-request-per-minute guard. Rejected SQL
transactions roll back counters; these are not edge-level DDoS controls.

The client-side retry UUIDs, refresh/reconnect recovery and lifecycle fixes still
need the updated **signed release build**, installation and device QA when the
OnePlus returns. No AAB was uploaded. Supabase quotas are unchanged; this
deployment does not establish support for 1,000 simultaneous live connections.

The six staging lint diagnostics classified as PostGIS-owned utilities remain
documented in `architecture_upgrade_readiness.md`; managed extension functions
were not changed or suppressed during this deployment.

## Follow-up: signed OnePlus connection audit, 6–7 September

The prepared production client was subsequently built and installed on the
OnePlus as a signed arm64 release: Android version code 42038 (Flutter base
build 40038). App data were preserved; no AAB was uploaded. Repeated member-chat
and photo-request navigation/background tests showed no accumulating Supabase
connections. The full Flutter suite passed 503 tests and the analyzer reported
no issues. See [the exact artifact, device measurements and limitations](oneplus_connection_audit_20260907.md).

This resolves the pending installation and bounded connection-lifecycle evidence,
not every item in the earlier device QA list. New two-person send/retry/FCM,
Guardian-account physical-device, radio-loss, billing and combined 1,000-user
capacity tests were not performed in this follow-up. Provider quotas are unchanged.
