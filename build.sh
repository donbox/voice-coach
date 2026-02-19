#!/bin/zsh
set -euo pipefail

PROJECT="VoiceCoach.xcodeproj"
SCHEME="VoiceCoach"
SIM_ID="E47DE600-4A0D-4364-8099-12EB39A3D222"  # iPad (A16), iOS 26.2
BUNDLE_ID="com.voicecoach.app"
LOG="/tmp/vc-build.log"

usage() {
  echo "Usage: ./build.sh [sim|mac|run]"
  echo "  (no args)  build for simulator (compile check)"
  echo "  sim        build + install + launch in iPad simulator"
  echo "  mac        build + launch Mac Catalyst app"
  exit 1
}

build_simulator() {
  echo "Building for simulator..."
  xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -destination "id=$SIM_ID" \
    > "$LOG" 2>&1
  grep -E "error:|warning:" "$LOG" || true
  grep -E "BUILD SUCCEEDED|BUILD FAILED" "$LOG"
}

build_mac() {
  echo "Building for Mac Catalyst..."
  xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -destination "platform=macOS,variant=Mac Catalyst" \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    > "$LOG" 2>&1
  grep -E "error:" "$LOG" || true
  grep -E "BUILD SUCCEEDED|BUILD FAILED" "$LOG"
}

case "${1:-}" in
  sim)
    build_simulator
    APP_PATH=$(grep "BUILT_PRODUCTS_DIR" "$LOG" | head -1 | awk '{print $NF}' || \
      find ~/Library/Developer/Xcode/DerivedData/VoiceCoach-*/Build/Products/Debug-iphonesimulator -name "$SCHEME.app" -maxdepth 1 2>/dev/null | head -1)
    echo "Installing and launching in simulator..."
    xcrun simctl boot "$SIM_ID" 2>/dev/null || true
    xcrun simctl install "$SIM_ID" "$APP_PATH"
    xcrun simctl launch "$SIM_ID" "$BUNDLE_ID"
    open -a Simulator
    ;;
  mac)
    build_mac
    APP=$(find ~/Library/Developer/Xcode/DerivedData/VoiceCoach-*/Build/Products/Debug-maccatalyst -name "$SCHEME.app" -maxdepth 1 2>/dev/null | head -1)
    echo "Launching $APP..."
    open "$APP"
    ;;
  "")
    build_simulator
    ;;
  *)
    usage
    ;;
esac
