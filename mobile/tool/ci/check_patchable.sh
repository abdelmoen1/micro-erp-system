#!/usr/bin/env bash
# Usage: check_patchable.sh <before-sha> <after-sha>   (run from mobile/)
# Shorebird patches replace Dart code only. Native/Gradle files, packaged assets, shorebird.yaml
# and the patch-signing public key ship only in a full release, so a push that touches them must
# not be published as a patch. Shorebird's own native/asset checks still run afterwards.
set -euo pipefail

before=${1:-}
after=${2:-HEAD}

if [ -z "$before" ] || [[ $before =~ ^0+$ ]] || ! git cat-file -e "$before^{commit}" 2>/dev/null; then
  echo "No previous commit to compare (manual run or new branch); relying on Shorebird's checks."
  exit 0
fi

blocked=$(git diff --name-only "$before" "$after" -- . | grep -E '^mobile/(android/|assets/|shorebird\.yaml$|shorebird-patch-public\.pem$)' || true)
if [ -n "$blocked" ]; then
  echo "::error::This push changes files that a Shorebird patch cannot deliver. Run the 'Mobile release (Shorebird, Android)' workflow (full APK) instead."
  echo "$blocked" | sed 's/^/  - /'
  {
    echo "### Full release required"
    echo "These files only ship in a new APK, so no patch was published:"
    echo "$blocked" | sed 's/^/- `/; s/$/`/'
  } >> "${GITHUB_STEP_SUMMARY:-/dev/null}"
  exit 1
fi
echo "Only patchable files changed."
