#!/usr/bin/env bash
# Create (or verify) Notably iPhone and Notably iPad iOS simulators.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# shellcheck source=env.sh
source "$ROOT/scripts/env.sh"

if [[ -z "${DEVELOPER_DIR:-}" || ! -d "$DEVELOPER_DIR" ]]; then
  echo "Xcode not found. Install Xcode, then run:"
  echo "  sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer"
  exit 1
fi

# Prefer the newest installed iOS simulator runtime.
RUNTIME="$(xcrun simctl list runtimes available -j \
  | python3 -c "
import json, sys
runtimes = json.load(sys.stdin).get('runtimes', [])
ios = [r for r in runtimes if r.get('isAvailable') and r.get('identifier', '').startswith('com.apple.CoreSimulator.SimRuntime.iOS-')]
ios.sort(key=lambda r: r.get('version', ''), reverse=True)
print(ios[0]['identifier'] if ios else '')
")"

if [[ -z "$RUNTIME" ]]; then
  echo "No iOS simulator runtime installed."
  echo "Open Xcode → Settings → Platforms and install an iOS simulator."
  exit 1
fi

echo "Using runtime: $RUNTIME"

create_if_missing() {
  local name="$1"
  local device_type="$2"

  if xcrun simctl list devices available | grep -qE "[[:space:]]${name}[[:space:]]\\("; then
    echo "✓ $name already exists"
    return 0
  fi

  local udid
  udid="$(xcrun simctl create "$name" "$device_type" "$RUNTIME")"
  echo "Created $name ($udid)"
}

create_if_missing "Notably iPhone" "com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro"
create_if_missing "Notably iPad" "com.apple.CoreSimulator.SimDeviceType.iPad-Pro-11-inch-M5-12GB"

echo ""
echo "Available Notably simulators:"
xcrun simctl list devices available | grep -E 'Notably (iPhone|iPad)' || true
