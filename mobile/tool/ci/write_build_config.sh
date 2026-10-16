#!/usr/bin/env bash
# Writes the release signing config and env/production.json on the CI runner (run from mobile/).
# All outputs are git-ignored or outside the checkout, and removed at the end of the job.
set -euo pipefail

umask 077

# Secrets set from a Windows pipe may end in CR/LF; trailing line breaks are never part of a value.
strip() { local v=$1; while [[ $v == *$'\n' || $v == *$'\r' ]]; do v=${v%$'\n'}; v=${v%$'\r'}; done; printf '%s' "$v"; }

printf '%s' "$KEYSTORE_B64" | tr -d '\r\n' | base64 --decode > android/app/upload-keystore.jks

# java.util.Properties treats backslashes as escapes.
esc() { local bs='\' v; v=$(strip "$1"); printf '%s' "${v//"$bs"/"$bs$bs"}"; }
{
  echo "storeFile=upload-keystore.jks"
  echo "storePassword=$(esc "$KEYSTORE_PASSWORD")"
  echo "keyAlias=$(esc "$KEY_ALIAS")"
  echo "keyPassword=$(esc "$KEY_PASSWORD")"
} > android/key.properties

jq -n --arg url "$API_BASE_URL" '{API_BASE_URL: $url}' > env/production.json

# Patches only: Shorebird patch-signing private key, outside the checkout.
if [ -n "${PATCH_PRIVATE_KEY:-}" ]; then
  printf '%s\n' "$PATCH_PRIVATE_KEY" | tr -d '\r' > "$RUNNER_TEMP/shorebird-patch-private.pem"
fi
echo "Signing config and env/production.json written."
