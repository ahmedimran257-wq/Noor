# Extended OnePlus connection and Guardian verification — 8 September 2026

Status: **bounded device checks reviewed on 9 September; findings remain open. No completed uninterrupted 60-minute pass is claimed.**

## Scope and safeguards

- Owner authorized one uninterrupted 60-minute OnePlus test and isolated staging Guardian accounts.
- Ordinary-member soak uses the existing signed production release, Android version 42038. No artificial production members/messages, paid quotas, or store uploads.
- Original production APK preserved at `audit_artifacts/guardian-device-20260907/original-production-42038.apk`; SHA-256 `8a619f4539383f72aff07ab3b1d31784426c4acb1685511aa125442f9ae6640c`.
- Guardian testing uses only three run-tagged staging identities: ward, counterpart, Guardian. Only the ward and counterpart have discovery profiles; one fixture conversation exists.
- A signed staging build used the staging Supabase project with billing keys disabled. Production/staging Supabase auth storage keys are project-scoped in the pinned Flutter SDK. No uninstall or app-data clearing is authorized. Production restoration is recorded separately below.
- Guardian fixture authentication uses genuine staging sessions and the app's existing HTTPS callback. This is **not** evidence of end-to-end email delivery or ordinary signup consent completion. No email sends to fake addresses were requested.
- Staging APK compiled and was installed on 8 September: SHA-256 `9509168f33a8cfc608ea858a4096bfa148329bdc8554da5c8eb6346a138f8a05`. Signature Scheme v2 verified; signer certificate matches the production APK. Inspection of `libapp.so` found the staging Supabase URL and no production Supabase URL. Preserved as `audit_artifacts/guardian-device-20260907/staging-42038.apk`.

## Run accounting

1. 7 September: runner disappeared before next-day resume; last saved sample at 17:17:03 India time, approximately 16 minutes after start. Marked interrupted. Cause not established; not called an app crash or completed soak.
2. 8 September, 09:20 start: stopped when the expected Discovery screen changed. Owner confirmed using the phone. This disturbed run is excluded from uninterrupted-test certification.
3. 8 September, 09:24:40 start: completed Discovery (5 minutes) and held chat (35 minutes). Interrupted in background at 10:06:14. Android exit history identifies PID 29160 at 10:06:04.936 as `USER REQUESTED / REMOVE TASK`, not a crash. The record does not identify the actor. Original run remains interrupted, never relabelled as a completed hour.
4. At the owner's explicit request to continue without restarting, a separate remaining-phase run began at approximately 14:44. It skips the completed Discovery and 35-minute chat stages. Its one-minute re-entry baseline completed. A sampler/ADB failure interrupted background measurements after 276 seconds; the saved final sample has zero established and zero CLOSE_WAIT sockets. ADB transport changed from 1 to 2; app PID 6956 remained unchanged. This is a measurement gap, not evidence of an app crash.
5. At 14:52:59, continued the 324 unmeasured background seconds, then the pending resume (8 minutes) and inbox cleanup (2 minutes). These remaining phases completed and were reviewed. Earlier phase data remains in its original directory. These segments cannot be stitched into uninterrupted-hour evidence.

### Preserved measurements from the interrupted morning run

- 548 samples in checkpointed chunks; maximum observation gap 23.131 seconds.
- Held chat: 470 samples spanning 2,097.233 seconds; the same Supabase socket inode `154614295` appears throughout. 456 samples contain one established Supabase socket, 12 contain two, and two startup samples contain four. Other sockets were short-lived, not an accumulating tail.
- Held-chat CLOSE_WAIT: zero. First/last five-minute median PSS: 209.34 / 208.49 MiB. This does not show upward PSS growth within this window; it is not a heap-leak proof.
- Background: 15 checkpointed samples spanning 61.699 seconds before interruption. The held-chat inode is absent throughout. Three transition samples have two other Supabase sockets; the remaining 12 have zero. Final PSS 118.45 MiB.
- Discovery briefly had up to three CLOSE_WAIT sockets, which cleared before the end of that phase. This is retained in the evidence rather than described as zero throughout.
- Exit-history excerpt: `audit_artifacts/connection-audit-20260908/soak-exit-review.json`.

Each attempt has its own raw directory under `audit_artifacts/connection-soak-*`; earlier data is not overwritten. The sampler reads both TCP families, identifies app-UID sockets and records PID, memory, states and inodes. Unavailable data, wrong screen, changed build and process restart stop the test rather than count as success.

## Completed staging pre-checks

- Authenticated ward created a Guardian invitation through the real configuration RPC.
- Wrong-email account could not accept the invitation.
- Unlinked Guardian dashboard is empty.
- Unlinked Guardian transcript RPC is denied.
- Direct message-table reads by the unlinked Guardian return no conversation rows under RLS.

## Completed continuation review

Evidence: `audit_artifacts/connection-soak-2026-09-08T09-22-59-116Z/verified-summary.json`.

- 214 samples, maximum sample gap 6.684 seconds, same PID 6956 throughout this continuation.
- Remaining background: 77 samples, all zero established sockets and zero CLOSE_WAIT.
- Resumed chat: 109 samples; one persistent Supabase inode `155936707` throughout. 105 samples have one Supabase socket; startup bursts reached 16. TCP includes HTTPS requests, so this is not evidence of 16 Realtime connections.
- Resumed-chat first/last five-minute median PSS: 188.42 / 182.38 MiB. Two transient non-Supabase CLOSE_WAIT sockets cleared after approximately 55 seconds.
- Inbox cleanup: the held-chat inode is absent in every sample. 26 of 28 samples have no Supabase connection; the last two have one new inode. This proves release of the held chat socket in this journey, not zero networking forever.

