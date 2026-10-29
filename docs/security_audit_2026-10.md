# Silarah security audit — October 2026

Date: 29 October 2026. Branch `release/42045`, starting at `fe1343d`.

## How this was done

- **Method.** I followed Cloudflare's security-audit skill, installed from `github.com/cloudflare/security-audit-skill`. I used its rules: every finding needs a real boundary and a concrete result, severity follows its scale, and nothing was tested against live servers. To keep costs down I ran it as one reviewer, not the skill's full multi-agent pipeline. That means no `findings.json` or coverage-ledger files were produced.
- **Scope.** The whole repository:
  - the Flutter app (`lib/`, Android manifest);
  - all SQL migrations, cross-checked against the live staging catalog (grants, RLS policies, SECURITY DEFINER functions, `search_path`);
  - all edge functions, both in source and as deployed;
  - the admin panel's server-key use.
- **Verification.** Every finding was reproduced on staging (`ykmgkrveucslglxvcyss`) inside a transaction that was rolled back, so no test data was left behind. The same checks were re-run after the fix. Production (`jukpscfxzwttgtxvrbmj`) was only read: function permissions and definitions, and the list of deployed functions. The affected functions there are byte-identical to staging, so the same gaps existed in production until `280` was applied there (see below).

## Findings

| # | Severity | What was wrong (plain words) | Where | Status |
|---|---|---|---|---|
| 1 | Medium | After you block someone, they could still load your photos through an old interest, a closed match, a bookmark or an earlier photo grant. | `get_authorized_photo_paths` (used by `get-signed-url`) | Fixed in `280`, verified on staging, applied to production 29 Oct |
| 2 | Medium | Any signed-in member could ask "can member X see member Y's private photos?" for any two people. That reveals whether two other members are matched or have shared photos. | `can_view_photo` | Fixed in `280`, verified on staging, applied to production 29 Oct |
| 3 | Low | A blocked member could keep sending you photo-access requests, and each request notified you. | `request_photo_access` | Fixed in `280`, verified on staging, applied to production 29 Oct |
| 4 | Low | A billing-email worker function was callable by members. Anyone who knew a RevenueCat event id could read that email's purchase details (product, price, expiry) and hold the email back from sending. The event id is hard to guess, which keeps this Low. | `claim_transactional_email` | Fixed in `280`, verified on staging, applied to production 29 Oct |
| 5 | Low | Any member could read a "reporter trust score" for any other member. The score partly reflects how many open reports exist against that person. | `compute_reporter_trust_score` | Fixed in `280`, verified on staging, applied to production 29 Oct |
| 6 | Informational | Root cause of #4 and #5: Supabase gives signed-in members execute rights on every new function. The old migrations only removed the PUBLIC grant, so 15 more worker functions stayed callable by members. Each of those checks `service_role` inside, so none could be misused. | 17 functions listed in `280` | Member access removed in `280`, verified on staging, applied to production 29 Oct |
| 7 | Informational | The chat-topic check trusted a caller-supplied user id (an attacker would also need a match id). | `can_access_chat_realtime_topic` | Bound to the caller in `280`, applied to production 29 Oct |
| 8 | Low (cleanup) | Production still runs `verify-firebase-phone`. Its code was deleted from the repo and the database functions it needs no longer exist, so every call fails. It is dead code and should be removed. | production edge functions | Deleted from production 29 Oct |

The fix is in `supabase/migrations/280_security_audit_hardening.sql`. The regression test is `test/security_audit_2026_10_test.dart`. Among other things, the test fails if a future migration grants a function only to `service_role` without also removing member access.

### Staging verification (after `280`)

- **Finding 2 (`can_view_photo`).** A stranger asking about the owner now gets `false`. The owner asking about themselves still gets `true`.
- **Findings 4 and 5.** Calling `claim_transactional_email` or `compute_reporter_trust_score` as a member is now denied.
- **Finding 1 (photos after a block).**
  - Before the block, a matched viewer gets 1 photo path.
  - After the owner blocks them, they get 0.
  - The owner still gets their own photo.
