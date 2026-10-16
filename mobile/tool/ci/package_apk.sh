#!/usr/bin/env bash
# Usage: package_apk.sh <apk> <out-dir> <base-name>
# Prepares the release APK for the workflow artifact according to MOBILE_APK_DISTRIBUTION:
#   encrypted: AES-256 with MOBILE_APK_PASSPHRASE (the artifact is useless without it; decrypt on
#              the PC with tool/release/decrypt_apk.sh, see docs/mobile/ota-updates.md)
#   artifact:  the plain APK (on a public repository, any signed-in GitHub user can download it)
# Both write <base-name>.apk.sha256, the checksum of the plain APK, to verify the decrypted file.
set -euo pipefail

apk=$1
out=$2
name=$3
mkdir -p "$out"

sum=$(sha256sum "$apk" | cut -d' ' -f1)
echo "$sum  $name.apk" > "$out/$name.apk.sha256"

case ${APK_DISTRIBUTION:-} in
  encrypted)
    openssl enc -aes-256-cbc -pbkdf2 -iter 600000 -salt -in "$apk" -out "$out/$name.apk.enc" -pass env:APK_PASSPHRASE
    echo "Encrypted APK: $name.apk.enc (plain SHA-256 $sum)"
    ;;
  artifact)
    cp "$apk" "$out/$name.apk"
    echo "Plain APK: $name.apk (SHA-256 $sum)"
    ;;
  *)
    echo "::error::MOBILE_APK_DISTRIBUTION must be 'encrypted' or 'artifact'."
    exit 1
    ;;
esac
