# Notably file service (Cloudflare Worker + R2)

Holds the **source files** (PDFs, images). Notes and annotations live in
Firestore; only the big binaries come here, because R2 gives 10 GB free with
**no egress fees** — the 150 MB textbook is the reason this exists.

R2 credentials must never be shipped inside the app, so the Worker verifies
the caller's Firebase ID token and scopes every object to `users/{uid}/`.

## One-time setup

```bash
cd worker
npm install
npx wrangler login
npx wrangler r2 bucket create notably-files
npx wrangler deploy
```

Deploy prints a URL like `https://notably-files.<your>.workers.dev`.
Pass it to the app when running:

```bash
flutter run -d chrome --web-port=5000 --dart-define=NOTABLY_FILE_ENDPOINT=https://notably-files.<your>.workers.dev
```

Without that define the app simply skips file sync — notes and annotations
still sync normally.

## Endpoints

All require `Authorization: Bearer <firebase id token>` and a `?key=` param.

| Method | Path      | Purpose                   |
| ------ | --------- | ------------------------- |
| PUT    | `/file`   | Upload (body = raw bytes) |
| GET    | `/file`   | Download                  |
| GET    | `/head`   | Existence + size check    |
| POST   | `/delete` | Remove an object          |

## Costs

R2 free tier: 10 GB stored, 1M class-A and 10M class-B operations per month,
and **zero** egress. Workers free tier: 100k requests/day.
