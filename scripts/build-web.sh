#!/usr/bin/env bash
# Build Notably for the web, with client-unsafe secrets stripped from the bundle.
#
# `.env` ships as a Flutter *asset* (pubspec.yaml `assets: - .env`, `- assets/env`),
# so it is downloadable at /assets/.env by anyone who visits the site. Filtering
# --dart-define-from-file is NOT enough on its own. Every key listed in
# SECRET_KEYS is therefore removed from the built asset copies as well.
#
# Anything removed here must be proxied server-side to keep working in production.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SECRET_KEYS=(GEMINI_API_KEY LLM_API_KEY)

# .dart_defines.json is generated from .env by sync-env.sh
[[ -f .env ]] && ./scripts/sync-env.sh >/dev/null

python3 - "${SECRET_KEYS[@]}" <<'PY'
import json, sys
secret = set(sys.argv[1:])
src = json.load(open('.dart_defines.json'))
json.dump({k: v for k, v in src.items() if k not in secret},
          open('.dart_defines.web.json', 'w'), indent=2)
PY

flutter build web --release --dart-define-from-file=.dart_defines.web.json "$@"

OUT="$ROOT/build/web"

python3 - "$OUT" "${SECRET_KEYS[@]}" <<'PY'
import pathlib, sys
out, secret = pathlib.Path(sys.argv[1]), set(sys.argv[2:])
for rel in ('assets/.env', 'assets/assets/env'):
    p = out / rel
    if not p.exists():
        continue
    kept = [l for l in p.read_text().splitlines()
            if l.split('=')[0].strip() not in secret]
    p.write_text('\n'.join(kept) + '\n')
    print(f'stripped {sorted(secret)} from {rel}')
PY

# Fail loudly if any secret value still appears anywhere in the output.
python3 - "$OUT" "${SECRET_KEYS[@]}" <<'PY'
import json, pathlib, sys
out, secret = pathlib.Path(sys.argv[1]), sys.argv[2:]
vals = {k: str(v).strip() for k, v in json.load(open('.dart_defines.json')).items()
        if k in secret and str(v).strip()}
bad = []
for f in out.rglob('*'):
    if not f.is_file():
        continue
    blob = f.read_bytes().decode('utf-8', 'ignore')
    bad += [f'{k} in {f.relative_to(out)}' for k, v in vals.items() if v in blob]
if bad:
    sys.exit('LEAK: ' + '; '.join(bad))
print(f'verified: no secret values in {out}')
PY

# `build/` is a symlink to /tmp/notably-ios-build (kept out of the repo tree
# for the iOS build) and Vercel's uploader does not follow a symlink that
# points outside the project directory — it silently deploys an empty site.
# Mirror the real output into a plain on-disk directory so `vercel.json`'s
# outputDirectory has real files to find.
DEPLOY_DIR="$ROOT/vercel_out"
# Preserve the Vercel project link across rebuilds — wiping it makes the next
# `vercel --prod` try to create a new project instead of updating this one.
LINK_BACKUP="$(mktemp -d)"
[[ -d "$DEPLOY_DIR/.vercel" ]] && cp -R "$DEPLOY_DIR/.vercel" "$LINK_BACKUP/"
rm -rf "$DEPLOY_DIR"
mkdir -p "$DEPLOY_DIR"
cp -R "$OUT/." "$DEPLOY_DIR/"
[[ -d "$LINK_BACKUP/.vercel" ]] && cp -R "$LINK_BACKUP/.vercel" "$DEPLOY_DIR/"
rm -rf "$LINK_BACKUP"

# go_router does client-side routing, so every path must serve index.html.
# Generated rather than copied: this directory is wiped on each build, and a
# missing rewrite 404s every deep link (/settings, /doc/<id>) on refresh.
cat > "$DEPLOY_DIR/vercel.json" <<'JSON'
{
  "rewrites": [{ "source": "/(.*)", "destination": "/index.html" }]
}
JSON

echo "Built: $OUT"
echo "Mirrored for Vercel: $DEPLOY_DIR"
