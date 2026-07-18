# Silarah Android release package

This directory contains the reproducible, non-secret material needed for the
first Google Play submission. It deliberately does not contain the upload
keystore, passwords, production API keys, tester credentials, or identity
documents.

## Build identity

- Application ID: `com.silarah.app`
- App name: Silarah
- Version source: `pubspec.yaml`
- Upload key alias: `silarah-upload`
- Upload SHA-1: `B9:29:81:CA:8D:5F:D8:A9:E8:EF:76:A1:42:C3:04:94:2B:BD:BC:1C`
- Upload SHA-256: `0C:F0:7C:C5:C3:70:0F:B7:F5:09:DE:46:79:68:C1:C4:52:EF:C7:E0:A1:A6:C7:95:E3:18:BC:F1:73:84:A9:22`

The signing properties are read from
`%USERPROFILE%/.silarah/release-signing/key.properties` or the path supplied in
`SILARAH_SIGNING_PROPERTIES`. Never copy that file or the `.jks` into Git.

Before the first upload, make two encrypted offline backups of the `.jks` and
store the password separately. Google Play App Signing protects the app-signing
key, but losing the upload key still creates an avoidable recovery incident.

## Release command

```powershell
.\tool\build_android_release.ps1 `
  -Config config/dev.local.json `
  -UploadCrashlyticsSymbols
```

The script refuses placeholders and RevenueCat Test Store keys, uses the
external permanent signing identity, writes Dart symbols outside the repository,
and opts the release task into Crashlytics mapping/native-symbol upload. Run the
automated checks in `release-checklist.md` before creating the final bundle.

## Submission material

- `play-listing.md`: store title, descriptions, category and contact details.
- `data-safety.md`: a conservative answer worksheet to copy into Play Console.
- `reviewer-instructions.md`: review access and deterministic test paths.
- `device-qa.md`: pre-release physical-device acceptance checklist.
- `release-checklist.md`: final owner sign-off, including account-only actions.
