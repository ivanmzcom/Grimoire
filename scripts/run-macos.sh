#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED_DATA_PATH="$ROOT_DIR/.build/CodexDerivedData"
APP_PATH="$DERIVED_DATA_PATH/Build/Products/Debug/JuegosApp.app"

xcodebuild \
  -project "$ROOT_DIR/JuegosApp.xcodeproj" \
  -scheme JuegosApp \
  -configuration Debug \
  -destination "platform=macOS" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  build

open "$APP_PATH"
