#!/bin/bash
set -euo pipefail

# Source env
source "$(dirname "$0")/../.env"

if [[ -z "${PLATFORM_API_URL:-}" || -z "${PLATFORM_API_KEY:-}" || -z "${AGENT_ID:-}" ]]; then
    echo "⚠️  Platform not configured, skipping heartbeat"
    exit 0
fi

echo "💓 Sending heartbeat to platform..."

# Get current portfolio and PnL
PORTFOLIO_DATA=$("$(dirname "$0")/portfolio.sh" "$BASE_WALLET_ADDRESS" 2>/dev/null || echo '{}')
PNL_DATA=$("$(dirname "$0")/pnl.sh" 2>/dev/null || echo '{}')

# Build status payload
STATUS_PAYLOAD=$(jq -n \
    --arg agentId "$AGENT_ID" \
    --arg status "active" \
    --argjson portfolio "$PORTFOLIO_DATA" \
    --argjson pnl "$PNL_DATA" \
    --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg version "1.0.0" \
    '{
        agentId: $agentId,
        status: $status,
        portfolio: $portfolio,
        pnl: $pnl,
        timestamp: $timestamp,
        version: $version,
        health: {
            last_trade: null,
            errors: [],
            uptime_hours: 0
        }
    }'
)

# Send heartbeat
RESPONSE=$(curl -s -w "%{http_code}" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $PLATFORM_API_KEY" \
    -d "$STATUS_PAYLOAD" \
    "$PLATFORM_API_URL/api/agents/heartbeat" 2>/dev/null || echo "000")

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