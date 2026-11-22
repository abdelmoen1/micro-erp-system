#!/usr/bin/env bash
# Usage: inspect_aab.sh <aab>
# Verifies that a production AAB is signed with the permanent Hisbah release certificate.
set -euo pipefail

aab=$1
expected_cert_sha256=D4C70C9BDE05937D92C071A4CAF1661009EDFF6A664D745BF72296FA57C52BC6

if [[ ! -s "$aab" ]]; then
  echo "::error::Production AAB is missing or empty."
  exit 1
fi

if ! jarsigner -verify "$aab" >/dev/null 2>&1; then
  echo "::error::Production AAB signature verification failed."
  exit 1
fi

certificate=$(keytool -printcert -jarfile "$aab" 2>&1) || {
  echo "::error::Could not read the production AAB signing certificate."
  exit 1
}
cert_sha256=$(sed -n 's/^[[:space:]]*SHA256:[[:space:]]*//p' <<<"$certificate" | head -n1)
normalized_cert_sha256=$(tr -d ':' <<<"$cert_sha256" | tr '[:lower:]' '[:upper:]')

if [[ "$normalized_cert_sha256" != "$expected_cert_sha256" ]]; then
  echo "::error::AAB signing certificate SHA-256 is '$cert_sha256', expected '$expected_cert_sha256'."
  exit 1
fi

echo "Production AAB signing certificate verified: SHA-256 $cert_sha256"
echo "cert_sha256=$cert_sha256" >> "${GITHUB_OUTPUT:-/dev/null}"
