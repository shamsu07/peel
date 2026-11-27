#!/usr/bin/env bash
# Builds the store releases as small as they go:
# --obfuscate shortens Dart names (about 1 MB less per platform) and
# --split-debug-info keeps the symbols out of the app. Keep the symbols
# folder for each release: `flutter symbolize` needs it to read crash logs.
# Store builds never include the test lab (see lib/core/build_info.dart).
set -euo pipefail
cd "$(dirname "$0")/.."
version=$(grep '^version:' pubspec.yaml | awk '{print $2}')
symbols="build/symbols/$version"

if [[ ! -f android/key.properties ]]; then
  echo "android/key.properties is missing, so Play would reject the bundle."
  echo "See docs/store/release.md, 'Android upload key'."
  exit 1
fi

flutter test
flutter build appbundle --release --obfuscate --split-debug-info="$symbols/android"
flutter build ipa --release --obfuscate --split-debug-info="$symbols/ios"

echo "Android: build/app/outputs/bundle/release/app-release.aab"
echo "iOS:     build/ios/ipa/"
echo "Symbols: $symbols (keep these)"
