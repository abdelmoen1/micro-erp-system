#!/usr/bin/env bash
# Usage: package_apk.sh <apk> <out-dir> <base-name>   (run from mobile/)
# Prepares the release APK for download according to MOBILE_APK_DISTRIBUTION:
#   draft-release: the plain APK, attached by the workflow to a draft GitHub release. Drafts are visible
#              only to users with write access (checked: 404 for anyone else), so the phone downloads it
#              from github.com while signed in.
#   encrypted: workflow artifact, AES-256 with a random one-time key; that key is encrypted (RSA-OAEP) to
#              tool/release/apk-delivery-public.pem. Only the matching private key, which never
#              leaves the release PC, can open it (tool/release/decrypt_apk.sh).
#   artifact:  workflow artifact with the plain APK (on a public repository, any signed-in GitHub user
#              can download it).
# All modes write <base-name>.apk.sha256, the checksum of the plain APK.
set -euo pipefail

apk=$1
out=$2
name=$3
public_key=tool/release/apk-delivery-public.pem
mkdir -p "$out"

sum=$(sha256sum "$apk" | cut -d' ' -f1)
echo "$sum  $name.apk" > "$out/$name.apk.sha256"

case ${APK_DISTRIBUTION:-} in
  encrypted)
    key=$(mktemp)
    trap 'rm -f "$key"' EXIT
    keyarg=$key
    if command -v cygpath > /dev/null; then keyarg=$(cygpath -m "$key"); fi # Git Bash: -pass file: is not path-translated
    openssl rand -hex 32 > "$key"
    openssl enc -aes-256-cbc -pbkdf2 -iter 100000 -salt -in "$apk" -out "$out/$name.apk.enc" -pass "file:$keyarg"
    openssl pkeyutl -encrypt -pubin -inkey "$public_key" \
      -pkeyopt rsa_padding_mode:oaep -pkeyopt rsa_oaep_md:sha256 -in "$key" -out "$out/$name.key.enc"
    echo "Encrypted APK: $name.apk.enc + $name.key.enc (plain SHA-256 $sum)"
    ;;
  draft-release | artifact)
    cp "$apk" "$out/$name.apk"
    echo "Plain APK: $name.apk (SHA-256 $sum)"
    ;;
  *)
    echo "::error::MOBILE_APK_DISTRIBUTION must be 'draft-release', 'encrypted' or 'artifact'."
    exit 1
    ;;
esac
