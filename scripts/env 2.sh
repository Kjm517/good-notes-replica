#!/usr/bin/env bash
# Source this before flutter/ios/android commands:  source scripts/env.sh
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ -d "/Applications/Xcode.app/Contents/Developer" ]]; then
  export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
elif [[ -d "${HOME}/Downloads/Xcode-beta.app/Contents/Developer" ]]; then
  export DEVELOPER_DIR="${HOME}/Downloads/Xcode-beta.app/Contents/Developer"
fi

export PATH="$ROOT/scripts/ios-bin:$PATH"
export COPYFILE_DISABLE=1

# Build artifacts on Desktop fail codesign; keep them on /tmp instead.
BUILD_LINK="$ROOT/build"
if [[ ! -L "$BUILD_LINK" ]]; then
  rm -rf "$BUILD_LINK"
  mkdir -p /tmp/notably-ios-build
  ln -s /tmp/notably-ios-build "$BUILD_LINK"
fi

# .env → .dart_defines.json for --dart-define-from-file
DART_DEFINE_ARGS=()
if [[ -f "$ROOT/.env" ]]; then
  "$ROOT/scripts/sync-env.sh" >/dev/null
  DART_DEFINE_ARGS=(--dart-define-from-file="$ROOT/.dart_defines.json")
fi
