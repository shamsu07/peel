#!/usr/bin/env bash
# Builds the Android APK locally, for trying it before a release. The live
# site serves the APK from GitHub Releases (see website/README.md).
#
#   website/tool/build_apk.sh [--site https://your.domain] [--contact you@your.domain]
#
# Output: website/public/download/peel.apk (git ignores it), plus the
# version and size written into the page by tool/build.mjs. Any arguments
# are passed on to build.mjs.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
website="$(dirname "$here")"
app="$(dirname "$website")/app"

if [[ ! -f "$app/android/key.properties" ]]; then
  cat >&2 <<'MSG'
! app/android/key.properties is missing, so this APK is signed with the
  DEBUG key. Fine for trying it out; read "Signing" in website/README.md
  before sharing it, because people can't update from it to a properly
  signed build without uninstalling first.
MSG
fi

(
  cd "$app"
  flutter build apk --release --target-platform android-arm64 \
    --obfuscate --split-debug-info=build/symbols/apk
)

mkdir -p "$website/public/download"
cp "$app/build/app/outputs/flutter-apk/app-release.apk" "$website/public/download/peel.apk"

node "$here/build.mjs" "$@"

echo
echo "Done: website/public/download/peel.apk"
echo "Keep app/build/symbols/apk for this version: it's needed to read crash stack traces."
