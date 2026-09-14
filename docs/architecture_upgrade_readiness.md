# Architecture upgrade readiness — 5–6 September 2026

## Decision

An upgrade of the **same Supabase project** does not require an app rewrite to
raise its provider connection quota. The app uses one shared Supabase client;
there is no client-side 200/500/1,000-user ceiling to change. This is not an
unlimited-capacity guarantee, a zero-bug certification, or a successful
post-upgrade 1,000-connected-user test.

The client release work below is in source. Following the owner's deployment
request on **6 September 2026**, migrations **256–258 are also live in production**
(`jukpscfxzwttgtxvrbmj`), after a verified app-schema backup. Production function
definitions, grants, receipt constraints/indexes and the enabled rate trigger
match the tested staging implementation (`ykmgkrveucslglxvcyss`). See
[production deployment evidence](production_architecture_deployment_20260906.md).
Billing settings, provider quotas and installed device builds were not changed.
The owner deferred signed-build installation until the OnePlus is connected.
Do not install/release this client against another backend missing migration
258: it intentionally has no unsafe legacy-send fallback.

## Connection and cost model reviewed

| Path | Current behavior | Capacity implication |
| --- | --- | --- |
| Discovery | 20-profile pages, batched authorized photos and relationship data | No whole-catalog download or socket per card |
| Ordinary member chat | Shared client; one active conversation subscription, filtered by match ID | Opening chat uses a live socket; ordinary browsing need not |
| Inbox / notifications / standing | RPC reads, FCM recovery and foreground reconciliation; no permanent account-wide channels | Fewer idle connections; FCM is not treated as durable message storage |
| Chat history | 30-message pages, timestamp + ID cursor | Read payloads remain bounded |
| Presence | 10-minute foreground heartbeat; duplicate-state suppression | Not a per-second server heartbeat |
| Photo requests | Owner-filtered subscription while the screen exists | No unfiltered photo-request fan-out |
| Guardian | RLS-protected message subscription plus dashboard/transcript RPCs | Broad message subscription remains a scaling consideration; see below |
| Countdown / resend timers | Local UI timers | These do not independently poll the database every second |

These are code-level observations, not a measurement of all features together.

## Defects corrected

1. **Ambiguous chat-send outcomes could duplicate messages.** Member and guardian
   clients now retain an operation UUID on retry. The new authenticated RPC
   serializes that operation and returns its existing acknowledgement. A changed
   body/match/role cannot reuse the operation. Deliberately sending identical
   text twice with different operations still creates two messages. Existing
   authorization, subscription, guardian approval and safety checks stay in the
   original send functions. Receipts are private and cascade on message/account
   deletion; they add one small indexed row per new-client message, not another
   copy of the message body.
2. **Chat lacked a shared send-rate guard.** A database insert trigger now caps
   successful user-initiated sends at 60 per account per fixed minute, across
   matches and legacy/new send endpoints. Guardian sends are charged to the
   authenticated guardian. The new idempotent endpoint also caps successful
   send/acknowledgement requests at 120 per minute. This is not a substitute for
   an edge-wide abuse/WAF limit: rejected SQL transactions roll back their rate
   counter writes. Fixed windows can allow a burst across a minute boundary.
3. **Leaving a screen could leave an idle transport open.** Chat and photo-request
   cleanup now use `removeChannel`, which disconnects the SDK transport when no
   other channels remain. It does not disconnect another active screen's channel.
4. **Missed live events were not explicitly reconciled on rejoin.** Active chat,
   guardian dashboard/transcript and photo requests now use coalesced recovery
   reads. Healthy connections do not periodically poll. Failed subscriptions
   trigger one jittered recovery signal every 30–45 seconds (plus the read delay).
   Reads are single-flight with a trailing request when events arrive during a
   fetch. Pausing/disposal cancels scheduled work.
5. **Continuous events could indefinitely postpone inbox refresh.** The inbox
   debounce no longer restarts on every event.
6. **Late requests could affect the wrong screen/session.** Chat authorization
   uses a route generation; message loads and send acknowledgements use account
   epochs; late subscription callbacks are ignored after cleanup. A background
   authorization cannot start a new chat socket until foreground resume.
7. **Opening chat while its inbox was already loading could return too early.**
   Callers now await the shared inbox completion. A previous account's completion
   cannot clear a new account's in-flight guard. Only explicit route activation
   subscribes; a background message fetch cannot reopen a disposed channel.
8. **A large missed-message gap could become unpageable.** Recovery now resets
   a disconnected history window to the latest 30 messages, retains unsent
   bubbles, and restores the older-page cursor. Continuity is checked against
   the last authoritative page, not a newly arrived live event. Temporary local
   message IDs are never sent as database UUID cursors. Events/acknowledgements
   arriving during a page fetch queue a trailing recovery read.

## Executed evidence

- Staging migration 258: dry-run showed only 258 pending, then applied successfully.
- `build/staging-architecture-recovery-20260905/extended-10-report.json`:
  - 10/10 ordinary authorized chat sends and reads; 10 durable notifications.
  - 20 concurrent member retries -> one message, same returned ID.
  - Sequential replay -> same ID; changed-body replay rejected.
  - Two deliberate same-text sends -> two separate messages.
  - Anonymous, non-participant and forged guardian-mode attempts rejected.
  - Genuine email-bound guardian invitation accepted; sending before approval
    rejected; approval allowed sending; 10 concurrent retries -> one guardian
    message with the correct ward sender; revocation blocked a new send.
  - Banned sender could not replay a successful receipt.
  - Mixed legacy/new traffic: 60 sends accepted, next 4 rejected in one fresh
    server minute. Test concurrency was bounded to four for this check.
  - All 10 disposable Auth/public accounts and the temporary bucket cleaned up.
