#!/usr/bin/env bash
# Reads .env and writes .dart_defines.json for Flutter --dart-define-from-file.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="$ROOT/.env"
OUT="$ROOT/.dart_defines.json"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "No .env found. Copy .env.example to .env and fill in your keys:"
  echo "  cp .env.example .env"
  exit 1
fi

python3 - "$ENV_FILE" "$OUT" <<'PY'
import json
import sys
from pathlib import Path

env_path = Path(sys.argv[1])
out_path = Path(sys.argv[2])
values: dict[str, str] = {}

for raw in env_path.read_text(encoding="utf-8").splitlines():
    line = raw.strip()
    if not line or line.startswith("#"):
        continue
    if "=" not in line:
        continue
    key, _, val = line.partition("=")
    key = key.strip()
    val = val.strip().strip('"').strip("'")
    if key:
        values[key] = val

out_path.write_text(json.dumps(values, indent=2) + "\n", encoding="utf-8")
# Flutter web cannot serve files that start with `.`, so also write a
# non-hidden copy for dotenv on Chrome.
asset_env = Path(sys.argv[1]).parent / "assets" / "env"
asset_env.parent.mkdir(parents=True, exist_ok=True)

# Keys that must never ship inside the app bundle. A Flutter asset is
# plaintext in the APK/IPA — `unzip` reads it — so a vendor key placed here
# is public the moment the app is distributed. The app calls the Worker's
# /ai/generate instead, which holds these keys server-side, so nothing in
# app code reads them when NOTABLY_FILE_ENDPOINT is set.
SERVER_ONLY = {"GEMINI_API_KEY", "LLM_API_KEY"}

asset_values = {k: v for k, v in values.items() if k not in SERVER_ONLY}
stripped = sorted(set(values) & SERVER_ONLY)

lines = [f"{k}={v}" for k, v in asset_values.items()]
asset_env.write_text("\n".join(lines) + "\n", encoding="utf-8")

# Defines for app (Android/iOS) builds, with the server-only keys removed.
# `--dart-define` values are compiled into the binary, so pointing a release
# build at the full file would put a vendor key inside the APK/IPA even now
# that the asset copy is clean. The full file stays as-is: it is gitignored,
# and build-web.sh reads it to scan the built output for leaked values.
app_defines = out_path.parent / ".dart_defines.app.json"
app_defines.write_text(
    json.dumps({k: v for k, v in values.items() if k not in SERVER_ONLY}, indent=2)
    + "\n",
    encoding="utf-8",
)
print(f"Wrote {out_path} ({len(values)} key(s))")
print(f"Wrote {asset_env} ({len(asset_values)} key(s))")
print(f"Wrote {app_defines} (for `flutter build apk/ipa`)")
if stripped:
    print(f"Kept out of the app bundle (server-side only): {', '.join(stripped)}")
PY
