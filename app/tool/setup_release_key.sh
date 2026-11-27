#!/usr/bin/env bash
# One-time setup of the Android upload key for releases.
#
#   app/tool/setup_release_key.sh
#
# - Creates ~/peel-upload.jks (or reuses it if it's already there).
# - Saves it and its password as GitHub Actions secrets, so the Release
#   workflow can sign builds.
# - Writes app/android/key.properties (git ignores it) for local builds.
# - Optionally saves a Vercel deploy hook as a secret.
#
# You type the password here. It isn't shown, logged or passed on the
# command line. Keep ~/peel-upload.jks and the password safe (a password
# manager is ideal): every future update must be signed with this key.
set -euo pipefail

repo="shamsu07/peel"
keystore="$HOME/peel-upload.jks"
alias_name="upload"
app="$(cd "$(dirname "$0")/.." && pwd)"

command -v keytool >/dev/null || { echo "keytool not found: install a JDK first."; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "Sign in to GitHub first: gh auth login"; exit 1; }

echo "Peel release key setup"
echo

if [[ -e "$keystore" ]]; then
  echo "Using the existing key at $keystore."
  read -rsp "Its password: " pass; echo
  PEEL_KS_PASS="$pass" keytool -list -keystore "$keystore" -storepass:env PEEL_KS_PASS -alias "$alias_name" >/dev/null \
    || { echo "That password doesn't open the key."; exit 1; }
else
  read -rsp "Choose a password for the key (at least 8 characters): " pass; echo
  read -rsp "Type it again: " again; echo
  [[ "$pass" == "$again" ]] || { echo "The passwords don't match."; exit 1; }
  (( ${#pass} >= 8 )) || { echo "Use at least 8 characters."; exit 1; }
  PEEL_KS_PASS="$pass" keytool -genkeypair -keystore "$keystore" -storetype PKCS12 \
    -keyalg RSA -keysize 2048 -validity 10000 -alias "$alias_name" \
    -dname "CN=Peel, O=Peel" -storepass:env PEEL_KS_PASS -keypass:env PEEL_KS_PASS
  chmod 600 "$keystore"
  echo "Created $keystore."
fi

echo "Saving GitHub secrets for $repo..."
base64 -i "$keystore" | gh secret set ANDROID_KEYSTORE_BASE64 -R "$repo"
printf '%s' "$pass" | gh secret set ANDROID_KEYSTORE_PASSWORD -R "$repo"
printf '%s' "$alias_name" | gh secret set ANDROID_KEY_ALIAS -R "$repo"
printf '%s' "$pass" | gh secret set ANDROID_KEY_PASSWORD -R "$repo"

umask 077
cat > "$app/android/key.properties" <<EOF
storePassword=$pass
keyPassword=$pass
keyAlias=$alias_name
storeFile=$keystore
EOF
echo "Wrote app/android/key.properties for local release builds."

echo
echo "Optional: a Vercel deploy hook refreshes the website after each release."
echo "Create one in Vercel: project > Settings > Git > Deploy Hooks (branch main)."
read -rsp "Paste the hook URL, or press Enter to skip: " hook; echo
if [[ -n "$hook" ]]; then
  printf '%s' "$hook" | gh secret set VERCEL_DEPLOY_HOOK -R "$repo"
  echo "Saved VERCEL_DEPLOY_HOOK."
fi

unset pass again hook
echo
echo "All set. Back up $keystore and its password now."
