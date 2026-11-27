#!/usr/bin/env bash
# Builds a test version (with the test lab) and installs it on a plugged-in
# iPhone. Usage: tool/install_test_iphone.sh <device id from `xcrun devicectl list devices`>
set -euo pipefail
cd "$(dirname "$0")/.."
device="${1:?Pass the iPhone device id}"
flutter build ios --release --dart-define=PEEL_LAB=true \
  --obfuscate --split-debug-info=build/symbols/dev/ios
xcrun devicectl device install app --device "$device" build/ios/iphoneos/Runner.app
xcrun devicectl device process launch --device "$device" --terminate-existing app.peel.peel