## Guardian physical findings

Evidence: `audit_artifacts/guardian-device-20260907/evidence.json`, `connection-review.json`, and the labelled device captures in that directory. Do not publish the private fixture manifest or invitation-code captures.

- Actual device invitation acceptance succeeded; the invitation could not be replayed. Approval unlocked the composer; the device-sent Guardian reply was recorded exactly once with the correct ward sender and Guardian flag.
- Ward messages arrived live before and after background/resume. Background settled to zero established sockets; resume settled to one after a short 15-socket HTTP/Realtime burst.
- Three transcript/dashboard cycles retained one common inode `157561074`; each cycle's final measurement had two Supabase sockets with the second inode changing. No accumulating socket tail was observed in those cycles.
- Revocation denied Guardian sends and transcript RPC reads, returned an empty dashboard, and the subsequent ward message did not arrive on the revoked listener during the 30-second observation.
- **Open defect:** Guardian received a “Your ward sent a message” notification for its own reply. The legacy mirror trigger does not exclude the Guardian actor.
- **Open defect:** revoked transcript retains cached content, active-oversight status and composer despite server denial. No newly sent private message was observed after revocation, but stale authorization presentation must be fixed.
- **Open defect:** Back after revocation issues a mark-seen dashboard call for an unauthorized ward. Its error path retains the old card; a subsequent unmarked refresh clears it.
- **Optimization gap:** even with no linked ward, the empty Guardian dashboard retains a Realtime connection and shows “Live”. Role-independent app resume also performs member refresh work for Guardian-only accounts.
- On 9 September, a new process restored the empty staging Guardian dashboard. Sign-out returned to the welcome screen. Its same-day established Supabase inode `158930490` disappeared; established connections settled to zero. This is a separate logout check, not an overnight continuous soak.
- **Unresolved socket observation:** one IPv6 CLOSE_WAIT inode `158932620`, already present before logout, remained through the 30-second logout sample and 45-second follow-up. Its peer does not match the measured Supabase IPv4/DNS64 endpoints. The owning SDK and eventual cleanup were not established. Do not claim all sockets cleaned up or a proven accumulating leak from this single socket.

## Cleanup and production restoration

- On 9 September, exact run ownership was checked and all three staging Auth/public accounts were deleted. Follow-up public reads returned zero rows and Auth lookups returned 404. Fixture passwords and invitation code were removed from the local manifest. `evidence.json` records `cleanupComplete: true`.
- Restored the preserved signed production APK in place on OnePlus `d2e084e7` on 9 September, without uninstalling or clearing app data. Pulled the installed APK back and verified SHA-256 `8a619f4539383f72aff07ab3b1d31784426c4acb1685511aa125442f9ae6640c`; version 42038, nondebuggable. Existing production authentication survived and Discovery loaded real profile cards, saved filters and quotas. Captures: `production-restored-20260909.png` and `production-restored-settled-20260909.png` in the Guardian audit directory.
- Restored `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` from the preserved production artifact after checking that the destination still matched the staging hash. Its final hash matches the restored device. This is restoration of the original release, not a newly fixed build; no AAB/store upload was performed.

## Evidence tools

- `tool/android_connection_soak.mjs`: bounded one-device run with UI/artifact/process guards.
- `tool/summarize_android_connection_soak.mjs`: offline full-sample review; partial runs cannot produce a completed-hour summary.
- Eleven Node checks passed (four socket-parser tests, seven soak-summary tests), including interrupted/missing evidence, process restart, retained-inode detection, continuation refusal to certify an uninterrupted hour, and explicit measurement-gap/duration validation. These are tooling tests, not eleven physical-device journeys.
- The first targeted Flutter run had 21 passes and one failure: the local loopback test server attempted to acknowledge an already-closed WebSocket (`StreamSink is closed`) and the join subsequently timed out. Its unchanged isolated rerun passed all three SDK tests. The fixture now checks the socket's open state before replying, with a deterministic closed-peer regression test. Join deadlines, the 40-cycle loop and actual zero-socket/channel assertions were not weakened. No runtime app code changed for this test-harness correction.
- After the harness correction, **23 targeted Flutter tests passed**, followed by **504 full-suite tests passed** on 8 September. The targeted tests overlap the full suite; do not add these counts. **Flutter analyzer: no issues found**. Full outputs: `audit_artifacts/connection-audit-20260908/full-tests.log` and `analyzer.log`.
- `tool/guardian_device_fixture.mjs`: staging-only exact fixture provisioning, authenticated permission checks and scoped cleanup. Private manifest is gitignored and must not be published.

## Interpretation limits

Socket samples include HTTPS keep-alive as well as Realtime. An established socket is not by itself proof of live event delivery; the separate Guardian message test addresses that path. PSS is not a heap-retention proof. No one-device result certifies all SDKs, all devices, all failures, 1,000 concurrent users, or perfect optimization. The original shorter audit remains separate evidence in `docs/oneplus_connection_audit_20260907.md`.

The installed Supabase Flutter 2.12.2 SDK contains its own `WidgetsBindingObserver`: paused/detached disconnect Realtime, resumed reconnects existing channels and rejoins them. This is why app-specific code need not manually duplicate transport shutdown. The physical background/resume observations above support that lifecycle in the tested journeys; source inspection alone is not a device pass.

No runtime app or database fixes were made for these newly identified Guardian findings during this audit. Test harness/tooling changes are not a production fix. Conclusion: ordinary chat did not show accumulating connections in the measured windows; Guardian correctness and idle-cost issues, plus the unresolved CLOSE_WAIT observation, prevent a blanket “perfectly optimized / no leaks” sign-off.
