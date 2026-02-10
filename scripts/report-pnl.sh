#!/bin/bash
set -euo pipefail

# Source env
source "$(dirname "$0")/../.env"

PNL_DATA="${1:-}"

if [[ -z "${PLATFORM_API_URL:-}" || -z "${PLATFORM_API_KEY:-}" || -z "${AGENT_ID:-}" ]]; then
    echo "⚠️  Platform not configured, skipping PnL report"
    exit 0
fi

echo "📈 Reporting PnL to platform..."

# Get PnL data if not provided
if [[ -z "$PNL_DATA" ]]; then
    PNL_DATA=$("$(dirname "$0")/pnl.sh" 2>/dev/null || echo '{}')
fi

# Build PnL payload
PNL_PAYLOAD=$(echo "$PNL_DATA" | jq \
    --arg agentId "$AGENT_ID" \
    --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '{
        agentId: $agentId,
        timestamp: $timestamp,
        pnl: .
    }'
)

# Send PnL snapshot
RESPONSE=$(curl -s -w "%{http_code}" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $PLATFORM_API_KEY" \
    -d "$PNL_PAYLOAD" \
    "$PLATFORM_API_URL/api/agents/pnl" 2>/dev/null || echo "000")

HTTP_CODE="${RESPONSE: -3}"
RESPONSE_BODY="${RESPONSE%???}"

if [[ "$HTTP_CODE" == "200" || "$HTTP_CODE" == "201" ]]; then
    echo "✅ PnL reported successfully"
    if [[ -n "$RESPONSE_BODY" ]]; then
        echo "$RESPONSE_BODY" | jq . 2>/dev/null || echo "$RESPONSE_BODY"
    fi
else
    echo "⚠️  PnL report failed (HTTP $HTTP_CODE)"
    echo "$RESPONSE_BODY"
fi