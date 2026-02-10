#!/bin/bash
set -euo pipefail

# Source env
source "$(dirname "$0")/../.env"

TWEET_DATA="$1"

if [[ -z "$TWEET_DATA" ]]; then
    echo "Usage: $0 '<tweet_json>'"
    exit 1
fi

if [[ -z "${PLATFORM_API_URL:-}" || -z "${PLATFORM_API_KEY:-}" || -z "${AGENT_ID:-}" ]]; then
    echo "⚠️  Platform not configured, skipping tweet report"
    exit 0
fi

echo "🐦 Reporting tweet to platform..."

# Build tweet event payload
TWEET_PAYLOAD=$(echo "$TWEET_DATA" | jq \
    --arg agentId "$AGENT_ID" \
    --arg eventType "tweet" \
    --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '{
        agentId: $agentId,
        eventType: $eventType,
        timestamp: $timestamp,
        tweet: .
    }'
)

# Send tweet event
RESPONSE=$(curl -s -w "%{http_code}" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $PLATFORM_API_KEY" \
    -d "$TWEET_PAYLOAD" \
    "$PLATFORM_API_URL/api/events/tweet" 2>/dev/null || echo "000")

HTTP_CODE="${RESPONSE: -3}"
RESPONSE_BODY="${RESPONSE%???}"

if [[ "$HTTP_CODE" == "200" || "$HTTP_CODE" == "201" ]]; then
    echo "✅ Tweet reported successfully"
    if [[ -n "$RESPONSE_BODY" ]]; then
        echo "$RESPONSE_BODY" | jq . 2>/dev/null || echo "$RESPONSE_BODY"
    fi
else
    echo "⚠️  Tweet report failed (HTTP $HTTP_CODE)"
    echo "$RESPONSE_BODY"
fi