- `test/live_refresh_controller_test.dart`: executable fake-clock tests for
  burst coalescing, trailing refresh, pause/resume/disposal, error behavior,
  jitter, no healthy polling, and operation-ID preservation.
- `test/chat_typing_presence_test.dart`: includes a disposed-route/late-auth
  regression test alongside typing and profile navigation widget tests.
- `test/chat_message_page_test.dart`: executable gap recovery, cursor, history
  continuity and local-retry preservation tests.
- `tool/realtime_hold_gate.test.mjs`: all 9 socket-capacity oracle tests pass.
- Final Flutter full-suite on 6 September: **500 tests passed** (unit, widget and
  source-contract checks; this number is not concurrent users). Evidence:
  `build/architecture-flutter-final-tests.log`. **Flutter analyzer: no issues**,
  recorded in `build/architecture-final-analyze.log`.
- Read-only staging verification on 6 September confirms the new endpoint is
  authenticated-only, the trigger helper is not directly executable by members,
  both have an empty fixed search path, private receipts are unreadable by anon
  and authenticated roles, and zero orphan receipts or audit-run accounts remain.
  Raw CLI evidence: `build/architecture-staging-db-verification.json`.

### Database lint classification (not an all-green database claim)

`supabase db lint --linked --schema public,private --level error --fail-on error`
reported **six diagnostics**, all in PostGIS utilities: two `st_findextent`
overloads, `populate_geometry_columns`, `postgis_full_version`, `lockrow`, and
`addauth`. No app-owned function, including migration 258's functions, appeared
in that error-level result. Extension ownership was checked through
`pg_depend`/`pg_extension`, not guessed from names. Repository searches found no
application call sites for these utilities.

These are unassigned-record / optional-object diagnostics, not evidence that a
tested chat operation failed. They remain in the raw lint result; they have not
been silently suppressed or declared proven false positives. Managed extension
functions were left unchanged. Any future use of these utilities needs targeted
runtime validation or provider-supported extension maintenance. Evidence:
`build/architecture-staging-db-lint.log`, with the read-only verification SQL in
`tool/verify_architecture_database.sql`.

The staging checks above validate server behavior with authenticated test
accounts. They do not certify radio loss, process death, OS notification delivery
or upgrade behavior on the eventual signed Android build. Message retry UUIDs
are retained in the current screen/session, not a new persistent offline outbox.

## Provider limits and unresolved capacity boundaries

As checked on 5 September 2026, Supabase publishes 200 concurrent Realtime
connections for Free, 500 for Pro with a spend cap, and 10,000 for Pro without a
spend cap. These are quotas, not a benchmark of this app's database/throughput.
No paid upgrade or removal of the spend cap has been authorized or performed.
See [Supabase Realtime limits](https://supabase.com/docs/guides/realtime/limits).

The earlier 1,000-socket shared-hold test on the current staging limits failed:
only 150 sockets satisfied the entire common hold, with quota/subscription
failures recorded. Separate successful API, upload, chat and queue tests do not
turn that into a 1,000-connected-user pass. See `load-tests/SCALE_BASELINE.md`.

Additional scaling considerations remain:

- Guardian notifications still use an RLS-protected subscription to the whole
  messages table; guardian dashboard results also are not paginated. These are
  not new leaks introduced by this patch, but they must be included in the next
  combined capacity workload. A large guardian workload may warrant scoped
  broadcasts and dashboard pagination.
- The pinned Dart Realtime SDK owns socket retry timing. Recovery-read jitter
  in this change does **not** add jitter to the SDK's reconnect handshake. A
  reconnect storm therefore remains a specific post-upgrade test case.
- Postgres Changes authorization cost scales with subscribers; increasing
  compute alone is not a promise of proportionally higher change throughput.
  [Supabase scaling guidance](https://supabase.com/docs/guides/realtime/postgres-changes#scaling-postgres-changes)
  recommends benchmarking and considering Broadcast for large fan-out.
- New screens/features, a changed traffic mix, more retained data, many devices
  per person and external-provider outages can require future engineering. A
  promise that no code will ever need changes would be misleading.

## Safe release / upgrade sequence

1. **Backend deployment completed on 6 September:** production backup verified,
   migrations 256–258 applied, and read-only/anonymous HTTP checks passed. Old
   installed clients keep their existing RPCs; the shared server send-rate guard
   applies immediately. Lost-response retry protection requires the new client.
2. Build with the existing guarded production configuration and correct signing
   key. Test send/lost-response retry, background/resume, airplane-mode recovery,
   chat back-navigation, guardian transcript and photo requests on both devices.
   No AAB upload is part of this audit.
3. When the owner authorizes the paid quota configuration, upgrade the same
   project and verify its effective connection/join/message limits. Do not
   change the app URL/key merely because the plan changed.
4. Repeat a combined workload with sufficient distinct identities, sustained
   1,000 authenticated chat sockets, reconnect bursts, chat/read receipts,
   Discovery, guardian traffic, notification backlog and uploads. Verify p95/p99,
   errors, cleanup and cost before certifying that operating envelope.
5. Keep quota/backlog alerts and an explicit budget decision. A larger quota
   permits more usage; it does not make that usage free.

### Device evidence added on 7 September

Signed OnePlus build 42038 is installed. Five full chat cycles, ten faster
open/back cycles, three chat background/resume cycles and photo-request
navigation/background checks showed no accumulating Supabase connections.
503 Flutter tests passed; analyzer reported no issues. The [device audit](oneplus_connection_audit_20260907.md)
records the APK checksum, raw socket evidence and explicit limits. This is not
a substitute for the remaining genuine Guardian-device, radio-loss, billing
or post-quota-upgrade combined capacity tests above.
