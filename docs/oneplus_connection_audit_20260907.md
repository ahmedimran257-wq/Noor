# OnePlus signed-release connection audit — 6–7 September 2026

## Verdict

**No accumulating Supabase connection leak was observed in the tested ordinary-member journeys.** Actual device socket inventories show a settled connection while a live screen is open, closure when it is left/backgrounded, and a replacement connection after resume—not an increasing collection of old connections.

This is bounded evidence, not a claim that the entire application is perfectly optimized, universally bug-free, or capable of 1,000 concurrent users on its current provider quota.

## Exact installed artifact

- OnePlus 8 / IN2011, Android 13; package `com.silarah.app`.
- Signed **release**, Android version code **42038**. The Flutter build number is 40038; the arm64 split adds its normal 2000 version-code offset.
- Built 6 September with production configuration and the existing release-signing guard. Installed successfully using an in-place update; account/app data were not cleared.
- APK: `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`, 75,391,115 bytes.
- APK SHA-256: `8a619f4539383f72aff07ab3b1d31784426c4acb1685511aa125442f9ae6640c`.
- Signing certificate SHA-256: `0cf07cc5c3700fb7f509de467968c1c452efc7e0a1a6c795e318bcf17384a922`.
- `apksigner verify`: successful APK Signature Scheme v2 verification. Installed package is **not DEBUGGABLE**, independently checked by every measurement run.
- No AAB was uploaded. No subscription purchase, new account, artificial message, paid-plan change or quota stress test was performed in this device audit. Normal app reads, presence and read-receipt operations still occur when navigating an existing account.

## Measurement method

The local ADB sampler reads both `/proc/net/tcp` and `/proc/net/tcp6`, retaining only Silarah's UID-owned sockets. It records timestamps, process ID, socket state/inode and Android PSS/RSS. An unreadable or malformed inventory fails the measurement; it cannot be misreported as zero.

Production DNS was resolved on both days: `104.18.38.10`, `172.64.149.246`, and their mobile-network DNS64 equivalents. Classification includes native IPv4, IPv4-mapped IPv6 and the observed `64:ff9b::/96` prefix. These are **IP-level TCP counts**, including HTTPS requests, not an unencrypted protocol trace or an SDK channel counter. Other service sockets are retained in the evidence instead of silently excluded from total counts.

The repeated journey runner inspects the current Android accessibility hierarchy before opening the previously observed active conversation and verifies the destination/return screen. No screen result is inferred only from a tap. The faster repeated test is still limited by UI-hierarchy observation time (roughly 10 seconds per open/back cycle); it is not a sub-frame gesture-race test.

Device samples generally occur about every 5–6 seconds. The settled phases are 25–45 seconds. The two days are **separate sessions**, not an overnight continuous soak. The app was stopped at the start of 7 September and relaunched with its existing session intact.

## Physical-device results

| Journey | Measured result |
| --- | --- |
| Discovery, 45-second settled observation | 0 Supabase connections in all 9 samples |
| Initial conversation open / Back | Settled at 1 Supabase connection; original socket released and inbox visibly restored |
| 5 additional full conversation cycles | Each open settled at 1; each original socket was absent from **every** sampled post-Back inventory |
| End of those 5 Back phases | 4 ended with 0 total app TCP sockets. One had a different transient Supabase socket; it was not the previous chat socket and disappeared before the next settled open |
| 10 faster open/back cycles | All 10 returned to the inbox; final 30-second idle observation ended at 0 total app TCP sockets, 0 connecting, 0 CLOSE_WAIT |
| 3 background/resume cycles with chat open | Each settled pause: 0 Supabase connections. Each settled resume: 1, with a new socket inode |
| Photo requests: 2 openings | Each settled at 1 Supabase connection; Back restored Settings and released the photo-screen socket |
| Photo requests: background/resume | Settled background: 0 Supabase connections; settled resume: 1 new connection; photo-access UI restored |
| Final Discovery check, 7 September | After the navigation request settled, 0 Supabase connections through the rest of the 45-second observation; final total was 1 non-Supabase HTTPS socket, 0 connecting and 0 CLOSE_WAIT |

The transient socket in chat cycle 4 is explicitly preserved: the open socket inode was `148240757`; the later post-Back socket was `148283591`. The original socket was never retained in any post-Back sample. The next open used `148287504`; the transient socket was gone. This distinction prevents ordinary request traffic from being mislabeled as either a leak or a completely idle network.

Other services temporarily maintained established/CLOSE_WAIT sockets. During the 6 September repeated chat run these also returned to zero. A remaining third-party service socket must not be described as a Supabase Realtime connection merely because it belongs to this app.

The final 7 September sample was captured at `2026-09-07T04:18:30.428Z` (09:48:30 India time), with the app restored to Discovery. A non-Supabase connection to `18.161.229.54` remained established. It did not accumulate across the inspected samples, but this audit does not certify every third-party SDK's connection lifetime.

### Memory and process stability

