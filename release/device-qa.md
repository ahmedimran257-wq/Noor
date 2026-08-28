# Physical-device release QA

Record device model, Android version, app version, tester, date and evidence for
each run. Test the signed release build—not a debug build.

## Installation and startup

- [ ] Clean install launches without a missing-services warning.
- [ ] Existing signed-in session returns to the correct profile after restart.
- [ ] Offline cold start shows the offline experience and, after reconnecting,
      restores the existing session instead of routing to sign-up.
- [ ] Upgrade from the previous installed build preserves auth and user data.
- [ ] App links from `https://silarah.com/...` open the expected in-app route.

## Account and onboarding

- [ ] Sign-up sends exactly one email containing one usable OTP.
- [ ] An unfinished OTP sign-up can resume without an “already exists” dead end.
- [ ] Sign-in sends exactly one OTP and rejects an expired/replaced code.
- [ ] All five onboarding steps save and resume correctly.
- [ ] At least one safe profile photo uploads and an explicit test fixture is
      blocked/queued according to policy without a crash or generic failure.

## Core product

- [ ] Discovery returns eligible same-city and India-wide profiles.
- [ ] Same city, same state, explicit state/city, radius and View all India
      filters return only authoritative matches; outside-India controls remain
      unavailable in this release.
- [ ] Filter and bottom-tab transitions remain smooth under repeated use.
- [ ] Interest limits, reset time and premium prompt match server entitlements.
- [ ] Accepted connection opens chat; messages, realtime insert, unread count and
      typing presence work between two devices.
- [ ] Translation changes only the chosen message and handles provider failure.
- [ ] Multiple profile photos swipe for owner and authorized viewers.
- [ ] Photo privacy modes are enforced from a second account, not only hidden in UI.
- [ ] Notification insert appears live as a badge/banner/list item and routes correctly.

## Safety, billing and lifecycle

- [ ] Report, block, pause, resume, suspend/ban/shadowban standing UI and appeals work.
- [ ] Human profile-photo review exposes only the temporary look/smile/blink
      evidence required for a reviewer decision and enforces the 48-hour limit.
- [ ] RevenueCat Test Store purchase, renewal, cancellation, restore and expiry update
      both app entitlement and Supabase webhook state exactly once.
- [ ] Transactional purchase email is sent once per event.
- [ ] A controlled non-fatal and controlled test crash appear in Crashlytics for
      this exact version; release symbols/mapping are present.
- [ ] Delete account schedules deletion, signs out and documents the recovery window.

## Performance and data cost

- [ ] No unexpected repeated network calls while idle on each main tab.
- [ ] Images load from cached/signed URLs without unbounded refetching.
- [ ] A 15-minute navigation/chat/photo session has no ANR, memory kill or visible
      sustained jank in Android Studio profiler.
- [ ] Validate on at least Android 8 (API 26), a current Android version and one
      low-memory physical device before production rollout.
