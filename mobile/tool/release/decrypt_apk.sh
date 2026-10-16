#!/usr/bin/env bash
# Usage (Git Bash, on the release PC, in the folder of the unzipped workflow artifact):
#   bash decrypt_apk.sh hisbah-1.0.0+1.apk.enc [private-key]
# Opens an APK packaged with MOBILE_APK_DISTRIBUTION=encrypted, using the delivery private key
# (default: ~/hisbah-release/apk-delivery-private.pem), and checks it against the .apk.sha256 file.
set -euo pipefail

enc=${1:?usage: decrypt_apk.sh <file>.apk.enc [private-key]}
private_key=${2:-$HOME/hisbah-release/apk-delivery-private.pem}
apk=${enc%.enc}
wrapped_key=${apk%.apk}.key.enc

key=$(mktemp)
trap 'rm -f "$key"' EXIT
keyarg=$key
if command -v cygpath > /dev/null; then keyarg=$(cygpath -m "$key"); fi # Git Bash: -pass file: is not path-translated

if ! openssl pkeyutl -decrypt -inkey "$private_key" \
    -pkeyopt rsa_padding_mode:oaep -pkeyopt rsa_oaep_md:sha256 -in "$wrapped_key" -out "$key" \
  || ! openssl enc -d -aes-256-cbc -pbkdf2 -iter 100000 -in "$enc" -out "$apk" -pass "file:$keyarg"; then
  rm -f "$apk"
  echo "Decryption failed: wrong private key or damaged download. Nothing kept." >&2
  exit 1
fi
if sha256sum -c "$apk.sha256"; then
  echo "Decrypted and verified: $apk"
else
  rm -f "$apk"
  echo "Checksum mismatch: damaged download. Nothing kept." >&2
  exit 1
fi
