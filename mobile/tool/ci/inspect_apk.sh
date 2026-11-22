#!/usr/bin/env bash
# Usage: inspect_apk.sh <apk>
# Records the application ID, version and signing certificate of a release APK, and refuses
# an APK with the wrong application ID, version or production signing certificate.
set -euo pipefail

apk=$1
expected_package=com.hisbah.smartshop
expected_cert_sha256=D4C70C9BDE05937D92C071A4CAF1661009EDFF6A664D745BF72296FA57C52BC6
tools=$(ls -d "$ANDROID_HOME"/build-tools/* | sort -V | tail -n1)

badging=$("$tools/aapt2" dump badging "$apk" | head -n1)
package=$(sed -n "s/.*package: name='\([^']*\)'.*/\1/p" <<<"$badging")
version_code=$(sed -n "s/.*versionCode='\([^']*\)'.*/\1/p" <<<"$badging")
version_name=$(sed -n "s/.*versionName='\([^']*\)'.*/\1/p" <<<"$badging")
pubspec_version=$(sed -n 's/^version:[[:space:]]*//p' pubspec.yaml | tr -d '[:space:]')

certs=$("$tools/apksigner" verify --print-certs "$apk")
cert_dn=$(sed -n 's/.*certificate DN: //p' <<<"$certs" | head -n1)
cert_sha256=$(sed -n 's/.*certificate SHA-256 digest: //p' <<<"$certs" | head -n1)
normalized_cert_sha256=$(tr -d ':' <<<"$cert_sha256" | tr '[:lower:]' '[:upper:]')

echo "package=$package versionCode=$version_code versionName=$version_name"
echo "certificate: $cert_dn / SHA-256 $cert_sha256"

if [ "$package" != "$expected_package" ]; then
  echo "::error::APK application ID is '$package', expected '$expected_package'."
  exit 1
fi
if [[ $pubspec_version =~ ^([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)$ ]]; then
  expected_version_name=${BASH_REMATCH[1]}
  expected_version_code=${BASH_REMATCH[2]}
else
  echo "::error::pubspec.yaml version '$pubspec_version' is not a valid name+build version."
  exit 1
fi
if [[ "$version_name" != "$expected_version_name" || "$version_code" != "$expected_version_code" ]]; then
  echo "::error::APK version is $version_name+$version_code, expected $expected_version_name+$expected_version_code from pubspec.yaml."
  exit 1
fi
if [[ "$normalized_cert_sha256" != "$expected_cert_sha256" ]]; then
  echo "::error::APK signing certificate SHA-256 is '$cert_sha256', expected '$expected_cert_sha256'."
  exit 1
fi

{
  echo "package=$package"
  echo "version_code=$version_code"
  echo "version_name=$version_name"
  echo "cert_sha256=$cert_sha256"
} >> "${GITHUB_OUTPUT:-/dev/null}"
