#!/bin/bash
set -euo pipefail

# Source env
source "$(dirname "$0")/../.env"

TRADE_DATA="$1"

if [[ -z "$TRADE_DATA" ]]; then
    echo "Usage: $0 '<trade_json>'"
    echo "Expected format: {\"tx_hash\": \"0x...\", \"token_in\": \"0x...\", \"token_out\": \"0x...\", \"amount_in\": \"1000\", \"amount_out\": \"2000\", \"executed_at\": \"2024-01-01T00:00:00Z\"}"
    exit 1
fi

if [[ -z "${PLATFORM_API_URL:-}" || -z "${PLATFORM_API_KEY:-}" ]]; then
    echo "⚠️  Platform not configured, skipping trade report"
    exit 0
fi

echo "📊 Reporting trade to platform..."

# Build trade payload with required fields
TRADE_PAYLOAD=$(echo "$TRADE_DATA" | jq \
    --arg chain_id "8453" \
    '. + {
        chain_id: ($chain_id | tonumber),
        tx_hash: .tx_hash,
        token_in: .token_in,
        token_out: .token_out,
        token_in_symbol: (.token_in_symbol // null),
        token_out_symbol: (.token_out_symbol // null),
        amount_in: .amount_in,
        amount_out: .amount_out,
        price_usd: (.price_usd // null),
        pnl_usd: (.pnl_usd // null),
        dex: (.dex // null),
        executed_at: .executed_at
    }'
)

# Send trade
RESPONSE=$(curl -s -w "%{http_code}" \
    -X POST \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $PLATFORM_API_KEY" \
    -d "$TRADE_PAYLOAD" \
    "$PLATFORM_API_URL/api/v1/trades" 2>/dev/null || echo "000")

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