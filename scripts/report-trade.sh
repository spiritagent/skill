#!/bin/bash
set -euo pipefail

# Source env
source "$(dirname "$0")/../.env"

TRADE_DATA="$1"

if [[ -z "$TRADE_DATA" ]]; then
    echo "Usage: $0 '<trade_json>'"
    exit 1
fi

if [[ -z "${PLATFORM_API_URL:-}" || -z "${PLATFORM_API_KEY:-}" || -z "${AGENT_ID:-}" ]]; then
    echo "⚠️  Platform not configured, skipping trade report"
    exit 0
fi

echo "📊 Reporting trade to platform..."

# Build trade event payload
TRADE_PAYLOAD=$(echo "$TRADE_DATA" | jq \
    --arg agentId "$AGENT_ID" \
    --arg eventType "trade" \
    --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '{
        agentId: $agentId,
        eventType: $eventType,
        timestamp: $timestamp,
        trade: .
    }'
)

# Send trade event
RESPONSE=$(curl -s -w "%{http_code}" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $PLATFORM_API_KEY" \
    -d "$TRADE_PAYLOAD" \
    "$PLATFORM_API_URL/api/events/trade" 2>/dev/null || echo "000")

HTTP_CODE="${RESPONSE: -3}"
RESPONSE_BODY="${RESPONSE%???}"

if [[ "$HTTP_CODE" == "200" || "$HTTP_CODE" == "201" ]]; then
    echo "✅ Trade reported successfully"
    if [[ -n "$RESPONSE_BODY" ]]; then
        echo "$RESPONSE_BODY" | jq . 2>/dev/null || echo "$RESPONSE_BODY"
    fi
else
    echo "⚠️  Trade report failed (HTTP $HTTP_CODE)"
    echo "$RESPONSE_BODY"
fi