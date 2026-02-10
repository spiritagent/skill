#!/bin/bash
set -euo pipefail

# Source env
source "$(dirname "$0")/../.env"

if [[ -z "${PLATFORM_API_URL:-}" || -z "${PLATFORM_API_KEY:-}" ]]; then
    echo "⚠️  Platform not configured, skipping heartbeat"
    exit 0
fi

echo "💓 Sending heartbeat to platform..."

# Send heartbeat - no body required, just auth header
RESPONSE=$(curl -s -w "%{http_code}" \
    -X POST \
    -H "Authorization: Bearer $PLATFORM_API_KEY" \
    "$PLATFORM_API_URL/api/v1/agents/heartbeat" 2>/dev/null || echo "000")

HTTP_CODE="${RESPONSE: -3}"
RESPONSE_BODY="${RESPONSE%???}"

if [[ "$HTTP_CODE" == "200" || "$HTTP_CODE" == "204" ]]; then
    echo "✅ Heartbeat sent successfully"
    if [[ -n "$RESPONSE_BODY" ]]; then
        echo "$RESPONSE_BODY" | jq . 2>/dev/null || echo "$RESPONSE_BODY"
    fi
else
    echo "⚠️  Heartbeat failed (HTTP $HTTP_CODE)"
    echo "$RESPONSE_BODY"
fi