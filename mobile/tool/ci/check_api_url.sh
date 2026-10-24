#!/usr/bin/env bash
# Validates the production API base URL baked into release builds and patches:
# HTTPS, a public host, the /api/v1 prefix, no trailing slash.
set -euo pipefail

url=${1:-}
if [ -z "$url" ]; then
  echo "::error::Repository variable MOBILE_API_BASE_URL is not set (e.g. https://<service>.onrender.com/api/v1)."
  exit 1
fi
if ! [[ $url =~ ^https://([A-Za-z0-9.-]+)(:[0-9]+)?/api/v1$ ]]; then
  echo "::error::MOBILE_API_BASE_URL must look like https://<host>/api/v1 (HTTPS, /api/v1 prefix, no trailing slash). Got: $url"
  exit 1
fi
host=${BASH_REMATCH[1],,}
if [[ $host == localhost || $host == *.local || $host =~ ^(127\.|10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[01])\.|0\.) ]]; then
  echo "::error::MOBILE_API_BASE_URL points at a local/private host ($host); release builds must use the deployed API."
  exit 1
fi
echo "API base URL OK: $url"