- 6 September warm Discovery final PSS: approximately **252.1 MiB**.
- End of the ten faster chat cycles: **233.2 MiB**.
- Three chat background PSS readings: **145.7, 145.4, 147.4 MiB**.
- Three resumed chat PSS readings: **215.9, 217.6, 204.9 MiB**.
- The same app process remained alive throughout each day's measured session. There was no increasing per-cycle PSS trend in these observations; this is **not a heap-retention proof**.
- PID-scoped log checks on 6 September found no current-session crash indicators. On 7 September, the checked 619-line current-process log contained 0 crash indicators and 0 matched Realtime/auth-subscription errors. Historical process exits were inspected separately; older records must not be called crashes caused by this test.

## Automated evidence

- **503 Flutter tests passed** on 6 September, including unit, widget and source-contract checks. These are not 503 physical-device users or end-to-end scenarios.
- **46 targeted tests passed** for socket lifecycle, live refresh, pagination, typing, route disposal, back navigation, data-cost safeguards and scaling contracts. These overlap with the full suite; do not add the counts together.
- **Flutter analyzer: no issues found**.
- **4 Node measurement tests passed**: app-UID isolation, socket states, fail-closed unreadable inventory and IPv4/IPv6/DNS64 peer classification.
- The added SDK integration test uses the pinned production Realtime SDK against a real **local loopback WebSocket server**: 40 join/remove cycles returned actual server sockets and client channels to zero after each removal; peak server socket count was 1. Two active channels shared one transport, and removal without a server leave acknowledgement still closed it. These local tests consume no Supabase quota. They do not substitute for production authentication tests.

## Existing cost controls verified in source/tests

- One Supabase initialization; channel creation is limited to active chat, photo requests and the Guardian dashboard. Discovery, ordinary inbox, notifications and account-standing views have no permanent Realtime subscription.
- Chat is scoped to the currently open conversation. Leaving it removes the SDK channel rather than only unsubscribing and leaving an idle transport.
- Foreground health checks: 5 minutes when healthy; presence heartbeat: 10 minutes, with duplicate-state suppression. Background timers stop.
- Healthy live screens do not poll. Failed-channel recovery uses bounded, jittered reads and single-flight/coalesced refresh work.
- Notifications, signed-photo URL caches and relationship queries have explicit limits, account scoping and batched reads.
- Previously deployed migration 258's retry-safe send and actor rate guard remain documented in the production deployment report. This audit did not rerun a provider-load or payment test.

These are specific optimization measures, not a measured monthly-cost guarantee. Provider usage depends on actual users, payloads, photos, notifications and traffic mix.

## Quota warning context

The signed-in usage dashboard inspected earlier on 6 September showed organization peak Realtime usage of 320 against an allowance of 200: **production peak 3, staging peak 317**. That historical staging-test peak explains the displayed over-quota situation; it is not evidence of an accumulating production-device connection leak. The dashboard was not used as a live per-device socket counter. No new large socket test was run to investigate the warning.

## Limits and follow-ups

- A genuine Guardian-account physical-device journey was not run in this audit. Its separate authorization and dashboard flow must not be counted as a member-chat pass. The earlier authenticated staging Guardian checks are separate evidence.
- No new incoming photo request was generated; the photo screen had an empty request list. This verifies subscription lifetime/navigation, not approval/revocation/event-delivery functionality.
- Expired-session refresh during backgrounding, airplane-mode/radio loss, OS-kill recovery, reconnect storms, multi-day soaking, all OEMs and 1,000 simultaneous authenticated devices are not certified by this run.
- No new two-person message/FCM delivery, billing or payment-provider test was performed here.
- The previously documented Guardian broad message subscription/unpaginated dashboard and provider-capacity boundaries remain. No promise is made that future growth will never require code changes.
- Separately observed accessibility follow-up: the Profile Settings gear is clickable but has no accessible text label in the Android hierarchy. This is not a connection leak; this measurement-only pass did not change app UI source.

## Evidence location and reproduction

All raw evidence is local and gitignored in `audit_artifacts/connection-audit-20260906/`. It includes app screens and should not be published wholesale.

- `apk-signature.log`, `full-tests.log`, `targeted-tests.log`, `analyzer.log`.
- `release-discovery-idle.json`, `release-conversation.json`, `release-chat-back.json`.
- `cycle-1-open.json` through `cycle-5-closed.json`, `journey-chat.json`.
- `journey-rapid.json`, `rapid-final-idle.json`.
- `journey-background.json`, `background-*-paused.json`, `background-*-resumed.json`.
- `sep7-photos-*.json`, the corresponding UI captures, and `measurements.ndjson`.
- 49 earlier reports preserved under `prebuild-reports/` before the clean Android build removed the old build directory.
- `sep7-final-idle.json` and `verified-summary.json`, including the nonzero final **total** socket count rather than hiding it behind the zero Supabase count.

Use `tool/android_connection_audit.mjs` for individual samples/watches. The bounded journey script is intentionally tied to this authorized, inspected device/conversation; re-inspect the UI and update the explicit artifact gate before using it with another build/account. No account secrets or packet decryption are required.

`node tool/summarize_android_connection_audit.mjs` recomputes the summary from the raw files, asserts the measured cleanup results, checks completed cycle counts/test logs, and verifies the APK checksum. This reproducibility check passed on 7 September; it performs no device or server operations.
