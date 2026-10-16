#!/usr/bin/env bash
# Usage: inspect_apk.sh <apk>
# Records the application ID, version and signing certificate of a release APK, and refuses
# an APK with the wrong application ID or signed with the Android debug key.
set -euo pipefail

apk=$1
expected_package=com.hisbah.smartshop
tools=$(ls -d "$ANDROID_HOME"/build-tools/* | sort -V | tail -n1)

badging=$("$tools/aapt2" dump badging "$apk" | head -n1)
package=$(sed -n "s/.*package: name='\([^']*\)'.*/\1/p" <<<"$badging")
version_code=$(sed -n "s/.*versionCode='\([^']*\)'.*/\1/p" <<<"$badging")
version_name=$(sed -n "s/.*versionName='\([^']*\)'.*/\1/p" <<<"$badging")

certs=$("$tools/apksigner" verify --print-certs "$apk")
cert_dn=$(sed -n 's/.*certificate DN: //p' <<<"$certs" | head -n1)
cert_sha256=$(sed -n 's/.*certificate SHA-256 digest: //p' <<<"$certs" | head -n1)

echo "package=$package versionCode=$version_code versionName=$version_name"
echo "certificate: $cert_dn / SHA-256 $cert_sha256"

if [ "$package" != "$expected_package" ]; then
  echo "::error::APK application ID is '$package', expected '$expected_package'."
  exit 1
fi
if grep -q 'CN=Android Debug' <<<"$cert_dn"; then
  echo "::error::APK is signed with the Android debug key; release builds must use the Hisbah release key."
  exit 1
fi

{
  echo "package=$package"
  echo "version_code=$version_code"
  echo "version_name=$version_name"
  echo "cert_sha256=$cert_sha256"
} >> "${GITHUB_OUTPUT:-/dev/null}"
