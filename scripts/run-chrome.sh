#!/usr/bin/env bash
# Run Notably in Chrome with .env loaded (Supabase, file endpoint, Google login).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=env.sh
source "$ROOT/scripts/env.sh"

cd "$ROOT"
flutter run -d chrome --web-port=5000 "${DART_DEFINE_ARGS[@]}"
