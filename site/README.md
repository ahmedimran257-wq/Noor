# Silarah public site

Static Cloudflare Pages project for `silarah.com`.

- Build command: none
- Output directory: `site`
- Production domain: `silarah.com`

## Production domain topology

- `silarah.com` serves this public site and is the canonical origin.
- `www.silarah.com` is a permanent redirect to the matching path and query on
  `silarah.com`; it must never serve an independent copy.
- `app.silarah.com` serves the Flutter web application from the
  `silarah-app` Cloudflare Pages project.
- `admin.silarah.com` serves the staff console.
- `mail.silarah.com` is the authenticated Brevo transactional sending domain.
- `news.silarah.com` is the authenticated Brevo marketing sending domain.
- `silarah.com/sitemap.xml` lists public, indexable pages only. The app and
  staff console are intentionally excluded.

The Android asset link currently contains the development/release-debug signing
fingerprint used before Play Console enrollment. Add the Play App Signing SHA-256
fingerprint before publishing the store build. Add an Apple App Site Association
file after the Apple Developer Team ID is available.
