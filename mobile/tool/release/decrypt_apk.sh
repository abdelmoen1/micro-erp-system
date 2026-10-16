#!/usr/bin/env bash
# Usage (Git Bash, in the folder of the unzipped workflow artifact):
#   bash decrypt_apk.sh hisbah-1.0.0+1.apk.enc
# Asks for MOBILE_APK_PASSPHRASE at a hidden prompt, writes hisbah-1.0.0+1.apk next to it and
# checks it against the .apk.sha256 file from the same artifact.
set -euo pipefail

enc=${1:?usage: decrypt_apk.sh <file>.apk.enc}
apk=${enc%.enc}

if ! openssl enc -d -aes-256-cbc -pbkdf2 -iter 600000 -in "$enc" -out "$apk"; then
  rm -f "$apk"
  echo "Decryption failed: wrong passphrase or damaged download. Nothing kept." >&2
  exit 1
fi
if sha256sum -c "$apk.sha256"; then
  echo "Decrypted and verified: $apk"
else
  rm -f "$apk"
  echo "Checksum mismatch: wrong passphrase or damaged download. Nothing kept." >&2
  exit 1
fi
