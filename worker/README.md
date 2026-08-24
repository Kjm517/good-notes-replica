# Notably file service (Cloudflare Worker + R2)

Holds the **source files** (PDFs, images). Notes and annotations live in
Supabase Postgres; only the big binaries come here, because R2 gives 10 GB free
with **no egress fees** — the 150 MB textbook is the reason this exists.

R2 credentials must never be shipped inside the app, so the Worker verifies the
caller's **Supabase access token** and scopes every object to `users/{uid}/`.

## One-time setup

```bash
cd worker
npm install
npx wrangler login
npx wrangler r2 bucket create notably-files
# Set Supabase project URL in wrangler.toml [vars] SUPABASE_URL
npx wrangler secret put SUPABASE_JWT_SECRET   # Project Settings → API → JWT Secret
npx wrangler secret put SUPABASE_SERVICE_ROLE_KEY  # service_role — create admins from Team
npx wrangler secret put ADMIN_UIDS            # your first/bootstrap Supabase user UUID(s)
npx wrangler deploy
```

After bootstrap, open **Admin → Team** and use **Create admin in Supabase** for more staff
(no need to paste UUIDs into `.env` for them).

Deploy prints a URL like `https://notably-files.<your>.workers.dev`.
Pass it to the app when running:

```bash
./scripts/run-chrome.sh
# Windows:
./scripts/run-chrome.ps1
```

Or set `NOTABLY_FILE_ENDPOINT` in `.env` and use the VS Code **Notably (Chrome, fixed port)** launch config. Without that, the app skips file sync —
notes and annotations still sync via Supabase.

## Endpoints

All require `Authorization: Bearer <supabase access token>` and a `?key=` param
for file routes.

See `src/index.ts` for the full route table (files, billing, admin, telemetry).
