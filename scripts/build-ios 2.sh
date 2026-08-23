#!/usr/bin/env bash
# Build Notably for the iOS Simulator.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# shellcheck source=env.sh
source "$ROOT/scripts/env.sh"

if [[ -z "${DEVELOPER_DIR:-}" || ! -d "$DEVELOPER_DIR" ]]; then
  echo "Xcode not found. Install Xcode from the App Store, then run:"
  echo "  sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer"
  exit 1
fi

cd "$ROOT"
flutter pub get
flutter build ios --simulator --no-codesign "${DART_DEFINE_ARGS[@]}" "$@"

echo ""
echo "Built: $ROOT/build/ios/iphonesimulator/Runner.app"
