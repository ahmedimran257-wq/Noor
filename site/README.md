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

The Android asset link contains both the upload-certificate and Play App Signing fingerprints.

## Localisation and edge personalisation

- `/hi/` and `/ur/` are built by `python tool/build_site_languages.py`; policies
  stay in English, which governs.
- `_worker.js` names an Indian visitor's state on the home pages, explains to
  visitors outside India that Silarah is India-only, and offers Hindi or Urdu
  to matching browsers. Crawlers receive the unpersonalised page.

## Search

After each deploy, run `node tool/indexnow_submit.mjs` to notify IndexNow
engines. Google discovers changes through the sitemap in Search Console.
