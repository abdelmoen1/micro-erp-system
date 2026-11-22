#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
cd "$script_dir/../.."

for script in verify_signing_key.sh inspect_apk.sh inspect_aab.sh test_inspect_artifact_signatures.sh; do
  bash -n "$script_dir/$script"
done

tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT

build_tools="$tmp/android-sdk/build-tools/36.1.0"
mkdir -p "$build_tools" "$tmp/bin"

cat > "$build_tools/aapt2" <<'STUB'
#!/usr/bin/env bash
printf "package: name='%s' versionCode='%s' versionName='%s'\n" \
  "${MOCK_PACKAGE:-com.hisbah.smartshop}" \
  "${MOCK_VERSION_CODE:?}" \
  "${MOCK_VERSION_NAME:?}"
STUB

cat > "$build_tools/apksigner" <<'STUB'
#!/usr/bin/env bash
if [[ ${MOCK_APKSIGNER_FAIL:-} == 1 ]]; then
  exit 1
fi
printf 'Signer #1 certificate DN: CN=Hisbah Smart Shop, O=Hisbah\n'
printf 'Signer #1 certificate SHA-256 digest: %s\n' "${MOCK_APK_CERT:?}"
STUB

cat > "$tmp/bin/jarsigner" <<'STUB'
#!/usr/bin/env bash
[[ ${MOCK_JARSIGNER_FAIL:-} != 1 ]]
STUB

cat > "$tmp/bin/keytool" <<'STUB'
#!/usr/bin/env bash
printf 'Owner: CN=Hisbah Smart Shop\nSHA256: %s\n' "${MOCK_AAB_CERT:?}"
STUB

chmod +x "$build_tools/aapt2" "$build_tools/apksigner" "$tmp/bin/jarsigner" "$tmp/bin/keytool"
export ANDROID_HOME="$tmp/android-sdk"
export PATH="$tmp/bin:$PATH"
unset GITHUB_OUTPUT

version=$(sed -n 's/^version:[[:space:]]*//p' pubspec.yaml | tr -d '[:space:]')
version_name=${version%+*}
version_code=${version##*+}
export MOCK_VERSION_NAME=$version_name
export MOCK_VERSION_CODE=$version_code

apk="$tmp/hisbah.apk"
aab="$tmp/hisbah.aab"
printf 'mock apk\n' > "$apk"
printf 'mock aab\n' > "$aab"

d4=D4C70C9BDE05937D92C071A4CAF1661009EDFF6A664D745BF72296FA57C52BC6
wrong_cert=0000000000000000000000000000000000000000000000000000000000000000

expect_failure() {
  local label=$1
  shift
  if "$@" >/dev/null 2>&1; then
    echo "Expected failure: $label" >&2
    exit 1
  fi
}

MOCK_APK_CERT=$d4 bash tool/ci/inspect_apk.sh "$apk"
expect_failure "APK certificate mismatch" env MOCK_APK_CERT=$wrong_cert bash tool/ci/inspect_apk.sh "$apk"
expect_failure "APK signature failure" env MOCK_APK_CERT=$d4 MOCK_APKSIGNER_FAIL=1 bash tool/ci/inspect_apk.sh "$apk"
expect_failure "APK package mismatch" env MOCK_APK_CERT=$d4 MOCK_PACKAGE=com.example.other bash tool/ci/inspect_apk.sh "$apk"

MOCK_AAB_CERT=$d4 bash tool/ci/inspect_aab.sh "$aab"
expect_failure "AAB certificate mismatch" env MOCK_AAB_CERT=$wrong_cert bash tool/ci/inspect_aab.sh "$aab"
expect_failure "AAB signature failure" env MOCK_AAB_CERT=$d4 MOCK_JARSIGNER_FAIL=1 bash tool/ci/inspect_aab.sh "$aab"

echo "APK/AAB inspector tests passed."
