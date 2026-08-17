#!/usr/bin/env bash
set -euo pipefail

# Build a release APK whose Android versionName is based on local month/day/hour/minute.
# Example: June 26 15:21 -> 6.26.15.21
#
# Usage:
#   ./scripts/build_release_versioned.sh
#   ./scripts/build_release_versioned.sh --split-per-abi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

FLUTTER_BIN="${FLUTTER_BIN:-/e/DevelopmentSoftware/flutter/bin/flutter}"
if [[ ! -x "$FLUTTER_BIN" ]]; then
  FLUTTER_BIN="flutter"
fi

BUILD_NAME="$(date +%-m.%-d.%H.%M)"
# Android versionCode must be a positive integer and monotonically increase
# if you ever distribute updates. For local testing, MMDDHHMM is convenient.
BUILD_NUMBER="$(date +%m%d%H%M)"

echo "Building AstrBot Mobile Dashboard"
echo "  versionName: $BUILD_NAME"
echo "  versionCode: $BUILD_NUMBER"
echo

"$FLUTTER_BIN" build apk --release \
  --build-name "$BUILD_NAME" \
  --build-number "$BUILD_NUMBER" \
  "$@"

echo
echo "APK output:"
ls -lh build/app/outputs/flutter-apk/*.apk
