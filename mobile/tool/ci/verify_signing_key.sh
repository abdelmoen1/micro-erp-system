#!/usr/bin/env bash
# Verify the configured release credentials before Shorebird builds an APK or AAB.
set +x
set -euo pipefail
umask 077

fail() {
  echo "::error::$1" >&2
  exit 1
}

for name in KEYSTORE_B64 KEYSTORE_PASSWORD KEY_ALIAS KEY_PASSWORD; do
  if [[ -z "${!name:-}" ]]; then
    fail "Required production signing input $name is not configured."
  fi
done

tmp_root=${RUNNER_TEMP:-${TMPDIR:-/tmp}}
tmp=$(mktemp -d "$tmp_root/hisbah-signing-check.XXXXXX")
trap 'rm -rf -- "$tmp"' EXIT

keystore="$tmp/production-keystore.p12"
bom=$'\xEF\xBB\xBF'
encoded=${KEYSTORE_B64#"$bom"}
if ! printf '%s' "$encoded" | tr -d '\r\n' | base64 --decode > "$keystore" 2>/dev/null; then
  fail "ANDROID_KEYSTORE_BASE64 is not valid base64."
fi
chmod 600 "$keystore"

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
mkdir "$tmp/classes"
javac --release 17 -d "$tmp/classes" "$script_dir/VerifySigningKey.java"
java -cp "$tmp/classes" VerifySigningKey "$keystore"
