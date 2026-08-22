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
print(f"Wrote {out_path} ({len(values)} key(s))")
PY
