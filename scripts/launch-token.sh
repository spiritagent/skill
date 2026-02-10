#!/bin/bash
# Usage: launch-token.sh '<json_config>'
#
# JSON must include at minimum: { "name": "...", "symbol": "..." }
# Optional: "version": "v3" or "v4" (default: "v4")
#   v3 = Uniswap v3 pools (pool.quoteToken, pool.initialMarketCap, vault.durationInDays)
#   v4 = Uniswap v4 pools (pool.pairedToken, pool.positions, vault.lockupDuration, fees, sniperFees, presale, etc.)
#
# Examples:
#   v4: launch-token.sh '{"name":"MyToken","symbol":"TKN","image":"ipfs://...","vault":{"percentage":10,"lockupDuration":2592000}}'
#   v3: launch-token.sh '{"name":"MyToken","symbol":"TKN","version":"v3","pool":{"initialMarketCap":10},"vault":{"percentage":5,"durationInDays":30}}'
set -euo pipefail

source "$(dirname "$0")/../.env" 2>/dev/null || true

CONFIG="$1"

if [[ -z "$CONFIG" ]]; then
    echo "Usage: $0 '<json_config>'"
    echo "  JSON must include: name, symbol"
    exit 1
fi

if [[ -z "${PLATFORM_API_URL:-}" || -z "${PLATFORM_API_KEY:-}" ]]; then
    echo "PLATFORM_API_URL and PLATFORM_API_KEY must be set"
    exit 1
fi

# Validate required fields
NAME=$(echo "$CONFIG" | jq -r '.name // empty')
SYMBOL=$(echo "$CONFIG" | jq -r '.symbol // empty')

if [[ -z "$NAME" || -z "$SYMBOL" ]]; then
    echo "ERROR: name and symbol are required in the JSON config"
    exit 1
fi

VERSION=$(echo "$CONFIG" | jq -r '.version // "v4"')
echo "Launching token $NAME ($SYMBOL) on Base via Clanker $VERSION..."

RESPONSE=$(curl -s -w "\n%{http_code}" \
    -X POST \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $PLATFORM_API_KEY" \
    -d "$CONFIG" \
    "$PLATFORM_API_URL/api/v1/launches")

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
RESPONSE_BODY=$(echo "$RESPONSE" | sed '$d')

if [[ "$HTTP_CODE" == "201" ]]; then
    echo "Token deployment submitted!"
    echo "$RESPONSE_BODY" | jq '{
      id: .data.launch.id,
      txHash: .data.launch.txHash,
      status: .data.launch.status,
      tokenAdmin: .data.launch.tokenAdmin
    }'
else
    echo "ERROR: Launch failed (HTTP $HTTP_CODE)"
    echo "$RESPONSE_BODY" | jq . 2>/dev/null || echo "$RESPONSE_BODY"
    exit 1
fi
