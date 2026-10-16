#!/usr/bin/env bash
# Usage: preflight.sh release|patch   (run from mobile/)
# CI preflight for Shorebird. Fails early, naming what is missing; never prints secret values.
set -euo pipefail

mode=${1:?usage: preflight.sh release|patch}
fail=0
err() { echo "::error::$1"; fail=1; }

if ! grep -Eq '^app_id:[[:space:]]*[0-9a-fA-F-]{8,}' shorebird.yaml 2>/dev/null; then
  err "mobile/shorebird.yaml with an app_id is missing. Run 'shorebird init' in mobile/ once and commit the result (docs/mobile/ota-updates.md)."
fi
if ! grep -q 'BEGIN PUBLIC KEY' shorebird-patch-public.pem 2>/dev/null; then
  err "mobile/shorebird-patch-public.pem (patch signing public key) is missing."
fi

check_secret() { # <env var> <GitHub secret name>
  if [ -z "${!1:-}" ]; then err "GitHub Actions secret $2 is not set."; fi
}
check_secret SHOREBIRD_TOKEN SHOREBIRD_TOKEN
check_secret KEYSTORE_B64 ANDROID_KEYSTORE_BASE64
check_secret KEYSTORE_PASSWORD ANDROID_KEYSTORE_PASSWORD
check_secret KEY_ALIAS ANDROID_KEY_ALIAS
check_secret KEY_PASSWORD ANDROID_KEY_PASSWORD

case $mode in
  release)
    case ${APK_DISTRIBUTION:-} in
      encrypted) check_secret APK_PASSPHRASE MOBILE_APK_PASSPHRASE ;;
      artifact) echo "::warning::MOBILE_APK_DISTRIBUTION=artifact: the APK is uploaded unencrypted; on a public repository any signed-in GitHub user can download it." ;;
      *) err "Repository variable MOBILE_APK_DISTRIBUTION must be 'encrypted' or 'artifact' (how the APK leaves CI; see docs/mobile/ota-updates.md). Without it the release would be published with no way to install it." ;;
    esac
    ;;
  patch)
    check_secret PATCH_PRIVATE_KEY SHOREBIRD_PATCH_PRIVATE_KEY
    pubspec_version=$(sed -n 's/^version:[[:space:]]*//p' pubspec.yaml | tr -d '[:space:]')
    if [ -z "${OTA_RELEASE_VERSION:-}" ]; then
      err "Repository variable MOBILE_OTA_RELEASE_VERSION is not set: set it to the release version installed and verified on the phone."
    elif [ "$OTA_RELEASE_VERSION" != "$pubspec_version" ]; then
      err "pubspec.yaml version $pubspec_version differs from the established release $OTA_RELEASE_VERSION (MOBILE_OTA_RELEASE_VERSION). A version bump needs a full release first; patches only target the verified release."
    fi
    ;;
  *) err "unknown mode $mode" ;;
esac

bash "$(dirname "$0")/check_api_url.sh" "${API_BASE_URL:-}" || fail=1

exit $fail
