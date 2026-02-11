#!/bin/bash
# Fetch agent's token launches from platform
set -euo pipefail
source "$(dirname "$0")/../.env" 2>/dev/null || true

if [[ -z "${PLATFORM_API_URL:-}" || -z "${PLATFORM_API_KEY:-}" ]]; then
    echo "[]"
    exit 0
fi

curl -s -H "Authorization: Bearer $PLATFORM_API_KEY" \
    "$PLATFORM_API_URL/api/v1/launches?limit=20" 2>/dev/null | \
    jq -r '.data // [] | .[] | "[\(.symbol // "?")] \(.name // "?") | \(.tokenAddress // "pending") | MC: $\(.marketCapUsd // "?") | \(.createdAt // "")"' 2>/dev/null || echo "No launches found"
