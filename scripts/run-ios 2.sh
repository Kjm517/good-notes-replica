#!/usr/bin/env bash
# Boot an iOS simulator and run Notably with hot reload.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEVICE="${1:-Notably iPhone}"

# shellcheck source=env.sh
source "$ROOT/scripts/env.sh"

echo "Booting simulator: $DEVICE"
xcrun simctl boot "$DEVICE" 2>/dev/null || true

cd "$ROOT"
echo "Available devices:"
flutter devices

echo ""
echo "Running on: $DEVICE"
flutter run -d "$DEVICE" "${DART_DEFINE_ARGS[@]}"