- **Finding 3 (photo requests).** A blocked member's photo request is now refused with the normal "not accepting requests" message, so the block is not revealed. An unblocked member's request still goes through (`pending`).
- **Supabase security advisor.** No new errors. The only ERROR is still `spatial_ref_sys`, which you are raising with Supabase support.

## Production (approved and done, 29 October)

1. Migration `280` was applied to production, and `schema_migrations` now shows version 280. A fingerprint of every changed function's definition and permissions is identical on production and staging. The only three of those functions members can still call are the caller-checked ones: `can_view_photo`, `can_access_chat_realtime_topic` and `request_photo_access`.
2. `verify-firebase-phone` was deleted from production and no longer appears in the function list.

## Hardening notes (not vulnerabilities, no change made)

- **Leaked-password protection is off.** This is a Supabase Auth setting that is only available on the paid plan.
- **RevenueCat webhook secret check.** It uses a plain string comparison rather than a constant-time one. Timing it over the internet is not practical, but a constant-time compare would be tidier.
- **Photo moderation.** A new photo goes live on the device's own safety score and is then moderated. A modified app could send a false score, so the quality of moderation depends on the moderation queue. This is a design choice, not an access bug.
- **Premium status is visible.** `interest_daily_limit` and `profile_view_daily_limit` can tell a member whether another member has Premium. This is low-value information and was left alone because other functions depend on them.
- **Private typing channel.** Staging has no `realtime.messages` policies. That means the private typing channel can only fail closed: it may not work, but it cannot leak.

## Checked and found fine

- **Tables.** RLS is on for every public table except `spatial_ref_sys`. Members have no direct read access to `profiles`. Profile data only comes out through checked functions, and the edit functions (`patch_my_profile`, `patch_my_user`) accept only an allowlist of fields. Members cannot set `subscription_status`, verification or ban fields.
- **Premium.** Paid features are checked on the server through `has_active_premium`, which covers chat (`can_open_chat`), discovery filters, compatibility insight, shortlist and incognito. Subscription state is written only by the RevenueCat webhook. The webhook checks a 32+ character secret plus the app id, environment, entitlement, product and store allowlists. It also applies events atomically and in order, and the double-charge guard is in place.
- **Photos and storage.**
  - All four buckets are private, with size and type limits.
  - Signed URLs are issued only by `get-signed-url`. It takes member ids rather than file paths, re-checks access on every request, rate-limits, and expires links after 5 minutes.
  - Uploads go through reservations. `validate-photo-upload` checks the path prefix, JPEG format and dimensions.
- **Photo verification.** It uses per-member random paths, rate limits and owner-checked submission ids. Captures are purged after review.
- **KYC.** The old KYC and DigiLocker flows have been removed, and none of those functions are deployed.
- **Chat.** Reading and sending use `can_open_chat`, which requires a match member, active status, no ban and guardian approval where needed. Sends are rate-limited and idempotent. Base-table RLS limits messages to the sender, the receiver, or a current guardian.
- **Guardian (wali).** To accept an invitation, the guardian needs the hashed one-time code and a verified email that matches the invited one. Wrong-email attempts lock the invitation after 5 tries. The guardian chat view requires a current guardian mirror.
- **Referrals.** The anonymous code check is rate-limited. Members cannot refer themselves or apply a code after onboarding.
- **Sign-up.** The anonymous consent functions are rate-limited and strictly validated.
- **Edge functions.**
  - Every scheduled job checks a vault-backed cron secret with a constant-time compare.
  - `dispatch-notifications` lets a member trigger only their own fixed "profile live" message, at most 5 a day.
  - `location-search` calls only one fixed provider, so it cannot be pointed at other servers (SSRF). It is rate-limited and caps the response size.
  - `translate-message` is retired and returns 410.
  - `health-probe` reveals nothing.
- **Discovery and search.** Both reject a viewer id that is not the caller's own.
- **Admin panel.** The service key is used only on the server after `requireAdmin` and role checks. Admin functions check `is_active_admin`. The login rate limiter uses the trusted Cloudflare IP header.
- **App.**
  - Android backups are off.
  - No service keys or secrets are in `lib/`. The APK holds only the anon key, as checked earlier.
  - External links open in the system browser, and there is no WebView bridge.
