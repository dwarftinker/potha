# Deploying the web app

The web app is hosted on Cloudflare Pages (free plan) at `https://potha.dwarftinker.com`.
It is a static site: build it locally, then upload `build/web` with Wrangler.

Don't use Pages' Git integration. Its build machines have no Flutter, and the dictionary
build needs a 3 GB download and about 4 GB of disk.

## Fit with the free plan

- Limits: 20,000 files, 25 MiB per file, 500 deploys a month, unlimited traffic.
- The build is about 52 files and 73 MB. The largest file is the dictionary
  (`assets/assets/dictionary/en.sqlite.gz`, 23.8 MiB), about 1.2 MiB under the per-file
  limit. If a dictionary build grows past 25 MiB, the upload fails.
- No redirect rules: the app uses hash URLs (`#/…`).
- No special headers: drift picks a storage that works without cross-origin isolation.
- HTTPS gives the secure context OPFS needs.

## 1. Build

From the repo root, with the full dictionary in `assets/dictionary/` (see CLAUDE.md,
"Running and testing"):

```bash
export PATH="$HOME/develop/flutter/bin:$PATH"
tool/build_web.sh
```

Always build with `tool/build_web.sh`, not `flutter build web` alone. It bundles CanvasKit
and the fonts (no Google CDN), and it fills in the service worker's file list and
version (`web/potha_sw.js`). Without that step the app doesn't work offline.

## 2. Upload

First time only:

```bash
npx wrangler login                                   # opens the browser
npx wrangler pages project create potha --production-branch main
```

Every deploy:

```bash
npx wrangler pages deploy build/web --project-name potha --branch main
```

The site is then live at `https://potha.pages.dev`.

## 3. Custom domain (first time only)

In the Cloudflare dashboard, go to Workers & Pages → **potha** → Custom domains →
**Set up a custom domain**, and enter `potha.dwarftinker.com`. Because
`dwarftinker.com` is on Cloudflare, the DNS record and the certificate are created
automatically. This takes a few minutes.

## 4. Check

1. Open `https://potha.dwarftinker.com` on the phone and open a book, so the dictionary
   downloads.
2. Switch to airplane mode and reload. The library, the reader and lookups should still
   work.

## Updates

To release an update, repeat steps 1 and 2. Open tabs keep the old version. A browser
switches to the new deploy once every tab of the app is closed.

## Notes

- Deploying publishes the dictionary file: anyone can download `en.sqlite.gz` from the
  site. It is CC BY-SA 4.0 (Wiktionary), and the credit is shown in the lookup panel and
  About.
- Wrangler writes a local `.wrangler/` folder. Keep it out of git.
