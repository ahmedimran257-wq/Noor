# Navigation and introduction review — 13 September 2026

## Recording diagnosis

Reviewed the supplied 14.13-second WhatsApp recording, including frame sequences
around 3.25–3.65 seconds (Notifications back) and 7.7–8.1 seconds (profile back).

- Notifications faded over the feed while both screens also translated. Text
  and controls from both surfaces were visible in the same place.
- The profile gallery flew into a card with a different crop and gradient. Its
  uncropped, brighter image appeared during the flight, independently of the
  page's fade. This produced a visible photo pop and overlapping content.
- The recording is variable-frame-rate (about 27 fps on average). It establishes
  these visual defects, but is not a reliable rendering-performance benchmark.

## Changes

- GoRouter now creates Material pages using the same theme transition as
  imperative routes. Notifications, profiles, editing, photos, chat and help
  share Flutter's gesture-aware Cupertino transition, including RTL and swipe
  cancellation. Whole-page cross-fades and scale effects are removed.
- The profile gallery stays within its opaque page instead of flying between
  differently cropped photo surfaces. Card text never participates in a Hero.
- Modal sheets retain their drag-aware movement without an additional content
  fade/scale. The product guide sizes to its content bounds, without outlining
  the entire screen behind the sheet.
- The welcome offers an optional, scrollable three-part product guide. Existing
  members can replay it from Help & Support; registration is not forced through
  a carousel.
- Help includes interests, photo privacy, profile views, Guardian connection,
  and safety guidance, with member-only links to the relevant controls.
- Contextual tips occupy their own bounded, scrollable dock above navigation;
  they no longer cover profile actions. Existing interest/chat usage suppresses
  introductory tips unless replay was explicitly requested.
- Replay resets only the current account's guidance state and updates the
  already-mounted home screen. No profile, database, or other-account data is
  cleared.
- Height and mother tongue remain outside the optional details disclosure.
  Saved optional values are preserved. Photo setup displays the selected photo
  audience before Continue/Save. Profile ownership distinguishes the person
  seeking marriage from a separately invited Guardian.
- New guide copy covers all ten shipped locales. Small-phone, large-text,
  theme, RTL, and reduced-motion checks cover the new surfaces.

## Verification

Focused navigation tests passed: opaque push/pop, monotonic frame geometry,
cancelled edge swipe, mixed router/imperative navigation, RTL, reduced motion,
and prevention of the mismatched profile Hero.

Focused guide tests passed for all themes with large text, account-isolated
replay, photo-audience selection, and optional-field preservation. Visual review
used the real Inter/Playfair fonts and Material icons, not the test fallback font.

Final automated verification:

- `flutter analyze --no-pub`: no issues.
- `flutter test --no-pub --concurrency=4`: **539/539 passed**.
- The old sheet test was updated to require native sheet timing, reduced-motion
  support, and no additional fade/scale; its blur and idle-animation guards remain.

### Signed release installed

- Production Firebase configuration verified before building; the Android
  billing key was checked for its production prefix without printing it.
- `flutter build apk --release --split-per-abi --target-platform android-arm64
  --dart-define-from-file=config/prod.local.json` succeeded.
- Artifact: `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`.
- Version: `1.0.0 (42041)` on ARM64; source version `1.0.0+40041`.
- Size: 75,390,977 bytes.
- APK SHA-256:
  `55e438efb54a20c5a87d15b4c976074ca6a95af9398ed9e9345240aa779b25a0`.
- APK v2 signature verified against the Silarah Android Upload certificate;
  certificate SHA-256:
  `0cf07cc5c3700fb7f509de467968c1c452efc7e0a1a6c795e318bcf17384a922`.
- Installed with `adb install -r` on the connected OnePlus IN2011, Android 13.
  Package inspection confirmed version code 42041. Login and app data were
  preserved; the existing Black & White theme was left unchanged.

### Physical-device review

- Recorded Notifications → back → Discover and profile → back → Discover in
  the signed release. Each navigation action verified the current app/screen.
- Dense frame review showed opaque pages moving continuously without the
  original overlapping text or uncropped photo flight. Both routes returned
  to Discover correctly. This is visual verification, not a frame-time benchmark.
- Opened Settings → Help Center → View guide. Verified the three steps,
  privacy/Guardian note, readable layout, contained sheet outline, and working
  Done button on the actual phone.
- Replayed first-use tips from Help. Returning to the already-mounted Profile
  screen immediately displayed the correct tip in its reserved dock above the
  navigation bar, without covering profile actions. Dismissed it using Got it.
- The inspected app-process log buffer contained no Flutter error or fatal
  Android exception lines after these checks.
- Local evidence directory:
  `C:/Users/imran/AppData/Local/Temp/silarah-motion-ibzt5jpx/`.
  The verified recording is `after-verified.mp4`; frame sheets are
  `notification-return-full.png` and `profile-return-full.png`; final device
  screenshots are `guide-device-final.png` and `tip-device-final.png`.
  Full test output is `final-tests.log`.

Automated geometry checks and recordings are not a claim of measured 60/90 fps,
testing on an Apple device, or complete Play Console readiness. This pass did
not upload an AAB or publish a store release.
