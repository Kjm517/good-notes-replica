#!/usr/bin/env bash
# Run Notably on Android with the same .env / dart-define setup as iOS.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEVICE="${1:-android}"

# shellcheck source=env.sh
source "$ROOT/scripts/env.sh"

cd "$ROOT"
flutter run -d "$DEVICE" "${DART_DEFINE_ARGS[@]}"
