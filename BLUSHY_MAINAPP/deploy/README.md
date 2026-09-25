# Web deploy config (source of truth)

`vercel.json` here is the **version-controlled canonical copy** of the config
that Vercel actually serves for the web build.

The live deploy runs from `blushy-web-upload/` (a sibling of `BLUSHY_MAINAPP/`)
which is **git-ignored**, so its own `vercel.json` is not in version control.
Keep the two in sync: **edit this file**, then copy it into the deploy dir
before deploying so the change is both tracked and live.

```bash
# from repo root, after editing BLUSHY_MAINAPP/deploy/vercel.json:
cp BLUSHY_MAINAPP/deploy/vercel.json blushy-web-upload/vercel.json
cd blushy-web-upload && npx vercel@latest deploy --prod --yes
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
