# Web deploy config (source of truth)

`vercel.json` here is the **version-controlled canonical copy** of the config
that Vercel actually serves for the web build.

The live deploy runs from `blushy-web-upload/` (a sibling of `BLUSHY_MAINAPP/`)
which is **git-ignored**, so its own `vercel.json` is not in version control.
Keep the two in sync: **edit this file**, then copy it into the deploy dir
before deploying so the change is both tracked and live.

```bash
# from repo root, after `flutter build web --release`:
# 1) WIPE stale build artifacts from the deploy dir, keeping only the
#    hand-added files (vercel.json + legal pages + Google verification).
#    Do NOT just cp -rf over the top: the dir accumulates files across builds
#    and an overlay can leave an inconsistent set that white-screens on prod
#    (this actually happened 2026-09-26 — a "good build, bad deploy" outage).
cd blushy-web-upload && find . -maxdepth 1 -mindepth 1 \
  ! -name 'vercel.json' ! -name 'privacy.html' ! -name 'terms.html' \
  ! -name 'delete-account.html' ! -name 'google3f3db983af0dd0f9.html' \
  -exec rm -rf {} +
# 2) Copy the fresh build + refresh the canonical vercel.json.
cp -rf ../BLUSHY_MAINAPP/build/web/* .
cp -f ../BLUSHY_MAINAPP/deploy/vercel.json ./vercel.json
# 3) Deploy.
npx vercel@latest deploy --prod --yes
# 4) ALWAYS browser-verify the prod alias RENDERS (not just hash-match):
#    https://blushy-web-upload-eight.vercel.app/ should show the language screen.
#    If it white-screens: `npx vercel@latest rollback <previous-deployment-url> --yes`.
```

## What it configures
- **Rewrites**: `/privacy`, `/terms`, `/delete-account` (needed by the Play
  Console listing) and the SPA fallback to `/index.html`.
- **Security headers**, including the **Content-Security-Policy**.

## CSP gotcha (why this file exists)
WebSockets are governed by CSP `connect-src` **by scheme**. Allowing
`https://blushy-api-new.onrender.com` does **not** authorize
`wss://blushy-api-new.onrender.com` — both must be listed, or the browser
silently blocks the partner WebSocket (the socket goes straight to CLOSED,
`state 3`). If the backend host ever changes, update **both** the `https://`
and `wss://` entries in `connect-src`.
