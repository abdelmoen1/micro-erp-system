#!/usr/bin/env bash
# Usage: check_patchable.sh <release-version> [after-sha]   (run from mobile/, full git history + tags)
# Shorebird patches replace Dart code only. Native/Gradle files, packaged assets, shorebird.yaml
# and the patch-signing public key ship only in a full release. A patch is built on top of the
# release that is on the phones, so the comparison is against that release's commit (the tag
# android-<version> that mobile-release.yml creates), not against the previous push: a native change
# merged earlier and never released would otherwise slip through on the next Dart-only push.
# Shorebird's own native/asset checks still run afterwards.
#
# Writes patchable=true|false to $GITHUB_OUTPUT. A blocked push is reported as a warning and exits 0
# (nothing is wrong with main, it needs a full release); set FAIL_WHEN_BLOCKED=1 to exit 1 instead.
set -euo pipefail

version=${1:-}
after=${2:-HEAD}
out=${GITHUB_OUTPUT:-/dev/null}
summary=${GITHUB_STEP_SUMMARY:-/dev/null}

if [ -z "$version" ]; then
  echo "::error::Repository variable MOBILE_OTA_RELEASE_VERSION is not set: set it to the release version installed on the phones."
  exit 1
fi

tag="android-${version//+/_}"
if ! base=$(git rev-parse -q --verify "refs/tags/$tag^{commit}"); then
  echo "::error::Tag $tag (the commit of release $version) was not found, so the push cannot be compared with what is on the phones. No patch was published."
  exit 1
fi

# .gitignore files never reach the APK.
blocked=$(git diff --name-only "$base" "$after" -- . \
  | grep -E '^mobile/(android/|assets/|shorebird\.yaml$|shorebird-patch-public\.pem$)' \
  | grep -v '/\.gitignore$' || true)
if [ -z "$blocked" ]; then
  echo "Only patchable files changed since release $version ($tag, ${base:0:7})."
  echo "patchable=true" >> "$out"
  exit 0
fi

echo "patchable=false" >> "$out"
level=warning
if [ "${FAIL_WHEN_BLOCKED:-0}" = 1 ]; then level=error; fi
echo "::$level::Changed since release $version: files that only ship in a new APK. No patch was published. Run 'Mobile release (Shorebird, Android)' after bumping version: in mobile/pubspec.yaml."
echo "$blocked" | sed 's/^/  - /'
{
  echo "### Full release required: no patch published"
  echo "Release on the phones: \`$version\` (tag \`$tag\`, ${base:0:7}). These files changed since it and only ship in a new APK:"
  echo "$blocked" | sed 's/^/- `/; s/$/`/'
  echo
  echo "Bump \`version:\` in \`mobile/pubspec.yaml\`, merge, run **Mobile release (Shorebird, Android)**, then set"
  echo "\`MOBILE_OTA_RELEASE_VERSION\` to the new version once it is installed. Patches resume after that."
} >> "$summary"
if [ "$level" = error ]; then exit 1; fi
exit 0
